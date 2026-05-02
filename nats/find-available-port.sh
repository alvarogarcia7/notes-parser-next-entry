#!/bin/bash
# Find an available TCP port (>1000) on the system
# Usage: PORT=$(bash find-available-port.sh [start_port])
# Default start_port is 4222

START_PORT=${1:-4222}

# Function to check if port is available (Mac and Linux compatible)
is_port_available() {
    local port=$1

    # Try to bind to the port using a simple TCP check
    # This works on both Mac (bash 3.2+) and Linux
    if command -v nc &> /dev/null; then
        # Using netcat (most reliable)
        timeout 1 bash -c "</dev/tcp/localhost/$port" 2>/dev/null
        if [ $? -ne 0 ]; then
            return 0  # Port is available
        fi
    else
        # Fallback: check if port is in use
        lsof -i :$port &> /dev/null
        if [ $? -ne 0 ]; then
            return 0  # Port is available
        fi
    fi

    return 1  # Port is in use
}

# Find available port starting from START_PORT
PORT=$START_PORT
MAX_ATTEMPTS=100
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if is_port_available $PORT; then
        echo $PORT
        exit 0
    fi
    PORT=$((PORT + 1))
    ATTEMPT=$((ATTEMPT + 1))
done

# If we get here, no available port was found
echo "Error: Could not find available port after $MAX_ATTEMPTS attempts" >&2
exit 1
