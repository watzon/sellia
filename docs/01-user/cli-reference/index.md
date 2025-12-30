# CLI Reference

Complete command-line interface reference for Sellia.

## Overview

Reference documentation for all Sellia CLI commands and options.

## CLI Commands

### sellia

Main CLI client for creating tunnels.

### sellia-server

Tunnel server for hosting tunnels.

## sellia Commands

### http

Create HTTP tunnel to local port.

```bash
sellia http <port> [options]
```

**Arguments:**
- `port` - Local port to expose (required)

**Options:**

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--subdomain NAME` | `-s` | Request specific subdomain | Random |
| `--auth USER:PASS` | `-a` | Enable basic auth protection | None |
| `--host HOST` | `-H` | Local host to forward to | localhost |
| `--api-key KEY` | `-k` | API key for authentication | None |
| `--inspector-port PORT` | `-i PORT` | Inspector UI port | 4040 |
| `--open` | `-o` | Open inspector in browser | false |
| `--no-inspector` | | Disable request inspector | false |
| `--server URL` | | Tunnel server URL | From config or https://sellia.me |

**Examples:**

```bash
# Basic tunnel
sellia http 3000

# Custom subdomain
sellia http 3000 --subdomain myapp

# With authentication
sellia http 3000 --auth admin:secret

# Specify local host
sellia http 3000 --host 127.0.0.1

# Using hosted server
sellia http 3000 --server https://sellia.me

# Auto-open inspector
sellia http 3000 --open

# Custom inspector port
sellia http 3000 --inspector-port 5000

# Disable inspector
sellia http 3000 --no-inspector

# Full example
sellia http 3000 \
  --subdomain myapp \
  --auth admin:secret123 \
  --server https://sellia.me \
  --api-key your-api-key \
  --open
```

### start

Start tunnels from config file.

```bash
sellia start [options]
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `--config PATH` | Path to config file | ./sellia.yml |

**Examples:**

```bash
# Start with default config
sellia start

# Start with specific config
sellia start --config config/tunnels.yml

# Start with environment-specific config
sellia start --config sellia.prod.yml
```

### auth

Manage authentication.

```bash
sellia auth <subcommand> [options]
```

**Subcommands:**

#### auth login

Store API key for server.

```bash
sellia auth login <api-key>
```

**Example:**

```bash
sellia auth login your-api-key-here
```

#### auth logout

Remove stored API key.

```bash
sellia auth logout
```

### version

Show version information.

```bash
sellia version
```

**Output:**

```
sellia version 0.1.0
```

### help

Show help information.

```bash
sellia help [command]
```

**Examples:**

```bash
# General help
sellia help

# Command-specific help
sellia help http
sellia help start
```

## sellia-server Commands

### Server Options

```bash
sellia-server [options]
```

**Options:**

| Option | Description | Default | Environment Variable |
|--------|-------------|---------|---------------------|
| `--host HOST` | Host to bind to | 0.0.0.0 | `SELLIA_HOST` |
| `--port PORT` | Port to listen on | 3000 | `SELLIA_PORT` |
| `--domain DOMAIN` | Base domain for subdomains | Required | `SELLIA_DOMAIN` |
| `--require-auth` | Require API key authentication | false | `SELLIA_REQUIRE_AUTH` |
| `--master-key KEY` | Master API key | None | `SELLIA_MASTER_KEY` |
| `--https` | Generate HTTPS URLs for tunnels | false | `SELLIA_USE_HTTPS` |
| `--no-rate-limit` | Disable rate limiting | false | `SELLIA_RATE_LIMITING` |

**Examples:**

```bash
# Basic server
sellia-server --port 3000 --domain yourdomain.com

# With authentication
sellia-server \
  --port 3000 \
  --domain yourdomain.com \
  --require-auth \
  --master-key your-master-key

# Production server
sellia-server \
  --host 0.0.0.0 \
  --port 3000 \
  --domain yourdomain.com \
  --require-auth \
  --master-key $(openssl rand -hex 32) \
  --https

# Development server
LOG_LEVEL=debug sellia-server \
  --port 3000 \
  --domain localhost
```

## Environment Variables

### Client Variables

