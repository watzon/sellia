# Docker Image Publishing

Process for building and publishing Docker images for Sellia.

## Overview

Sellia provides Docker images for containerized deployment. Images are published to Docker Hub and GitHub Container Registry (GHCR).

---

## Docker Images

### Image Locations

| Registry | Image | Tags |
|----------|-------|------|
| GHCR (Primary) | `ghcr.io/watzon/sellia` | `latest`, `v0.4.0`, `0`, `0.4` |

---

## Dockerfile

### Client Image (Tunnel Client)

**Location:** `Dockerfile`

```dockerfile
# Multi-stage build for smaller image
FROM 84codes/crystal:1.18.2-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
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

# Copy shard files first for layer caching
COPY shard.yml shard.lock ./
RUN shards install --production

# Copy source code
COPY src/ src/

# Build server binary (static for Alpine)
RUN mkdir -p bin && crystal build src/server/main.cr -o bin/sellia-server \
    --release --static --no-debug

# Final stage
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

---

## Building Images

### Local Build

```bash
# Build image
docker build -t ghcr.io/watzon/sellia:latest .

# Build with specific version
docker build -t ghcr.io/watzon/sellia:v0.4.0 .
```

---

### Build Arguments

```dockerfile
# Pass version at build time
ARG VERSION=dev
RUN echo "const VERSION = \"${VERSION}\"" > src/version.cr
```

```bash
docker build --build-arg VERSION=1.2.3 -t sellia/tunnel:v1.2.3 .
```

---

## Multi-Architecture Builds

### Buildx for Multi-Platform

```bash
# Enable buildx
docker buildx create --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t sellia/tunnel:latest \
  --push \
  .
```

**Platforms:**
- `linux/amd64` - Intel/AMD 64-bit
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)

---

### GitHub Actions Workflow

**Location:** `.github/workflows/docker.yml`

```yaml
name: Docker

on:
  push:
    tags:
      - 'v*'
  push:
    branches:
      - main

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: sellia/tunnel
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Image Tags

### Tagging Strategy

| Tag | Purpose | Example |
|-----|---------|---------|
| `latest` | Most recent release | `ghcr.io/watzon/sellia:latest` |
| `v0.4.0` | Specific version | `ghcr.io/watzon/sellia:v0.4.0` |
| `0` | Major version | `ghcr.io/watzon/sellia:0` |
| `0.4` | Minor version | `ghcr.io/watzon/sellia:0.4` |

---

### Tag Commands

```bash
# Tag image for multiple versions
docker tag ghcr.io/watzon/sellia:v0.4.0 ghcr.io/watzon/sellia:latest
docker tag ghcr.io/watzon/sellia:v0.4.0 ghcr.io/watzon/sellia:0
docker tag ghcr.io/watzon/sellia:v0.4.0 ghcr.io/watzon/sellia:0.4

# Push all tags
docker push ghcr.io/watzon/sellia:latest
docker push ghcr.io/watzon/sellia:0
docker push ghcr.io/watzon/sellia:0.4
docker push ghcr.io/watzon/sellia:v0.4.0
```

---

## Publishing

### Manual Publishing

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin

# Build and push
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/watzon/sellia:v0.4.0 \
  -t ghcr.io/watzon/sellia:latest \
  --push \
  .
```

---

### GitHub Container Registry

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin

# Build and push
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/watzon/sellia:v1.2.3 \
  -t ghcr.io/watzon/sellia:latest \
  --push \
  .
```

---

## Using Docker Images

### Basic Usage

```bash
# Tunnel localhost:3000 (requires CLI binary, not server image)
# Note: The Docker image currently only contains sellia-server
# Use local binary for tunnel client

# Example with server:
docker run --rm \
  --name sellia-server \
  -p 3000:3000 \
  ghcr.io/watzon/sellia:latest
```

---

### With Configuration File

```bash
# Mount config file
docker run --rm \
  --name sellia-server \
  -v $(pwd)/sellia.yml:/app/sellia.yml \
  -p 3000:3000 \
  ghcr.io/watzon/sellia:latest
```

