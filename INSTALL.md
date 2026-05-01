# Installation Guide for macOS

This guide explains how to set up the NATS pipeline project on macOS with Docker.

## Prerequisites

- **macOS** (bash 3.2+)
- **Docker Desktop** for Mac ([download](https://docs.docker.com/desktop/install/mac-install/))
- **Python 3.x** (check with `python3 --version`)
- **Git** (should be available on macOS)

## Quick Start

### 1. Automated Installation

Run the installation script (recommended):

```bash
bash install-mac.sh
```

This script will:
- ✓ Check prerequisites (Git, Docker, Python)
- ✓ Initialize Git submodules
- ✓ Find available ports automatically
- ✓ Create `.env` file with configuration
- ✓ Set up Python virtual environments for each project
- ✓ Generate TLS certificates
- ✓ Configure NATS server

### 2. Manual Setup (if needed)

If you prefer manual setup:

```bash
# 1. Initialize submodules
git submodule update --init --recursive

# 2. Find available port
NATS_PORT=$(bash find-available-port.sh 4222)
echo "NATS_PORT=$NATS_PORT"

# 3. Create .env file
cat > .env << EOF
NATS_URL=tls://localhost:$NATS_PORT
NATS_PORT=$NATS_PORT
CERTS_DIR=$(pwd)/certs
EOF

# 4. Source the configuration
source .env

# 5. Generate TLS certificates (if not present)
bash gen-certs.sh

# 6. Set up Python virtual environments
python3 -m venv google-keep-notes-parser/.venv
source google-keep-notes-parser/.venv/bin/activate
pip install -r google-keep-notes-parser/requirements.txt
deactivate

# (Repeat for other projects)
```

## Running NATS Server

### With Docker

```bash
# Make sure .env is sourced
source .env

# Start NATS server
docker run -d \
    --name nats-server \
    -p $NATS_PORT:4222 \
    -v $(pwd)/certs:/certs:ro \
    -v $(pwd)/nats-server.conf:/etc/nats/nats-server.conf:ro \
    nats:latest \
    -c /etc/nats/nats-server.conf
```

## Running the Pipeline

### 1. Start NATS Server (first terminal)

```bash
source .env
docker run -d --name nats-server \
    -p $NATS_PORT:4222 \
    -v $(pwd)/certs:/certs:ro \
    -v $(pwd)/nats-server.conf:/etc/nats/nats-server.conf:ro \
    nats:latest \
    -c /etc/nats/nats-server.conf
```

### 2. Publisher (second terminal)

```bash
source .env
source google-keep-notes-parser/.venv/bin/activate
python3 google-keep-notes-parser/nats_publisher.py
```

### 3. Listeners (separate terminals)

```bash
# Time Entry Listener
source .env
source time-entry-notes-parser/.venv/bin/activate
python3 time-entry-notes-parser/nats_time_listener.py

# Training Listener
source .env
source training-parser-antlr4/.venv/bin/activate
python3 training-parser-antlr4/nats_training_listener.py

# Next Entry Listener
source .env
source notes-parser-next-entry/.venv/bin/activate
python3 notes-parser-next-entry/nats_next_listener.py
```

### 4. Writers (separate terminals)

```bash
# Time Entry Writer
source .env
source time-entry-notes-parser/.venv/bin/activate
python3 time-entry-notes-parser/nats_writer.py

# Training Writer
source .env
source training-parser-antlr4/.venv/bin/activate
python3 training-parser-antlr4/nats_writer.py

# Next Entry Writer
source .env
source notes-parser-next-entry/.venv/bin/activate
python3 notes-parser-next-entry/nats_writer.py
```

## Environment Variables

The following environment variables are used:

| Variable | Default | Description |
|----------|---------|-------------|
| `NATS_URL` | `tls://localhost:4222` | NATS server URL |
| `NATS_PORT` | `4222` | NATS server port |
| `CERTS_DIR` | `./certs` | TLS certificates directory |

Example:
```bash
export NATS_URL=tls://localhost:5000
export NATS_PORT=5000
export CERTS_DIR=/path/to/certs
```

## Port Discovery

To find an available port without using the installation script:

```bash
bash find-available-port.sh 4222
```

This will:
- Start at port 4222
- Check if port is in use
- Return the first available port
- Exit with error if no port available

## Cleanup

To remove Docker containers and virtual environments:

```bash
# Stop and remove NATS container
docker stop nats-server nats-pipeline-test 2>/dev/null || true
docker rm nats-server nats-pipeline-test 2>/dev/null || true

# Remove virtual environments
rm -rf google-keep-notes-parser/.venv
rm -rf training-parser-antlr4/.venv
rm -rf time-entry-notes-parser/.venv
rm -rf notes-parser-next-entry/.venv
rm -rf project-router/.venv
```

## Troubleshooting

### Port already in use

If port 4222 is already in use:

```bash
# Find available port
NEW_PORT=$(bash find-available-port.sh 4222)

# Update .env
sed -i '' "s/NATS_PORT=.*/NATS_PORT=$NEW_PORT/" .env
sed -i '' "s/NATS_URL=.*/NATS_URL=tls:\/\/localhost:$NEW_PORT/" .env

source .env
```

### Docker connection issues

On macOS, Docker Desktop may need to be restarted:

```bash
# Restart Docker
osascript -e 'quit app "Docker"'
sleep 2
open -a Docker
```

### Certificate issues

Regenerate TLS certificates:

```bash
rm -rf certs/
bash gen-certs.sh
```

### Python module not found

Ensure the virtual environment is activated:

```bash
source project-name/.venv/bin/activate
python3 -c "import nats"  # Should not error
```

## Notes

- Virtual environments are created per project (no system-wide Python modifications)
- All scripts use bash 3.2 for macOS compatibility
- Docker is required for NATS server (no local installation needed)
- TLS certificates are self-signed and generated on first install
- Port discovery automatically finds available ports (no port conflicts)
