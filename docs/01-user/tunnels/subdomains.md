# Subdomain Management

Custom subdomains make your tunnel URLs memorable and professional. Instead of random subdomains like `abc123.sellia.me`, use meaningful names like `myapp.sellia.me` or `project-staging.sellia.me`.

## What are Subdomains?

Sellia routes tunnels using subdomains. When you create a tunnel, you get:

```
<SUBDOMAIN>.<DOMAIN>.<PORT>
```

For example: `myapp.sellia.me` or `api-staging.localhost:3000`

### Default Behavior

Without specifying a subdomain, Sellia assigns a random 8-character hex string:

```bash
sellia http 8080
# Output: https://a1b2c3d4.your-domain.com
```

## Requesting Custom Subdomains

Use the `--subdomain` flag to request a specific subdomain:

```bash
sellia http 8080 --subdomain myapp
# Output: http://myapp.your-domain.com:3000 (or https://myapp.your-domain.com if server has --https)
```

### Subdomain Requirements

Valid subdomains:
- **Length**: 3-63 characters
- **Characters**: Lowercase letters, numbers, hyphens
- **Format**: Must start and end with letter or number
- **No**: Spaces, special characters, or consecutive hyphens

Examples:
```
✅ myapp
✅ api-v2
✅ project123
✅ test-environment

❌ MyApp (uppercase)
❡ api_v2 (underscores)
❡ -test (starts with hyphen)
❡ test- (ends with hyphen)
❡ api--v2 (consecutive hyphens)
```

## Subdomain Availability

### First-Come, First-Served

Subdomains are assigned on a first-come, first-served basis:

```bash
# User 1 creates tunnel
sellia http 8080 --subdomain myapp
# Success: http://myapp.your-domain.com:3000

# User 2 tries same subdomain
sellia http 8080 --subdomain myapp
# Error: Subdomain 'myapp' is not available
```

### Conflict Resolution

If your requested subdomain is taken:
1. Sellia returns an error and closes the connection
2. Client will not reconnect (to prevent infinite loops)
3. Try a different subdomain or use a naming convention

```bash
# Try variations
sellia http 8080 --subdomain myapp-backup
sellia http 8080 --subdomain myapp-v2
sellia http 8080 --subdomain myapp-test
```

## Naming Strategies

### 1. Project-Based

Name subdomains after your project:

```bash
sellia http 3000 --subdomain blog-cms
sellia http 4000 --subdomain blog-api
```

### 2. Environment-Based

Include the environment:

```bash
sellia http 3000 --subdomain app-dev
sellia http 3000 --subdomain app-staging
sellia http 3000 --subdomain app-prod-like
```

### 3. Feature-Based

Name after specific features:

```bash
sellia http 3000 --subdomain auth-service
sellia http 4000 --subdomain payment-gateway
sellia http 5000 --subdomain notification-system
```

### 4. User-Based

For personal tunnels:

```bash
sellia http 3000 --subdomain john-dev
sellia http 3000 --subdomain sarah-test
```

### 5. Branch-Based

For Git branch workflows:

```bash
# Current git branch as subdomain
BRANCH=$(git rev-parse --abbrev-ref HEAD)
sellia http 3000 --subdomain "app-$BRANCH"

# Or short commit hash
HASH=$(git rev-parse --short HEAD)
sellia http 3000 --subdomain "app-$HASH"
```

## Configuration File

Define subdomains in `sellia.yml`:

```yaml
server: https://sellia.me

tunnels:
  # Multiple services
  web:
    port: 3000
    subdomain: myapp

  api:
    port: 4000
    subdomain: myapp-api

  admin:
    port: 5000
    subdomain: myapp-admin

  # Multiple environments
  staging:
    port: 3000
    subdomain: app-staging

  dev:
    port: 3001
    subdomain: app-dev
```

Start all tunnels:

```bash
sellia start
```

## Multiple Tunnels with Subdomains

Run multiple tunnels simultaneously, each with its own subdomain:

```bash
# Terminal 1
sellia http 3000 --subdomain frontend --server https://sellia.me &

# Terminal 2
sellia http 4000 --subdomain backend --server https://sellia.me &

# Terminal 3
sellia http 5000 --subdatabase --server https://sellia.me &
```

Now you have:
- `https://frontend.sellia.me` → Frontend app
- `https://backend.sellia.me` → API backend
- `https://database.sellia.me` → Database interface

## Wildcard Subdomains

### For Self-Hosted Servers

When running your own server, configure DNS to accept all subdomains:

```
*.yourdomain.com  →  YOUR_SERVER_IP
```

Now any subdomain works:
- `app1.yourdomain.com`
- `app2.yourdomain.com`
- `test-environment.yourdomain.com`

### Cloudflare Configuration

For Cloudflare-hosted domains:

1. Add domain to Cloudflare
2. Go to **DNS** → **Records**
3. Add CNAME record:
   - **Name**: `*`
   - **Target**: `your-server.com`
   - **Proxy**: Enabled (orange cloud)

## URL Formats

### HTTP URLs

```bash
sellia http 8080 --subdomain myapp --server http://localhost:3000
# Output: http://myapp.localhost:3000
```

### HTTPS URLs

```bash
sellia http 8080 --subdomain myapp --server https://sellia.me
# Output: https://myapp.sellia.me
```

### With Custom Ports

If your server uses a non-standard port:

```bash
sellia http 8080 --subdomain myapp --server https://sellia.me:8443
# Output: https://myapp.sellia.me:8443
```

## Subdomain Best Practices

### 1. Use Meaningful Names

Choose subdomains that identify the purpose:

```bash
# Good
sellia http 3000 --subdomain stripe-webhook-test
sellia http 4000 --subdomain github-integration-dev

# Less clear
sellia http 3000 --subdomain test1
sellia http 4000 --subdomain temp
```

### 2. Consistent Naming Convention

Use a consistent pattern:

```bash
# Pattern: <app>-<environment>-<type>
sellia http 3000 --subdomain shopify-staging-webhook
sellia http 4000 --subdomain shopify-staging-api
```

### 3. Include Environment

Always specify the environment:

```bash
# Production-like
sellia http 3000 --subdomain app-staging
sellia http 3000 --subdomain app-dev

# Avoid confusion
sellia http 3000 --subdomain app  # Which environment?
```

### 4. Avoid Reserved Words

Some words might be reserved for system use:

```bash
# Potentially problematic
www
mail
ftp
localhost
api (if reserved for main API)
admin (if reserved)
```

### 5. Use Hyphens for Readability

Separate words with hyphens:

```bash
# Good
myapp-staging-api
webhook-tester-v2

# Harder to read
myappstagingapi
webhooktesterv2
```

### 6. Keep It Short

Shorter subdomains are easier to remember:

```bash
# Good
app-dev
api-test

# Long
application-development-environment
api-testing-server
```

## Dynamic Subdomains

### Based on Git Branch

```bash
# Automatically use current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD | sed 's/sl_/g/' | tr '/' '-')
sellia http 3000 --subdomain "app-$BRANCH"

# Examples:
# feature/new-ui → app-feature-new-ui
# bugfix/login-issue → app-bugfix-login-issue
```

### Based on Environment Variable

```bash
# Use environment-specific subdomain
sellia http 3000 --subdomain "app-${RAILS_ENV:-development}"
```

### Based on Timestamp

```bash
# Include date or timestamp
DATE=$(date +%Y%m%d)
sellia http 3000 --subdomain "deploy-$DATE"
# Output: deploy-20241230
```

## Subdomain Validation

### Check Subdomain Availability

Before creating a tunnel, check if the subdomain is available:

```bash
# Try to access the subdomain
curl -I https://myapp.sellia.me

# If 404 or connection refused, likely available
# If 200 or similar, subdomain is in use
```

### DNS Verification

Verify DNS is configured correctly:

```bash
dig myapp.yourdomain.com
nslookup myapp.yourdomain.com
```

## Troubleshooting

### Subdomain Already Taken

Error: "Subdomain already in use"

Solutions:
1. Use a different subdomain
2. Add a suffix: `-v2`, `-backup`, `-alt`
3. Include your name/initials

### Subdomain Not Resolving

If your subdomain doesn't work:

1. Verify DNS is configured:
   ```bash
   dig yourdomain.com
   dig *.yourdomain.com
   ```

2. Check server is running:
   ```bash
   sellia-server --domain yourdomain.com
   ```

3. Ensure wildcard DNS is set up

### Mixed Case Issues

Subdomains are case-insensitive but should be lowercase:

```bash
# Sellia converts to lowercase
sellia http 3000 --subdomain MyApp
# Actually creates: myapp.sellia.me
```

## Examples

### Example 1: Full-Stack Application

```yaml
tunnels:
  # Frontend
  web:
    port: 3000
    subdomain: shopify-staging-web

  # API
  api:
    port: 4000
    subdomain: shopify-staging-api

  # Webhook receiver
  webhooks:
    port: 5000
    subdomain: shopify-staging-webhooks
    auth: webhook-tester:secret
```

Access:
- `https://shopify-staging-web.sellia.me` - Frontend
- `https://shopify-staging-api.sellia.me` - API
- `https://shopify-staging-webhooks.sellia.me` - Webhooks

### Example 2: Developer Workflow

```bash
# Automatically use branch name
create_tunnel() {
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  SAFE_NAME=$(echo "$BRANCH" | tr '/' '-' | tr '[:upper:]' '[:lower:]')
  sellia http 3000 --subdomain "app-$SAFE_NAME" --server https://sellia.me
}

# Usage
git checkout feature/new-dashboard
create_tunnel
# Creates: app-feature-new-dashboard.sellia.me
```

### Example 3: Client Demos

```bash
# Unique subdomain per client
CLIENTS=("acme" "globex" "initech")

for client in "${CLIENTS[@]}"; do
  sellia http 3000 \
    --subdomain "demo-$client" \
    --auth "$client-client:$(openssl rand -base64 16)" \
    --server https://sellia.me &
done
```

Creates:
- `demo-acme.sellia.me` (with client-specific auth)
- `demo-globex.sellia.me`
- `demo-initech.sellia.me`

### Example 4: Microservices

```yaml
# Microservice architecture
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

## Next Steps

- [HTTP Tunnels](./http-tunnels.md) - Basic tunnel usage
- [Basic Authentication](./basic-auth.md) - Secure tunnels
- [Configuration File](../configuration/config-file.md) - Multiple tunnels
- [Self-Hosting](../getting-started/self-hosting-quickstart.md) - Your own server

## Quick Reference

| Command | Description |
|---------|-------------|
| `sellia http 8080` | Random subdomain |
| `sellia http 8080 --subdomain myapp` | Custom subdomain |
| `--subdomain app-dev` | Environment-specific |
| `--subdomain svc-name` | Service naming |
| `--subdomain demo-client` | Client-specific |

## Subdomain Checklist

Before creating a production tunnel:

- [ ] Subdomain is meaningful and descriptive
- [ ] Follows naming convention
- [ ] Includes environment identifier
- [ ] Checked for availability
- [ ] DNS is properly configured
- [ ] Documented in team wiki
- [ ] Added to monitoring/config
- [ ] Considered future conflicts
