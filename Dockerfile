# Sellia - Multi-stage Docker build for minimal production images
# Produces a ~15-20MB image with statically linked binaries

# =============================================================================
# Stage 1: Build web UI
# =============================================================================
FROM node:20-alpine AS web-builder

WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci --production=false
COPY web/ ./
RUN npm run build

# =============================================================================
# Stage 2: Build Crystal binaries
# =============================================================================
FROM 84codes/crystal:1.18.2-alpine AS crystal-builder

# Install build dependencies
RUN apk add --no-cache --update \
    yaml-static \
    openssl-libs-static \
    openssl-dev \
    zlib-static \
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

# Copy built web assets for baking
COPY --from=web-builder /app/web/dist web/dist

# Create output directory and build static binaries
RUN mkdir -p bin && crystal build src/cli/main.cr -o bin/sellia \
    --release --static --no-debug \
    -Drelease

RUN crystal build src/server/main.cr -o bin/sellia-server \
    --release --static --no-debug

# Verify binaries exist and show sizes
RUN ls -lh bin/

# =============================================================================
# Stage 3: Minimal runtime image
# =============================================================================
FROM alpine:3.20 AS runtime

# Add CA certificates for HTTPS and create non-root user
RUN apk add --no-cache ca-certificates tzdata \
    && addgroup -g 1000 sellia \
    && adduser -u 1000 -G sellia -s /bin/sh -D sellia

WORKDIR /app

# Copy binaries from builder
COPY --from=crystal-builder /app/bin/sellia /usr/local/bin/sellia
COPY --from=crystal-builder /app/bin/sellia-server /usr/local/bin/sellia-server

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
