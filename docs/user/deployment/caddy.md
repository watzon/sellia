# Caddy Reverse Proxy

Caddy is a modern, HTTPS-by-default reverse proxy that works well with Sellia. This guide covers configuring Caddy for production deployments.

## Overview

Caddy handles:

- **TLS termination** - Automatic HTTPS with Let's Encrypt
- **HTTP/2 to HTTP/1.1** - Downgrade for WebSocket compatibility
- **Reverse proxy** - Forward requests to Sellia server
- **Wildcard subdomains** - Handle all tunnel subdomains
- **Static file serving** - Health checks and status endpoints

## Quick Start

### Using Docker Compose (Recommended)

The easiest way to deploy Sellia with Caddy:

```yaml
# docker-compose.yml
version: '3.8'

services:
  sellia-server:
    image: ghcr.io/watzon/sellia:latest
    environment:
      - SELLIA_USE_HTTPS=true
      - SELLIA_REQUIRE_AUTH=true
      - SELLIA_MASTER_KEY=${SELLIA_MASTER_KEY}
    env_file: .env
    networks:
      - sellia-internal
    restart: unless-stopped

  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./deploy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/certs:ro
      - caddy-data:/data
      - caddy-config:/config
    environment:
      - SELLIA_DOMAIN=${SELLIA_DOMAIN}
    networks:
      - sellia-internal
    depends_on:
      - sellia-server
    restart: unless-stopped

volumes:
  caddy-data:
  caddy_config:

networks:
  sellia-internal:
    driver: bridge
```

**Run:**

```bash
# Create .env file
cat > .env <<EOF
SELLIA_DOMAIN=yourdomain.com
SELLIA_MASTER_KEY=your-master-key
EOF

# Create certs directory and add certificates
mkdir -p certs
# Place cert.pem and key.pem in certs/

# Start
docker compose up -d
```

## Caddyfile Configuration

### With Custom Certificates

Use this when you have your own TLS certificates (e.g., Cloudflare Origin Certificate):

```caddyfile
# /path/to/Caddyfile
{
	# Disable HTTP/3 - it can cause request cancellation issues with tunneled traffic
	servers {
		protocols h1 h2
	}
}

# HTTP to HTTPS redirect
:80 {
	respond /health 200

	# Redir all other HTTP requests to HTTPS
	@host {
		host {args.0}
		not {args.0} :8080
	}
	redir @host https://{host}{uri}
}

# Wildcard for all tunnel subdomains
*.{$SELLIA_DOMAIN} {
	reverse_proxy sellia-server:3000 {
		# Force HTTP/1.1 for backend connection (required for WebSocket)
		transport http {
			versions h1c1
		}
		header_up Host {host}
		header_up X-Real-IP {remote_host}
		header_up X-Forwarded-For {remote_host}
		header_up X-Forwarded-Proto {scheme}
		flush_interval -1
	}

	tls /certs/cert.pem /certs/key.pem

	log {
		output file /var/log/caddy/tunnels.log
		format json
	}
}

# Base domain for WebSocket connections and health checks
{$SELLIA_DOMAIN} {
	reverse_proxy sellia-server:3000 {
		# Force HTTP/1.1 for backend connection (required for WebSocket)
		transport http {
			versions h1c1
		}
		header_up Host {host}
		header_up X-Real-IP {remote_host}
		header_up X-Forwarded-For {remote_host}
		header_up X-Forwarded-Proto {scheme}
		flush_interval -1
	}

	tls /certs/cert.pem /certs/key.pem

	log {
		output file /var/log/caddy/sellia.log
		format json
	}
}
```

### With Let's Encrypt (Automatic HTTPS)

For automatic TLS certificate management:

```caddyfile
{
    # Disable HTTP/3
    servers {
        protocols h1 h2
    }

    # Email for Let's Encrypt notifications
    email admin@yourdomain.com
}

# HTTP to HTTPS redirect
:80 {
    respond /health 200

    @host {
        host {args.0}
        not {args.0} :8080
    }
    redir @host https://{host}{uri}
}

# Base domain
yourdomain.com {
    reverse_proxy sellia-server:3000 {
        transport http {
            versions h1c1
        }
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        flush_interval -1
    }

    log {
        output file /var/log/caddy/sellia.log
        format json
    }
}

# Wildcard subdomains
*.yourdomain.com {
    reverse_proxy sellia-server:3000 {
        transport http {
            versions h1c1
        }
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        flush_interval -1
    }

    log {
        output file /var/log/caddy/tunnels.log
        format json
    }
}
```

## Certificate Setup

### Cloudflare Origin Certificate

Recommended for use with Cloudflare CDN:

1. **Generate certificate in Cloudflare:**
   - Go to SSL/TLS > Origin Server > Create Certificate
   - Select wildcard: `*.yourdomain.com`
   - Copy certificate and key

2. **Save certificate files:**

   ```bash
   mkdir -p certs
   nano certs/cert.pem   # Paste certificate
   nano certs/key.pem    # Paste private key
   ```

3. **Set permissions:**

   ```bash
   chmod 644 certs/cert.pem
   chmod 600 certs/key.pem
   ```

4. **Update Caddyfile:**

   ```caddyfile
   tls /certs/cert.pem /certs/key.pem
   ```

