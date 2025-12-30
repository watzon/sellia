# CLI Flags Reference

Complete reference of all command-line flags for the Sellia CLI client and server. Use flags to override configuration files or for one-off commands.

## Client Commands

### sellia

Main CLI command.

```bash
sellia <command> [options]
```

### Commands

#### `http <port>`

Create an HTTP tunnel to a local port.

```bash
sellia http <port> [options]
```

**Positional Argument:**
- `port` - Local port to tunnel (required)

**Example:**
```bash
sellia http 8080
```

#### `start`

Start tunnels from configuration file.

```bash
sellia start [options]
```

**Example:**
```bash
sellia start
```

#### `auth`

Manage authentication (reserved for future use).

```bash
sellia auth <subcommand>
```

#### `version`

Show version information.

```bash
sellia version
```

**Output:**
```
Sellia version 1.0.0
```

#### `help`

Show help information.

```bash
sellia help [command]
```

Show help for specific command:
```bash
sellia help http
```

## HTTP Tunnel Options

### `--subdomain` / `-s`

Request a specific subdomain.

```bash
sellia http 8080 --subdomain myapp
```

**Long form:**
```bash
sellia http 8080 --subdomain myapp
```

**Short form:**
```bash
sellia http 8080 -s myapp
```

**Requirements:**
- 3-63 characters
- Lowercase letters, numbers, hyphens
- Must start and end with letter or number

### `--auth` / `-a`

Enable basic authentication.

```bash
sellia http 8080 --auth username:password
```

**Long form:**
```bash
sellia http 8080 --auth admin:secret123
```

**Short form:**
```bash
sellia http 8080 -a admin:secret123
```

**Format:** `username:password`

**Example:**
```bash
sellia http 8080 --auth webhook-tester:webhook-secret
```

### `--host` / `-H`

Local host to tunnel to (default: localhost).

```bash
sellia http 8080 --host 192.168.1.100
```

**Long form:**
```bash
sellia http 8080 --host 192.168.1.100
```

**Short form:**
```bash
sellia http 8080 -H 192.168.1.100
```

**Use cases:**
- Tunnel to service on different machine
- Tunnel to container
- Tunnel to VM

**Example:**
```bash
# Tunnel to Docker container
sellia http 8080 --host 172.17.0.2

# Tunnel to specific network interface
sellia http 8080 --host 0.0.0.0
```

### `--api-key` / `-k`

API key for server authentication.

```bash
sellia http 8080 --api-key your-api-key
```

**Long form:**
```bash
sellia http 8080 --api-key abc123...
```

**Short form:**
```bash
sellia http 8080 -k abc123...
```

**Alternative:** Set via environment variable:
```bash
export SELLIA_API_KEY="your-key"
sellia http 8080
```

### `--inspector-port` / `-i`

Custom port for the inspector UI.

```bash
sellia http 8080 --inspector-port 5000
```

**Long form:**
```bash
sellia http 8080 --inspector-port 5000
```

**Short form:**
```bash
sellia http 8080 -i 5000
```

**Default:** `4040`

**Use when:** Port 4040 is already in use

### `--open` / `-o`

Open inspector in browser automatically.

```bash
sellia http 8080 --open
```

**Long form:**
```bash
sellia http 8080 --open
```

**Short form:**
```bash
sellia http 8080 -o
```

**Effect:** Opens `http://localhost:4040` in default browser

### `--no-inspector`

Disable the request inspector.

```bash
sellia http 8080 --no-inspector
```

**Use cases:**
- Production deployments
- Resource-constrained environments
- High-traffic scenarios

### `--server`

Tunnel server URL.

```bash
sellia http 8080 --server https://sellia.me
```

**Default:** Uses value from `SELLIA_SERVER` environment variable or config file

**Examples:**
```bash
# Use hosted service
sellia http 8080 --server https://sellia.me

# Use local server
sellia http 8080 --server http://localhost:3000

# Use custom server
sellia http 8080 --server https://tunnels.mycompany.com
```