Variables for `sellia` CLI:

| Variable | Description | Example |
|----------|-------------|---------|
| `SELLIA_SERVER` | Default tunnel server URL | `https://sellia.me` |
| `SELLIA_API_KEY` | Default API key | `your-api-key` |
| `SELLIA_ADMIN_API_KEY` | Admin API key for admin commands | `sk_master_xyz` |

### Server Variables

Variables for `sellia-server`:

| Variable | Description | Example |
|----------|-------------|---------|
| `SELLIA_HOST` | Host to bind to | `0.0.0.0` |
| `SELLIA_PORT` | Port to listen on | `3000` |
| `SELLIA_DOMAIN` | Base domain for subdomains | `yourdomain.com` |
| `SELLIA_REQUIRE_AUTH` | Require authentication | `true`/`false` |
| `SELLIA_MASTER_KEY` | Master API key | `random-key` |
| `SELLIA_USE_HTTPS` | Generate HTTPS URLs | `true`/`false` |
| `SELLIA_RATE_LIMITING` | Enable rate limiting | `true`/`false` |
| `LOG_LEVEL` | Set log level | `debug`, `info`, `warn`, `error` |

## Configuration Files

### sellia.yml

Example configuration file:

```yaml
# Server settings
server: https://sellia.me
api_key: your-api-key

inspector:
  port: 4040
  open: true

# Tunnel definitions
tunnels:
  web:
    port: 3000
    subdomain: myapp
    local_host: localhost

  api:
    port: 8080
    subdomain: myapp-api
    auth: admin:secret

  webhook:
    port: 3000
    subdomain: webhooks
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid usage |
| 3 | Network error |
| 4 | Authentication failed |
| 5 | Server unavailable |

## Common Patterns

### Webhook Development

```bash
sellia http 3000 \
  --subdomain webhooks \
  --open \
  --server https://sellia.me
```

### API Development

```bash
sellia http 8080 \
  --subdomain api \
  --auth api:secret123
```

### Client Demo

```bash
sellia http 3000 \
  --subdomain demo \
  --auth client:preview456
```

### Multiple Services

```yaml
# sellia.yml
tunnels:
  web:
    port: 3000
    subdomain: myapp
  api:
    port: 8080
    subdomain: myapp-api
  admin:
    port: 3001
    subdomain: myapp-admin
    auth: admin:secret
```

```bash
sellia start
```

## Tips and Tricks

### Aliases

Create shell aliases for common commands:

```bash
# ~/.bashrc or ~/.zshrc
alias tunnel='sellia http'
alias tunnel-dev='sellia http --subdomain dev'
alias tunnel-prod='sellia http --server https://sellia.me'
```

### Auto-Completion

Enable bash completion (coming soon):

```bash
# ~/.bashrc
source <(sellia completion bash)
```

### Quick Server

Quick development server:

```bash
LOG_LEVEL=debug sellia-server --port 3000 --domain localhost
```

### Generate Strong Keys

Generate secure authentication keys:

```bash
# Master key
openssl rand -hex 32

# Tunnel auth password
openssl rand -base64 16
```

## Troubleshooting

### Command Not Found

**Problem:** `sellia: command not found`

**Solutions:**
- Add to PATH: `export PATH=$PATH:./bin`
- Install globally: `cp ./bin/sellia /usr/local/bin/`
- Use full path: `./bin/sellia http 3000`

### Port Already in Use

**Problem:** "Port 3000 is already in use"

**Solutions:**
- Use different port: `--port 3001`
- Kill existing process: `kill $(lsof -ti :3000)`
- Find and kill process: `lsof -i :3000`

### Authentication Failed

**Problem:** "Authentication failed"

**Solutions:**
- Verify API key: `--api-key your-key`
- Check server requires auth
- Verify master key on server

### Connection Refused

**Problem:** "Connection refused"

**Solutions:**
- Verify server is running
- Check server URL: `--server http://localhost:3000`
- Check firewall rules
- Verify network connectivity

## Next Steps

- [Getting Started](../getting-started/) - First tunnel setup
- [Tunnels](../tunnels/) - Tunnel creation and management
- [Configuration](../configuration/) - Advanced configuration
