# Sellia

A fast, secure tunneling service written in Crystal that allows you to expose local services to the internet with custom subdomains.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [Server](#server)
  - [Client](#client)
  - [Docker](#docker)
- [Environment Variables](#environment-variables)
- [API](#api)
- [Contributing](#contributing)
- [License](#license)

## Install

### From Source

```bash
# Clone the repository
git clone https://github.com/your-github-user/sellia.git
cd sellia

# Install dependencies
shards install

# Build the project
shards build --release
```

### Using Docker

```bash
# Build the Docker image
docker build -t sellia .

# Or pull from registry (if published)
docker pull sellia/sellia:latest
```

## Usage

### Server

Start the tunnel server:

```bash
# Basic usage
./bin/sellia serve

# With custom host and port
./bin/sellia serve --host 0.0.0.0 --port 3000

# With domain and SSL (Let's Encrypt)
./bin/sellia serve --domain yourdomain.com --acme --acme-email admin@yourdomain.com
```

### Client

Create a tunnel to your local service:

```bash
# Basic tunnel to localhost:3000
./bin/sellia tunnel --port 3000

# With custom subdomain
./bin/sellia tunnel --port 3000 --subdomain myapp

# Connect to custom server
./bin/sellia tunnel --host https://your-server.com --port 3000
```

### Docker

#### Using Docker Compose

```bash
# Copy environment file and customize
cp .env.example .env

# Start the server
docker-compose up sellia-server

# Stop all services
docker-compose down
```

#### Using Docker directly

```bash
# Start server
docker run -d \
  --name sellia-server \
  -p 3000:3000 \
  -e SELLIA_HOST=0.0.0.0 \
  -e SELLIA_PORT=3000 \
  sellia serve

# Start client (separate container)
docker run -d \
  --name sellia-client \
  -e SELLIA_SERVER_HOST=http://your-server.com \
  -e SELLIA_LOCAL_PORT=3000 \
  sellia tunnel
```

## Environment Variables

### Server Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SELLIA_HOST` | `0.0.0.0` | Host to bind to |
| `SELLIA_PORT` | `3000` | Port to listen on |
| `SELLIA_DOMAIN` | - | Base domain for subdomains |
| `SELLIA_ACME_ENABLED` | `false` | Enable Let's Encrypt SSL |
| `SELLIA_ACME_EMAIL` | `admin@example.com` | Email for ACME registration |
| `SELLIA_ACME_TEST` | `true` | Use Let's Encrypt staging |

### Client Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SELLIA_SERVER_HOST` | `https://sellia.me` | Upstream server host |
| `SELLIA_SERVER_PORT` | `443` | Upstream server port |
| `SELLIA_LOCAL_PORT` | `3000` | Local port to forward |
| `SELLIA_SUBDOMAIN` | - | Request this subdomain |
| `SELLIA_LOCAL_HOST` | `localhost` | Local host to forward to |

## API

### Server Endpoints

- `GET /` - Landing page (redirects to documentation)
- `GET /<subdomain>` - Register new tunnel with subdomain
- `GET /?new` - Register new tunnel with random subdomain
- `GET /api/tunnels/<id>/status` - Get tunnel status

### Response Format

```json
{
  "id": "myapp",
  "port": 40001,
  "max_conn_count": 10,
  "url": "https://myapp.yourdomain.com"
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate and follow the existing code style.

### Development

```bash
# Install development dependencies
shards install

# Run tests
crystal spec

# Run with development options
./bin/sellia serve --port 3000
```

## License

MIT © [Chris Watson](https://github.com/your-github-user) - see the [LICENSE](LICENSE) file for details.
