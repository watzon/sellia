# Default Values Reference

Complete list of default values used throughout Sellia.

## Configuration Defaults

### Server Configuration

| Setting | Default Value | Location |
|---------|---------------|----------|
| `server` | `https://sellia.me` | Config, ENV |
| `api_key` | `nil` (none required) | Config, ENV |
| `local_host` | `localhost` | CLI flag, Config |

### Inspector Defaults

| Setting | Default Value | Location |
|---------|---------------|----------|
| `inspector.port` | `4040` | Config, CLI flag |
| `inspector.open` | `false` | Config, CLI flag |
| `--no-inspector` | `false` (inspector enabled) | CLI flag |

### Database Defaults

| Setting | Default Value | Location |
|---------|---------------|----------|
| `database.enabled` | `nil` (enabled by default) | Config |
| `database.path` | Platform-dependent | Config, ENV |
| `SELLIA_NO_DB` | `false` (database enabled) | ENV |

**Note:** When `SELLIA_NO_DB` is set to `"true"` or `"1"`, it **disables** the database. This is inverted from the `database.enabled` config setting where `false` disables the database.

### Tunnel Defaults

| Setting | Default Value | Location |
|---------|---------------|----------|
| `port` | `3000` | CLI argument |
| `type` | `http` | Config |
| `subdomain` | `nil` (random assigned) | Config, CLI flag |
| `auth` | `nil` (no auth) | Config, CLI flag |
| `routes` | `[]` (empty) | Config |

---

## Network Defaults

### Timeouts

| Setting | Default Value | Description |
|---------|---------------|-------------|
| `reconnect_delay` | `3 seconds` | Initial reconnect delay |
| `reconnect_delay * attempt` | Linear backoff | Subsequent reconnects |
| `max_reconnect_attempts` | `10` | Maximum reconnect attempts |
| WebSocket ping timeout | Default Crystal WebSocket timeout | Keepalive interval |

### Ports

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Inspector port | `4040` | Local inspector UI |
| Vite dev server | `5173` | Development build server |
| Default local port | `3000` | Default forwarded port |

### URLs

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Tunnel server | `https://sellia.me` | Production server |
| WebSocket endpoint | `/ws` | Server WebSocket path |
| Inspector API | `/api/*` | Inspector REST API |
| Inspector live | `/api/live` | Inspector WebSocket endpoint |

---

## Path Defaults

### Config File Search Order

1. `~/.config/sellia/sellia.yml`
2. `~/.sellia.yml`
3. `./sellia.yml` (current directory)

### Database Path

**Platform-dependent locations:**

| Platform | Default Path |
|----------|--------------|
| macOS | `~/Library/Application Support/Sellia/sellia.db` |
| Linux | `~/.local/share/sellia/sellia.db` |
| Windows | `%APPDATA%/Sellia/sellia.db` |

Can be overridden via:
- `SELLIA_DB_PATH` environment variable
- `database.path` in config file

### Asset Paths

| Setting | Path | Description |
|---------|------|-------------|
| Inspector UI (dev) | Proxies to `localhost:5173` | Vite dev server |
| Inspector UI (prod) | Baked into binary | `web/dist/` contents |

---

## Request/Response Defaults

### Body Size Limits

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Inspector display limit | `100,000 bytes` (100 KB) | Max body size for UI display |
| Body truncation suffix | `\n... (truncated)` | Added to truncated bodies |

### Request Storage

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Max stored requests | `1000` | Requests kept in memory |
| Storage duration | Session-based | Cleared on restart |
| WebSocket buffer | `8192 bytes` | Response chunk size |

---

## Reconnection Defaults

### Linear Backoff

| Attempt | Delay |
|---------|-------|
| 1 | 3 seconds |
| 2 | 6 seconds |
| 3 | 9 seconds |
| ... | ... |
| 10 | 30 seconds |

Formula: `delay = reconnect_delay * reconnect_attempts`

### Auto-Reconnect

| Setting | Default Value | Description |
|---------|---------------|-------------|
| `auto_reconnect` | `true` | Automatically reconnect on disconnect |
| `max_reconnect_attempts` | `10` | Give up after this many attempts |

Disabled on certain errors (e.g., authentication failure).

---

## Logging Defaults

### Log Levels

| Environment Variable | Default Level | Description |
|---------------------|---------------|-------------|
| `LOG_LEVEL` | `warn` | Minimum log level |
| (unset) | `warn` | Crystal default |

Available levels: `fatal`, `error`, `warn`, `info`, `debug`, `trace`.

### Log Format

| Mode | Default Format | Enable |
|------|----------------|--------|
| Production | JSON | Default |
| Text | Human-readable | `LOG_TEXT=1` |

---

## Protocol Defaults

### Message Defaults

| Setting | Default Value |
|---------|---------------|
| Serialization | MessagePack |
| WebSocket frame size | `8192 bytes` (response chunks) |
| Ping interval | Server-controlled |

### Message Types

| Type | Default Behavior |
|------|------------------|
| Auth | Sent if `api_key` is set |
| Tunnel Open | Sent immediately after auth |
| Ping/ Pong | Automatic keepalive |

---

## Development Defaults

### Vite Dev Server

| Setting | Default Value |
|---------|---------------|
| Host | `localhost` |
| Port | `5173` |
| HMR | WebSocket (not proxied in inspector) |

### Build Defaults

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Build mode | `debug` (default) | Faster compilation |
| Release mode | `--release` flag | Optimized binary |
| Static assets | `web/dist/` | Production UI location |

---

## Browser Opening

### Default Browsers by Platform

| Platform | Command | File |
|----------|---------|------|
| macOS | `open` | `src/cli/main.cr:522` |
| Linux | `xdg-open` | `src/cli/main.cr:524` |
| Windows | `cmd /c start` | `src/cli/main.cr:526` |

Triggered by:
- `inspector.open: true` in config
- `--open` / `-o` CLI flag

---

## Rate Limiting Defaults

| Setting | Default Value | Description |
|---------|---------------|-------------|
| Client rate limit | Server-controlled | Requests per minute |
| Tunnel creation | Server-controlled | Per-account limit |

---

## Security Defaults

| Setting | Default Value | Description |
|---------|---------------|-------------|
| TLS/SSL | Required for WSS | Production |
| Inspector binding | `127.0.0.1` only | Localhost only |
| CORS headers | `*` (all origins) | Inspector API |

---

## WebSocket Defaults

### Inspector WebSocket

| Setting | Default Value |
|---------|---------------|
| Path | `/api/live` |
| Reconnect delay | `3 seconds` |
| Max retries | Unlimited (with UI reconnection) |

### Tunnel WebSocket

| Setting | Default Value |
|---------|---------------|
| Scheme | `wss://` (HTTPS) or `ws://` (HTTP) |
| Auto ping/pong | Enabled |

---

## See Also

- [Configuration Reference](./config-reference.md) - Config file schema
- [Environment Variables](./env-vars.md) - ENV configuration
- [CLI Flags Reference](./cli-flags.md) - Command-line options
