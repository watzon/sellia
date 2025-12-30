# Sellia Documentation

Welcome to the Sellia documentation! Sellia is a self-hosted ngrok alternative written in Crystal that exposes your local development servers to the internet through secure tunnels.

## Quick Links

- [Getting Started](user/getting-started/) - Set up Sellia in minutes
- [User Guide](user/) - Complete usage documentation
- [Developer Guide](developer/) - Contribute to Sellia
- [Troubleshooting](user/troubleshooting/) - Common issues and solutions

## What is Sellia?

Sellia provides secure tunnels to localhost, perfect for:

- **Webhook Development** - Test Stripe, GitHub, and other webhooks locally
- **Mobile Development** - Test mobile apps against local APIs
- **Client Demos** - Share work-in-progress with clients
- **OAuth Testing** - Test callback URLs locally

### Key Features

- Subdomain-based routing (`myapp.your-domain.com`)
- Real-time request inspector with web UI
- Automatic reconnection with linear backoff
- Basic auth protection for tunnels
- Rate limiting and subdomain validation
- MessagePack-based binary protocol over WebSocket

### Self-Hosted or Hosted

**Self-Hosted:** Run your own tunnel server with full control over your data and infrastructure.

**Hosted:** Use the hosted service at [sellia.me](https://sellia.me) for a quick start without managing infrastructure.

## Documentation Sections

### [User Guide](user/)
Complete guide for using Sellia, from installation to advanced configuration.

- Installation and setup
- Creating and managing tunnels
- Using the request inspector
- Configuration options
- Deployment guides
- Troubleshooting

### [Developer Guide](developer/)
For contributors and extenders:

- Architecture overview
- Project structure
- Development setup
- Contributing guidelines
- Release process

## Quick Start

### 1. Install

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
shards build --release
```

### 2. Start the Server

```bash
./bin/sellia-server --port 3000 --domain your-domain.com
```

### 3. Create a Tunnel

```bash
./bin/sellia http 8080 --server http://localhost:3000
```

### 4. Access Your Server

Visit the provided URL (e.g., `http://abc123.your-domain.com:3000`).

## Community

- **GitHub:** [github.com/watzon/sellia](https://github.com/watzon/sellia)
- **Issues:** [github.com/watzon/sellia/issues](https://github.com/watzon/sellia/issues)
- **License:** MIT

## Next Steps

- New users: Start with [Getting Started](user/getting-started/)
- Deploying: See [Deployment](user/deployment/)
- Developing: Check [Development Setup](developer/development/)
