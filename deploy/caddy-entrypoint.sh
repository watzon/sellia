#!/bin/sh
# Select Caddyfile based on whether Cloudflare token is set

CADDYFILE_DIR="/etc/caddy"

if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    echo "Using Cloudflare DNS challenge for wildcard certs"
    cp /etc/caddy/Caddyfile.cloudflare "$CADDYFILE_DIR/Caddyfile"
else
    echo "Using on-demand TLS (no Cloudflare token set)"
    cp /etc/caddy/Caddyfile.ondemand "$CADDYFILE_DIR/Caddyfile"
fi

# Execute the original Caddy entrypoint
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
