# Configuration File

Sellia uses YAML configuration files for persistent settings, multiple tunnels, and team collaboration. Configuration files are loaded in layers, allowing you to override settings at different levels.

## Configuration File Locations

Sellia searches for configuration files in this order (later overrides earlier):

1. `~/.config/sellia/sellia.yml` - System-wide user config
2. `~/.sellia.yml` - User home directory config
3. `./sellia.yml` - Project-specific config (current directory)
4. CLI flags - Command-line arguments override all files

### Example Hierarchy

```
~/.config/sellia/sellia.yml  (global defaults)
    ↓
~/.sellia.yml                (user overrides)
    ↓
./sellia.yml                 (project overrides)
    ↓
CLI flags                    (session overrides)
```

## Basic Configuration File

### Minimal Example

```yaml
# sellia.yml
server: https://sellia.me
```

This sets the default server for all tunnels.

### Complete Example

```yaml
# sellia.yml
server: https://sellia.me
api_key: your-api-key-here

inspector:
  port: 4040
  open: false

tunnels:
  web:
    port: 3000
    subdomain: myapp

  api:
    port: 4000
    subdomain: myapp-api
    auth: admin:secret
```

## Configuration Options

### Server Settings

```yaml
# Server URL
server: https://sellia.me

# or with custom port
server: https://sellia.me:8443
```

### Authentication

```yaml
# API key for server authentication
api_key: your-api-key-here

# or via environment variable
api_key: ${SELLIA_API_KEY}
```

### Inspector Settings

Inspector settings apply to `sellia http`. The `sellia start` command does not run the inspector.

```yaml
inspector:
  port: 4040
  open: true

database:
  path: /var/lib/sellia/sellia.db  # Optional: custom database path
  enabled: true                     # Optional: disable database
```

### Tunnel Definitions

```yaml
tunnels:
  # Tunnel name (key)
  web:
    port: 3000              # Required: local port
    subdomain: myapp        # Optional: custom subdomain
    local_host: localhost   # Optional: local host (default: localhost)
    auth: user:pass         # Optional: basic auth
    routes:                 # Optional: advanced routing
      - path: /api
        port: 4000
        host: api-service
```

## Multiple Tunnels

### Defining Multiple Tunnels

```yaml
tunnels:
  # Frontend application
  web:
    port: 3000
    subdomain: myapp

  # API backend
  api:
    port: 4000
    subdomain: myapp-api

  # Admin panel
  admin:
    port: 5000
    subdomain: myapp-admin
    auth: admin:admin123

  # Webhook receiver
  webhooks:
    port: 6000
    subdomain: webhooks
    auth: webhook-tester:secret
```

### Starting Multiple Tunnels

```bash
# Start all configured tunnels
sellia start
```

**Output:**
```
Sellia v1.0.0
Starting 4 tunnel(s)...

[web] https://myapp.sellia.me -> localhost:3000
[api] https://myapp-api.sellia.me -> localhost:4000
[admin] https://myapp-admin.sellia.me -> localhost:5000
[webhooks] https://webhooks.sellia.me -> localhost:6000

Press Ctrl+C to stop all tunnels
```

## Environment Variables

### Using Environment Variables

**IMPORTANT:** Crystal's YAML parser does **not** support `${VAR}` syntax. Environment variables can only be set via shell/ENV and will override config file values.

### Available Environment Variables

The following environment variables are read by Sellia:

**Client:**
- `SELLIA_SERVER` - Override server URL from config
- `SELLIA_API_KEY` - Override API key from config
- `SELLIA_DB_PATH` - Override database path (server only)
- `SELLIA_NO_DB` - Disable database (set to "true" or "1")

**Server:**
- `SELLIA_HOST` - Bind host
- `SELLIA_PORT` - Bind port
- `SELLIA_DOMAIN` - Base domain
- `SELLIA_REQUIRE_AUTH` - Require authentication
- `SELLIA_MASTER_KEY` - Master API key
- `SELLIA_USE_HTTPS` - Generate HTTPS URLs
- `SELLIA_RATE_LIMITING` - Enable/disable rate limiting
- `SELLIA_DISABLE_LANDING` - Disable landing page
- `LOG_LEVEL` - Logging verbosity

