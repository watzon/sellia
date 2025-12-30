# Quick Start Guide

Get up and running with Sellia in 5 minutes. This guide will show you how to expose a local server to the internet using secure tunnels.

## What You'll Learn

By the end of this guide, you'll be able to:
- Create a secure tunnel to a local web server
- Access your local server from the internet
- Monitor incoming requests in real-time
- Use custom subdomains for your tunnels

## Prerequisites

Before starting, ensure you have:
- Sellia installed ([Installation Guide](./installation.md))
- A local web server running (or create a simple one for testing)
- Terminal access

## Step 1: Start a Local Server

First, let's create a simple local server to tunnel. If you already have a server running, skip to Step 2.

### Example: Python HTTP Server

```bash
# Create a test directory
mkdir sellia-test
cd sellia-test

# Start a simple HTTP server on port 8080
python3 -m http.server 8080
```

Or with Node.js:

```bash
# Create a simple server
echo "const http = require('http'); http.createServer((req, res) => res.end('Hello from Sellia!')).listen(8080);" > server.js
node server.js
```

Keep this server running in a terminal window.

## Step 2: Create a Tunnel

Open a new terminal window and create a tunnel to your local server:

```bash
sellia http 8080 --server http://localhost:3000
```

You'll see output like:

```
Sellia v0.4.0
Forwarding to localhost:8080

Public URL: http://abc123.your-domain.com -> localhost:8080

Inspector:  http://127.0.0.1:4040

Press Ctrl+C to stop
```

**That's it!** Your local server is now accessible from the internet.

## Step 3: Test Your Tunnel

Open the tunnel URL in your browser or use curl:

```bash
curl http://abc123.your-domain.com
```

You should see the response from your local server.

## Step 4: Monitor Requests

Sellia includes a real-time request inspector. Open your browser and navigate to:

```
http://localhost:4040
```

Make a few requests to your tunnel URL and watch them appear in the inspector in real-time.

### Inspector Features

- **Live request streaming** - See requests as they arrive
- **Request details** - View headers, body, and timing information
- **Copy as cURL** - Reproduce requests with one click
- **Clear history** - Reset the request log

## Step 5: Use a Custom Subdomain

Instead of a random subdomain, you can request a specific one:

```bash
sellia http 8080 --subdomain myapp --server http://localhost:3000
```

Now your tunnel is accessible at:

```
http://myapp.your-domain.com
```

## Common Use Cases

### Webhook Development

Test webhooks from services like Stripe, GitHub, or Slack:

```bash
# Start your webhook handler
node webhook-handler.js &

# Create a tunnel
sellia http 3000 --subdomain webhooks --server http://localhost:3000

# Use the provided URL in your webhook configuration
# http://webhooks.your-domain.com/webhook
```

### Mobile App Development

Test mobile apps against a local API:

```bash
# Start your API server
rails server -p 4000 &

# Create a tunnel
sellia http 4000 --subdomain api-dev --server http://localhost:3000

# Point your mobile app to http://api-dev.your-domain.com
```

### Client Demos

Share work-in-progress with clients:

```bash
# Start your frontend dev server
npm run dev &

# Create a tunnel with a memorable subdomain
sellia http 5173 --subdomain demo-acme --server http://localhost:3000

# Share http://demo-acme.your-domain.com with your client
```

### OAuth Callback Testing

Test OAuth callbacks locally:

```bash
# Start your OAuth callback handler
node oauth-server.js &

# Create a tunnel
sellia http 5000 --subdomain oauth-test --server http://localhost:3000

# Use http://oauth-test.your-domain.com/callback in your OAuth app settings
```

## Advanced Options

### Basic Authentication

Protect your tunnel with basic auth:

```bash
sellia http 8080 --auth admin:secret123 --server http://localhost:3000
```

Users will be prompted for credentials when accessing the tunnel.

### Disable Inspector

If you don't need the request inspector:

```bash
sellia http 8080 --no-inspector --server http://localhost:3000
```

### Custom Inspector Port

Change the inspector port if 4040 is in use:

```bash
sellia http 8080 --inspector-port 5000 --server http://localhost:3000
```

### Open Inspector Automatically

Open the inspector in your browser when the tunnel starts:

```bash
sellia http 8080 --open --server http://localhost:3000
```

## Configuration File

For multiple tunnels or persistent settings, use a configuration file:

Create `sellia.yml` in your project directory:

```yaml
server: http://localhost:3000

tunnels:
  web:
    port: 8080
    subdomain: myapp
  api:
    port: 3000
    subdomain: myapp-api
```

Start all tunnels:

```bash
sellia start
```

## Stopping Tunnels

To stop a tunnel, press `Ctrl+C` in the terminal where it's running.

All tunnels will be automatically closed when you stop the Sellia client.

## Troubleshooting

### "Connection Refused" Error

Ensure your local server is running:

```bash
# Check if port is in use
lsof -i :8080

# Or with netstat
netstat -an | grep 8080
```

### Tunnel URL Not Accessible

1. Verify the server is running
2. Check your network connection
3. Ensure the server URL is correct

### Inspector Not Loading

1. Check if the inspector port is already in use
2. Try disabling the inspector with `--no-inspector`
3. Verify the tunnel is running

## What's Next?

Now that you've got the basics down, explore more features:

- [Self-Hosting](./self-hosting-quickstart.md) - Run your own tunnel server
- [Configuration Guide](../configuration/config-file.md) - Set up config files
- [Authentication](../authentication/) - Secure your tunnels
- [Docker Deployment](../deployment/docker.md) - Deploy Sellia with Docker

## Need Help?

- Check the [main README](../../../README.md)
- Open an issue on [GitHub](https://github.com/watzon/sellia/issues)
- Join the community discussions
