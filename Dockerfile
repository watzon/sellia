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
