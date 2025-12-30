# Path-Based Routing

Path-based routing is a Tier 2 feature that allows you to route multiple paths from a single tunnel URL to different local ports. This is useful for serving multiple services from a single subdomain.

## Overview

Path-based routing allows you to route multiple paths from a single tunnel URL to different local ports. This is useful for serving multiple services from a single subdomain.

**Important**: This feature is only available via configuration file (`sellia.yml`), not via command-line flags.

Instead of creating multiple tunnels (one for each service), you can define routes that forward requests based on the request path. For example:

- `https://myapp.sellia.me/api` -> localhost:8080
- `https://myapp.sellia.me/web` -> localhost:3000
- `https://myapp.sellia.me/*` -> localhost:3000 (fallback)

## How It Works

The router matches paths in the order defined in your configuration:

1. **Exact matches**: `/api` matches only `/api`
2. **Prefix matches**: `/api/*` matches `/api`, `/api/users`, `/api/v1/resources`, etc.
3. **Glob patterns**: `/static/*` matches any path starting with `/static/`
4. **Wildcard fallback**: `/*` matches everything (usually defined last as a catch-all)

## Configuration

### Command Line

**Note**: Path routing is only available via configuration file, not command-line flags.

To use path routing, define routes in `sellia.yml`:

### Config File

Create a `sellia.yml` with route definitions:

```yaml
tunnels:
  myapp:
    port: 3000
    subdomain: myapp
    routes:
      - path: /api
        port: 8080
        host: localhost
      - path: /admin
        port: 9000
      - path: /static/*
        port: 3001
```

## Examples

### Multi-Service Application

Route API and frontend from a single URL:

```yaml
tunnels:
  fullstack:
    port: 3000
    subdomain: myapp
    routes:
      - path: /api
        port: 8080  # Backend API
      - path: /graphql
        port: 8080  # GraphQL endpoint
      - path: /*
        port: 3000  # Frontend (fallback)
```

Result:
- `https://myapp.sellia.me/api/users` -> localhost:8080
- `https://myapp.sellia.me/graphql` -> localhost:8080
- `https://myapp.sellia.me/` -> localhost:3000

### Microservices Architecture

Route to multiple microservices:

```yaml
tunnels:
  gateway:
    port: 3000
    subdomain: gateway
    routes:
      - path: /users
        port: 8001
      - path: /orders
        port: 8002
      - path: /payments
        port: 8003
      - path: /auth
        port: 8004
      - path: /*
        port: 3000
```

### Static Assets Server

Offload static files to a dedicated server:

```yaml
tunnels:
  app:
    port: 3000
    subdomain: app
    routes:
      - path: /static/*
        port: 3001  # nginx or CDN
      - path: /uploads/*
        port: 3001
      - path: /*
        port: 3000  # Application server
```

## Pattern Matching

### Exact Match

```yaml
routes:
  - path: /health
    port: 9090
```

Matches only: `https://myapp.sellia.me/health`

### Prefix Match

```yaml
routes:
  - path: /api/*
  ```
Matches:
- `https://myapp.sellia.me/api`
- `https://myapp.sellia.me/api/users`
- `https://myapp.sellia.me/api/v1/resources`

### Wildcard (Catch-All)

```yaml
routes:
  - path: /*
    port: 3000
```

Matches all paths not matched by previous routes.

## Advanced Usage

### Custom Host per Route

Route to different hosts:

```yaml
tunnels:
  multi-host:
    port: 3000
    subdomain: app
    routes:
      - path: /api
        port: 8080
        host: api-server.local  # Custom host
      - path: /admin
        port: 9000
        host: admin.local
      - path: /*
        port: 3000
        host: localhost  # Default
```

### Path-Based Microfrontends

```yaml
tunnels:
  microfrontends:
    port: 3000
    subdomain: app
    routes:
      - path: /dashboard
        port: 3001  # Dashboard app
      - path: /settings
        port: 3002  # Settings app
      - path: /billing
        port: 3003  # Billing app
      - path: /*
        port: 3000  # Shell app
```

## Best Practices

### Route Order Matters

Define more specific routes before general ones:

```yaml
routes:
  - path: /api/v2
    port: 8081  # Must be first
  - path: /api/*
    port: 8080  # Catches everything else under /api
  - path: /*
    port: 3000  # Catch-all fallback
```

### Use Fallback for Root

Always define a catch-all route for unmatched paths:

```yaml
routes:
  - path: /api
    port: 8080
  - path: /admin
    port: 9000
  - path: /*
    port: 3000  # Default fallback
```

### Test Your Routes

Use curl to verify routing:

```bash
# Test API route
curl https://myapp.sellia.me/api/users

# Test admin route
curl https://myapp.sellia.me/admin/settings

# Test fallback
curl https://myapp.sellia.me/
```

## Limitations

- **Routes are evaluated in order** (first match wins)
- **Path matching is prefix-based with glob patterns** (`/api/*` matches `/api` and anything under `/api`)
- **No regex support**
- **WebSocket connections work with path routing**
- **Headers and query strings don't affect routing**
- **Only available via configuration file** (not CLI flags)
- **Routes match exact path or prefix pattern**:
  - Exact: `/api` matches only `/api`
  - Glob: `/api/*` matches `/api`, `/api/users`, `/api/v1/resources`, etc.
- **If no routes match and no fallback port exists**, returns 502 "No route matched path"

## Troubleshooting

### Route Not Matching

If a route isn't working:

1. Check the route order (specific routes first)
2. Verify the path includes leading slash: `/api` not `api`
3. Check for trailing slashes (they matter): `/api/` != `/api`
4. Use the inspector to see which route matched

### All Requests Go to Fallback

This usually means:

1. A catch-all (`/*`) is defined before specific routes
2. Path doesn't match any pattern (check typos)
3. Missing leading slash in path definition

### WebSocket Issues

WebSocket connections work with path routing, but ensure:

1. The backend handles the WebSocket upgrade
2. No HTTP/2 interference between proxy and backend
3. Long-lived connection timeouts are configured

## See Also

- [Configuration](../configuration/) - Full config reference
- [Inspector](../inspector/) - Debug routing issues
- [API Keys](../authentication/api-keys.md) - Secure your tunnels