## Start Command Options

### `--config` / `-c`

Specify configuration file.

```bash
sellia start --config sellia.prod.yml
```

**Long form:**
```bash
sellia start --config sellia.prod.yml
```

**Short form:**
```bash
sellia start -c sellia.prod.yml
```

**Default:** Searches for:
1. `~/.config/sellia/sellia.yml`
2. `~/.sellia.yml`
3. `./sellia.yml`

**Examples:**
```bash
# Use specific config
sellia start --config sellia.dev.yml

# Use absolute path
sellia start --config /etc/sellia/config.yml
```

## Server Commands

### sellia-server

Start the tunnel server.

```bash
sellia-server [options]
```

## Server Options

### `--host`

Host to bind to.

```bash
sellia-server --host 0.0.0.0
```

**Default:** `0.0.0.0` (all interfaces)

**Examples:**
```bash
# Listen on all interfaces
sellia-server --host 0.0.0.0

# Listen only on localhost
sellia-server --host 127.0.0.1

# Listen on specific IP
sellia-server --host 192.168.1.10
```

### `--port`

Port to listen on.

```bash
sellia-server --port 3000
```

**Default:** `3000`

**Examples:**
```bash
# Use port 8080
sellia-server --port 8080

# Use port 443 for HTTPS
sellia-server --port 443
```

### `--domain`

Base domain for subdomains.

```bash
sellia-server --domain yourdomain.com
```

**Required** for subdomain routing

**Examples:**
```bash
sellia-server --domain tunnels.mycompany.com
sellia-server --domain sellia.me
```

### `--require-auth`

Require API key authentication.

```bash
sellia-server --require-auth
```

**Default:** `false` (disabled)

**Effect:** Clients must provide valid API key

**Example:**
```bash
sellia-server --require-auth --master-key abc123...
```

### `--master-key`

Master API key (enables authentication).

```bash
sellia-server --master-key abc123...
```

**Generate secure key:**
```bash
openssl rand -hex 32
```

**Example:**
```bash
# Generate and use key
KEY=$(openssl rand -hex 32)
sellia-server --master-key "$KEY" --require-auth
```

### `--https`

Generate HTTPS URLs for tunnels.

```bash
sellia-server --https
```

**Default:** `false` (HTTP URLs)

**Requires:** TLS certificates in `./certs/` directory

**Example:**
```bash
sellia-server --domain yourdomain.com --https
```

### `--no-rate-limit`

Disable rate limiting.

```bash
sellia-server --no-rate-limit
```

**Default:** Rate limiting enabled

**Warning:** Disabling may expose server to abuse

**Use when:** You have external rate limiting (e.g., reverse proxy)

### `--no-landing`

Disable the public landing page.

```bash
sellia-server --no-landing
```

**Default:** Landing page enabled

**Use when:** You want a pure tunnel server without web interface

### `--db-path`

Path to SQLite database for reserved subdomains.

```bash
sellia-server --db-path /var/lib/sellia/sellia.db
```

**Default:** `~/.sellia/sellia.db`

### `--no-db`

Disable database and use in-memory defaults.

```bash
sellia-server --no-db
```

**Default:** Database enabled

**Use when:** You don't need persistent reserved subdomain storage

## Flag Precedence

Flags are applied in this order (later overrides earlier):

1. Configuration file defaults
2. Environment variables
3. Command-line flags

**Example:**

Configuration file (`sellia.yml`):
```yaml
server: https://sellia.me
api_key: default-key
```

Environment:
```bash
export SELLIA_API_KEY="env-key"
```

Command:
```bash
sellia http 8080 --api-key cli-key
```

**Result:** `cli-key` is used (highest priority)

## Common Combinations

### Development Tunnel

```bash
sellia http 8080 \
  --subdomain myapp-dev \
  --server https://sellia.me \
  --open
```

### Production Tunnel

```bash
sellia http 8080 \
  --subdomain myapp \
  --server https://sellia.me \
  --api-key $PROD_API_KEY \
  --no-inspector
```

