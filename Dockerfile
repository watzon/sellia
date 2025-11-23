# Multi-stage Dockerfile for Sellia

# Build stage
FROM crystallang/crystal:1.18-alpine AS builder

WORKDIR /app

# Copy shard files and install dependencies
COPY shard.yml shard.lock ./
RUN shards install

# Copy source code
COPY . .

# Build the application
RUN shards build --release --production --static

# Runtime stage
FROM alpine:3.19

# Install only CA certificates for HTTPS connections
RUN apk add --no-cache ca-certificates

# Create non-root user
RUN addgroup -g 1000 -S sellia && \
    adduser -u 1000 -S sellia -G sellia

WORKDIR /app

# Copy the static binary from builder stage
COPY --from=builder /app/bin/sellia /usr/local/bin/sellia

# Create directories for certificates and data
RUN mkdir -p /app/certs /app/data && \
    chown -R sellia:sellia /app

# Switch to non-root user
USER sellia

# Expose default ports
EXPOSE 3000 80 443

# Set default command
CMD ["sellia", "serve"]