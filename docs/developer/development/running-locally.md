# Running Locally

This guide covers running Sellia locally for development and testing purposes.

## Quick Start

### Prerequisites

- [Build Sellia from source](building.md) or have binaries available
- Three terminal windows (or use a terminal multiplexer like tmux)

### Basic Local Setup

#### Terminal 1: Start the Server

```bash
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io
```

**What this does:**
- Starts the tunnel server on port 3000
- Uses `127.0.0.1.nip.io` as the base domain (resolves to 127.0.0.1)
- Enables local testing without a real domain

**Expected output:**
```
[Sellia Server] Starting server on 0.0.0.0:3000
[Sellia Server] Domain: 127.0.0.1.nip.io
```

#### Terminal 2: Start a Tunnel

First, create a simple local server to tunnel:

```bash
# Example: Python HTTP server
python3 -m http.server 8080

# Or: Node.js http-server
npx http-server -p 8080

# Or: Any other service on port 8080
```

Then create the tunnel in a new terminal:

```bash
./bin/sellia http 8080 --server http://127.0.0.1:3000
```

**Expected output:**
```
Sellia v0.4.0
Forwarding to localhost:8080

Public URL: http://random-string.127.0.0.1.nip.io:3000 -> localhost:8080

Press Ctrl+C to stop
```

#### Terminal 3: Start the Inspector UI (Optional)

For inspector UI development:

```bash
cd web
npm run dev
```

The inspector will be available at `http://localhost:4040` automatically when the tunnel is running.

### Test Your Tunnel

```bash
# Access your local service through the tunnel
curl http://random-string.127.0.0.1.nip.io:3000
```

## Development Workflow

### Full Development Environment

For active development, run all three components:

```bash
# Terminal 1: Server with debug logging
LOG_LEVEL=debug ./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Terminal 2: Tunnel with inspector enabled
./bin/sellia http 8080 --server http://127.0.0.1:3000 --open

# Terminal 3: Inspector UI dev server (for UI development)
cd web && npm run dev
```

### Using Configuration Files

Create `sellia.yml` for persistent configuration:

```yaml
server: http://127.0.0.1:3000

tunnels:
  webapp:
    port: 3000
    subdomain: myapp
  api:
    port: 8080
    subdomain: myapp-api
    auth: admin:secret
```

Start all tunnels:

```bash
./bin/sellia start
```

## Development Features

### Debug Logging

Enable verbose logging for debugging:

```bash
LOG_LEVEL=debug ./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io
```

Or for the CLI:

```bash
LOG_LEVEL=debug ./bin/sellia http 8080 --server http://127.0.0.1:3000
```

### Rate Limiting

Disable rate limiting for easier testing (not recommended for production):

```bash
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io --no-rate-limit
```

### Authentication Testing

Test with API key authentication:

```bash
# Terminal 1: Server with auth required
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io --require-auth --master-key test-key-123

# Terminal 2: Tunnel with API key
./bin/sellia http 8080 --server http://127.0.0.1:3000 --api-key test-key-123
```

**Note:** You can also use environment variables for authentication:
```bash
# Set API key via environment
export SELLIA_API_KEY=test-key-123
./bin/sellia http 8080 --server http://127.0.0.1:3000
```

### Reserved Subdomains

Test reserved subdomain persistence:

```bash
# Server with SQLite storage at custom path
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io --db-path ./sellia.db

# Try to reserve a subdomain
./bin/sellia http 8080 --server http://127.0.0.1:3000 --subdomain myapp
```

Restart the server and try again - the subdomain should still be reserved.

**Note:** By default, the database is stored at `~/.sellia/sellia.db`. Use `--db-path` to specify a custom location.

## Testing Scenarios

### Test 1: Basic HTTP Tunnel

```bash
# Terminal 1: Server
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Terminal 2: Local service
python3 -m http.server 8080

# Terminal 3: Tunnel
./bin/sellia http 8080 --server http://127.0.0.1:3000

# Test
curl http://<assigned-subdomain>.127.0.0.1.nip.io:3000
```

### Test 2: WebSocket Tunnel

```bash
# Create a simple WebSocket server
# Save as ws_server.rb:
require 'websocket/server'
# (Or use any WebSocket server)

# Terminal 1: Server
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Terminal 2: WebSocket server on port 8080
ruby ws_server.rb

# Terminal 3: Tunnel
./bin/sellia http 8080 --server http://127.0.0.1:3000

# Test with websocat or a browser
```

### Test 3: Basic Auth Tunnel

