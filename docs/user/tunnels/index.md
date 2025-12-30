# Tunnels

Everything about creating and managing tunnels with Sellia.

## Overview

Tunnels are secure connections from the public internet to your local development server. Sellia makes it easy to expose local services through custom subdomains.

## Creating Tunnels

### Basic Tunnel

Expose a local service on port 3000:

```bash
sellia http 3000
```

### Custom Subdomain

Reserve a specific subdomain:

```bash
sellia http 3000 --subdomain myapp
```

Access at `http://myapp.your-domain.com`

### Basic Authentication

Protect your tunnel with username/password:

```bash
sellia http 3000 --auth admin:secret
```

### Advanced Options

```bash
# Specify local host
sellia http 3000 --host 127.0.0.1

# Use specific server
sellia http 3000 --server https://sellia.me

# Auto-open inspector
sellia http 3000 --open

# Custom inspector port
sellia http 3000 --inspector-port 5000

# Disable inspector
sellia http 3000 --no-inspector
```

## Managing Tunnels

### Configuration File

Define multiple tunnels in `sellia.yml`:

```yaml
server: https://sellia.me
api_key: your-api-key

tunnels:
  web:
    port: 3000
    subdomain: myapp
  api:
    port: 8080
    subdomain: myapp-api
    auth: admin:secret
```

Start all tunnels:

```bash
sellia start
```

## Tunnel Features

### Subdomain Routing

Each tunnel gets a unique subdomain for easy access:

- Random: `abc123.your-domain.com`
- Custom: `myapp.your-domain.com`

### Automatic Reconnection

Sellia automatically reconnects with linear backoff if the connection drops.

### Basic Auth Protection

Secure tunnels with HTTP basic authentication:

```bash
sellia http 3000 --auth user:pass
```

### Rate Limiting

Server-side rate limiting prevents abuse (configurable on server).

## Use Cases

### Webhook Development

```bash
sellia http 3000 --subdomain webhooks --open
```

Use the inspector to debug webhook payloads in real-time.

### API Development

```bash
sellia http 8080 --subdomain api --auth api:secret
```

Secure your API endpoint with authentication.

### Mobile Development

```bash
sellia http 3000 --subdomain mobile-app
```

Test mobile apps against your local development server.

### Client Demos

```bash
sellia http 3000 --subdomain demo --auth client:preview123
```

Share password-protected previews with clients.

## Best Practices

### Use Configuration Files

For multiple tunnels, use `sellia.yml` instead of CLI flags.

### Reserve Subdomains

Use consistent subdomains in config to avoid conflicts.

### Add Authentication

Always use `--auth` for sensitive development work.

### Monitor with Inspector

Use `--open` to automatically open the inspector UI.

## Troubleshooting

### Subdomain Taken

If your custom subdomain is taken:

- Use a different subdomain
- Let Sellia assign a random one

### Connection Refused

Check:
- Local server is running
- Correct port specified
- Server is accessible

### Inspector Not Working

- Check firewall rules for inspector port
- Try `--inspector-port` with a different port
- Verify no other service is using the port

## Next Steps

- [Inspector](../inspector/) - Debug your tunnels
- [Configuration](../configuration/) - Set up tunnel configs
- [Authentication](../authentication/) - Secure your tunnels
