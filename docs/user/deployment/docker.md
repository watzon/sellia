# Docker Deployment

Deploy Sellia using Docker or Docker Compose for production. Containerization provides isolation, easy deployment, and consistent environments across development, staging, and production.

## Prerequisites

- Docker >= 20.10
- Docker Compose >= 2.0
- Domain name with DNS configured
- TLS certificates (see [TLS Certificates guide](./tls-certificates.md))

## Quick Start

### Using Docker Compose (Recommended)

The fastest way to deploy Sellia:

```bash
# Clone repository
git clone https://github.com/watzon/sellia.git
cd sellia

# Create environment file
cat > .env << EOF
SELLIA_DOMAIN=yourdomain.com
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
EOF

# Create certs directory and add your certificates
mkdir -p certs
# Place cert.pem and key.pem in the certs directory

# Start the server
docker compose -f docker-compose.prod.yml up -d
```

### Verify Deployment

```bash
# Check logs
docker compose -f docker-compose.prod.yml logs -f

# Check status
docker compose -f docker-compose.prod.yml ps
```

## Docker Compose Configuration

### Production Docker Compose

The `docker-compose.prod.yml` file:

```yaml
version: '3.8'

services:
  sellia-server:
    image: ghcr.io/watzon/sellia:latest
    container_name: sellia-server
    restart: unless-stopped
    env_file: .env
    networks:
      - sellia-internal
    environment:
      - SELLIA_USE_HTTPS=true
      - SELLIA_REQUIRE_AUTH=true

  caddy:
    image: caddy:2-alpine
    container_name: sellia-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deploy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/certs:ro
      - caddy_data:/data
      - caddy_config:/config
    environment:
      - SELLIA_DOMAIN=${SELLIA_DOMAIN:-localhost}
    networks:
      - sellia-internal
    depends_on:
      - sellia-server

networks:
  sellia-internal:
    driver: bridge

volumes:
  caddy_data:
  caddy_config:
```

### Environment File

Create `.env` file:

```bash
# .env
SELLIA_DOMAIN=yourdomain.com
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
```

## Building the Docker Image

### Build from Source

```bash
# Clone repository
git clone https://github.com/watzon/sellia.git
cd sellia

# Build image
docker build -t sellia:latest .

# Or with build arguments
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  -t sellia:latest .
```

### Dockerfile

The official Dockerfile:

```dockerfile
# Sellia Server - Multi-stage Docker build for minimal production image

# =============================================================================
# Stage 1: Build Crystal server binary
# =============================================================================
FROM 84codes/crystal:1.18.2-alpine AS builder

# Install build dependencies
RUN apk add --no-cache --update \
    yaml-static \
    openssl-libs-static \
    openssl-dev \
    zlib-static \
    sqlite-dev \
    sqlite-static \
    pcre-dev \
    gc-dev \
    libevent-static \
    libxml2-dev

WORKDIR /app

# Copy shard files first for layer caching
COPY shard.yml shard.lock ./
RUN shards install --production

# Copy source code
COPY src/ src/

# Build server binary (static for Alpine)
RUN mkdir -p bin && crystal build src/server/main.cr -o bin/sellia-server \
    --release --static --no-debug

# =============================================================================
# Stage 2: Minimal runtime image
# =============================================================================
FROM alpine:3.20 AS runtime

# Add CA certificates for HTTPS and create non-root user
RUN apk add --no-cache ca-certificates tzdata \
    && addgroup -g 1000 sellia \
    && adduser -u 1000 -G sellia -s /bin/sh -D sellia

WORKDIR /app

# Copy server binary from builder
COPY --from=builder /app/bin/sellia-server /usr/local/bin/sellia-server

# Set ownership
RUN chown -R sellia:sellia /app

USER sellia

# Default environment variables
ENV SELLIA_HOST=0.0.0.0 \
    SELLIA_PORT=3000 \
    SELLIA_DOMAIN=localhost

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${SELLIA_PORT}/health || exit 1

ENTRYPOINT ["sellia-server"]
CMD ["--host", "0.0.0.0"]
```

## Docker Run Commands

### Basic Server

