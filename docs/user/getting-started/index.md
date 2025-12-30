# Getting Started

Get up and running with Sellia in minutes.

## Overview

This section guides you through installing Sellia and creating your first tunnel.

## Installation

### From Source

Requires [Crystal](https://crystal-lang.org/install/) >= 1.10.0.

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
shards build --release
```

Binaries will be in `./bin/`:

- `sellia` - CLI client for creating tunnels
- `sellia-server` - Tunnel server

### Pre-built Binaries

Coming soon.

## Quick Start

### 1. Start the Server

Or use a hosted instance at [sellia.me](https://sellia.me).

```bash
./bin/sellia-server --port 3000 --domain your-domain.com
```

### 2. Create a Tunnel

Expose your local server on port 8080:

```bash
./bin/sellia http 8080 --server http://localhost:3000
```

### 3. Access Your Server

Sellia will provide a URL like `http://abc123.your-domain.com`.

## Next Steps

- [Quick Start](./quickstart.md) - Common tunnel creation patterns
- [Configuration](../configuration/) - Set up config files
- [Authentication](../authentication/) - Secure your tunnels
- [Inspector](../inspector/) - Debug requests in real-time

## Example Workflows

### Webhook Development

```bash
# Start your webhook receiver
./bin/sellia http 3000 --subdomain webhooks --open --server http://localhost:3000
```

### Mobile Development

```bash
# Expose your API with authentication
./bin/sellia http 8080 --auth api:secret --subdomain myapp-api --server http://localhost:3000
```

### Multiple Services

```bash
# Terminal 1: Web app
./bin/sellia http 3000 --subdomain myapp --server http://localhost:3000

# Terminal 2: API
./bin/sellia http 8080 --subdomain myapp-api --server http://localhost:3000
```

## Help

- [CLI Reference](../cli-reference/) - Complete command documentation
- [Troubleshooting](../troubleshooting/) - Common issues and solutions
- [GitHub Issues](https://github.com/watzon/sellia/issues) - Report bugs
