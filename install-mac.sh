#!/bin/bash
# Installation script for macOS (bash 3.2+)
# Sets up the project with:
# - Git submodule initialization
# - Virtual environments (no system package modifications)
# - Docker for NATS server
# - Available port discovery and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v git &> /dev/null; then
    print_error "Git is not installed"
    exit 1
fi
print_success "Git found"

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker Desktop for Mac"
    exit 1
fi
print_success "Docker found"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed"
    exit 1
fi
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
print_success "Python $PYTHON_VERSION found"

# Initialize git submodules
print_step "Initializing Git submodules..."
git submodule update --init --recursive
print_success "Submodules initialized"

# Find available ports
print_step "Finding available ports..."
NATS_PORT=$(bash find-available-port.sh 4222)
if [ $? -ne 0 ]; then
    print_error "Could not find available port for NATS"
    exit 1
fi
print_success "Found available NATS port: $NATS_PORT"

# Create .env file with configuration
print_step "Creating environment configuration..."
ENV_FILE=".env"

cat > "$ENV_FILE" << EOF
# NATS Configuration (auto-configured by install-mac.sh)
NATS_URL=tls://localhost:$NATS_PORT
NATS_PORT=$NATS_PORT

# TLS Certificate Directory
CERTS_DIR=\$(pwd)/certs

# Docker Configuration
DOCKER_REGISTRY=docker.io
NATS_IMAGE=nats:latest
EOF

print_success "Created $ENV_FILE with NATS_PORT=$NATS_PORT"

# Create virtual environments for each project
print_step "Setting up Python virtual environments..."

setup_venv() {
    local project=$1
    local venv_path="$project/.venv"

    if [ -d "$venv_path" ]; then
        print_warning "$project virtual environment already exists"
        return
    fi

    print_step "Creating virtual environment for $project..."
    python3 -m venv "$venv_path"
    source "$venv_path/bin/activate"

    # Upgrade pip
    pip install --upgrade pip setuptools wheel > /dev/null 2>&1

    # Install project dependencies
    if [ -f "$project/requirements.txt" ]; then
        pip install -r "$project/requirements.txt" > /dev/null 2>&1
        print_success "Installed dependencies for $project"
    elif [ -f "$project/pyproject.toml" ]; then
        pip install -e "$project" > /dev/null 2>&1
        print_success "Installed $project from pyproject.toml"
    else
        print_warning "No requirements.txt or pyproject.toml found for $project"
    fi

    deactivate
}

# Set up virtual environments for each parser
setup_venv "google-keep-notes-parser"
setup_venv "training-parser-antlr4"
setup_venv "time-entry-notes-parser"
setup_venv "notes-parser-next-entry"
setup_venv "project-router"

# Update nats-server.conf with dynamic port
print_step "Configuring NATS server for port $NATS_PORT..."
if [ -f "nats-server.conf" ]; then
    # Create backup
    cp nats-server.conf nats-server.conf.backup

    # Update port (handles both listen and http directives)
    sed -i.bak "s/listen: 0.0.0.0:[0-9]\+/listen: 0.0.0.0:$NATS_PORT/" nats-server.conf
    sed -i.bak "s/http: 0.0.0.0:[0-9]\+/http: 0.0.0.0:$((NATS_PORT + 4000))/" nats-server.conf
    rm -f nats-server.conf.bak

    print_success "Updated nats-server.conf"
fi

# Generate TLS certificates if they don't exist
print_step "Checking TLS certificates..."
if [ ! -f "certs/rootCA.pem" ]; then
    print_step "Generating TLS certificates..."
    bash gen-certs.sh
    print_success "TLS certificates generated"
else
    print_success "TLS certificates already exist"
fi

# Source the .env file for this session
source ".env"

# Summary
print_step "Installation complete!"
echo ""
echo -e "${GREEN}Configuration Summary:${NC}"
echo "  NATS URL:       $NATS_URL"
echo "  NATS Port:      $NATS_PORT"
echo "  Certs Dir:      $CERTS_DIR"
echo "  Python:         $(python3 --version)"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Source environment variables:"
echo "     source .env"
echo ""
echo "  2. Run NATS server with Docker:"
echo "     docker run -d --name nats-server -p $NATS_PORT:4222 -v \$(pwd)/certs:/certs:ro -v \$(pwd)/nats-server.conf:/etc/nats/nats-server.conf:ro nats:latest -c /etc/nats/nats-server.conf"
echo ""
echo "  3. Start the pipelines:"
echo "     python3 google-keep-notes-parser/nats_publisher.py"
echo ""
echo -e "${YELLOW}Note:${NC} Each project has a virtual environment in .venv/"
echo "To use a specific project's environment:"
echo "  source project-name/.venv/bin/activate"
echo ""