### Protected Tunnel

```bash
sellia http 8080 \
  --subdomain webhooks \
  --auth webhook-tester:secret \
  --server https://sellia.me
```

### Local Server Testing

```bash
sellia http 8080 \
  --server http://localhost:3000 \
  --subdomain test
```

### Multiple Options

```bash
sellia http 8080 \
  --subdomain myapp \
  --auth admin:secret123 \
  --host 192.168.1.100 \
  --api-key abc123 \
  --inspector-port 5000 \
  --open \
  --server https://sellia.me
```

## Short Flag Examples

### Using Short Flags

```bash
# Short version of:
# sellia http 8080 --subdomain myapp --auth user:pass --open

sellia http 8080 -s myapp -a user:pass -o
```

### Mixed Short and Long

```bash
sellia http 8080 \
  -s myapp \
  --auth admin:secret \
  -o
```

## Help Flags

### Get Help

```bash
# General help
sellia help

# Command-specific help
sellia help http
sellia help start

# Server help
sellia-server --help
```

## Version Flag

### Check Version

```bash
sellia version
```

**Output:**
```
Sellia version 1.0.0
Crystal 1.10.0
```

## Troubleshooting Flags

### Debug Mode

Enable debug logging:

```bash
export LOG_LEVEL=debug
sellia http 8080
```

### Config File Issues

If config isn't loading:

```bash
# Check which config files exist
ls -la ~/.config/sellia/sellia.yml ~/.sellia.yml ./sellia.yml

# Use specific config file
sellia start --config /path/to/config.yml
```

## Quick Reference Table

### Client Flags

| Flag | Short | Description | Example |
|------|-------|-------------|---------|
| `--subdomain` | `-s` | Custom subdomain | `--subdomain myapp` |
| `--auth` | `-a` | Basic auth | `--auth user:pass` |
| `--host` | `-H` | Local host | `--host 192.168.1.1` |
| `--api-key` | `-k` | API key | `--api-key abc123` |
| `--inspector-port` | `-i` | Inspector port | `--inspector-port 5000` |
| `--open` | `-o` | Open inspector | `--open` |
| `--no-inspector` | - | Disable inspector | `--no-inspector` |
| `--server` | - | Server URL | `--server https://sellia.me` |
| `--config` | `-c` | Config file | `--config sellia.yml` |

### Server Flags

| Flag | Description | Example | Default |
|------|-------------|---------|---------|
| `--host` | Bind host | `--host 0.0.0.0` | `0.0.0.0` |
| `--port` | Bind port | `--port 3000` | `3000` |
| `--domain` | Base domain | `--domain example.com` | - |
| `--require-auth` | Require auth | `--require-auth` | `false` |
| `--master-key` | API key | `--master-key abc123` | - |
| `--https` | HTTPS URLs | `--https` | `false` |
| `--no-rate-limit` | Disable rate limit | `--no-rate-limit` | (enabled) |
| `--no-landing` | Disable landing page | `--no-landing` | (enabled) |
| `--db-path` | Database path | `--db-path /path/to/db` | `~/.sellia/sellia.db` |
| `--no-db` | Disable database | `--no-db` | (enabled) |

## Next Steps

- [Configuration File](./config-file.md) - YAML configuration
- [Environment Variables](./environment-variables.md) - ENV var reference
- [Multiple Tunnels](./multiple-tunnels.md) - Managing several tunnels

## Examples Repository

See more examples in the [Sellia examples repository](https://github.com/watzon/sellia/tree/main/examples).

## Command Reference

### Quick Commands

```bash
# Basic tunnel
sellia http 8080

# Custom subdomain
sellia http 8080 -s myapp

# With authentication
sellia http 8080 -a admin:secret

# Full featured
sellia http 8080 \
  -s myapp \
  -a admin:secret \
  -o \
  --server https://sellia.me

# Start from config
sellia start

# Start server
sellia-server \
  --domain yourdomain.com \
  --require-auth \
  --master-key $(openssl rand -hex 32)
```
