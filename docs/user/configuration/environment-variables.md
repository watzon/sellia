# Environment Variables

Configure Sellia using environment variables for secrets, environment-specific settings, and CI/CD integration. Environment variables take precedence over config file defaults but can be overridden by CLI flags.

## Priority Order

Settings are applied in this order (later overrides earlier):

1. Config file defaults (`sellia.yml`)
2. Environment variables
3. CLI flags

## Client Environment Variables

### Server Configuration

#### `SELLIA_SERVER`

Default tunnel server URL.

```bash
export SELLIA_SERVER="https://sellia.me"
```

Usage:
```bash
sellia http 8080  # Uses SELLIA_SERVER
```

Override with flag:
```bash
sellia http 8080 --server https://other-server.com
```

### Authentication

#### `SELLIA_API_KEY`

API key for server authentication.

```bash
export SELLIA_API_KEY="your-api-key-here"
```

Usage:
```bash
sellia http 8080  # Uses SELLIA_API_KEY
```

**Note:** The admin API uses the same `SELLIA_API_KEY` environment variable or `api_key` config file setting. There is no separate admin API key.

#### `SELLIA_DB_PATH`

Path to SQLite database for reserved subdomains (server only).

```bash
export SELLIA_DB_PATH="/var/lib/sellia/sellia.db"
```

Default: `~/.sellia/sellia.db`

#### `SELLIA_NO_DB`

Disable database and use in-memory defaults (server only).

```bash
export SELLIA_NO_DB="true"
```

Values: `true`, `1` to disable

### Inspector Settings

The inspector is controlled by CLI flags (`--no-inspector`, `--inspector-port`, `--open`) and config file settings rather than environment variables.

### Log Level

#### `LOG_LEVEL`

Set logging verbosity.

```bash
export LOG_LEVEL="debug"  # debug, info, warn, error
```

Default: `warn`

## Server Environment Variables

### Basic Settings

#### `SELLIA_HOST`

Host to bind to.

```bash
export SELLIA_HOST="0.0.0.0"
```

Default: `0.0.0.0`

#### `SELLIA_PORT`

Port to listen on.

```bash
export SELLIA_PORT="3000"
```

Default: `3000`

#### `SELLIA_DOMAIN`

Base domain for subdomains.

```bash
export SELLIA_DOMAIN="yourdomain.com"
```

Required for subdomain routing.

### Authentication

#### `SELLIA_REQUIRE_AUTH`

Require API key authentication.

```bash
export SELLIA_REQUIRE_AUTH="true"
```

Values: `true`, `false`
Default: `false`

#### `SELLIA_MASTER_KEY`

Master API key for server authentication.

```bash
export SELLIA_MASTER_KEY="$(openssl rand -hex 32)"
```

Generate secure key:
```bash
openssl rand -hex 32
```

### TLS/HTTPS

#### `SELLIA_USE_HTTPS`

Generate HTTPS URLs for tunnels.

```bash
export SELLIA_USE_HTTPS="true"
```

Values: `true`, `false`
Default: `false`

### Rate Limiting

#### `SELLIA_RATE_LIMITING`

Enable or disable rate limiting.

```bash
# Enable (default)
export SELLIA_RATE_LIMITING="true"

# Disable
export SELLIA_RATE_LIMITING="false"
```

Values: `true`, `false`
Default: `true`

### Landing Page

#### `SELLIA_DISABLE_LANDING`

Disable the public landing page UI.

```bash
export SELLIA_DISABLE_LANDING="true"
```

Values: `true`, `false`
Default: `false`

### Logging

Use `LOG_LEVEL` to control server logging verbosity.

## Using Environment Variables

### Shell Session

Set in your current shell:

```bash
export SELLIA_SERVER="https://sellia.me"
export SELLIA_API_KEY="your-key"
sellia http 8080
```

### Permanent Configuration

Add to shell profile:

```bash
# ~/.bashrc or ~/.zshrc
export SELLIA_SERVER="https://sellia.me"
export SELLIA_API_KEY="your-key"
```

Reload:
```bash
source ~/.bashrc
# or
source ~/.zshrc
```

### .env File

Create `.env` in project directory:

```bash
# .env
SELLIA_SERVER=https://sellia.me
SELLIA_API_KEY=your-key
```

