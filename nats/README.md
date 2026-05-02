# NATS Infrastructure

This directory contains the NATS server infrastructure, TLS certificate generation, and the control plane Makefile for the entire system.

## Quick Start

```bash
# From the parent directory (project-router root)

# 1. Install and configure
make install

# 2. Start the entire system
make up

# 3. Check status
make status

# 4. Stop the system
make down
```

## Structure

```
nats/
├── Makefile                # Control plane for system orchestration
├── nats-server.conf        # NATS server TLS configuration
├── gen-certs.sh            # Certificate generation script (ed25519)
├── install-mac.sh          # Setup script for macOS
├── find-available-port.sh  # Dynamic port discovery
├── update-parsers.sh       # Parser version management tool
├── parser-versions.txt     # Version tracking for parsers
├── .env.sample             # Environment template
├── certs/                  # TLS certificates (generated at install)
│   ├── rootCA.key
│   ├── rootCA.pem
│   ├── server.key
│   ├── server.pem
│   ├── client.key
│   └── client.pem
└── README.md              # This file
```

## Configuration Files

### nats-server.conf

NATS server configuration with:
- TLS enabled with mutual authentication (mTLS)
- Certificate paths pointing to `/certs/`
- Authorization block mapping client certificates to users
- HTTP monitoring on port 8222 (or dynamic)

Example:

```conf
listen: 0.0.0.0:4222
http: 0.0.0.0:8222

tls {
  cert_file: "/certs/server.pem"
  key_file:  "/certs/server.key"
  ca_file:   "/certs/rootCA.pem"
  verify_and_map: true
}

authorization {
  users = [
    { user: "pipeline-client" }
  ]
}
```

### gen-certs.sh

Generates TLS certificates using ed25519 keys:

```bash
bash nats/gen-certs.sh
```

Creates:
- `certs/rootCA.key` and `certs/rootCA.pem` — root certificate authority
- `certs/server.key` and `certs/server.pem` — server certificate
- `certs/client.key` and `certs/client.pem` — client certificate

**Note:** The client certificate CN is mapped to a NATS user via `verify_and_map: true`.

### .env

Created during `make install` with dynamically discovered port:

```bash
NATS_URL=tls://localhost:4222
NATS_PORT=4222
CERTS_DIR=/path/to/nats/certs
DOCKER_REGISTRY=docker.io
NATS_IMAGE=nats:latest
```

Override variables:

```bash
# One-time
make NATS_PORT=5000 up

# Or export in shell
export NATS_PORT=5000
make up
```

## Makefile Targets

### System Control

- `make up` — Start entire system (NATS + all listeners/writers/publishers)
- `make down` — Stop entire system gracefully
- `make status` — Show health status of all components
- `make logs` — Display log file locations
- `make clean` — Stop and clean up (remove PIDs and logs)
- `make install` — Run setup (certificates, venvs, .env)
- `make env-check` — Verify environment configuration
- `make setup` — Run install if needed

### NATS Server

- `make nats-up` — Start NATS server in Docker
- `make nats-down` — Stop NATS server
- `make nats-status` — Check if NATS is running

### Listeners

Start components that parse raw messages:

- `make listener` — Start all listeners
- `make listener-time` — Time entry listener
- `make listener-training` — Training parser listener
- `make listener-hn` — HackerNews listener (placeholder)
- `make listener-next` — Next entry listener

### Writers

Start components that write parsed results to disk:

- `make writer` — Start all writers
- `make writer-time` — Time entry writer
- `make writer-training` — Training writer
- `make writer-hn` — HackerNews writer (placeholder)
- `make writer-next` — Next entry writer

### Publisher

- `make publisher` — Start Google Keep notes publisher

### Parser Bundles (convenience)

These start NATS + listener + writer for a specific parser:

- `make time` — Start time entry pipeline
- `make training` — Start training parser pipeline
- `make hn` — Start HackerNews pipeline
- `make next` — Start next entry pipeline

### Parser Updates

- `make update-parsers-check` — Check all parsers for updates
- `make update-parsers-all` — Update all parsers
- `make update-parser-[name]` — Check specific parser
- `make update-[name]` — Update specific parser
- `make parser-status` — Show parser versions
- `make parser-versions` — Show version history

## Workflow Examples

### Fresh Install

```bash
# Run from parent directory
make install

# This will:
# 1. Check prerequisites (git, docker, python3)
# 2. Initialize git submodules
# 3. Find available port
# 4. Generate TLS certificates
# 5. Create Python virtual environments
# 6. Create .env with configuration
# 7. Display next steps
```

### Start System for Development

```bash
# In terminal 1: Start system
make up

# In terminal 2: Watch status
watch -n 2 'make status'

# In terminal 3: View logs
tail -f /tmp/listener-time.log
```

### Restart a Component

```bash
# Stop listener if it crashes
kill $(cat .make-pids/listener-time.pid)

# Restart just that component
make listener-time

# Or restart all
make down
make up
```

### Update All Parsers Before Deployment

```bash
# Check for updates
make update-parsers-check

# Update all if available
make update-parsers-all

# Verify versions
make parser-versions

# Start system
make up
```