```bash
docker run -d \
  --name sellia-server \
  -p 3000:3000 \
  -e SELLIA_DOMAIN=yourdomain.com \
  -e SELLIA_MASTER_KEY=$(openssl rand -hex 32) \
  -e SELLIA_REQUIRE_AUTH=true \
  ghcr.io/watzon/sellia:latest
```

### With Environment File

```bash
docker run -d \
  --name sellia-server \
  --env-file .env \
  -p 3000:3000 \
  ghcr.io/watzon/sellia:latest
```

### Interactive Testing

```bash
docker run -it \
  --rm \
  -p 3000:3000 \
  -e SELLIA_DOMAIN=yourdomain.com \
  ghcr.io/watzon/sellia:latest
```

## Docker Compose Workflows

### Start Server

```bash
docker compose -f docker-compose.prod.yml up -d
```

### Stop Server

```bash
docker compose -f docker-compose.prod.yml down
```

### View Logs

```bash
# Follow logs
docker compose -f docker-compose.prod.yml logs -f

# Last 100 lines
docker compose -f docker-compose.prod.yml logs --tail 100
```

### Restart Server

```bash
docker compose -f docker-compose.prod.yml restart
```

### Update Deployment

```bash
# Pull latest changes
git pull

# Rebuild image
docker compose -f docker-compose.prod.yml build

# Restart with new image
docker compose -f docker-compose.prod.yml up -d
```

## Multi-Stage Deployment

### Development, Staging, Production

Create multiple compose files:

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  sellia-server:
    image: sellia:latest
    ports:
      - "3000:3000"
    environment:
      - SELLIA_DOMAIN=localhost
      - SELLIA_USE_HTTPS=false
      - LOG_LEVEL=debug
```

```yaml
# docker-compose.staging.yml
version: '3.8'

services:
  sellia-server:
    image: sellia:latest
    environment:
      - SELLIA_DOMAIN=staging.yourdomain.com
      - SELLIA_USE_HTTPS=true
      - LOG_LEVEL=debug
```

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  sellia-server:
    image: sellia:latest
    environment:
      - SELLIA_DOMAIN=yourdomain.com
      - SELLIA_USE_HTTPS=true
      - LOG_LEVEL=warn
```

Deploy to each environment:

```bash
# Development
docker compose -f docker-compose.dev.yml up -d

# Staging
docker compose -f docker-compose.staging.yml up -d

# Production
docker compose -f docker-compose.prod.yml up -d
```

## Reverse Proxy Setup

### With Nginx

```yaml
version: '3.8'

services:
  sellia-server:
    image: ghcr.io/watzon/sellia:latest
    expose:
      - "3000"
    environment:
      - SELLIA_DOMAIN=yourdomain.com
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deploy/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - sellia-server
    restart: unless-stopped
```

Nginx configuration (`nginx.conf`):

```nginx
events {
    worker_connections 1024;
}

http {
    upstream sellia {
        server sellia-server:3000;
    }

    server {
        listen 80;
        server_name yourdomain.com *.yourdomain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name yourdomain.com *.yourdomain.com;

        ssl_certificate /etc/nginx/certs/cert.pem;
        ssl_certificate_key /etc/nginx/certs/key.pem;

        location / {
            proxy_pass http://sellia;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

### With Traefik

```yaml
version: '3.8'

services:
  sellia-server:
    image: sellia:latest
    expose:
      - "3000"
    environment:
      - SELLIA_DOMAIN=yourdomain.com
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sellia.rule=HostRegexp(`{subdomain:.+}.yourdomain.com`)"
      - "traefik.http.routers.sellia.entrypoints=websecure"
      - "traefik.http.routers.sellia.tls.certresolver=letsencrypt"
    networks:
      - traefik-network

  traefik:
    image: traefik:v2.10
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml
      - ./acme.json:/acme.json
    networks:
      - traefik-network

networks:
  traefik-network:
    external: true
```

## Health Checks

### Docker Healthcheck

```yaml
services:
  sellia-server:
    image: ghcr.io/watzon/sellia:latest
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 5s
```

### Manual Health Check

```bash
# Check if container is healthy
docker inspect --format='{{.State.Health.Status}}' sellia-server

