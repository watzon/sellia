# Multiple Tunnels

Manage multiple tunnels simultaneously for complex applications, microservices architectures, or development workflows. Sellia makes it easy to run and manage several tunnels at once.

## Why Multiple Tunnels?

Use multiple tunnels for:

- **Microservices**: Each service on its own tunnel
- **Full-stack apps**: Separate frontend and backend tunnels
- **Environment separation**: Dev, staging, and production-like tunnels
- **Team collaboration**: Individual tunnels per developer
- **Feature branches**: Dynamic tunnels per Git branch
- **Webhook testing**: Multiple webhook receivers

## Creating Multiple Tunnels

### Command Line (Multiple Terminals)

Run each tunnel in a separate terminal:

```bash
# Terminal 1
sellia http 3000 --subdomain frontend --server https://sellia.me

# Terminal 2
sellia http 4000 --subdomain backend --server https://sellia.me

# Terminal 3
sellia http 5000 --subdomain database --server https://sellia.me
```

### Configuration File (Recommended)

Define all tunnels in `sellia.yml`:

```yaml
server: https://sellia.me

tunnels:
  frontend:
    port: 3000
    subdomain: myapp-frontend

  backend:
    port: 4000
    subdomain: myapp-backend

  admin:
    port: 5000
    subdomain: myapp-admin
```

Start all tunnels:

```bash
sellia start
```

## Configuration File Structure

### Basic Multiple Tunnels

```yaml
server: https://sellia.me
api_key: your-api-key

tunnels:
  web:
    port: 3000
    subdomain: myapp

  api:
    port: 4000
    subdomain: myapp-api

  webhooks:
    port: 5000
    subdomain: myapp-webhooks
```

### Advanced Configuration

```yaml
server: https://sellia.me

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
    auth: admin:secret123  # Protected

  # Webhook receiver
  webhooks:
    port: 6000
    subdomain: myapp-webhooks
    auth: webhook-tester:webhook-secret
```

## Common Patterns

### 1. Full-Stack Application

Frontend and backend tunnels:

```yaml
tunnels:
  frontend:
    port: 3000  # React/Vue/Angular dev server
    subdomain: myapp

  api:
    port: 4000  # Express/Rails/Django API
    subdomain: myapp-api
```

Frontend can call API at `https://myapp-api.sellia.me`.

### 2. Microservices Architecture

Multiple independent services:

```yaml
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

### 3. Environment Separation

Multiple environments for testing:

```yaml
tunnels:
  # Development
  app-dev:
    port: 3000
    subdomain: myapp-dev

  # Staging
  app-staging:
    port: 3001
    subdomain: myapp-staging

  # Production mirror
  app-prod-mirror:
    port: 3002
    subdomain: myapp-prod-like
```

### 4. Team Development

Individual developer tunnels:

```yaml
server: https://sellia.me
api_key: ${SELLIA_API_KEY}

tunnels:
  # Uses developer's username
  web:
    port: 3000
    subdomain: ${USER}-myapp

  api:
    port: 4000
    subdomain: ${USER}-myapi
```

Each developer:
```bash
# John's machine
# Creates: john-myapp.sellia.me
# Creates: john-myapi.sellia.me
```

### 5. Feature Branch Tunnels

Dynamic subdomains based on Git branch:

```bash
# In your development workflow
BRANCH=$(git rev-parse --abbrev-ref HEAD | sed 's/sl_/g/' | tr '/' '-')
SUBDOMAIN="myapp-$BRANCH"

sellia http 3000 --subdomain "$SUBDOMAIN"
```

Or create a script:

```bash
#!/bin/bash
# tunnel-branch.sh

BRANCH=$(git rev-parse --abbrev-ref HEAD)
SAFE_NAME=$(echo "$BRANCH" | tr '[:upper:]' '[:lower:]' | tr '/' '-')
SUBDOMAIN="myapp-$SAFE_NAME"

echo "Creating tunnel for branch: $BRANCH"
echo "Subdomain: $SUBDOMAIN"

sellia http 3000 \
  --subdomain "$SUBDOMAIN" \
  --server https://sellia.me
```

Usage:
```bash
git checkout feature/new-ui
./tunnel-branch.sh
# Creates: myapp-feature-new-ui.sellia.me
```

### 6. Webhook Testing

Multiple webhook receivers:

```yaml
tunnels:
  stripe-webhooks:
    port: 3000
    subdomain: stripe-test
    auth: stripe-tester:secret

  github-webhooks:
    port: 3001
    subdomain: github-test
    auth: github-tester:secret

  slack-webhooks:
    port: 3002
    subdomain: slack-test
    auth: slack-tester:secret
