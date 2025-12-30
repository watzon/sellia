# HTTP Tunnels

HTTP tunnels are the primary way to expose local web servers to the internet through Sellia. This guide covers the basics of creating and managing HTTP tunnels.

## What are HTTP Tunnels?

HTTP tunnels create a secure pathway from a public URL to your local development server. When requests come to your tunnel URL, Sellia forwards them to your local machine and returns the response to the requester.

### How It Works

```
Internet Request → Sellia Server → Your Local Sellia Client → Your Local Server → Response → Back Through Tunnel
```

1. You create a tunnel from port 8080 on your machine
2. Sellia provides a public URL like `http://abc123.domain.com`
3. When someone requests that URL, Sellia forwards the request to your local port 8080
4. Your application responds, and Sellia sends it back

## Creating Your First HTTP Tunnel

### Basic Tunnel

The simplest tunnel forwards a local port to a random subdomain:

```bash
sellia http 8080
```

This will output:
```
Sellia v0.x.x
Forwarding to localhost:8080

Public URL: http://xyz789.your-domain.com:3000 -> localhost:8080

Inspector:  http://127.0.0.1:4040

Press Ctrl+C to stop
```

Your local server on port 8080 is now accessible via the provided URL.

### Tunnel to Specific Server

By default, Sellia connects to the server configured in your config file (or `https://sellia.me`). To specify a different server:

```bash
sellia http 8080 --server ws://localhost:3000

# Or for a remote server with HTTPS
sellia http 8080 --server https://your-server.com
```

### Custom Local Host

If your local server is running on a different host (not localhost):

```bash
sellia http 8080 --host 192.168.1.100
```

## Common Use Cases

### Webhook Development

Test webhooks from Stripe, GitHub, Slack, etc.:

```bash
# Start your webhook handler
python webhook_server.py &

# Create tunnel
sellia http 5000 --subdomain webhooks

# Use the URL in your webhook configuration
# The URL format depends on your server configuration
```

### API Development

Test mobile apps or frontend against a local API:

```bash
# Start your API
rails server -p 4000 &

# Create tunnel
sellia http 4000 --subdomain api-dev

# Your mobile app can now access the tunnel URL
# URL format depends on server configuration
```

### Frontend Development

Share your frontend work with clients or team members:

```bash
# Start your dev server
npm run dev &

# Create tunnel
sellia http 5173 --subdomain preview

# Share the tunnel URL for review
```

### Microservices Testing

Test multiple services at once:

```bash
# Terminal 1 - Service A
sellia http 8001 --subdomain service-a &

# Terminal 2 - Service B
sellia http 8002 --subdomain service-b &

# Terminal 3 - Service C
sellia http 8003 --subdomain service-c &
```

## Request and Response Behavior

### Preserving Headers

Sellia preserves most HTTP headers through the tunnel, including:
- `Content-Type`
- `User-Agent`
- `Authorization`
- Custom headers

### WebSocket Support

HTTP tunnels automatically support WebSocket connections. The tunnel upgrades connections seamlessly:

```bash
# Your WebSocket server on port 8080
sellia http 8080 --subdomain ws-server

# Clients can connect to wss://ws-server.your-domain.com:3000
```

See [WebSocket Support](./websockets.md) for more details.

### HTTPS/TLS

The tunnel itself is encrypted using WebSocket over TLS. Your application can use HTTP or HTTPS locally - Sellia handles the secure connection to the server.

## Connection Management

### Automatic Reconnection

Sellia automatically reconnects to the tunnel server if the connection drops, using linear backoff:

- Initial retry: 3 seconds
- Maximum retry: 30 seconds (after 10 attempts)
- Max attempts: 10
- Delay formula: `3s × attempt_number` (3s, 6s, 9s, 12s...)

You'll see log messages like:
```
[Sellia] Connection lost, reconnecting in 1s...
[Sellia] Reconnected successfully
```

### Manual Reconnection

If you need to force a reconnection, press `Ctrl+C` to stop the tunnel and restart it.

### Connection Health

Monitor your connection status:

```bash
# Watch the tunnel logs
sellia http 8080 --server https://sellia.me
```

Healthy connections show:
```
[Sellia] Tunnel established at: http://xyz789.your-domain.com:3000
[Sellia] Connection active
```

## URL Formats

### HTTP URLs

```bash
sellia http 8080 --server http://localhost:3000
# Output: http://xyz789.localhost:3000
```

