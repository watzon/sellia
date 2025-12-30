# Nginx Reverse Proxy

Nginx is a high-performance reverse proxy that works well with Sellia. This guide covers configuring Nginx for production deployments.

## Overview

Nginx handles:

- **TLS termination** - HTTPS with your certificates
- **HTTP/2 to HTTP/1.1** - Downgrade for WebSocket compatibility
- **Reverse proxy** - Forward requests to Sellia server
- **Wildcard subdomains** - Handle all tunnel subdomains
- **Static file serving** - Health checks and status endpoints

## Quick Start

### Prerequisites

```bash
# Install Nginx
sudo apt update
sudo apt install nginx

# Install Certbot for Let's Encrypt
sudo apt install certbot python3-certbot-nginx

# Ensure Nginx is running
sudo systemctl enable nginx
sudo systemctl start nginx
```

## Configuration

### Full Configuration File

This configuration is available at `/deploy/nginx.conf` in the Sellia repository. Replace `YOUR_DOMAIN` with your actual domain:

```nginx
# Upstream for Sellia server
upstream sellia_backend {
    server 127.0.0.1:3000;
    keepalive 64;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com *.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS server - handles both main domain and subdomains
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name yourdomain.com *.yourdomain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Modern TLS configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS (uncomment after testing)
    # add_header Strict-Transport-Security "max-age=63072000" always;

    # Proxy settings
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # WebSocket support
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Timeouts for long-lived connections
    proxy_connect_timeout 60s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    # Buffering settings
    proxy_buffering off;
    proxy_request_buffering off;

    # Main location
    location / {
        proxy_pass http://sellia_backend;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://sellia_backend;
        access_log off;
    }

    # WebSocket endpoint for tunnels
    location /ws {
        proxy_pass http://sellia_backend;

        # Extended timeout for WebSocket connections
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}

# Optional: Status endpoint for monitoring
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```

### Deploying Configuration

1. **Copy and modify configuration:**

   ```bash
   sudo cp deploy/nginx.conf /etc/nginx/sites-available/sellia
   sudo nano /etc/nginx/sites-available/sellia

   # Replace 'YOUR_DOMAIN' with your actual domain (e.g., sellia.me)
   ```

2. **Enable site:**

   ```bash
   sudo ln -s /etc/nginx/sites-available/sellia /etc/nginx/sites-enabled/
   ```

3. **Test configuration:**

   ```bash
   sudo nginx -t
   ```

4. **Reload Nginx:**

   ```bash
   sudo systemctl reload nginx
   ```

## Certificate Setup

### Let's Encrypt Certificates

#### Obtain Wildcard Certificate

```bash
# Obtain wildcard certificate (requires DNS challenge)
sudo certbot certonly --manual --preferred-challenges dns -d yourdomain.com -d *.yourdomain.com

# Follow instructions to add DNS TXT record
# Wait for DNS propagation, then press Enter
```

**Alternative: HTTP validation (no wildcard)**

```bash
sudo certbot --nginx -d yourdomain.com
```

**Note:** HTTP validation only works for the base domain, not wildcard subdomains.

#### Auto-Renewal

Certbot sets up auto-renewal automatically. Verify:

```bash
sudo certbot renew --dry-run
```

Cron job is created at `/etc/cron.d/certbot`.

### Custom Certificates

For Cloudflare Origin Certificate or other custom certificates:

1. **Place certificate files:**

   ```bash
   sudo cp cert.pem /etc/ssl/certs/sellia.crt
   sudo cp key.pem /etc/ssl/private/sellia.key
   sudo chmod 644 /etc/ssl/certs/sellia.crt
   sudo chmod 600 /etc/ssl/private/sellia.key
   ```

2. **Update Nginx config:**

   ```nginx
   ssl_certificate /etc/ssl/certs/sellia.crt;
   ssl_certificate_key /etc/ssl/private/sellia.key;
   ```

3. **Reload Nginx:**

   ```bash
   sudo systemctl reload nginx
   ```

## Configuration Options Explained

### Upstream Configuration

```nginx
upstream sellia_backend {
    server 127.0.0.1:3000;
    keepalive 64;
}
```

**Why:**
- `keepalive 64` - Keep 64 connections open to backend for better performance
- Reduces TCP handshake overhead

### HTTP/2

```nginx
listen 443 ssl http2;
```

**Why:**
- HTTP/2 is faster for clients
- Nginx handles HTTP/2 to backend
- Backend still uses HTTP/1.1 for WebSocket compatibility

### WebSocket Support

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

**Why:**
- Required for WebSocket protocol upgrade
- Without this, tunnel connections fail

### Timeouts

```nginx
proxy_connect_timeout 60s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;
```

**For `/ws` endpoint:**

```nginx
proxy_read_timeout 86400s;
proxy_send_timeout 86400s;
```

**Why:**
- Tunnel WebSocket connections are long-lived
- 86400s = 24 hours (practically unlimited)
- Prevents premature disconnection

### No Buffering

```nginx
proxy_buffering off;
proxy_request_buffering off;
```

**Why:**
- Real-time data flow for WebSocket
- Large file uploads don't consume memory
- Lower latency

### HTTP/1.1 to Backend

```nginx
proxy_http_version 1.1;
```

**Why:**
- Required for WebSocket support
- Backend server speaks HTTP/1.1

## Performance Tuning

### Worker Processes

```nginx
# /etc/nginx/nginx.conf
worker_processes auto;

events {
    worker_connections 1024;
}
```