### Debug a Specific Parser

```bash
# Start just that pipeline
make time

# Watch its output
tail -f /tmp/listener-time.log
tail -f /tmp/writer-time.log

# Check results
ls -la /tmp/time-entries/
```

## Environment Variables

The system uses these environment variables (set in `.env` during install):

| Variable | Default | Purpose |
|----------|---------|---------|
| `NATS_URL` | `tls://docker:4222` | NATS server URL |
| `NATS_PORT` | `4222` | NATS server port |
| `CERTS_DIR` | `$REPO_ROOT/nats/certs` | TLS certificates directory |
| `DOCKER_REGISTRY` | `docker.io` | Docker registry for NATS image |
| `NATS_IMAGE` | `nats:latest` | Docker image name |

## TLS/mTLS Details

### Server Certificate

- Subject: CN=nats-server
- SAN: DNS:docker, DNS:localhost, IP:127.0.0.1
- Signed by rootCA

### Client Certificate

- Subject: CN=pipeline-client
- Signed by rootCA
- NATS maps CN to user via `verify_and_map: true`

### Verification

Check that TLS is working:

```bash
# Check NATS is listening on TLS
docker logs nats-pipeline-test 2>&1 | grep -i "tls\|listening"

# Try to connect without certificate (should fail)
nats sub messages.10.raw -s tls://docker:4222

# Try with certificate (should work)
nats sub messages.10.raw -s tls://docker:4222 \
  --tlscert certs/client.pem \
  --tlskey certs/client.key \
  --tlsca certs/rootCA.pem
```

## Process Management

The Makefile tracks process IDs in `.make-pids/`:

```
.make-pids/
├── listener-time.pid
├── listener-training.pid
├── listener-next.pid
├── writer-time.pid
├── writer-training.pid
├── writer-next.pid
└── publisher.pid
```

These are used by `make status` and `make down` to manage processes gracefully.

## Logs

All components log to `/tmp/`:

| Component | Log File |
|-----------|----------|
| NATS | Docker logs (via `docker logs nats-[name]`) |
| listener-time | `/tmp/listener-time.log` |
| listener-training | `/tmp/listener-training.log` |
| listener-next | `/tmp/listener-next.log` |
| writer-time | `/tmp/time-entries/` (output, not logs) |
| writer-training | `/tmp/training/` (output, not logs) |
| writer-next | `/tmp/next-entries/` (output, not logs) |
| publisher | `/tmp/publisher.log` |

View all at once:

```bash
make logs
```

## Troubleshooting

### Port Already in Use

```bash
# Find available port
PORT=$(bash find-available-port.sh 4222)
echo "Using port: $PORT"

# Start with custom port
make NATS_PORT=$PORT up
```

### NATS Won't Start

```bash
# Check Docker
docker ps | grep nats

# View NATS logs
docker logs nats-pipeline-test

# Restart
make nats-down
make nats-up
```

### Certificate Issues

```bash
# Regenerate certificates
rm -rf certs/
bash gen-certs.sh

# Verify they exist
ls -la certs/
```

### Virtual Environment Issues

```bash
# Recreate venvs
make clean
make install

# Or for specific parser
rm -rf time-entry-notes-parser/.venv
source nats/.venv/bin/activate  # Or: source Makefile's activation
pip install -e time-entry-notes-parser
```

### Process Cleanup

If processes don't stop cleanly:

```bash
# Kill all Python NATS processes
pkill -f "python3.*nats"

# Or specific PID
kill -9 $(cat .make-pids/listener-time.pid)

# Clean up
make clean
```

## Architecture Diagrams

### System Overview

```
┌─────────────────────────────────────────────────┐
│              NATS Pipeline System               │
├─────────────────────────────────────────────────┤
│                                                 │
│  Publisher (Google Keep)                        │
│         ↓                                       │
│   NATS Topic: messages.10.raw                   │
│         ↓                                       │
│    ┌─────────────────────────────────┐         │
│    │  Listeners (parsing)            │         │
│    │  - time-entry                   │         │
│    │  - training                     │         │
│    │  - next-entry                   │         │
│    └─────────────────────────────────┘         │
│         ↓                                       │
│   NATS Topics: messages.30.type.*              │
│         ↓                                       │
│    ┌─────────────────────────────────┐         │
│    │  Writers (persistence)          │         │
│    │  - time-entries/ (disk)         │         │
│    │  - training/ (disk)             │         │
│    │  - next-entries/ (disk)         │         │
│    └─────────────────────────────────┘         │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Message Flow

```
Google Keep Notes
       ↓
   Publisher
       ↓
  NATS Server (mTLS)
  ├─ Listener-Time
  ├─ Listener-Training
  └─ Listener-Next
       ↓
   Parsing (in-process)
       ↓
   Writer (same as Listener in some cases)
       ↓
   Disk Storage (/tmp/*)
```

## Related Documentation

- `../README.md` — System overview
- `../parsers/README.md` — Colocated parser management
- `../MAKEFILE.md` — Detailed Makefile documentation
- `../UPDATE-PARSERS.md` — Parser update tool reference