**IMPORTANT**: Add `.env` to `.gitignore`:
```bash
echo ".env" >> .gitignore
```

### Docker Compose

Use in `docker-compose.yml`:

```yaml
version: '3.8'
services:
  sellia:
    image: sellia:latest
    environment:
      - SELLIA_DOMAIN=yourdomain.com
      - SELLIA_MASTER_KEY=${SELLIA_MASTER_KEY}
      - SELLIA_REQUIRE_AUTH=true
      - SELLIA_USE_HTTPS=true
    env_file:
      - .env
```

### Systemd Service

Use in systemd service file:

```ini
# /etc/systemd/system/sellia.service
[Unit]
Description=Sellia Tunnel Server
After=network.target

[Service]
Type=simple
User=sellia
Environment="SELLIA_DOMAIN=yourdomain.com"
Environment="SELLIA_MASTER_KEY=your-key"
Environment="SELLIA_REQUIRE_AUTH=true"
Environment="SELLIA_USE_HTTPS=true"
ExecStart=/usr/local/bin/sellia-server
Restart=always

[Install]
WantedBy=multi-user.target
```

## Environment-Specific Configuration

### Development

```bash
# .env.development
SELLIA_SERVER=http://localhost:3000
LOG_LEVEL=debug
```

### Staging

```bash
# .env.staging
SELLIA_SERVER=https://staging.sellia.me
SELLIA_API_KEY=${STAGING_API_KEY}
LOG_LEVEL=info
```

### Production

```bash
# .env.production
SELLIA_SERVER=https://sellia.me
SELLIA_API_KEY=${PROD_API_KEY}
LOG_LEVEL=warn
```

Load environment-specific file:

```bash
# Development
export $(cat .env.development | xargs)
sellia start

# Production
export $(cat .env.production | xargs)
sellia start
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy Tunnels

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Sellia
        run: |
          wget https://github.com/watzon/sellia/releases/latest/download/sellia-linux-amd64
          chmod +x sellia-linux-amd64
          sudo mv sellia-linux-amd64 /usr/local/bin/sellia

      - name: Start tunnels
        env:
          SELLIA_SERVER: ${{ secrets.SELLIA_SERVER }}
          SELLIA_API_KEY: ${{ secrets.SELLIA_API_KEY }}
        run: sellia start
```

### GitLab CI

```yaml
# .gitlab-ci.yml
deploy:
  script:
    - apt-get update && apt-get install -y sellia
    - sellia http 3000 --subdomain $CI_PROJECT_NAME
  variables:
    SELLIA_SERVER: "https://sellia.me"
    SELLIA_API_KEY: "$SELLIA_API_KEY"
```

### Jenkins

```groovy
// Jenkinsfile
pipeline {
  agent any
  environment {
    SELLIA_SERVER = 'https://sellia.me'
    SELLIA_API_KEY = credentials('sellia-api-key')
  }
  stages {
    stage('Deploy Tunnel') {
      steps {
        sh 'sellia http 3000 --subdomain myapp'
      }
    }
  }
}
```

## Security Best Practices

### 1. Never Commit Secrets

**WRONG**:
```yaml
# sellia.yml (committed)
api_key: key_abc123...
```

**CORRECT**:
```yaml
# sellia.yml (committed)
api_key: ${SELLIA_API_KEY}
```

```bash
# .env (NOT committed)
SELLIA_API_KEY=key_abc123...
```

### 2. Use Different Keys per Environment

```bash
# Development
export SELLIA_API_KEY="dev-key-abc123"

# Staging
export SELLIA_API_KEY="staging-key-def456"

# Production
export SELLIA_API_KEY="prod-key-ghi789"
```

### 3. Rotate Keys Regularly

```bash
# Generate new key
NEW_KEY=$(openssl rand -hex 32)

# Update environment
export SELLIA_API_KEY="$NEW_KEY"

# Update server configuration
# (restart server with new key)
```

### 4. Use Secret Management

For production, use secret management tools:

- **AWS**: Parameter Store, Secrets Manager
- **HashiCorp**: Vault
- **Cloud**: Google Secret Manager, Azure Key Vault
- **Tools**: 1Password, Bitwarden Secrets

Example with AWS Secrets Manager:

```bash
# Load secret from AWS
export SELLIA_API_KEY=$(aws secretsmanager get-secret-value --secret-id sellia/api-key --query SecretString --output text)
sellia http 8080
```