**Recommendations:**
- `worker_processes auto` - One worker per CPU core
- `worker_connections 1024` - Adjust based on load

### Connection Limits

```nginx
# /etc/nginx/nginx.conf
limit_conn_zone $binary_remote_addr zone=addr:10m;

server {
    limit_conn addr 10;
}
```

**Why:** Prevent abuse from single IP addresses.

### Rate Limiting

```nginx
# /etc/nginx/nginx.conf
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

server {
    location /api/ {
        limit_req zone=api burst=20;
    }
}
```

**Why:** Protect API endpoints from abuse.

### Gzip Compression

```nginx
# /etc/nginx/nginx.conf
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
```

**Why:** Reduce bandwidth usage for text-based responses.

## Logging

### Access Logs

```nginx
access_log /var/log/nginx/sellia-access.log;
```

**JSON format for log aggregation:**

```nginx
log_format json_combined escape=json '{'
    '"time_local":"$time_local",'
    '"remote_addr":"$remote_addr",'
    '"remote_user":"$remote_user",'
    '"request":"$request",'
    '"status": "$status",'
    '"body_bytes_sent":"$body_bytes_sent",'
    '"request_time":"$request_time",'
    '"http_referrer":"$http_referer",'
    '"http_user_agent":"$http_user_agent"'
'}';

access_log /var/log/nginx/sellia-access.log json_combined;
```

### Error Logs

```nginx
error_log /var/log/nginx/sellia-error.log warn;
```

### Log Rotation

```bash
# /etc/logrotate.d/nginx
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerotate; \
        fi
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1 || true
    endscript
}
```

## Monitoring

### Nginx Status Module

```nginx
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```

**Check status:**

```bash
curl http://127.0.0.1:8080/nginx_status
```

**Output:**

```
Active connections: 10
server accepts handled requests
 1000 1000 5000
Reading: 0 Writing: 2 Waiting: 8
```

## Security Hardening

### HSTS

```nginx
add_header Strict-Transport-Security "max-age=63072000" always;
```

**Enable only after:**
- TLS is working correctly
- No mixed content issues
- Tested thoroughly

### Disable Server Tokens

```nginx
# /etc/nginx/nginx.conf
server_tokens off;
```

**Why:** Hide Nginx version from HTTP headers.

### Limit Request Size

```nginx
client_max_body_size 100M;
```

**Adjust based on your needs.**

### IP Whitelisting (Optional)

For admin endpoints:

```nginx
location /api/admin {
    allow 192.168.1.0/24;
    deny all;
    proxy_pass http://sellia_backend;
}
```

## Troubleshooting

### WebSocket Disconnections

**Symptoms:** Tunnels connect but immediately disconnect.

**Solutions:**

1. **Verify WebSocket headers:**
   ```nginx
   proxy_set_header Upgrade $http_upgrade;
   proxy_set_header Connection "upgrade";
   ```

2. **Check timeouts:**
   ```nginx
   proxy_read_timeout 86400s;
   proxy_send_timeout 86400s;
   ```

3. **Verify HTTP/1.1:**
   ```nginx
   proxy_http_version 1.1;
   ```

### 502 Bad Gateway

**Symptoms:** Nginx can't connect to Sellia server.

**Solutions:**

1. **Check Sellia server is running:**
   ```bash
   sudo systemctl status sellia-server
   ```

2. **Verify upstream address:**
   ```bash
   curl http://127.0.0.1:3000/health
   ```

3. **Check SELinux:**
   ```bash
   sudo setsebool -P httpd_can_network_connect 1
   ```

### Certificate Errors

**Symptoms:** Browser warnings or connection failures.

**Solutions:**

1. **Verify certificate files exist:**
   ```bash
   ls -la /etc/letsencrypt/live/yourdomain.com/
   ```

2. **Check certificate validity:**
   ```bash
   sudo certbot certificates
   ```

3. **Reload Nginx after renewal:**
   ```bash
   sudo systemctl reload nginx
   ```

### DNS Configuration

**Symptoms:** Subdomains not accessible.

**Solutions:**

1. **Verify DNS records:**
   ```bash
   dig yourdomain.com
   dig myapp.yourdomain.com
   ```

2. **For wildcard subdomains:**
   - Add A record: `*.yourdomain.com` → your server IP
   - Or use CNAME: `*.yourdomain.com` → `yourdomain.com`

3. **Check Nginx server_name:**
   ```nginx
   server_name yourdomain.com *.yourdomain.com;
   ```

## Production Checklist

- [ ] TLS certificates installed and valid
- [ ] DNS records configured (A records for base and wildcard)
- [ ] Nginx configuration tested (`nginx -t`)
- [ ] HTTP to HTTPS redirect working
- [ ] WebSocket connections successful
- [ ] Log rotation configured
- [ ] HSTS enabled (after testing)
- [ ] Server tokens disabled
- [ ] Firewall allows ports 80 and 443
- [ ] SELinux/AppArmor configured
- [ ] Monitor Nginx status endpoint
- [ ] Backup Nginx configuration
- [ ] Auto-renewal of Let's Encrypt certificates verified

## See Also

- [Caddy Configuration](./caddy.md) - Alternative to Nginx
- [Production Checklist](./production-checklist.md) - Complete production guide
- [Server Auth](../authentication/server-auth.md) - Authentication setup
- [Database Configuration](../storage/database-config.md) - Database setup
