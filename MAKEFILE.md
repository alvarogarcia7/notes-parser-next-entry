# Makefile Control Plane

The `Makefile` provides a complete control plane for managing the NATS pipeline system. It handles starting, stopping, and monitoring all components.

## Quick Start

```bash
# Start the entire system
make up

# Check system status
make status

# Stop the entire system
make down
```

## System Control Targets

### `make up`
Starts all components in the correct order:
1. NATS server (port configurable)
2. All listeners (depend on NATS being up)
3. All writers (depend on NATS being up)
4. Publisher (depends on NATS being up)

**Example:**
```bash
$ make up
...
╔════════════════════════════════════════════════════════════╗
║                    System Started                          ║
╚════════════════════════════════════════════════════════════╝

Active Components:
  ✓ NATS server (port 4222)
  ✓ Time entry listener & writer
  ✓ Training listener & writer
  ✓ Next entry listener & writer
  ✓ Google Keep publisher

Check logs: make logs
Stop system: make down
```

### `make down`
Stops all running components gracefully in reverse order:
1. Listeners
2. Writers
3. Publisher
4. NATS server

**Example:**
```bash
$ make down
▶ Stopping all components...

Stopping listeners...
✓ Listeners stopped

Stopping writers...
✓ Writers stopped

Stopping publisher...
✓ Publisher stopped

Stopping NATS server...
✓ NATS server stopped

╔════════════════════════════════════════════════════════════╗
║                    System Stopped                          ║
╚════════════════════════════════════════════════════════════╝
```

### `make status`
Shows the current health status of all components:

**Example:**
```bash
$ make status
════════════════════════════════════════════════════════════
                   System Status
════════════════════════════════════════════════════════════

NATS Server:
✓ NATS server is running

Listeners:
✓ listener-time (PID: 12345)
✓ listener-training (PID: 12346)
✓ listener-next (PID: 12347)

Writers:
✓ writer-time (PID: 12348)
✓ writer-training (PID: 12349)
✓ writer-next (PID: 12350)

Publisher:
✓ publisher (PID: 12351)
```

### `make logs`
Displays log file locations for each component:

**Example:**
```bash
$ make logs
════════════════════════════════════════════════════════════
                   System Logs
════════════════════════════════════════════════════════════

Time Entry:
  Listener: tail -f /tmp/listener-time.log
  Writer:   tail -f /tmp/writer-time.log

Training:
  Listener: tail -f /tmp/listener-training.log
  Writer:   tail -f /tmp/writer-training.log

Next Entry:
  Listener: tail -f /tmp/listener-next.log
  Writer:   tail -f /tmp/writer-next.log

Publisher:
  tail -f /tmp/publisher.log
```

### `make clean`
Stops all components and cleans up process files and logs.

```bash
make clean
```

## NATS Server Targets

### `make nats-up`
Starts the NATS server in Docker:
- Loads TLS certificates from `CERTS_DIR`
- Uses configuration from `nats-server.conf`
- Exposes port `NATS_PORT` (default: 4222)

**Example:**
```bash
$ make nats-up
▶ Starting NATS server...
✓ NATS server started on port 4222
```

### `make nats-down`
Stops and removes the NATS Docker container:

**Example:**
```bash
$ make nats-down
▶ Stopping NATS server...
✓ NATS server stopped
```

### `make nats-status`
Checks if NATS server is running:

```bash
$ make nats-status
✓ NATS server is running
```

## Individual Listener Targets

Each listener depends on NATS being up and will automatically start NATS if needed.

### `make listener-time`
Starts the time entry listener:
- Parses time entry notes from NATS
- Publishes to `messages.20.type.time` topic
- Logs to `/tmp/listener-time.log`

### `make listener-training`
Starts the training listener:
- Parses training sessions with ANTLR4
- Publishes to `messages.20.type.training` topic
- Logs to `/tmp/listener-training.log`

### `make listener-hn`
Starts the HackerNews listener:
- Currently not implemented
- Placeholder for future use

### `make listener-next`
Starts the next entry listener:
- Parses action items from notes
- Publishes to `messages.20.type.next` topic
- Logs to `/tmp/listener-next.log`

## Individual Writer Targets

Writers subscribe to parsed topics and write results to disk.

