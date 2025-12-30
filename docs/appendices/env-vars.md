# Environment Variables Reference

Complete list of environment variables supported by Sellia.

## Overview

Environment variables provide a way to configure Sellia without using config files or CLI flags. They follow the naming convention `SELLIA_*` and can be set in your shell environment, `.envrc`, or system configuration.

## Priority Order

Configuration is loaded in the following order (later overrides earlier):

1. Default values (hardcoded)
2. `~/.config/sellia/sellia.yml`
3. `~/.sellia.yml`
4. `./sellia.yml`
5. **Environment variables** (highest priority)

Note: When multiple config files exist, they are merged according to the rules in [Configuration Reference](./config-reference.md#config-merging).

## Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `SELLIA_SERVER` | String | `https://sellia.me` | Tunnel server URL. Override to use a custom tunnel server. |
| `SELLIA_API_KEY` | String | (none) | API authentication key. Required for protected tunnels. |
| `SELLIA_ADMIN_API_KEY` | String | (none) | Admin API key for `sellia admin` commands. |
| `SELLIA_DB_PATH` | String | (none) | Custom path for SQLite database file. Overrides default location. |
| `SELLIA_NO_DB` | Boolean | `false` | Disable database persistence. Set to `1` or `true` to disable. |

**Important:** `SELLIA_NO_DB` behavior is inverted - setting it to `"true"` or `"1"` **disables** the database, while the config file's `database.enabled: false` also disables the database. Both achieve the same result but through opposite logic.

## Usage Examples

### Setting API Key

```bash
# In shell
export SELLIA_API_KEY="your-api-key-here"
sellia http 3000

# Single command
SELLIA_API_KEY="key" sellia http 3000
```

### Using Custom Server

```bash
export SELLIA_SERVER="https://tunnel.example.com"
sellia http 3000
```

### Disabling Database

```bash
# Run without persisting tunnel state
SELLIA_NO_DB=1 sellia http 3000
```

### Custom Database Location

```bash
export SELLIA_DB_PATH="/mnt/data/sellia.db"
sellia http 3000
```

## Security Considerations

### API Key Security

- Never commit API keys to version control
- Use `.envrc` or `.env.local` files (add to `.gitignore`)
- Consider using secret management tools in production

### Example .gitignore

```
.env
.env.local
.envrc
sellia.yml
```

## Environment-Specific Configuration

### Development

```bash
# .envrc for development
export SELLIA_SERVER="http://localhost:8080"
export SELLIA_API_KEY="dev-key"
export SELLIA_DB_PATH="./dev.db"
```

### Production

```bash
# Production environment
export SELLIA_SERVER="https://sellia.me"
export SELLIA_API_KEY="${SECRET_API_KEY}"
# Database enabled by default, no need to set SELLIA_NO_DB
```

### Testing

```bash
# Disable persistence for tests
export SELLIA_NO_DB=1
export SELLIA_SERVER="http://test-server:8080"
```

## Interaction with Config Files

Environment variables override config file values:

```yaml
# sellia.yml
server: https://default-server.com
api_key: default-key
```

```bash
# Environment overrides both
export SELLIA_SERVER="https://custom-server.com"
export SELLIA_API_KEY="custom-key"

# Result: Uses custom values
```

## Logging

Sellia respects Crystal's standard logging environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `LOG_LEVEL` | Minimum log level | `LOG_LEVEL=debug` |
| `LOG_TEXT` | Use text format (default is JSON) | `LOG_TEXT=1` |

Example:

```bash
LOG_LEVEL=debug sellia http 3000
```

## See Also

- [Configuration Reference](./config-reference.md) - Config file format
- [CLI Flags Reference](./cli-flags.md) - Command-line options
- [Defaults Reference](./defaults.md) - Default values