```

## Managing Multiple Tunnels

### Starting All Tunnels

```bash
sellia start
```

Output:
```
Sellia v1.0.0
Starting 3 tunnel(s)...

[frontend] https://myapp.sellia.me -> localhost:3000
[api] https://myapp-api.sellia.me -> localhost:4000
[admin] https://myapp-admin.sellia.me -> localhost:5000

Press Ctrl+C to stop all tunnels
```

**Note:** The inspector is not available with `sellia start`. Use `sellia http` for individual tunnels with inspector functionality.

### Stopping All Tunnels

Press `Ctrl+C` in the terminal where `sellia start` is running.

### Selective Tunnel Start

If you need to start only specific tunnels, create multiple config files:

```bash
# sellia.dev.yml - Only development tunnels
tunnels:
  web:
    port: 3000
    subdomain: myapp-dev

# sellia.prod.yml - Only production tunnels
tunnels:
  web:
    port: 3000
    subdomain: myapp
```

Start selectively:
```bash
sellia start --config sellia.dev.yml
sellia start --config sellia.prod.yml
```

## Inspector and `sellia start`

The request inspector is only available for `sellia http`. The `sellia start` command does not run the inspector for any tunnels.

If you need inspector functionality for development:
- Use `sellia http <port>` for single tunnels with inspector
- The inspector provides HTTP request/response inspection at `http://localhost:4040`
- Use `--no-inspector` flag to disable it when not needed

For production deployments with multiple tunnels, `sellia start` is preferred as it's lighter weight without the inspector overhead.

## Configuration Examples

### Example 1: E-Commerce Platform

```yaml
server: https://sellia.me

tunnels:
  # Frontend stores
  store-web:
    port: 3000
    subdomain: store

  store-admin:
    port: 3001
    subdomain: store-admin
    auth: admin:secret

  # Microservices
  users-api:
    port: 8001
    subdomain: svc-users

  products-api:
    port: 8002
    subdomain: svc-products

  orders-api:
    port: 8003
    subdomain: svc-orders

  payments-api:
    port: 8004
    subdomain: svc-payments

  # Webhooks
  stripe-webhooks:
    port: 5000
    subdomain: stripe-hooks
    auth: webhook:secret
```

### Example 2. Monorepo with Multiple Apps

```yaml
server: https://sellia.me

tunnels:
  # App A
  app-a-web:
    port: 3000
    subdomain: app-a

  app-a-api:
    port: 4000
    subdomain: app-a-api

  # App B
  app-b-web:
    port: 3001
    subdomain: app-b

  app-b-api:
    port: 4001
    subdomain: app-b-api

  # Shared services
  shared-auth:
    port: 8000
    subdomain: shared-auth

  shared-notifications:
    port: 8001
    subdomain: shared-notify
```

### Example 3: CI/CD Environment

```yaml
# sellia.ci.yml
server: ${SELLIA_SERVER}
api_key: ${SELLIA_API_KEY}

tunnels:
  # Pull request preview
  pr-preview:
    port: 3000
    subdomain: pr-${PR_NUMBER}

  # API testing
  api-test:
    port: 4000
    subdomain: api-test-${PR_NUMBER}
```

Usage in CI:
```bash
export PR_NUMBER=123
sellia start --config sellia.ci.yml
# Creates: pr-123.sellia.me
```

## Port Management

### Port Conflicts

If multiple tunnels try to use the same local port, you'll get an error:

```bash
[Sellia] Error: Port 3000 already in use
```

Solution: Use different ports or stop conflicting services.

### Port Ranges

Organize tunnels by port ranges:

```yaml
tunnels:
  # Frontends: 3000-3099
  web:
    port: 3000
    subdomain: web

  admin:
    port: 3001
    subdomain: admin

  # APIs: 4000-4099
  api:
    port: 4000
    subdomain: api

  # Services: 8000-8999
  svc-users:
    port: 8001
    subdomain: svc-users

  svc-payments:
    port: 8002
    subdomain: svc-payments
```

## Health Checking

### Verify All Tunnels

Script to check all tunnels:

```bash
#!/bin/bash
# check-tunnels.sh

TUNNELS=(
  "https://myapp.sellia.me"
  "https://myapp-api.sellia.me"
  "https://myapp-admin.sellia.me"
)

for tunnel in "${TUNNELS[@]}"; do
  echo "Checking $tunnel..."
  if curl -s -o /dev/null -w "%{http_code}" "$tunnel" | grep -q "200"; then
    echo "✓ $tunnel is up"
  else
    echo "✗ $tunnel is down"
  fi
done
```

## Automation

### Start on System Boot

Linux systemd service:

```ini
# /etc/systemd/system/sellia-tunnels.service
[Unit]
Description=Sellia Tunnels
After=network.target

[Service]
Type=simple
User=sellia
WorkingDirectory=/opt/sellia
ExecStart=/usr/local/bin/sellia start
Restart=always
EnvironmentFile=/opt/sellia/.env

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl enable sellia-tunnels
sudo systemctl start sellia-tunnels
```

**Note:** The `Restart=always` directive provides automatic restart on failure. No additional flags are needed.

## Best Practices

### 1. Use Meaningful Names

Choose clear, descriptive tunnel names:

```yaml
tunnels:
  # Good
  frontend-production:
    port: 3000
    subdomain: myapp

  # Less clear
  tunnel1:
    port: 3000
    subdomain: myapp
```

### 2. Group Related Tunnels

```yaml
tunnels:
  # App A tunnels
  app-a-web:
    port: 3000
    subdomain: app-a

  app-a-api:
    port: 4000
    subdomain: app-a-api

  # App B tunnels
  app-b-web:
    port: 3001
    subdomain: app-b

  app-b-api:
    port: 4001
    subdomain: app-b-api
```

### 3. Use Consistent Naming

```yaml
tunnels:
  # Pattern: <app>-<env>-<type>
  shopify-staging-webhook:
    port: 3000
    subdomain: shopify-staging-webhook

  shopify-production-webhook:
    port: 3001
    subdomain: shopify-prod-webhook
```

### 4. Document Tunnel Purpose

Add comments to config:

```yaml
tunnels:
  # Main web application
  web:
    port: 3000
    subdomain: myapp

  # REST API backend
  api:
    port: 4000
    subdomain: myapp-api

  # Admin panel (protected)
  admin:
    port: 5000
    subdomain: myapp-admin
    auth: admin:secret123
```

### 5. Separate Configs per Environment

```bash
sellia.dev.yml       # Development tunnels
sellia.staging.yml   # Staging tunnels
sellia.prod.yml      # Production tunnels
```

## Troubleshooting

### Tunnel Won't Start

Check port availability:

```bash
lsof -i :3000
```

Stop conflicting services or use different ports.

### Subdomain Conflicts

If subdomain is already in use:

```bash
[Sellia] Error: Subdomain 'myapp' already in use
```

Solution: Use different subdomains or stop conflicting tunnels.

### Too Many Inspectors

The `sellia start` command does not launch any inspectors. If you need inspector functionality:

**Option 1:** Use `sellia http` for individual tunnels
```bash
# Terminal 1
sellia http 3000 --subdomain web

# Terminal 2
sellia http 4000 --subdomain api --no-inspector  # Disable inspector for this one
```

**Option 2:** Use `sellia start` without inspector (production)
```bash
sellia start  # No inspector, lighter weight
```

## Next Steps

- [Configuration File](./config-file.md) - YAML configuration
- [Subdomain Management](../tunnels/subdomains.md) - Custom subdomains
- [CLI Flags](./cli-flags.md) - Command-line options

## Quick Reference

| Task | Command |
|------|---------|
| Start all tunnels | `sellia start` |
| Start specific config | `sellia start --config sellia.dev.yml` |
| Stop all tunnels | `Ctrl+C` |
| Check tunnel status | `ps aux \| grep sellia` |
| View all tunnels | Use CLI output and logs |

## Example Configurations

### Minimal Setup

```yaml
server: https://sellia.me

tunnels:
  web:
    port: 3000
    subdomain: myapp
```

### Production Setup

```yaml
server: https://sellia.me
api_key: ${SELLIA_API_KEY}

tunnels:
  web:
    port: 3000
    subdomain: myapp
```

### Development Setup

```yaml
server: https://dev.sellia.me

tunnels:
  web:
    port: 3000
    subdomain: myapp-dev
  api:
    port: 4000
    subdomain: myapi-dev
```
