# Colocated Parsers

This directory contains optional parser repositories that are colocated with the project-router infrastructure.

## Overview

Parsers can be deployed in two ways:

1. **Independent** — Parser repos in separate locations, communicate via NATS over the network
2. **Colocated** — Parser repos cloned into this directory, share the same NATS instance locally

## Using Colocated Parsers

### Clone a Parser

```bash
# Clone a parser into this directory
git clone https://github.com/your-org/time-entry-notes-parser.git time-entry-notes-parser

# Or symlink an existing clone
ln -s ../time-entry-notes-parser time-entry-notes-parser
```

### Start All Colocated Parsers

```bash
# From the parent directory
bash parsers/start-all.sh

# Or via Makefile
make start-all-parsers
```

The `start-all.sh` script uses a **command decorator pattern** — it discovers parser subdirectories and invokes their `bin/start.sh` without knowing implementation details.

### Parser Structure

Each parser must have a `bin/start.sh` script that:
- Loads environment variables from the parent `.env`
- Activates its virtual environment
- Starts its listener and writer (or publisher, depending on type)
- Waits for processes to complete

Example `bin/start.sh`:

```bash
#!/bin/bash
PARSER_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PARSER_ROOT/.." && pwd)"

# Load environment
if [ -f "$REPO_ROOT/.env" ]; then
    export $(grep -v '^#' "$REPO_ROOT/.env" | xargs)
fi

# Defaults
export NATS_URL="${NATS_URL:-tls://docker:4222}"
export CERTS_DIR="${CERTS_DIR:-$REPO_ROOT/nats/certs}"

# Activate venv
source "$PARSER_ROOT/.venv/bin/activate"

cd "$PARSER_ROOT"

# Start components
python3 nats_[PARSER_NAME]_listener.py &
LISTENER_PID=$!

python3 nats_writer.py &
WRITER_PID=$!

wait $LISTENER_PID $WRITER_PID
```

## System Architecture

### Workflow

```
┌─────────────────────────────────────────┐
│        project-router (root)            │
├──────────────────┬──────────────────────┤
│  nats/           │  parsers/            │
│  ├─ Makefile     │  ├─ start-all.sh     │
│  ├─ nats-conf    │  ├─ [parser-1]/      │
│  └─ gen-certs.sh │  ├─ [parser-2]/      │
│                  │  └─ [parser-3]/      │
└──────────────────┴──────────────────────┘
         ↓                   ↓
   NATS Server        Colocated Parsers
   (Docker)           (py3 processes)
         ↓                   ↓
         └─────────────┬──────────┘
                       ↓
            NATS Topic Communication
```

## Environment Variables

Colocated parsers inherit from the parent `.env` file created during `make install`:

```bash
NATS_URL=tls://docker:4222
NATS_PORT=4222
CERTS_DIR=/path/to/nats/certs
```

Each parser's `bin/start.sh` sets sensible defaults if these are not exported.

## Stopping Colocated Parsers

### Method 1: SIGINT (Ctrl+C)

If running `bash parsers/start-all.sh` in the foreground, press Ctrl+C to stop all parsers gracefully.

### Method 2: Kill via PID file

```bash
kill $(cat parsers/.pids)
```

### Method 3: Make target

```bash
make down
```

This stops the NATS server and all associated components.

## Independent (Non-Colocated) Parsers

Parsers not in this directory can still communicate via NATS if:

1. They have `bin/start.sh` (or equivalent startup script)
2. They have access to the same NATS URL and TLS certificates
3. Environment variables are exported: `NATS_URL`, `CERTS_DIR`

Example (from another directory):

```bash
export NATS_URL="tls://docker:4222"
export CERTS_DIR="/path/to/project-router/nats/certs"
bash /path/to/time-entry-notes-parser/bin/start.sh
```

## Workflow Examples

### Full System with Colocated Parsers

```bash
# 1. Setup
make install

# 2. Start NATS server (from nats/ Makefile)
make nats-up

# 3. Start all colocated parsers
bash parsers/start-all.sh

# 4. Monitor
make status
```

### Add New Parser to Colocated Setup

```bash
# Clone parser
git clone <parser-repo> parsers/[parser-name]

# Install its dependencies
source parsers/[parser-name]/.venv/bin/activate
pip install -e parsers/[parser-name]

# Start
bash parsers/start-all.sh
```

### Scale Out (Move Parser Out)

If you want to move a colocated parser to a separate machine:

1. Remove from this directory: `rm -rf parsers/[parser-name]`
2. Clone on the remote machine
3. Set environment variables pointing to the NATS server
4. Run `bin/start.sh` on the remote machine

Communication via NATS continues to work seamlessly.

## Troubleshooting

### Parser doesn't have bin/start.sh

Check that the parser repo has the required script:

```bash
ls parsers/[parser-name]/bin/start.sh
```

If missing, add it using the template above.

### NATS connection fails

Verify:
1. NATS server is running: `make nats-status`
2. Environment variables are set: `echo $NATS_URL $CERTS_DIR`
3. Certificates exist: `ls nats/certs/`

### Parser process exits immediately

Check logs:

```bash
# If running via start-all.sh, look for error output
bash parsers/start-all.sh 2>&1 | tail -50

# Or check individual parser logs
tail -f /tmp/listener-[parser-name].log
```

## Notes

- Each colocated parser runs in its own shell process (background)
- Parser startup is sequential (first parser starts, then second, etc.)
- If one parser fails to start, others will still be attempted
- The `.pids` file tracks all running parser PIDs for cleanup
