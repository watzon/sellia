# CLI Flags Reference

Complete reference of all command-line flags and options for Sellia.

## Commands Overview

```
sellia <command> [options]
```

Available commands:
- `http` - Create HTTP tunnel to local port
- `start` - Start tunnels from config file
- `auth` - Manage authentication
- `admin` - Admin commands (requires admin API key)
- `update` - Update to latest version
- `version` - Show version
- `help` - Show help

---

## Global Options

These options can be used with any command (though availability varies by command):

| Flag | Short | Type | Description | Available In |
|------|-------|------|-------------|--------------|
| `--help` | `-h` | - | Show help message | All commands |
| `--version` | `-v` | - | Show version | Top-level only |

---

## `sellia http` Command

Create a single HTTP tunnel to a local port.

### Usage

```
sellia http [port] [options]
```

### Options

| Flag | Short | Argument | Default | Description |
|------|-------|----------|---------|-------------|
| `--subdomain` | `-s` | `NAME` | (random) | Request specific subdomain |
| `--auth` | `-a` | `USER:PASS` | (none) | Enable basic auth protection |
| `--host` | `-H` | `HOST` | `localhost` | Local host to forward to |
| `--server` | - | `URL` | From config | Tunnel server URL |
| `--api-key` | `-k` | `KEY` | From config | API key for authentication |
| `--inspector-port` | `-i` | `PORT` | `4040` | Inspector UI port |
| `--open` | `-o` | - | `false` | Open inspector in browser on connect |
| `--no-inspector` | - | - | `false` | Disable the request inspector |
| `--help` | `-h` | - | - | Show help message |

### Positional Arguments

| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `port` | Integer | No | Local port to forward (default: 3000) |

### Examples

```bash
# Basic tunnel
sellia http 3000

# With custom subdomain
sellia http 3000 --subdomain myapp

# With basic auth
sellia http 3000 --auth admin:secret

# Custom local host
sellia http 8080 --host 192.168.1.100

# Disable inspector
sellia http 3000 --no-inspector

# Custom inspector port and auto-open
sellia http 3000 --inspector-port 8080 --open
```

---

## `sellia start` Command

Start multiple tunnels from config file.

### Usage

```
sellia start [options]
```

### Options

| Flag | Short | Argument | Default | Description |
|------|-------|----------|---------|-------------|
| `--config` | `-c` | `FILE` | `sellia.yml` | Config file path |
| `--help` | `-h` | - | - | Show help message |

### Examples

```bash
# Use default config file
sellia start

# Use custom config
sellia start --config tunnels.yml
sellia start -c /path/to/config.yml
```

---

## `sellia auth` Command

Manage authentication (save/remove API keys).

### Usage

```
sellia auth <subcommand>
```

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `login` | Save API key for authentication |
| `logout` | Remove saved API key |
| `status` | Show current authentication status |

### `sellia auth login`

Prompts for and saves API key to `~/.config/sellia/sellia.yml`.

```bash
sellia auth login
# Prompts: API Key: [paste key]
```

### `sellia auth logout`

Removes saved API key from config file.

```bash
sellia auth logout
```

### `sellia auth status`

Shows current authentication status and masked API key.

```bash
sellia auth status
```

---

## `sellia admin` Command

Admin commands for server management (requires admin API key).

### Usage

```
sellia admin <subcommand> [options]
```

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `reserved` | Manage reserved subdomains |
| `api-keys` | Manage API keys |

### Common Options

| Flag | Short | Argument | Default | Description |
|------|-------|----------|---------|-------------|
| `--server` | - | `URL` | From config | Tunnel server URL |

### `sellia admin reserved` Commands

| Subcommand | Description |
|------------|-------------|
| `list` | List all reserved subdomains |
| `add <subdomain>` | Add a reserved subdomain |
| `remove <subdomain>` | Remove a reserved subdomain |
| `rm <subdomain>` | Alias for remove |

#### `sellia admin reserved` Options

| Flag | Argument | Description |
|------|----------|-------------|
| `--reason` | `TEXT` | Reason for reserving the subdomain |
| `--server` | `URL` | Server URL (default: from config) |

### `sellia admin api-keys` Commands

| Subcommand | Description |
|------------|-------------|
| `list` | List all API keys |
| `create` | Create a new API key |
| `revoke <prefix>` | Revoke an API key |
| `rm <prefix>` | Alias for revoke |

#### `sellia admin api-keys` Options

| Flag | Argument | Description |
|------|----------|-------------|
| `--name` | `NAME` | Friendly name for the key |
| `--master` | - | Create master key (admin access) |
| `--server` | `URL` | Server URL (default: from config) |

### Examples

```bash
# List reserved subdomains
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin reserved list

# Reserve a subdomain
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin reserved add myapp

# Reserve with reason
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin reserved add myapp --reason "Production app"

# Release a subdomain
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin reserved remove myapp

# List API keys
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin api-keys list

# Create new API key
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin api-keys create --name "Dev key"

# Create master key
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin api-keys create --master --name "Admin key"

# Revoke API key
SELLIA_ADMIN_API_KEY=sk_live_admin sellia admin api-keys revoke sk_live_
```

---

## `sellia update` Command

Update Sellia to the latest version.

### Usage

```
sellia update [options]
```

### Options

| Flag | Short | Argument | Default | Description |
|------|-------|----------|---------|-------------|
| `--check` | `-c` | - | `false` | Check for updates without installing |
| `--force` | `-f` | - | `false` | Force reinstall even if up-to-date |
| `--version` | `-v` | `VERSION` | (latest) | Update to specific version |
| `--help` | `-h` | - | - | Show help message |

### Examples

```bash
# Check for updates
sellia update --check

# Update to latest
sellia update

# Force reinstall
sellia update --force

# Update to specific version
sellia update --version 0.2.0
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Error occurred |

---

## Configuration Precedence

When multiple sources provide the same value, priority is:

1. **CLI flags** (highest)
2. Environment variables
3. Config files
4. Default values (lowest)

Example:

```bash
# Config file has: server: https://default.com
# Environment: SELLIA_SERVER=https://env.com
# CLI flag: --server https://cli.com

sellia http 3000 --server https://cli.com
# Result: Uses https://cli.com (CLI flag wins)
```

---

## Common Flag Combinations

### Development

```bash
# Fast reload with inspector
sellia http 3000 --open --inspector-port 4040

# Multiple services with routing
sellia http 3000 --subdomain dev
```

### Production

```bash
# With auth and custom subdomain
sellia http 3000 --subdomain myapp --auth admin:secret

# Custom server
sellia http 3000 --server https://tunnel.mycompany.com
```

### Debugging

```bash
# Disable inspector for minimal overhead
sellia http 3000 --no-inspector

# Local development server
sellia http 3000 --host 0.0.0.0 --server http://localhost:8080
```

---

## See Also

- [Environment Variables Reference](./env-vars.md) - Environment-based configuration
- [Configuration Reference](./config-reference.md) - Config file format
- [Getting Started Guide](../user/getting-started/index.md) - Basic usage
