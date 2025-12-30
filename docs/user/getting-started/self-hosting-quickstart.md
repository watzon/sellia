# Self-Hosting Quick Start

Run your own Sellia tunnel server for full control, privacy, and customization. This guide will get you up and running in 10 minutes.

## Why Self-Host?

Self-hosting gives you:
- **Privacy**: Full control over your data
- **Customization**: Configure domains, auth, and features
- **Cost savings**: No subscription fees
- **Reliability**: No dependencies on external services
- **Security**: Manage your own TLS certificates

## Prerequisites

Before starting, ensure you have:
- Sellia installed ([Installation Guide](./installation.md))
- A domain name (or subdomain) with DNS configured
- A server with public IP (VPS, cloud server, or local machine with port forwarding)
- Basic knowledge of DNS and networking

## Quick Start: Docker Compose (Recommended)

The fastest way to self-host Sellia is with Docker Compose.

### Step 1: Clone the Repository

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
```

### Step 2: Configure Environment Variables

Create a `.env` file:

```bash
cat > .env << EOF
SELLIA_DOMAIN=yourdomain.com
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
SELLIA_USE_HTTPS=true
EOF
```

Replace `yourdomain.com` with your actual domain.

### Step 3: Prepare TLS Certificates

Sellia requires TLS certificates. The quickest option is using Cloudflare Origin Certificates (free):

1. Add your domain to [Cloudflare](https://cloudflare.com)
2. Go to **SSL/TLS** → **Origin Server** → **Create Certificate**
3. Select:
   - Hostnames: `*.yourdomain.com` and `yourdomain.com`
   - Validity: 15 years
4. Download the certificate and key
5. Place them in `./certs/`:
   ```
   certs/
   ├── cert.pem
   └── key.pem
   ```

### Step 4: Start the Server

```bash
docker compose -f docker-compose.prod.yml up -d
```

### Step 5: Verify Deployment

Check that the server is running:

```bash
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f
```

### Step 6: Create Your First Tunnel

On your local machine:

```bash
sellia http 8080 --server https://yourdomain.com --api-key YOUR_MASTER_KEY
```

Your tunnel is now accessible at:
```
https://abc123.yourdomain.com
```

## Manual Setup: Running from Source

If you prefer to run Sellia directly without Docker:

### Step 1: Build Sellia

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
shards build --release
```

### Step 2: Prepare TLS Certificates

As with Docker, you need TLS certificates. Place them in `./certs/`:
```
certs/
├── cert.pem
└── key.pem
```

### Step 3: Start the Server

```bash
./bin/sellia-server \
  --port 3000 \
  --domain yourdomain.com \
  --require-auth \
  --master-key $(openssl rand -hex 32) \
  --https
```

### Step 4: Configure Reverse Proxy (Recommended)

For production, use a reverse proxy like Nginx or Caddy. Here's a basic Nginx config:

```nginx
server {
    listen 80;
    server_name yourdomain.com *.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name yourdomain.com *.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Step 5: Create Tunnels

```bash
sellia http 8080 --server https://yourdomain.com --api-key YOUR_MASTER_KEY
```

## Server Configuration Options

The `sellia-server` binary supports several options:

```
sellia-server [options]

Options:
  --host HOST           Host to bind to (default: 0.0.0.0)
  --port PORT           Port to listen on (default: 3000)
  --domain DOMAIN       Base domain for subdomains (default: localhost)
  --require-auth        Require API key authentication
  --master-key KEY      Master API key (enables auth)
  --https               Generate HTTPS URLs for tunnels
  --no-rate-limit       Disable rate limiting
  --no-landing          Disable the landing page
  --db-path PATH        Path to SQLite database
  --no-db               Disable database (use in-memory defaults)
  -h, --help            Show help
  -v, --version         Show version
