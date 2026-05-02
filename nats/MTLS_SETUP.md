# Mutual TLS (mTLS) Setup for NATS

This NATS infrastructure uses **mutual TLS (mTLS)** to secure all client-server communication. Both the server and clients present certificates signed by a shared Certificate Authority (CA), ensuring that:

- **Server authentication**: Clients verify the NATS server's identity
- **Client authentication**: The server verifies each client's certificate
- **Authorization**: Certificate Common Names (CNs) are mapped to NATS users with specific permissions
- **Encryption**: All traffic is encrypted end-to-end

## Architecture Overview

```
Certificate Authority (CA)
    ├─ Generates and signs:
    ├─ Server certificate (nats-server)
    └─ Client certificate (pipeline-client)

NATS Server
    ├─ Presents: server.pem + server.key
    ├─ Trusts CA: rootCA.pem
    └─ Verifies client certs with verify_and_map: true

Python Clients (Publishers, Listeners, Writers)
    ├─ Present: client.pem + client.key
    ├─ Trust CA: rootCA.pem
    └─ Connect with: tls://docker:4222
```

## Certificate Management

### Files Generated

Located in `nats/certs/`:

| File | Purpose | Size |
|------|---------|------|
| `rootCA.pem` | Root CA certificate (public) | ~500 bytes |
| `rootCA.key` | Root CA private key (secret) | ~119 bytes |
| `server.pem` | Server certificate (public) | ~550 bytes |
| `server.key` | Server private key (secret) | ~119 bytes |
| `client.pem` | Client certificate (public) | ~477 bytes |
| `client.key` | Client private key (secret) | ~119 bytes |

### Generation Script

Run `nats/gen-certs.sh` to generate certificates:

```bash
bash nats/gen-certs.sh
```

The script:
- Creates ed25519 key pairs (modern, compact)
- Generates a 10-year CA certificate
- Creates server certificate with SANs for: `docker`, `localhost`, `nats-pipeline-test`, `127.0.0.1`
- Creates client certificate with CN `pipeline-client`
- Sets proper file permissions (600 for keys, 644 for certs)

**Important**: This is a ONE-TIME setup. Certificates persist across `make down` operations.

## Configuration

### NATS Server (nats/nats-server.conf)

```conf
port: 4222

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

**Key settings**:
- `verify_and_map: true` — Extract CN from client cert and match against user list
- Single user `pipeline-client` — Matches the client certificate CN
- All traffic on port 4222 requires mTLS (no fallback to plaintext)

### Docker Run Command

```bash
docker run -d \
    --name nats-server \
    -p 4222:4222 \
    -v nats/certs:/certs:ro \
    -v nats/nats-server.conf:/etc/nats/nats-server.conf:ro \
    nats:latest \
    -c /etc/nats/nats-server.conf
```

**Mounts**:
- `-v nats/certs:/certs:ro` — Read-only access to certificate files
- `-v nats/nats-server.conf:/etc/nats/nats-server.conf:ro` — Read-only config

## Client Configuration

### Environment Variables

All Python clients expect:

```bash
export NATS_URL="tls://docker:4222"
export CERTS_DIR="/path/to/nats/certs"
```

The Makefile automatically sets these when targets run.

### Python TLS Pattern

Every NATS client follows this pattern:

```python
import ssl
import os

CERTS_DIR = os.environ.get("CERTS_DIR", "/tmp/nats-certs")

def _make_ssl_ctx() -> ssl.SSLContext:
    """Create SSL context with client certificate for mTLS."""
    ctx = ssl.create_default_context()
    ctx.load_verify_locations(cafile=f"{CERTS_DIR}/rootCA.pem")
    ctx.load_cert_chain(
        certfile=f"{CERTS_DIR}/client.pem",
        keyfile=f"{CERTS_DIR}/client.key"
    )
    return ctx

# Connect with TLS
async def connect():
    ssl_ctx = _make_ssl_ctx()
    return await nats.connect(
        "tls://docker:4222",
        tls=ssl_ctx,
        connect_timeout=2
    )
```

## Using the System

### Start with mTLS

```bash
# From nats/ directory
make up
```

This automatically:
1. Generates certificates (if not present)
2. Starts NATS with TLS configuration
3. Starts all publishers, listeners, and writers
4. Exports `CERTS_DIR` to all subprocesses

### Verify TLS is Active

```bash
# Check NATS logs
docker logs nats-server

