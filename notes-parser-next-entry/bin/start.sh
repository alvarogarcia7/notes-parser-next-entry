#!/bin/bash
# Start next entry parser listener and writer
set -e

PARSER_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PARSER_ROOT/.." && pwd)"

# Load environment from parent .env if it exists
if [ -f "$REPO_ROOT/.env" ]; then
    export $(grep -v '^#' "$REPO_ROOT/.env" | xargs)
fi

# Set defaults if not already set
export NATS_URL="${NATS_URL:-tls://docker:4222}"
export CERTS_DIR="${CERTS_DIR:-$REPO_ROOT/nats/certs}"

# Activate virtual environment if it exists
if [ -f "$PARSER_ROOT/.venv/bin/activate" ]; then
    source "$PARSER_ROOT/.venv/bin/activate"
fi

# Change to parser directory
cd "$PARSER_ROOT"

# Start listener and writer
python3 nats_next_listener.py &
LISTENER_PID=$!
echo "[next-parser] Listener started (PID: $LISTENER_PID)"

python3 nats_writer.py &
WRITER_PID=$!
echo "[next-parser] Writer started (PID: $WRITER_PID)"

# Wait for both processes
wait $LISTENER_PID $WRITER_PID