### HTTPS URLs

When using a server with HTTPS:

```bash
sellia http 8080 --server https://sellia.me
# Output: https://xyz789.sellia.me
```

### Port Specification

The tunnel URL port depends on the server configuration:
- Default: Port 3000 or 443 (for HTTPS)
- Custom: Whatever port your server uses

## Tunnel Options

### Subdomain

Request a specific subdomain (if available):

```bash
sellia http 8080 --subdomain myapp
# Output: http://myapp.your-domain.com:3000 (or https:// with --https server)
```

See [Subdomain Management](./subdomains.md) for details.

### Basic Authentication

Protect your tunnel with username/password:

```bash
sellia http 8080 --auth admin:secret123
```

See [Basic Auth](./basic-auth.md) for details.

### Inspector Control

Enable or disable the request inspector:

```bash
# Enable inspector (default)
sellia http 8080

# Disable inspector
sellia http 8080 --no-inspector

# Custom inspector port
sellia http 8080 --inspector-port 5000

# Open inspector in browser
sellia http 8080 --open
```

See [Request Inspector](../inspector/live-monitoring.md) for details.

## Performance Considerations

### Bandwidth

Tunnel speed depends on:
- Your local internet upload speed
- Server bandwidth
- Distance between you and the server
- Number of concurrent connections

### Latency

Typical tunnel latency:
- Same server: 5-15ms
- Different regions: 50-200ms
- International: 200-500ms

### Concurrent Connections

Sellia handles multiple concurrent connections efficiently. For high-traffic scenarios:
- Use a server close to your users
- Enable server-side caching if applicable
- Monitor performance using the inspector

## Troubleshooting

### "Connection Refused"

Your local server isn't running:

```bash
# Check if port is in use
lsof -i :8080

# Start your server
python -m http.server 8080
```

### Tunnel Not Accessible

1. Verify the tunnel is running
2. Check the tunnel URL is correct
3. Ensure your local server is responding
4. Check firewall settings

### Slow Response Times

1. Check your internet connection
2. Verify server location (use a closer server)
3. Check if your local server is slow
4. Monitor using the inspector

### Intermittent Connections

1. Check your network stability
2. Verify server uptime
3. Check for rate limiting
4. Review server logs

## Best Practices

### 1. Use Meaningful Subdomains

Choose subdomains that identify your project:

```bash
# Good
sellia http 8080 --subdomain acme-webhooks
sellia http 8080 --subdomain feature-auth-test

# Avoid
sellia http 8080 --subdomain test
sellia http 8080 --subdomain temp
```

### 2. Protect Sensitive Tunnels

Use basic authentication for sensitive applications:

```bash
sellia http 8080 --auth user:secure-password
```

### 3. Monitor Requests

Use the inspector to debug issues:

```bash
sellia http 8080 --open
```

### 4. Clean Up

Stop tunnels when not needed to free server resources:

```bash
# Press Ctrl+C to stop the tunnel
```

### 5. Use Configuration Files

For persistent setups, use a configuration file:

```yaml
# sellia.yml
server: https://sellia.me

tunnels:
  web:
    port: 8080
    subdomain: myapp
  api:
    port: 4000
    subdomain: myapp-api
    auth: admin:secret
```

Start with:

```bash
sellia start
```

## Next Steps

- [WebSocket Support](./websockets.md) - Real-time connections
- [Basic Authentication](./basic-auth.md) - Secure your tunnels
- [Subdomain Management](./subdomains.md) - Custom URLs
- [Request Inspector](../inspector/live-monitoring.md) - Debug requests
- [Multiple Tunnels](../configuration/multiple-tunnels.md) - Manage several tunnels

## Examples

### Example 1: Development Workflow

```bash
# Terminal 1: Start your app
npm run dev

# Terminal 2: Create tunnel
sellia http 5173 --subdomain dev-$(git rev-parse --short HEAD) --open

# Share the URL with your team
# Output: https://dev-abc1234.sellia.me
```

### Example 2: Testing Multiple Environments

```bash
# Staging
sellia http 3000 --subdomain myapp-staging &

# Production (local)
sellia http 3000 --subdomain myapp-prod &
```

### Example 3: API and Frontend

```bash
# API tunnel
sellia http 4000 --subdomain api &

# Frontend tunnel
sellia http 5173 --subdomain app &
```

Now your frontend at `https://app.sellia.me` can talk to your API at `https://api.sellia.me`.
