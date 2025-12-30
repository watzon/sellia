# Configuration

Configure Sellia through files, environment variables, and CLI flags.

## Overview

Sellia supports layered configuration from multiple sources. Later sources override earlier ones:

1. `~/.config/sellia/sellia.yml`
2. `~/.sellia.yml`
3. `./sellia.yml` (current directory)
4. CLI flags (highest priority)

## Configuration File

### Location

Place `sellia.yml` in your project directory:

```bash
cd my-project
cat > sellia.yml << EOF
server: https://sellia.me
api_key: your-api-key
EOF
```

### Example Configuration

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
    auth: user:pass

  api:
    port: 8080
    subdomain: myapp-api
    auth: admin:secret

  webhook:
    port: 3000
    subdomain: webhooks
```

## Environment Variables

### Client Variables

Set environment variables for the CLI client:

```bash
export SELLIA_SERVER=https://sellia.me
export SELLIA_API_KEY=your-api-key
```

### Server Variables

Configure the Sellia server:

```bash
# Basic settings
export SELLIA_HOST=0.0.0.0
export SELLIA_PORT=3000
export SELLIA_DOMAIN=yourdomain.com

# Authentication
export SELLIA_REQUIRE_AUTH=true
export SELLIA_MASTER_KEY=your-master-key

# Features
export SELLIA_USE_HTTPS=true
export SELLIA_RATE_LIMITING=true
export SELLIA_DISABLE_LANDING=true

# Database
export SELLIA_DB_PATH=/var/lib/sellia/sellia.db
export SELLIA_NO_DB=false

# Debugging
export LOG_LEVEL=debug
```

### Docker Environment

Use `.env` file with Docker:

```bash
SELLIA_DOMAIN=yourdomain.com
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
SELLIA_USE_HTTPS=true
```

## CLI Flags

### Server Flags

```bash
sellia-server [options]

Options:
  --host HOST           Host to bind to (default: 0.0.0.0)
  --port PORT           Port to listen on (default: 3000)
  --domain DOMAIN       Base domain for subdomains
  --require-auth        Require API key authentication
  --master-key KEY      Master API key
  --https               Generate HTTPS URLs for tunnels
  --no-rate-limit       Disable rate limiting
  --no-landing          Disable the landing page
  --db-path PATH        Path to SQLite database
  --no-db               Disable database (use in-memory defaults)
```

### Client Flags

```bash
sellia http <port> [options]

Options:
  -s, --subdomain NAME    Request specific subdomain
  -a, --auth USER:PASS    Enable basic auth protection
  -H, --host HOST         Local host (default: localhost)
  -k, --api-key KEY       API key for authentication
  -i, --inspector-port    Inspector UI port (default: 4040)
  -o, --open              Open inspector in browser
  --no-inspector          Disable the request inspector
  --server URL            Tunnel server URL
```

## Configuration Examples

### Development Setup

```yaml
# sellia.yml
server: http://localhost:3000

tunnels:
  app:
    port: 3000
    subdomain: dev
```

### Production Setup

```yaml
# sellia.yml
server: https://tunnel.mycompany.com
api_key: ${SELLIA_API_KEY}  # Use environment variable

tunnels:
  webhook-receiver:
    port: 3000
    subdomain: webhooks-prod
    auth: ${WEBHOOK_AUTH}
```

### Multiple Environments

```yaml
# sellia.dev.yml
server: http://localhost:3000
tunnels:
  app:
    port: 3000
    subdomain: dev
```

```yaml
# sellia.prod.yml
server: https://tunnel.mycompany.com
api_key: ${PROD_API_KEY}
tunnels:
  app:
    port: 3000
    subdomain: prod
    auth: ${PROD_AUTH}
```

Use different configs:

```bash
sellia start --config sellia.dev.yml
sellia start --config sellia.prod.yml
```

## Best Practices

### Security

1. **Never commit API keys** - Use environment variables
2. **Use different keys per environment** - Dev, staging, production
3. **Rotate keys regularly** - Update configurations periodically
4. **Use .gitignore** - Exclude `sellia.yml` with secrets

```bash
# .gitignore
sellia.yml
.env
```

### Organization

1. **Project-specific configs** - Place `sellia.yml` in project root
2. **Shared settings** - Use `~/.config/sellia/sellia.yml` for defaults
3. **Team configs** - Commit example configs without secrets

```yaml
# sellia.example.yml
server: https://tunnel.mycompany.com
api_key: YOUR_API_KEY_HERE

tunnels:
  app:
    port: 3000
    subdomain: myapp
```

### Environment Variables

Use environment variables for:

- API keys
- Authentication credentials
- Server URLs
- Sensitive configuration

```yaml
# sellia.yml
server: ${SELLIA_SERVER}
api_key: ${SELLIA_API_KEY}

tunnels:
  app:
    port: 3000
    subdomain: ${APP_SUBDOMAIN}
    auth: ${APP_AUTH}
```

## Troubleshooting

### Config Not Loading

**Problem:** Configuration file not being read

**Solutions:**
- Verify file is named `sellia.yml`
- Check file location (current directory or home)
- Ensure valid YAML syntax
- Check file permissions

### Environment Variables Ignored

**Problem:** Environment variables not working

**Solutions:**
- Export variables: `export SELLIA_API_KEY=key`
- Use `${VAR}` syntax in YAML
- Check for typos in variable names
- Verify variables are set in shell session

### Conflicting Options

**Problem:** CLI flags not overriding config

**Solutions:**
- CLI flags have highest priority (should override)
- Check flag syntax
- Verify flag is after the command
- Check for multiple config files

## Next Steps

- [Authentication](../authentication/) - Managing API keys
- [Deployment](../deployment/) - Production configuration
- [CLI Reference](../cli-reference/) - All command options