# Check health endpoint
curl http://localhost:3000/health
```

## Volume Management

### TLS Certificates

In production with Caddy/Nginx reverse proxy, certificates are mounted to the reverse proxy container, not Sellia:

```yaml
# For Caddy (docker-compose.prod.yml)
volumes:
  - ./certs:/certs:ro

# For Nginx
volumes:
  - ./certs:/etc/nginx/certs:ro
```

### Persistent Data

Sellia uses SQLite for tunnel registry and reserved subdomains. Persist the database:

```yaml
volumes:
  - sellia-data:/var/lib/sellia

volumes:
  sellia-data:
    driver: local
```

## Resource Limits

### CPU and Memory Limits

```yaml
services:
  sellia-server:
    image: ghcr.io/watzon/sellia:latest
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

## Logging

### View Logs

```bash
# All logs
docker compose logs -f

# Specific service
docker compose logs -f sellia-server

# Last 100 lines
docker compose logs --tail 100 sellia-server
```

### Log Rotation

Configure Docker daemon for log rotation (`/etc/docker/daemon.json`):

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

## Security Best Practices

### 1. Read-Only Certificates

Mount certificates as read-only:

```yaml
volumes:
  - ./certs:/app/certs:ro
```

### 2. Non-Root User

Run as non-root user (if supported by image):

```yaml
services:
  sellia-server:
    user: "1000:1000"
```

### 3. Drop Capabilities

```yaml
services:
  sellia-server:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

### 4. Network Isolation

Use dedicated network:

```yaml
services:
  sellia-server:
    networks:
      - sellia-net

networks:
  sellia-net:
    driver: bridge
    internal: false
```

### 5. Secrets Management

Use Docker secrets (Swarm mode):

```yaml
version: '3.8'

secrets:
  master_key:
    external: true

services:
  sellia-server:
    image: sellia:latest
    secrets:
      - master_key
    environment:
      - SELLIA_MASTER_KEY_FILE=/run/secrets/master_key
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy Sellia

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/sellia
            git pull
            docker compose -f docker-compose.prod.yml up -d --build
```

### GitLab CI

```yaml
deploy:
  stage: deploy
  script:
    - ssh user@server "cd /opt/sellia && docker compose -f docker-compose.prod.yml up -d --build"
  only:
    - main
```

## Monitoring

### Metrics Endpoint

Sellia may expose metrics (future feature):

```yaml
services:
  sellia-server:
    ports:
      - "9090:9090"  # Metrics port
```

### Prometheus Integration

```yaml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9091:9090"
```

Prometheus config:

```yaml
scrape_configs:
  - job_name: 'sellia'
    static_configs:
      - targets: ['sellia-server:9090']
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs sellia-server

# Check container status
docker compose ps

# Inspect container
docker inspect sellia-server
```

### Permission Issues

```bash
# Check file permissions
ls -la certs/

# Fix permissions
chmod 644 certs/cert.pem
chmod 600 certs/key.pem
```

### Port Already in Use

```bash
# Check what's using the port
lsof -i :80
lsof -i :443

# Stop conflicting service
sudo systemctl stop nginx
```

### DNS Issues

```bash
# Verify DNS configuration
dig yourdomain.com
dig *.yourdomain.com

# Check Cloudflare/SaaS DNS settings
```

## Backup and Restore

### Backup

```bash
# Backup certificates and configuration
tar -czf sellia-backup-$(date +%Y%m%d).tar.gz \
  .env \
  docker-compose.prod.yml \
  certs/
```

### Restore

```bash
# Extract backup
tar -xzf sellia-backup-20241230.tar.gz

# Restart server
docker compose -f docker-compose.prod.yml up -d
```

## Next Steps

- [TLS Certificates](./tls-certificates.md) - Certificate setup
- [Configuration](../configuration/config-file.md) - Configuration files
- [Self-Hosting](../getting-started/self-hosting-quickstart.md) - Server setup

## Quick Reference

| Task | Command |
|------|---------|
| Start server | `docker compose up -d` |
| Stop server | `docker compose down` |
| View logs | `docker compose logs -f` |
| Rebuild | `docker compose build` |
| Update | `git pull && docker compose up -d --build` |
| Status | `docker compose ps` |
| Health check | `curl http://localhost/health` |