---

### With Inspector Access

```bash
# Expose server port with custom configuration
docker run --rm \
  --name sellia-server \
  -p 3000:3000 \
  -e SELLIA_DOMAIN=yourdomain.com \
  -e SELLIA_REQUIRE_AUTH=true \
  -e SELLIA_MASTER_KEY=your-key \
  ghcr.io/watzon/sellia:latest
```

---

### Docker Compose

**docker-compose.yml**

```yaml
version: '3.8'

services:
  sellia-server:
    image: ghcr.io/watzon/sellia:latest
    ports:
      - "3000:3000"
    environment:
      - SELLIA_HOST=0.0.0.0
      - SELLIA_DOMAIN=localhost
      - SELLIA_REQUIRE_AUTH=true
      - SELLIA_MASTER_KEY=${SELLIA_MASTER_KEY}
    restart: unless-stopped
```

**Run:**

```bash
docker-compose up
```

---

## Image Size Optimization

### Current Sizes

| Image Type | Size |
|------------|------|
| Alpine-based | ~15 MB |
| Debian-based | ~25 MB |
| Ubuntu-based | ~40 MB |

---

### Optimization Techniques

#### 1. Multi-Stage Build

```dockerfile
# Builder stage with all tools
FROM crystallang/crystal:latest AS builder
# ... build steps ...

# Final stage with minimal runtime
FROM alpine:3.19
COPY --from=builder /app/bin/sellia /app/sellia
```

#### 2. Strip Binary

```dockerfile
RUN strip /app/bin/sellia
```

#### 3. Use Distroless

```dockerfile
FROM gcr.io/distroless/cc-debian12
COPY --from=builder /app/bin/sellia /app/sellia
```

**Benefits:**
- Minimal attack surface
- Smaller image size
- No shell/package manager

---

## Security Scanning

### Trivy Scan

```bash
# Install Trivy
brew install trivy

# Scan image
trivy image sellia/tunnel:latest
```

---

### Docker Scout

```bash
# Scan image
docker scout cves sellia/tunnel:latest

# Quick check
docker scout quickview sellia/tunnel:latest
```

---

### CI Integration

```yaml
- name: Run Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: sellia/tunnel:latest
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy Results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

---

## Testing Images

### Smoke Test

```bash
# Pull image
docker pull ghcr.io/watzon/sellia:latest

# Run container
docker run --rm ghcr.io/watzon/sellia:latest --version

# Expected: Sellia Server output
```

---

### Integration Test

```bash
# Start test web server
docker run -d --name web -p 3000:80 nginx:alpine

# Start tunnel
docker run --rm --name tunnel \
  --link web:web \
  -e SELLIA_API_KEY=key \
  sellia/tunnel:latest \
  http 3000 --host web
```

---

## Update Strategy

### Auto-Update Watchtower

```bash
# Run Watchtower to auto-update containers
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  sellia-tunnel
```

**Behavior:** Watchtower checks for new images and restarts containers automatically.

---

## Troubleshooting

### "Permission Denied" Error

**Cause:** Running as non-root user without permissions.

**Solution:**
```bash
# Run with specific UID/GID
docker run --rm \
  -u $(id -u):$(id -g) \
  sellia/tunnel:latest \
  http 3000
```

---

### Inspector Not Accessible

**Cause:** Inspector port not exposed.

**Solution:**
```bash
# Expose inspector port
docker run --rm -p 4040:4040 sellia/tunnel:latest http 3000
```

---

### "Cannot Connect to Local Service"

**Cause:** Container networking issue.

**Solution:**
```bash
# Use network mode: host
docker run --rm --network host sellia/tunnel:latest http 3000

# Or use service name
docker run --rm --link web:web \
  sellia/tunnel:latest http 3000 --host web
```

---

## See Also

- [Building Binaries](./building-binaries.md) - Binary builds
- [Versioning Policy](./versioning.md) - Semantic versioning
- [GHCR](https://github.com/watzon/sellia/pkgs/container/sellia) - Published images
- [Dockerfile](../../../Dockerfile) - Source Dockerfile