```

### Environment Variables

You can also configure the server using environment variables:

| Variable                   | Description                             | Default      |
| -------------------------- | --------------------------------------- | ------------ |
| `SELLIA_HOST`              | Host to bind to                         | `0.0.0.0`    |
| `SELLIA_PORT`              | Port to listen on                       | `3000`       |
| `SELLIA_DOMAIN`            | Base domain for subdomains              | `localhost`  |
| `SELLIA_REQUIRE_AUTH`      | Require authentication                  | `false`      |
| `SELLIA_MASTER_KEY`        | Master API key                          | -            |
| `SELLIA_USE_HTTPS`         | Generate HTTPS URLs                     | `false`      |
| `SELLIA_RATE_LIMITING`     | Enable rate limiting                    | `true`       |
| `SELLIA_DISABLE_LANDING`   | Disable the landing page                | `false`      |
| `SELLIA_DB_PATH`           | Path to SQLite database                 | `~/.sellia/sellia.db` |
| `SELLIA_NO_DB`             | Disable database (use in-memory defaults) | `false`    |

## DNS Configuration

Your domain's DNS should point to your server:

```
A    yourdomain.com        -> YOUR_SERVER_IP
A    *.yourdomain.com      -> YOUR_SERVER_IP
```

If using Cloudflare, enable proxy mode (orange cloud icon) for DDoS protection.

## Security Best Practices

### 1. Use Strong API Keys

Generate secure random keys:

```bash
openssl rand -hex 32
```

### 2. Enable Authentication

Always require authentication in production:

```bash
sellia-server --require-auth --master-key $(openssl rand -hex 32)
```

### 3. Use HTTPS

Enable HTTPS for secure tunnel URLs:

```bash
sellia-server --https
```

### 4. Enable Rate Limiting

Keep rate limiting enabled (default) to prevent abuse:

```bash
# Default: enabled
sellia-server

# Disable only if needed
sellia-server --no-rate-limit
```

### 5. Monitor Logs

Regularly check server logs for suspicious activity:

```bash
# With Docker
docker compose -f docker-compose.prod.yml logs -f

# Manual
./bin/sellia-server
```

## Managing API Keys

The master API key created during setup can be used to create tunnels. For better security, create individual keys for each user or application.

### Using API Keys

Store your API key securely:

```bash
# In environment variable
export SELLIA_API_KEY="your-api-key"

# Use with tunnel
sellia http 8080 --server https://yourdomain.com
```

Or in `sellia.yml`:

```yaml
server: https://yourdomain.com
api_key: your-api-key
```

Then use:

```bash
sellia http 8080
```

## Production Deployment

For production deployment, consider:

### 1. Use a Process Manager

Keep the server running with systemd, supervisord, or Docker:

```ini
# /etc/systemd/system/sellia.service
[Unit]
Description=Sellia Tunnel Server
After=network.target

[Service]
Type=simple
User=sellia
WorkingDirectory=/opt/sellia
ExecStart=/opt/sellia/bin/sellia-server --port 3000 --domain yourdomain.com
Restart=always
EnvironmentFile=/opt/sellia/.env

[Install]
WantedBy=multi-user.target
```

### 2. Configure Firewall

Open necessary ports:

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow Sellia server port (if not behind reverse proxy)
sudo ufw allow 3000/tcp
```

### 3. Set Up Monitoring

Monitor server health with tools like:
- Prometheus + Grafana
- Datadog
- New Relic
- Custom health checks

### 4. Configure Backups

Back up your configuration and TLS certificates:

```bash
# Backup script
tar -czf sellia-backup-$(date +%Y%m%d).tar.gz \
  /opt/sellia/.env \
  /opt/sellia/certs/ \
  /opt/sellia/sellia.yml
```

## Scaling Considerations

For high-traffic deployments:

1. **Load Balancing**: Run multiple Sellia instances behind a load balancer
2. **Caching**: Add caching for static content
3. **Database**: For persistent tunnel registry, consider adding a database backend
4. **Monitoring**: Implement comprehensive monitoring and alerting

## Troubleshooting

### Server Won't Start

Check port availability:

```bash
lsof -i :3000
```

### TLS Certificate Errors

Verify certificate paths and permissions:

```bash
ls -la ./certs/
cat ./certs/cert.pem
```

### DNS Not Resolving

Check DNS propagation:

```bash
dig yourdomain.com
dig *.yourdomain.com
```

### Tunnel Connection Failures

Verify:
1. Server is running
2. API key is correct
3. Network connectivity
4. Firewall rules

## Next Steps

Now that your server is running:

- [Configuration Guide](../configuration/config-file.md) - Advanced configuration
- [TLS Certificates](../deployment/tls-certificates.md) - Certificate management
- [Docker Deployment](../deployment/docker.md) - Container deployment
- [Multiple Tunnels](../configuration/multiple-tunnels.md) - Manage multiple tunnels

## Support

- [Documentation](../../../README.md)
- [GitHub Issues](https://github.com/watzon/sellia/issues)
- [Community Discussions](https://github.com/watzon/sellia/discussions)