### Setting Environment Variables

Set in shell:

```bash
# Direct export
export SELLIA_SERVER="https://sellia.me"
export SELLIA_API_KEY="your-api-key"
sellia start
```

**Note:** Environment variables override config file values but are overridden by CLI flags.

### Environment-Specific Configuration

Use different config files per environment:

```yaml
# sellia.dev.yml
server: http://localhost:3000

tunnels:
  app:
    port: 3000
    subdomain: myapp-dev
```

```yaml
# sellia.prod.yml
server: https://sellia.me

tunnels:
  app:
    port: 3000
    subdomain: myapp-prod
```

Use the appropriate config:

```bash
# Development
sellia start --config sellia.dev.yml

# Production
export SELLIA_API_KEY="prod-key"
sellia start --config sellia.prod.yml
```

## Configuration File Examples

### Development Configuration

```yaml
# sellia.yml
server: https://dev.sellia.me

inspector:
  port: 4040
  open: true

tunnels:
  web:
    port: 3000
    subdomain: myapp-dev

  api:
    port: 4000
    subdomain: myapi-dev

  webhooks:
    port: 5000
    subdomain: webhooks-dev
```

### Production Configuration

```yaml
# sellia.prod.yml
server: https://sellia.me
api_key: ${PROD_API_KEY}

tunnels:
  app:
    port: 3000
    subdomain: myapp
```

### Team Collaboration

```yaml
# sellia.yml (shared in repo)
server: https://sellia.me
api_key: ${SELLIA_API_KEY}  # Each developer sets their own

tunnels:
  web:
    port: 3000
    subdomain: ${USER}-myapp  # john-myapp, jane-myapp

  api:
    port: 4000
    subdomain: ${USER}-myapi
```

Each developer:

```bash
# John's machine
export SELLIA_API_KEY="johns-key"
export USER=john
sellia start
# Creates john-myapp.sellia.me
```

### Microservices Architecture

```yaml
# sellia.yml
server: https://sellia.me

tunnels:
  # Services
  user-service:
    port: 8001
    subdomain: svc-users

  auth-service:
    port: 8002
    subdomain: svc-auth

  payment-service:
    port: 8003
    subdomain: svc-payments

  notification-service:
    port: 8004
    subdomain: svc-notifications

  # Frontends
  web-app:
    port: 3000
    subdomain: app-web

  admin-app:
    port: 3001
    subdomain: app-admin
```

### Monorepo Setup

```yaml
# sellia.yml (root of monorepo)
server: https://sellia.me

tunnels:
  # Package A
  package-a-web:
    port: 3000
    subdomain: pkg-a-web

  package-a-api:
    port: 4000
    subdomain: pkg-a-api

  # Package B
  package-b-web:
    port: 3001
    subdomain: pkg-b-web
```

## Advanced Configuration

### Conditional Configuration

Use different configs based on conditions:

```bash
# Use different config files
sellia start --config sellia.dev.yml
sellia start --config sellia.prod.yml
```

### Include External Configs

While Sellia doesn't support YAML includes, you can:

```bash
# Symbolic link approach
ln -s sellia.dev.yml sellia.yml
sellia start

# Or specify config file
sellia start --config sellia.dev.yml
```

### Per-Tunnel Override

Per-tunnel inspector settings are not supported. The inspector is only available with `sellia http`, not `sellia start`.

## Database Configuration

Sellia can use a SQLite database to persist reserved subdomains.

```yaml
database:
  path: /var/lib/sellia/sellia.db  # Path to database file
  enabled: true                     # Set to false to disable
```

**Defaults:**
- Path: `~/.sellia/sellia.db`
- Enabled: `true`

**Use cases:**
- Persist reserved subdomains across server restarts
- Share reserved subdomain registry between server instances
- Disable for simple deployments (uses in-memory defaults)

### Database Configuration

```yaml
# sellia.yml (server configuration)
database:
  enabled: true
  path: /var/lib/sellia/sellia.db
```

## Configuration Best Practices

### 1. Use Version Control

Commit your config file (excluding secrets):