## Examples

### Example 1: Local Development

```bash
# .env.local
SELLIA_SERVER=http://localhost:3000
LOG_LEVEL=debug

# Load and run
source .env.local
sellia http 8080
```

### Example 2: Team Setup

Each team member has their own `.env`:

```bash
# John's .env
SELLIA_SERVER=https://sellia.me
SELLIA_API_KEY=johns-key
```

```bash
# Jane's .env
SELLIA_SERVER=https://sellia.me
SELLIA_API_KEY=janes-key
```

Each developer has their own `sellia.yml`:
```yaml
# John's sellia.yml
server: https://sellia.me
api_key: jQK8Rz2m...

tunnels:
  web:
    port: 3000
    subdomain: john-dev
```

Or use environment-specific config files:
```bash
# John runs:
sellia start --config sellia.john.yml

# Jane runs:
sellia start --config sellia.jane.yml
```

### Example 3: Docker Deployment

```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - SELLIA_SERVER=${SELLIA_SERVER}
      - SELLIA_API_KEY=${SELLIA_API_KEY}
    depends_on:
      - sellia-client

  sellia-client:
    image: sellia:latest
    environment:
      - SELLIA_SERVER=${SELLIA_SERVER}
      - SELLIA_API_KEY=${SELLIA_API_KEY}
    command: http 3000
```

### Example 4: Server Deployment

```bash
# /etc/sellia/environment
SELLIA_DOMAIN=tunnels.mycompany.com
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
SELLIA_USE_HTTPS=true
SELLIA_RATE_LIMITING=true
LOG_LEVEL=warn
```

Start server:
```bash
source /etc/sellia/environment
sellia-server
```

## Troubleshooting

### Variable Not Set

Check if variable is set:

```bash
echo $SELLIA_API_KEY
# Should show value or empty
```

List all Sellia variables:

```bash
env | grep SELLIA
```

### Variable Ignored

Check priority order - CLI flags override env vars:

```bash
# This overrides SELLIA_SERVER
sellia http 8080 --server https://other.com
```

### Special Characters

Escape special characters:

```bash
# Wrong
export SELLIA_API_KEY=key with spaces

# Right
export SELLIA_API_KEY='key with spaces'

# Or
export SELLIA_API_KEY="key with spaces"
```

### Shell Profile Not Loaded

If variables aren't persistent:

```bash
# For bash
echo 'export SELLIA_API_KEY="key"' >> ~/.bashrc
source ~/.bashrc

# For zsh
echo 'export SELLIA_API_KEY="key"' >> ~/.zshrc
source ~/.zshrc
```

## Reference Table

### Client Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SELLIA_SERVER` | Tunnel server URL | - |
| `SELLIA_API_KEY` | API key for authentication | - |
| `SELLIA_DB_PATH` | SQLite database path (server) | `~/.sellia/sellia.db` |
| `SELLIA_NO_DB` | Disable database (server) | - |
| `LOG_LEVEL` | Logging verbosity | `warn` |

### Server Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SELLIA_HOST` | Host to bind to | `0.0.0.0` |
| `SELLIA_PORT` | Port to listen on | `3000` |
| `SELLIA_DOMAIN` | Base domain for subdomains | - |
| `SELLIA_REQUIRE_AUTH` | Require authentication | `false` |
| `SELLIA_MASTER_KEY` | Master API key | - |
| `SELLIA_USE_HTTPS` | Generate HTTPS URLs | `false` |
| `SELLIA_RATE_LIMITING` | Enable rate limiting | `true` |
| `SELLIA_DISABLE_LANDING` | Disable landing page | `false` |

## Next Steps

- [Configuration File](./config-file.md) - YAML configuration
- [CLI Flags](./cli-flags.md) - Command-line options
- [Multiple Tunnels](./multiple-tunnels.md) - Managing several tunnels

## Quick Reference

```bash
# Set variable
export SELLIA_SERVER="https://sellia.me"

# Use variable
sellia http 8080

# Multiple variables
export SELLIA_SERVER="https://sellia.me"
export SELLIA_API_KEY="key"
export LOG_LEVEL="debug"

# From .env file
source .env
sellia start

# In Docker
docker run -e SELLIA_API_KEY="key" sellia

# In systemd
Environment="SELLIA_SERVER=https://sellia.me"
```
