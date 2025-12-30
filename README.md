# Sellia

[![Crystal](https://img.shields.io/badge/crystal-%3E%3D1.10.0-black?logo=crystal)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Secure tunnels to localhost. A self-hosted ngrok alternative written in Crystal.

Sellia exposes your local development servers to the internet through secure tunnels. Run your own tunnel server or use the hosted service at [sellia.me](https://sellia.me). Named after the Crystal Tunnel in Elden Ring.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
  - [Quick Start](#quick-start)
  - [CLI Reference](#cli-reference)
  - [Server](#server)
  - [Configuration](#configuration)
- [Request Inspector](#request-inspector)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Background

Exposing local servers to the internet is essential for:

- Webhook development (Stripe, GitHub, etc.)
- Mobile app development against local APIs
- Sharing work-in-progress with clients
- Testing OAuth callbacks

Existing solutions like ngrok are excellent but can be expensive for individual developers. Sellia provides a fully open-source, self-hostable alternative with a familiar interface.

**Features:**

- Subdomain-based routing (`myapp.your-domain.com`)
- Real-time request inspector with web UI
- Automatic reconnection with exponential backoff
- Basic auth protection for tunnels
- Rate limiting and subdomain validation
- MessagePack-based binary protocol over WebSocket

## Install

### From Source

Requires [Crystal](https://crystal-lang.org/install/) >= 1.10.0.

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
shards build --release
```

Binaries will be in `./bin/`:

- `sellia` - CLI client
- `sellia-server` - Tunnel server

### Pre-built Binaries

Coming soon.

## Usage

### Quick Start

**1. Start the server** (or use a hosted instance):

```bash
./bin/sellia-server --port 3000 --domain your-domain.com
```

**2. Create a tunnel** to your local server:

```bash
./bin/sellia http 8080 --server http://localhost:3000
```

**3. Access your local server** at the provided URL (e.g., `http://abc123.your-domain.com:3000`).

### CLI Reference

```
sellia <command> [options]

Commands:
  http <port>     Create HTTP tunnel to local port
  start           Start tunnels from config file
  auth            Manage authentication
  version         Show version
  help            Show help

HTTP Options:
  -s, --subdomain NAME    Request specific subdomain
  -a, --auth USER:PASS    Enable basic auth protection
  -H, --host HOST         Local host (default: localhost)
  -k, --api-key KEY       API key for authentication
  -i, --inspector-port    Inspector UI port (default: 4040)
  -o, --open              Open inspector in browser
  --no-inspector          Disable the request inspector
  --server URL            Tunnel server URL
```

**Examples:**

```bash
# Basic tunnel
sellia http 3000

# Custom subdomain
sellia http 3000 --subdomain myapp

# With basic auth
sellia http 3000 --auth admin:secret

# Using a specific server
sellia http 3000 --server https://sellia.me
```

### Server

```
sellia-server [options]

Options:
  --host HOST           Host to bind to (default: 0.0.0.0)
  --port PORT           Port to listen on (default: 3000)
  --domain DOMAIN       Base domain for subdomains
  --require-auth        Require API key authentication
  --master-key KEY      Master API key (enables auth)
  --https               Generate HTTPS URLs for tunnels
  --no-rate-limit       Disable rate limiting
```

**Environment Variables:**

| Variable               | Description                             |
| ---------------------- | --------------------------------------- |
| `SELLIA_HOST`          | Host to bind to                         |
| `SELLIA_PORT`          | Port to listen on                       |
| `SELLIA_DOMAIN`        | Base domain for subdomains              |
| `SELLIA_REQUIRE_AUTH`  | Require authentication (`true`/`false`) |
| `SELLIA_MASTER_KEY`    | Master API key                          |
| `SELLIA_USE_HTTPS`     | Generate HTTPS URLs (`true`/`false`)    |
| `SELLIA_RATE_LIMITING` | Enable rate limiting (`true`/`false`)   |
| `SELLIA_DEBUG`         | Enable debug logging (`true`/`false`)   |

### Configuration

Sellia supports layered configuration. Files are loaded in order (later overrides earlier):

1. `~/.config/sellia/sellia.yml`
2. `~/.sellia.yml`
3. `./sellia.yml`
4. CLI flags

**Example `sellia.yml`:**

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

Start all configured tunnels:

```bash
sellia start
```

## Request Inspector

Sellia includes a real-time request inspector accessible at `http://localhost:4040` when a tunnel is running.

Features:

- Live request/response streaming
- Request details (headers, body, timing)
- Copy as cURL command
- Clear history

Disable with `--no-inspector` if not needed.

## Deployment

### Docker Compose

The easiest way to deploy Sellia is with Docker Compose:

```bash
# Clone and configure
git clone https://github.com/watzon/sellia.git
cd sellia

# Create .env file
cat > .env << EOF
SELLIA_DOMAIN=yourdomain.com
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
SELLIA_USE_HTTPS=true
EOF

# Start the server
docker compose -f docker-compose.prod.yml up -d
```

### TLS Configuration

Sellia requires TLS certificates to serve HTTPS tunnels. You provide your own certificates - giving you flexibility to use Cloudflare Origin Certificates, Let's Encrypt, self-signed certs, or any other valid certificate.

**Quick Setup with Cloudflare Origin Certificate (Recommended):**

1. Add your domain to [Cloudflare](https://cloudflare.com) (free tier works)
2. Go to **SSL/TLS** → **Origin Server** → **Create Certificate**
3. Select:
   - Hostnames: `*.yourdomain.com` and `yourdomain.com`
   - Validity: 15 years
   - Key format: PEM (default)
4. Click **Create** and download the certificate and key
5. Place them in `./certs/` directory:
   ```
   certs/
   ├── cert.pem  # Origin certificate
   └── key.pem   # Private key
   ```
6. Update `.env` with your domain:
   ```bash
   SELLIA_DOMAIN=yourdomain.com
   ```

**Alternative Certificate Sources:**

- **Let's Encrypt**: Generate certificates yourself using certbot or another ACME client, then place `cert.pem` and `key.pem` in the `certs/` directory
- **Self-signed**: Generate your own certificates for local testing (note: browsers will show warnings)

**Example .env file:**

```bash
SELLIA_DOMAIN=yourdomain.com
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
SELLIA_USE_HTTPS=true
```

**Start the server:**

```bash
docker compose -f docker-compose.prod.yml up -d
```

## Development

### Prerequisites

- [Crystal](https://crystal-lang.org/install/) >= 1.10.0
- [Node.js](https://nodejs.org/) >= 18 (for inspector UI development)

### Building

```bash
# Install dependencies
shards install

# Build debug binaries
shards build

# Build release binaries
shards build --release

# Run tests
crystal spec
```

### Inspector UI Development

```bash
cd web
npm install
npm run dev
```

The CLI will proxy to Vite's dev server at `localhost:5173` when not built with embedded assets.

### Project Structure

```
src/
├── core/           # Shared protocol and types
│   └── protocol/   # MessagePack message definitions
├── server/         # Tunnel server components
│   ├── tunnel_registry.cr
│   ├── ws_gateway.cr
│   ├── http_ingress.cr
│   └── ...
└── cli/            # CLI client components
    ├── tunnel_client.cr
    ├── inspector.cr
    └── ...
web/                # React inspector UI
spec/               # Tests
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please use [conventional commits](https://www.conventionalcommits.org/) for commit messages.

## License

[MIT](LICENSE) © Chris Watson