### `make writer-time`
Writes parsed time entries to `/tmp/time-entries/`

### `make writer-training`
Writes parsed training sessions to `/tmp/training/`

### `make writer-hn`
HackerNews writer (not implemented)

### `make writer-next`
Writes parsed action items to `/tmp/next-entries/`

## Publisher Target

### `make publisher`
Starts the Google Keep notes publisher:
- Reads notes from `google-keep-notes-parser/sample/` directory
- Publishes to `messages.10.raw` topic
- Logs to `/tmp/publisher.log`

## Environment Configuration

The Makefile automatically sources `.env` if it exists:

```bash
cat .env
NATS_URL=tls://localhost:4222
NATS_PORT=4222
CERTS_DIR=/path/to/certs
```

Override environment variables:

```bash
# One-time override
make NATS_PORT=5000 up

# Or export in current shell
export NATS_PORT=5000
make up
```

## Development Targets

### `make install`
Runs the macOS installation script (`install-mac.sh`):
- Checks prerequisites
- Initializes submodules
- Creates virtual environments
- Generates TLS certificates
- Creates `.env` file

### `make env-check`
Displays current environment configuration:

```bash
$ make env-check
Environment Configuration:
  NATS_URL: tls://localhost:4222
  NATS_PORT: 4222
  CERTS_DIR: /path/to/certs
  ✓ Certificates found
```

### `make setup`
Equivalent to:
1. `make env-check`
2. `make install` (if virtual environments don't exist)

## Process Management

The Makefile tracks process IDs in `.make-pids/` directory:

```
.make-pids/
  listener-time.pid
  listener-training.pid
  listener-next.pid
  writer-time.pid
  writer-training.pid
  writer-next.pid
  publisher.pid
```

These PIDs are used for:
- Checking process status with `make status`
- Gracefully stopping processes with `make down`
- Cleanup with `make clean`

## Common Workflows

### Start Fresh

```bash
# Clean up everything
make clean

# Install/setup (if first time)
make install

# Source environment
source .env

# Start system
make up
```

### Monitor While Running

```bash
# In terminal 1: Start system
make up

# In terminal 2: Watch status
watch -n 2 'make status'

# In terminal 3: Check logs
tail -f /tmp/listener-time.log
```

### Restart a Failed Component

```bash
# Check what failed
make status

# Kill a component
kill $(cat .make-pids/listener-time.pid)

# Restart it
make listener-time

# Or restart all
make down
make up
```

### Debug a Listener

```bash
# View logs in real-time
tail -f /tmp/listener-time.log

# Or check logs after component exits
cat /tmp/listener-time.log | grep ERROR
```

## Troubleshooting

### Port Already in Use

```bash
# Find available port
PORT=$(bash find-available-port.sh 4222)

# Start with custom port
make NATS_PORT=$PORT up
```

### Virtual Environments Not Found

```bash
# Reinstall virtual environments
make install

# Or manually setup for specific project
source time-entry-notes-parser/.venv/bin/activate
```

### NATS Not Responding

```bash
# Check if container is running
docker ps | grep nats

# Check logs
docker logs nats-server

# Restart NATS
make nats-down
make nats-up
```

### Processes Not Stopping

```bash
# Force kill all Python processes (careful!)
pkill -f "python3.*nats"

# Or check specific PID
cat .make-pids/listener-time.pid
kill -9 <PID>

# Clean up
make clean
```

## Makefile Structure

The Makefile is organized into sections:

1. **Configuration** - Variable definitions and environment setup
2. **NATS Server Targets** - `nats-up`, `nats-down`, `nats-status`
3. **Listener Targets** - `listener-*` targets
4. **Writer Targets** - `writer-*` targets
5. **Publisher Target** - `publisher` target
6. **System Control** - `up`, `down`, `status`, `logs`, `clean`
7. **Development Targets** - `install`, `env-check`, `setup`

## Notes

- All listener and writer processes run in the background
- Process IDs are tracked in `.make-pids/` for management
- Log files are written to `/tmp/` with component names
- The Makefile handles graceful shutdown of all processes
- Colors are used for better readability (can be disabled if needed)
- Dependencies are declared (e.g., `listener-time: nats-up`)
