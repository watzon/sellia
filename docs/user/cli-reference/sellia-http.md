# `sellia http` - Create HTTP Tunnel

Create an HTTP tunnel to a local port with optional request inspector.

## Synopsis

```bash
sellia http <port> [options]
```

## Description

Creates a secure HTTP tunnel from a public URL to your local development server. Includes a built-in request inspector for debugging HTTP traffic.

The tunnel forwards all incoming HTTP requests to your local port and displays real-time request information in the terminal.

## Arguments

### `<port>`

Local port number to forward to (required).

## Options

### `-s, --subdomain NAME`

Request a specific subdomain for the tunnel URL.

If the subdomain is already in use or reserved, the server will assign a random subdomain instead.

**Example:**
```bash
sellia http 3000 --subdomain myapp
# Creates: https://myapp.sellia.me
```

### `-a, --auth USER:PASS`

Enable basic authentication for the tunnel.

Protects your tunnel with a username and password. Users will be prompted to authenticate before accessing.

**Example:**
```bash
sellia http 3000 --auth admin:secret123
```

### `-H, --host HOST`

Local host to connect to (default: `localhost`).

Useful when your development server is running on a different interface or Docker container.

**Examples:**
```bash
# Connect to Docker container
sellia http 3000 --host host.docker.internal

# Connect to specific interface
sellia http 8080 --host 192.168.1.100
```

### `--server URL`

Tunnel server URL (default: from config or `https://sellia.me`).

Override the default tunnel server. Useful for self-hosted or development servers.

**Example:**
```bash
sellia http 3000 --server https://tunnel.mycompany.com
```

### `-k, --api-key KEY`

API key for authentication.

Overrides the API key from config or environment. Required if the server requires authentication.

**Example:**
```bash
sellia http 3000 --api-key sk_live_abc123
```

### `-i, --inspector-port PORT`

Inspector UI port (default: `4040`).

Change the port for the built-in request inspector web interface.

**Example:**
```bash
sellia http 3000 --inspector-port 5000
# Access inspector at http://127.0.0.1:5000
```

### `-o, --open`

Open inspector in browser automatically when tunnel connects.

Automatically opens the request inspector in your default browser when the tunnel is established.

**Example:**
```bash
sellia http 3000 --open
```

### `--no-inspector`

Disable the request inspector entirely.

Disables both the inspector UI and request logging. Useful for production use or when you don't need debugging.

**Example:**
```bash
sellia http 3000 --no-inspector
```

### `-h, --help`

Show help message and exit.

## Usage Examples

### Basic tunnel to localhost:3000

```bash
sellia http 3000
```

Output:
```
Sellia v1.0.0
Forwarding to localhost:3000

Public URL: https://random-name.sellia.me -> localhost:3000

Inspector:  http://127.0.0.1:4040

Press Ctrl+C to stop
```

### Tunnel with custom subdomain

```bash
sellia http 3000 --subdomain myapp
```

### Tunnel with basic authentication

```bash
sellia http 3000 --auth admin:mypassword
```

### Tunnel to Docker container

```bash
sellia http 3000 --host host.docker.internal --subdomain dev
```

### Tunnel without inspector

```bash
sellia http 3000 --no-inspector
```

### Tunnel with custom server

```bash
sellia http 3000 --server https://tunnel.example.com
```

## Inspector Features

When enabled (default), the request inspector provides:

- Real-time request logging in terminal
- Web interface at `http://127.0.0.1:4040`
- Request/response headers and bodies
- WebSocket connection monitoring
- Request history and search

## Terminal Output

The command displays real-time information about incoming requests:

```
[14:32:15] GET /api/users
[14:32:16] POST /api/login
[14:32:18] WS /websocket
```

Colors indicate HTTP methods:
- `GET` - Green
- `POST` - Blue
- `PUT` - Yellow
- `PATCH` - Yellow
- `DELETE` - Red
- `WS` (WebSocket) - Magenta

## Configuration

The `http` command respects configuration from:

1. `~/.config/sellia/sellia.yml`
2. `~/.sellia.yml`
3. `./sellia.yml`

Settings can be overridden by command-line flags or environment variables:
- `SELLIA_SERVER` - Default tunnel server
- `SELLIA_API_KEY` - Default API key

## Exit Codes

- `0` - Successful termination (via Ctrl+C)
- `1` - Error occurred

## Related Commands

- [`sellia start`](./sellia-start.md) - Start multiple tunnels from config file
- [`sellia auth`](./sellia-auth.md) - Manage authentication
- [`sellia admin`](./sellia-admin.md) - Admin commands for reserved subdomains and API keys
