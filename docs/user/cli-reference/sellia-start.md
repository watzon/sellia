# `sellia start` - Start Tunnels from Config

Start multiple tunnels from a configuration file.

## Synopsis

```bash
sellia start [options]
```

## Description

Starts multiple tunnels defined in a `sellia.yml` configuration file. This is the recommended way to manage multiple development tunnels simultaneously.

All tunnels run in parallel and display unified request logging. Each tunnel can have different ports, subdomains, authentication, and routing rules.

## Options

### `-c, --config FILE`

Config file path (default: `./sellia.yml`).

Load tunnel definitions from a custom configuration file instead of the default `./sellia.yml`.

**Example:**
```bash
sellia start --config /path/to/tunnels.yml
```

### `-h, --help`

Show help message and exit.

## Configuration File

The `sellia.yml` file defines multiple tunnels with individual settings:

```yaml
server: https://sellia.me
api_key: your-api-key

tunnels:
  web:
    port: 3000
    subdomain: myapp
    auth: user:pass

  api:
    port: 8080
    subdomain: myapp-api
    local_host: localhost

  admin:
    port: 9000
    subdomain: myapp-admin
```

### Tunnel Configuration Options

Each tunnel in the `tunnels` map supports these options:

#### `port` (required)

Local port number to forward to.

**Type:** `Integer`

```yaml
tunnels:
  web:
    port: 3000
```

#### `subdomain` (optional)

Requested subdomain for the tunnel URL.

**Type:** `String`

```yaml
tunnels:
  web:
    port: 3000
    subdomain: myapp
```

#### `auth` (optional)

Basic authentication in `username:password` format.

**Type:** `String`

```yaml
tunnels:
  web:
    port: 3000
    auth: admin:secret123
```

#### `local_host` (optional)

Local host to connect to (default: `localhost`).

**Type:** `String`

```yaml
tunnels:
  web:
    port: 3000
    local_host: host.docker.internal
```

#### `routes` (optional)

Array of route mappings for path-based routing to different ports.

**Type:** Array of objects with `path`, `port`, and optional `host`

```yaml
tunnels:
  app:
    port: 3000
    routes:
      - path: /api
        port: 8080
        host: localhost
      - path: /ws
        port: 9000
      - path: /static
        port: 3001
```

Routes allow you to forward different paths to different local services:
- Primary port (3000) handles all unmatched requests
- `/api/*` → localhost:8080
- `/ws/*` → localhost:9000
- `/static/*` → localhost:3001

### Global Configuration Options

#### `server`

Default tunnel server URL.

**Type:** `String` (default: `https://sellia.me`)

```yaml
server: https://sellia.me
```

#### `api_key`

API key for authentication.

**Type:** `String`

```yaml
api_key: key_abc123
```

## Configuration Loading Order

Configuration is loaded from multiple paths and merged (later paths override earlier ones):

1. `~/.config/sellia/sellia.yml` (system-wide user config)
2. `~/.sellia.yml` (user home directory)
3. `./sellia.yml` (current directory)
4. File specified with `--config` flag

Environment variables override all file-based settings:
- `SELLIA_SERVER`
- `SELLIA_API_KEY`
- `SELLIA_DB_PATH`
- `SELLIA_NO_DB`

## Usage Examples

### Start with default config file

```bash
sellia start
```

Uses `./sellia.yml` in the current directory.

### Start with custom config file

```bash
sellia start --config /path/to/production-tunnels.yml
```

### Example: Full-Stack Application

```yaml
# sellia.yml
server: https://sellia.me
api_key: ${SELLIA_API_KEY}

tunnels:
  frontend:
    port: 3000
    subdomain: myapp
    routes:
      - path: /api
        port: 4000
      - path: /graphql
        port: 4000

  admin:
    port: 3001
    subdomain: myapp-admin

  websocket:
    port: 4001
    subdomain: myapp-ws
```

```bash
sellia start
```

Output:
```
Sellia v1.0.0
Starting 3 tunnel(s)...

[frontend] https://myapp.sellia.me
  /api        -> localhost:4000
  /graphql    -> localhost:4000
  /*          -> localhost:3000 (fallback)

[admin] https://myapp-admin.sellia.me -> localhost:3001

[websocket] https://myapp-ws.sellia.me -> localhost:4001

Press Ctrl+C to stop all tunnels
```

### Example: Microservices with Docker

```yaml
# sellia.yml
tunnels:
  web:
    port: 3000
    local_host: host.docker.internal
    subdomain: app
    routes:
      - path: /api/users
        port: 8001
        host: host.docker.internal
      - path: /api/orders
        port: 8002
        host: host.docker.internal
      - path: /api
        port: 8000
        host: host.docker.internal

  worker:
    port: 9000
    local_host: host.docker.internal
    subdomain: worker
```

## Terminal Output

Each tunnel shows requests with its name:

```
[14:32:15] [frontend] GET /api/users
[14:32:16] [frontend] POST /api/orders
[14:32:18] [websocket] WS /socket
[14:32:20] [admin] GET /dashboard
```

## Error Handling

If no tunnels are defined in the config:

```bash
sellia start
```

Output:
```
Error: No tunnels defined in config

Create a sellia.yml with tunnel definitions:

  tunnels:
    web:
      port: 3000
      subdomain: myapp
    api:
      port: 8080
```

## Graceful Shutdown

Press `Ctrl+C` to gracefully shut down all tunnels:

```
^C
Shutting down...
```

The command waits for all tunnels to stop before exiting.

## Environment Variables

You can use environment variables in your config file:

```yaml
api_key: ${SELLIA_API_KEY}
server: ${TUNNEL_SERVER:-https://sellia.me}
```

Then run:

```bash
export SELLIA_API_KEY=key_abc123
sellia start
```

## Exit Codes

- `0` - Successful termination
- `1` - Error occurred (missing config, no tunnels defined, etc.)

## Related Commands

- [`sellia http`](./sellia-http.md) - Create a single HTTP tunnel
- [`sellia auth`](./sellia-auth.md) - Manage API key authentication
- [`sellia admin`](./sellia-admin.md) - Admin commands for reserved subdomains
