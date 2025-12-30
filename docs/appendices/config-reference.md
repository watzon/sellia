# Configuration Schema Reference

Complete reference for the `sellia.yml` configuration file format.

## Config File Locations

Sellia loads configuration from multiple locations in order (later overrides earlier):

1. `~/.config/sellia/sellia.yml`
2. `~/.sellia.yml`
3. `./sellia.yml` (current working directory)

## Root-Level Schema

```yaml
# Tunnel server URL
server: String (default: "https://sellia.me")

# API authentication key (optional)
api_key: String?

# Inspector configuration
inspector:
  port: Int32 (default: 4040)
  open: Boolean (default: false)

# Database configuration
database:
  path: String? (optional)
  enabled: Boolean? (optional)

# Tunnel definitions (key = tunnel name)
tunnels:
  <name>:
    type: String (default: "http")
    port: Int32 (required)
    subdomain: String? (optional)
    auth: String? (optional, format: "user:pass")
    local_host: String (default: "localhost")
    routes: Array[RouteConfig] (default: [])
```

## Complete Schema Reference

### server

**Type:** `String`
**Default:** `"https://sellia.me"`
**Required:** No

The tunnel server URL to connect to.

```yaml
server: https://sellia.me
server: http://localhost:8080  # Custom server
```

---

### api_key

**Type:** `String?`
**Default:** `nil`
**Required:** No

API authentication key for protected tunnels. Can also be set via `SELLIA_API_KEY` environment variable.

```yaml
api_key: sk_live_abc123...
```

---

### inspector

**Type:** `Inspector` object
**Required:** No

Configuration for the built-in request inspector UI.

#### inspector.port

**Type:** `Int32`
**Default:** `4040`
**Required:** No

Local port for the inspector web UI.

```yaml
inspector:
  port: 4040
```

#### inspector.open

**Type:** `Boolean`
**Default:** `false`
**Required:** No

Automatically open inspector in browser when tunnel connects.

```yaml
inspector:
  open: true
```

**Example:**

```yaml
inspector:
  port: 8080
  open: true
```

---

### database

**Type:** `DatabaseConfig` object
**Required:** No

Configuration for SQLite database persistence.

#### database.path

**Type:** `String?`
**Default:** `nil` (uses default location)
**Required:** No

Custom path for the SQLite database file.

```yaml
database:
  path: /custom/path/sellia.db
```

#### database.enabled

**Type:** `Boolean?`
**Default:** `nil` (enables database)
**Required:** No

Enable or disable database persistence. Set to `false` to disable.

**Note:** The behavior is inverted from environment variables. When set to `false` in config, it enables the database. When set via `SELLIA_NO_DB` environment variable, `"true"` or `"1"` disables the database.

```yaml
database:
  enabled: false  # Disables database
```

**Example:**

```yaml
database:
  path: /data/sellia.db
  enabled: true  # Enables database explicitly
```

---

### tunnels

**Type:** `Hash<String, TunnelConfig>`
**Required:** No
**Key:** Tunnel name (used for identification)

Named tunnel configurations for use with `sellia start`.

#### Tunnel Configuration

Each tunnel has the following properties:

##### type

**Type:** `String`
**Default:** `"http"`
**Required:** No

Tunnel type. Currently only `"http"` is supported.

```yaml
tunnels:
  web:
    type: http
```

##### port

**Type:** `Int32`
**Default:** (none)
**Required:** Yes

Local port to forward to.

```yaml
tunnels:
  web:
    port: 3000
```

##### subdomain

**Type:** `String?`
**Default:** `nil` (random subdomain assigned)
**Required:** No

Request a specific subdomain for the public URL.

```yaml
tunnels:
  web:
    subdomain: myapp
```

##### auth

**Type:** `String?`
**Default:** `nil`
**Required:** No
**Format:** `"username:password"`

Enable basic authentication for the tunnel.

```yaml
tunnels:
  web:
    auth: admin:secret123
```

##### local_host

**Type:** `String`
**Default:** `"localhost"`
**Required:** No

Local hostname to forward to.

```yaml
tunnels:
  web:
    local_host: 127.0.0.1
  docker:
    local_host: host.docker.internal
```

##### routes

**Type:** `Array[RouteConfig]`
**Default:** `[]`
**Required:** No

Path-based routing rules to forward different paths to different ports.

**RouteConfig Properties:**

- `path` (String, required): Path pattern (e.g., `/api`, `/admin/*`)
- `port` (Int32, required): Target port
- `host` (String?, optional): Override target host

```yaml
tunnels:
  app:
    port: 3000
    routes:
      - path: /api
        port: 8080
      - path: /admin
        port: 9000
        host: admin.local
      - path: /static/*
        port: 3001
```

## Complete Examples

### Minimal Config

```yaml
# sellia.yml
server: https://sellia.me
api_key: sk_live_abc123

tunnels:
  web:
    port: 3000
```

### Multi-Tunnel with Routing

```yaml
server: https://sellia.me
api_key: sk_live_abc123

inspector:
  port: 4040
  open: true

database:
  enabled: true
  path: /data/sellia.db

tunnels:
  frontend:
    port: 3000
    subdomain: myapp
    routes:
      - path: /api
        port: 8080
      - path: /admin
        port: 9000

  api:
    port: 8080
    subdomain: api

  admin:
    port: 9000
    auth: admin:secret
```

### Development Config

```yaml
# Development environment
server: http://localhost:8080
api_key: dev-key

inspector:
  port: 4040
  open: true

database:
  enabled: false  # Disable persistence in dev

tunnels:
  web:
    port: 3000
    local_host: localhost
```

## Config Merging

When multiple config files exist, they are merged with the following rules:

- **Scalar values:** Later config overrides earlier
- **Hash values:** Merged recursively (tunnels are combined)
- **Array values:** Later config replaces earlier

Example:

```yaml
# ~/.config/sellia/sellia.yml
server: https://sellia.me
api_key: global-key

tunnels:
  web:
    port: 3000
```

```yaml
# ./sellia.yml
api_key: local-key  # Overrides global

tunnels:
  web:
    subdomain: myapp  # Merged with web tunnel
  api:               # New tunnel added
    port: 8080
```

Result:
```yaml
server: https://sellia.me
api_key: local-key  # Local override wins
tunnels:
  web:
    port: 3000
    subdomain: myapp  # Both properties present
  api:
    port: 8080
```

## Validation Rules

1. **Required Fields:** Only `tunnel.port` is required for each tunnel
2. **Port Range:** Ports must be between 1-65535
3. **Auth Format:** Must be `username:password`
4. **Route Paths:** Must start with `/`
5. **Subdomain:** Must be valid hostname (alphanumeric, hyphens)

## See Also

- [Environment Variables Reference](./env-vars.md) - Environment-based configuration
- [CLI Flags Reference](./cli-flags.md) - Command-line options
- [Getting Started Guide](../user/getting-started/index.md) - Basic setup