```bash
# Terminal 1: Server
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Terminal 2: Protected tunnel
./bin/sellia http 8080 --server http://127.0.0.1:3000 --auth user:password

# Test without auth (should fail)
curl http://<assigned-subdomain>.127.0.0.1.nip.io:3000

# Test with auth (should succeed)
curl -u user:password http://<assigned-subdomain>.127.0.0.1.nip.io:3000
```

### Test 4: Multiple Tunnels

```bash
# Terminal 1: Server
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Terminal 2: Tunnel 1
./bin/sellia http 3000 --server http://127.0.0.1:3000 --subdomain app1

# Terminal 3: Tunnel 2
./bin/sellia http 8080 --server http://127.0.0.1:3000 --subdomain app2

# Test both
curl http://app1.127.0.0.1.nip.io:3000
curl http://app2.127.0.0.1.nip.io:3000
```

## Inspector UI Development

### Running in Dev Mode

The inspector UI runs via Vite's dev server during development:

```bash
cd web
npm run dev
# Available at http://localhost:5173
```

When the Crystal binary doesn't find embedded assets at `web/dist/`, it automatically proxies to the Vite dev server.

### Building Production Assets

When ready to test with embedded assets:

```bash
cd web
npm run build

# The Crystal binary will now use embedded assets
# instead of proxying to Vite
./bin/sellia http 8080 --server http://127.0.0.1:3000
```

### Inspector Features

- **Live Request Stream:** See requests in real-time
- **Request Details:** View headers, body, timing
- **Response Details:** View response status, headers, body
- **Copy as cURL:** Copy any request as a cURL command
- **Clear History:** Clear the inspector history
- **Filter:** Filter requests by various criteria

## Common Development Tasks

### Auto-Restart on File Changes

For server development:

```bash
# Install nodemon (or similar)
npm install -g nodemon

# Use nodemon to restart the server on changes
nodemon --exec ./bin/sellia-server -- --port 3000 --domain 127.0.0.1.nip.io
```

For CLI development, you'll need to restart the CLI manually after rebuilding:

```bash
# Terminal 1: Server
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Terminal 2: After code changes
shards build
./bin/sellia http 8080 --server http://127.0.0.1:3000
```

### Testing Protocol Messages

For testing protocol message serialization:

```bash
# Run protocol tests
crystal spec spec/core/protocol/
```

### Testing Connection Scenarios

```bash
# Test reconnection behavior
# 1. Start tunnel
./bin/sellia http 8080 --server http://127.0.0.1:3000

# 2. Kill server and restart
# 3. Observe automatic reconnection
```

## Environment Variables

### Server Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SELLIA_HOST` | Host to bind to | `0.0.0.0` |
| `SELLIA_PORT` | Port to listen on | `3000` |
| `SELLIA_DOMAIN` | Base domain for subdomains | `localhost` |
| `SELLIA_REQUIRE_AUTH` | Require authentication | `false` |
| `SELLIA_MASTER_KEY` | Master API key | (none) |
| `SELLIA_USE_HTTPS` | Generate HTTPS URLs | `false` |
| `SELLIA_RATE_LIMITING` | Enable rate limiting | `true` |
| `SELLIA_DISABLE_LANDING` | Disable landing page | `false` |
| `SELLIA_DB_PATH` | SQLite database path | `~/.sellia/sellia.db` |
| `SELLIA_NO_DB` | Disable database | `false` |
| `LOG_LEVEL` | Minimum log level | `warn` |

### CLI Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SELLIA_SERVER` | Tunnel server URL | `http://localhost:3000` |
| `SELLIA_API_KEY` | API key for authentication | (none) |
| `LOG_LEVEL` | Minimum log level | `warn` |

## Troubleshooting

### Port Already in Use

```bash
# Find process using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>
```

### Connection Refused

Ensure the server is running and accessible:

```bash
# Check if server is listening
lsof -i :3000

# Test server health
curl http://localhost:3000/health
```

### Subdomain Not Resolving

When using `127.0.0.1.nip.io`:

```bash
# Test DNS resolution
nslookup test.127.0.0.1.nip.io
# Should resolve to 127.0.0.1
```

### Tunnel Not Working

1. Check server logs for errors
2. Verify the tunnel is registered: `LOG_LEVEL=debug ./bin/sellia http 8080`
3. Check firewall settings
4. Ensure local service is running: `curl http://localhost:8080`

## Next Steps

- [Running Tests](testing.md) - Verify your changes
- [Debugging](debugging.md) - Debug techniques
- [Contributing Workflow](../contributing/workflow.md) - Submit your changes