### Let's Encrypt Automatic Certificates

Caddy will automatically obtain and renew certificates from Let's Encrypt:

**Requirements:**
- DNS A record for `yourdomain.com` → your server IP
- DNS A record for `*.yourdomain.com` → your server IP (if supported)
- Port 80 and 443 accessible from internet

**No configuration needed** - Caddy handles everything.

## Configuration Options

### HTTP/3 Disabled

```caddyfile
servers {
    protocols h1 h2
}
```

**Why:** HTTP/3 (QUIC) can cause WebSocket connection issues with tunneled traffic.

### HTTP/1.1 Backend

```caddyfile
transport http {
    versions h1c1
}
```

**Why:** Sellia's WebSocket server uses HTTP/1.1. HTTP/2 can cause issues with WebSocket upgrades.

### Headers

```caddyfile
header_up Host {host}
header_up X-Real-IP {remote_host}
header_up X-Forwarded-For {remote_host}
header_up X-Forwarded-Proto {scheme}
```

**Why:** Pass original client information to Sellia server for logging and authentication.

### No Buffering

```caddyfile
flush_interval -1
```

**Why:** Disable buffering for real-time WebSocket traffic and large file uploads.

## Logging

### JSON Format

```caddyfile
log {
    output file /var/log/caddy/tunnels.log
    format json
}
```

**Benefits:**
- Structured logs for parsing
- Easy integration with log aggregators (ELK, Splunk, etc.)
- Includes timestamps, status codes, response times

### Log Rotation

Configure logrotate:

```bash
# /etc/logrotate.d/caddy
/var/log/caddy/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 caddy caddy
    sharedscripts
    postrotate
        systemctl reload caddy > /dev/null 2>&1 || true
    endscript
}
```

## Health Checks

### Simple Health Check

```caddyfile
:80 {
    respond /health 200
}
```

Returns 200 OK at `http://your-domain.com/health`.

### Docker Healthcheck

```yaml
# docker-compose.yml
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

## Performance Tuning

### Connection Limits

```caddyfile
{
    servers {
        protocols h1 h2
        max_conns 1000
    }
}
```

### Timeouts

```caddyfile
reverse_proxy sellia-server:3000 {
    transport http {
        read_timeout 300s
        write_timeout 300s
        dial_timeout 10s
    }
}
```

**Recommended for Sellia:**
- `read_timeout`: 300s (5 minutes) - For long-lived WebSocket connections
- `write_timeout`: 300s (5 minutes) - For large uploads
- `dial_timeout`: 10s - Backend connection timeout

## Troubleshooting

### WebSocket Connection Failures

**Symptoms:** Tunnels connect but immediately disconnect.

**Solutions:**

1. **Verify HTTP/1.1 transport:**
   ```caddyfile
   transport http {
       versions h1c1
   }
   ```

2. **Disable HTTP/3:**
   ```caddyfile
   servers {
       protocols h1 h2
   }
   ```

3. **Check for buffering:**
   ```caddyfile
   flush_interval -1
   ```

### TLS Certificate Errors

**Symptoms:** `502 Bad Gateway` or certificate warnings.

**Solutions:**

1. **Verify certificate files exist:**
   ```bash
   ls -la certs/
   ```

2. **Check certificate validity:**
   ```bash
   openssl x509 -in certs/cert.pem -text -noout
   ```

3. **Check Caddy logs:**
   ```bash
   docker-compose logs caddy
   ```

### DNS Issues

**Symptoms:** Tunnels not accessible via subdomain.

**Solutions:**

1. **Verify DNS A record:**
   ```bash
   dig yourdomain.com
   dig myapp.yourdomain.com
   ```

2. **For wildcard DNS:**
   - Add A record: `*.yourdomain.com` → your server IP
   - Or use CNAME: `*.yourdomain.com` → `yourdomain.com`

3. **Check Cloudflare proxy (orange cloud):**
   - Disable for Sellia subdomains if using WebSocket
   - Or use "DNS only" (grey cloud)

### Port Conflicts

**Symptoms:** Caddy fails to start.

**Solutions:**

1. **Check ports in use:**
   ```bash
   sudo lsof -i :80
   sudo lsof -i :443
   ```

2. **Stop conflicting services:**
   ```bash
   sudo systemctl stop nginx
   sudo systemctl stop apache
   ```

3. **Use different ports (not recommended):**
   ```caddyfile
   :8080 {
       # ...
   }
   ```

## Production Checklist

- [ ] TLS certificates configured (Let's Encrypt or custom)
- [ ] DNS records pointing to server (A records)
- [ ] Wildcard DNS for subdomains (or individual records)
- [ ] HTTP/3 disabled in Caddyfile
- [ ] HTTP/1.1 transport for backend
- [ ] Log rotation configured
- [ ] Health check endpoint accessible
- [ ] Firewall allows ports 80 and 443
- [ ] SELinux/AppArmor configured (if applicable)
- [ ] Caddy service auto-start on boot
- [ ] Backup strategy for Caddy data

## See Also

- [Nginx Configuration](./nginx.md) - Alternative to Caddy
- [Production Checklist](./production-checklist.md) - Complete production guide
- [Server Auth](../authentication/server-auth.md) - Authentication setup
- [Database Configuration](../storage/database-config.md) - Database setup