# Should see TLS handshake messages:
# "TLS configured with cert_file:"
# "Require and verify client certificates"
```

### Test Connection

Verify a client can connect:

```bash
# From repo root
source nats/time-entry-notes-parser/.venv/bin/activate
export NATS_URL="tls://docker:4222"
export CERTS_DIR="$(pwd)/nats/certs"

python3 time-entry-notes-parser/nats_time_listener.py &
```

If TLS is working, you'll see:
```
Connection attempt 1/5 succeeded
✓ Subscribed to topic: messages.20.type.training
```

If TLS fails, you'll see:
```
Error: Could not connect to NATS at tls://docker:4222 after 5 attempts
Make sure NATS server is running: ...certificate verify failed...
```

## Troubleshooting

### "Certificate verify failed"

**Cause**: Client can't verify server certificate against the CA.

**Fix**:
1. Verify `rootCA.pem` is readable
2. Regenerate certificates: `bash nats/gen-certs.sh`
3. Check NATS logs: `docker logs nats-server`

### "No shared cipher suites"

**Cause**: OpenSSL version mismatch with ed25519.

**Fix**:
- macOS: `brew install openssl@3` and use `/usr/local/opt/openssl@3/bin/openssl`
- Linux: `openssl version` should be 1.1.1+
- Regenerate: `bash nats/gen-certs.sh`

### "Unable to find certificate file"

**Cause**: `CERTS_DIR` not set or incorrect path.

**Fix**:
```bash
# Always export before running
export CERTS_DIR="$(pwd)/nats/certs"
echo $CERTS_DIR  # Verify it's correct
```

### "NATS server not accepting connections"

**Cause**: Server config mounted incorrectly or server not started.

**Fix**:
```bash
# Stop and restart with full output
make nats-down
docker run -it \
    -p 4222:4222 \
    -v $(pwd)/nats/certs:/certs:ro \
    -v $(pwd)/nats/nats-server.conf:/etc/nats/nats-server.conf:ro \
    nats:latest \
    -c /etc/nats/nats-server.conf
```

## Security Considerations

### Certificate Expiration

- **Server certificate**: 365 days (renew annually)
- **Client certificate**: 365 days (renew annually)
- **CA certificate**: 3650 days (10 years)

Monitor expiration:
```bash
openssl x509 -in nats/certs/server.pem -noout -dates
openssl x509 -in nats/certs/client.pem -noout -dates
```

Regenerate if expired:
```bash
rm -f nats/certs/*
bash nats/gen-certs.sh
make down && make up
```

### Key Management

- **Private keys** are readable only by the owning process (`chmod 600`)
- **Do not commit** `.key` files to Git
- `.gitignore` should exclude:
  ```
  nats/certs/*.key
  nats/certs/*.srl
  ```

### Authorization

Currently, all clients use the same user (`pipeline-client`). For multi-user setups:

1. Generate separate client certificates for each user
2. Add users to `authorization` block in `nats-server.conf`
3. Set permissions per user as needed

Example:
```conf
authorization {
  users = [
    { user: "publisher", permissions: { publish: "messages.10.>" } },
    { user: "listener", permissions: { subscribe: "messages.20.>" } }
  ]
}
```

## Performance Impact

mTLS adds minimal overhead:
- **Handshake overhead**: ~5-10ms per connection (one-time)
- **Per-message overhead**: Negligible (<1% CPU)
- **Memory overhead**: ~10KB per connection

For the notes publishing system with <10 concurrent connections, TLS has no measurable performance impact.

## Certificate Renewal Workflow

When certificates near expiration (e.g., 30 days before):

```bash
# 1. Backup existing certificates
cp -r nats/certs nats/certs.backup.$(date +%Y%m%d)

# 2. Regenerate
bash nats/gen-certs.sh

# 3. Restart system (clients reconnect automatically)
make down
make up

# 4. Verify new dates
openssl x509 -in nats/certs/server.pem -noout -dates
```

## See Also

- [NATS Documentation](https://docs.nats.io/running-a-nats-service/configuration) — Full NATS configuration options
- [NATS Security](https://docs.nats.io/running-a-nats-service/security) — NATS security overview
- [Certificate Authority Setup](https://smallstep.com/blog/certificates-the-hard-way/) — If regenerating CA

## References

This setup was generated and verified:
- **Date**: 2026-05-02
- **ed25519**: Modern elliptic curve algorithm (FIPS 186-5)
- **Configuration**: Based on NATS documentation for mTLS with verify_and_map
- **Verification**: All 6 Python clients tested and confirmed to have TLS support