```yaml
# sellia.yml (committed)
server: https://sellia.me
api_key: ${SELLIA_API_KEY}  # From environment

tunnels:
  web:
    port: 3000
    subdomain: myapp
```

### 2. Never Commit Secrets

Use environment variables for sensitive data:

```yaml
# DON'T do this
api_key: sk_live_abc123...

# DO this instead
api_key: ${SELLIA_API_KEY}
```

Create `.env` file (in `.gitignore`):

```bash
# .env
SELLIA_API_KEY=sk_live_abc123...
```

### 3. Document Configuration

Add comments to your config:

```yaml
# Sellia Configuration
# Documentation: https://github.com/watzon/sellia

# Server Configuration
server: https://sellia.me

# Authentication (set via environment)
api_key: ${SELLIA_API_KEY}

# Tunnels Configuration
tunnels:
  # Main web application
  web:
    port: 3000
    subdomain: myapp
```

### 4. Separate Environments

Use different configs per environment:

```bash
sellia.yml           # Base config
sellia.dev.yml       # Development overrides
sellia.staging.yml   # Staging overrides
sellia.prod.yml      # Production overrides
```

### 5. Use Meaningful Names

Choose clear tunnel names:

```yaml
tunnels:
  # Good
  web-production:
    port: 3000
    subdomain: myapp

  # Less clear
  tunnel1:
    port: 3000
    subdomain: myapp
```

## Troubleshooting

### Config Not Loading

If config isn't being applied:

1. Check file location:
   ```bash
   pwd  # Should be project directory
   ls sellia.yml
   ```

2. Verify YAML syntax:
   ```bash
   # Use yamllint or similar
   yamllint sellia.yml
   ```

3. Check for syntax errors:
   ```bash
   # Sellia will show parse errors
   sellia start
   ```

### Environment Variables Not Working

If environment variables aren't being read:

1. Verify variable is set:
   ```bash
   echo $SELLIA_API_KEY
   ```

2. Check variable name in config:
   ```yaml
   # Case sensitive!
   api_key: ${SELLIA_API_KEY}  # Correct
   api_key: ${sellia_api_key}  # Wrong
   ```

3. Export the variable:
   ```bash
   # Make sure it's exported
   export SELLIA_API_KEY="key"
   ```

### Invalid YAML

Common YAML errors:

```yaml
# WRONG - tabs instead of spaces
tunnels:
	   web:  # Uses tab
    	port: 3000

# CORRECT - use spaces
tunnels:
  web:  # Uses spaces
    port: 3000
```

Always use spaces, not tabs.

## Configuration Validation

Sellia validates config on startup:

```bash
$ sellia start

# Valid config
[Sellia] Loading config from sellia.yml
[Sellia] Starting tunnel: web
[Sellia] Tunnel established at: https://myapp.sellia.me

# Invalid config
[Sellia] Error: Invalid configuration
[Sellia] - tunnel 'web': missing required field 'port'
```

## Next Steps

- [Multiple Tunnels](./multiple-tunnels.md) - Managing several tunnels
- [Environment Variables](./environment-variables.md) - ENV var reference
- [CLI Flags](./cli-flags.md) - Command-line options

## Quick Reference

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `server` | string | `https://sellia.me` | Tunnel server URL |
| `api_key` | string | - | Authentication key |
| `inspector.port` | integer | 4040 | Inspector UI port (used by `sellia http`) |
| `inspector.open` | boolean | false | Auto-open inspector (used by `sellia http`) |
| `database.path` | string | `~/.sellia/sellia.db` | SQLite database path (server) |
| `database.enabled` | boolean | true | Enable database (server) |
| `tunnels` | object | - | Tunnel definitions |
| `tunnels.<name>.port` | integer | required | Local port |
| `tunnels.<name>.subdomain` | string | random | Custom subdomain |
| `tunnels.<name>.local_host` | string | localhost | Local host |
| `tunnels.<name>.auth` | string | - | Basic auth (user:pass) |
| `tunnels.<name>.routes` | array | - | Advanced routing rules |
| `tunnels.<name>.routes[].path` | string | - | Route path pattern |
| `tunnels.<name>.routes[].port` | integer | - | Target port for route |
| `tunnels.<name>.routes[].host` | string | - | Target host for route |
