# Deployment

Deploy Sellia to production environments.

## Overview

This section covers deploying Sellia to production, from simple Docker setups to cloud deployments.

## Quick Start (Docker Compose)

The easiest way to deploy Sellia is with Docker Compose:

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

# Start server
docker compose -f docker-compose.prod.yml up -d
```

## Prerequisites

### Domain Requirements

You need a domain (or subdomain) for Sellia:

- **Option 1:** Use Cloudflare (recommended, free)
- **Option 2:** Use any domain with DNS control
- **Option 3:** Use subdomain: `tunnel.yourdomain.com`

### TLS Certificates

Sellia requires TLS certificates for HTTPS tunnels.

#### Cloudflare Origin Certificate (Recommended)

1. Add domain to [Cloudflare](https://cloudflare.com) (free tier works)
2. Go to **SSL/TLS** → **Origin Server** → **Create Certificate**
3. Select:
   - Hostnames: `*.yourdomain.com` and `yourdomain.com`
   - Validity: 15 years
   - Key format: PEM (default)
4. Click **Create** and download certificate and key
5. Place in `./certs/` directory:
   ```
   certs/
   ├── cert.pem  # Origin certificate
   └── key.pem   # Private key
   ```

#### Let's Encrypt

```bash
# Install certbot
sudo apt-get install certbot

# Generate certificate
certbot certonly --standalone -d yourdomain.com -d *.yourdomain.com

# Copy certificates
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem certs/cert.pem
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem certs/key.pem
```

#### Self-Signed (Testing Only)

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem -days 365 -nodes
```

## Docker Deployment

### Environment File

Create `.env` file:

```bash
# Domain
SELLIA_DOMAIN=yourdomain.com

# Authentication
SELLIA_MASTER_KEY=$(openssl rand -hex 32)
SELLIA_REQUIRE_AUTH=true
```

### Docker Compose

Use provided production compose file:

```bash
docker compose -f docker-compose.prod.yml up -d
```

### Manual Docker

```bash
# Build image
docker build -t sellia-server .

# Run container (without reverse proxy)
docker run -d \
  --name sellia-server \
  --env-file .env \
  -p 3000:3000 \
  sellia-server
```

## Cloud Deployment

### DigitalOcean

#### Create Droplet

```bash
# Create droplet with Docker
doctl compute droplet create sellia-server \
  --region nyc1 \
  --size s-2vcpu-4gb \
  --image docker-20-04 \
  --ssh-keys <your-ssh-key-fingerprint>
```

#### Deploy

```bash
# SSH into droplet
ssh root@your-droplet-ip

# Clone repository
git clone https://github.com/watzon/sellia.git
cd sellia

# Setup as above
```

### AWS

#### EC2 Instance

1. Launch EC2 instance with Ubuntu
2. Install Docker
3. Configure security groups (port 3000)
4. Deploy as above

#### Elastic Beanstalk

Create `Dockerrun.aws.json`:

```json
{
  "AWSEBDockerrunVersion": "1",
  "Image": {
    "Name": "sellia-server",
    "Update": "true"
  },
  "Ports": [
    {
      "ContainerPort": "3000"
    }
  ],
  "Environment": [
    {
      "Name": "SELLIA_DOMAIN",
      "Value": "yourdomain.com"
    },
    {
      "Name": "SELLIA_REQUIRE_AUTH",
      "Value": "true"
    },
    {
      "Name": "SELLIA_MASTER_KEY",
      "Value": "your-master-key"
    }
  ]
}
```

### Google Cloud Platform

#### Cloud Run

```bash
# Build image
gcloud builds submit --tag gcr.io/PROJECT-ID/sellia-server

# Deploy
gcloud run deploy sellia-server \
  --image gcr.io/PROJECT-ID/sellia-server \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

### Heroku

```bash
# Create app
heroku create sellia-server

# Set environment variables
heroku config:set SELLIA_DOMAIN=yourdomain.com
heroku config:set SELLIA_MASTER_KEY=$(openssl rand -hex 32)
heroku config:set SELLIA_REQUIRE_AUTH=true

# Deploy
git push heroku main
```

## DNS Configuration

### Cloudflare (Recommended)

1. Add domain to Cloudflare
2. Point DNS to your server IP
3. Enable proxy (orange cloud)
4. SSL/TLS → Full (strict)
5. Disable "Universal SSL" if using origin certificates

### Traditional DNS

```
Type: A
Name: tunnel (or your subdomain)
Value: your-server-ip
TTL: 300
```

For wildcard subdomains:

```
Type: CNAME
Name: *
Value: tunnel.yourdomain.com
TTL: 300
```

## Reverse Proxy

### Nginx

```nginx
server {
    listen 80;
    server_name tunnel.yourdomain.com *.tunnel.yourdomain.com;

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

### Caddy

```
tunnel.yourdomain.com, *.tunnel.yourdomain.com {
    reverse_proxy localhost:3000
}
```

## Monitoring

### Health Checks

Configure health checks:

```bash
# Check if server is responding
curl -f http://localhost:3000/health || echo "Server down"
```

Or via Caddy/Nginx reverse proxy:
```bash
curl -f https://yourdomain.com/health || echo "Server down"
```

### Logging

```bash
# View logs
docker compose -f docker-compose.prod.yml logs -f

# Rotate logs
logrotate /etc/logrotate.d/sellia
```

### Metrics

Consider integrating with:

- Prometheus + Grafana
- DataDog
- New Relic
- CloudWatch (AWS)

## Security

### Firewall

```bash
# Configure UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 3000/tcp
ufw enable
```

### SSL/TLS

- Always use HTTPS in production
- Keep certificates up to date
- Use strong ciphers
- Enable HSTS

### Authentication

- Always require authentication
- Use strong master key
- Rotate API keys regularly
- Monitor authentication attempts

## Backup

### Configuration Backup

```bash
# Backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
tar -czf sellia-backup-$DATE.tar.gz \
  .env \
  sellia.yml \
  certs/
```

### Automated Backup

```bash
# Add to crontab
0 2 * * * /path/to/backup-script.sh
```

## Scaling

### Multiple Servers

For high availability:

1. Deploy multiple Sellia servers
2. Use load balancer (nginx, HAProxy)
3. Configure shared storage
4. Health checks for failover

### Load Balancer Example (Nginx)

```nginx
upstream sellia_backend {
    server sellia1.example.com:3000;
    server sellia2.example.com:3000;
    server sellia3.example.com:3000;
}

server {
    listen 80;
    server_name tunnel.yourdomain.com;

    location / {
        proxy_pass http://sellia_backend;
    }
}
```

## Troubleshooting

### Certificate Issues

**Problem:** Certificate not loading

**Solutions:**
- Verify certificate files exist
- Check file permissions (644)
- Verify file format (PEM)
- Check certificate expiration

### DNS Issues

**Problem:** Subdomains not resolving

**Solutions:**
- Verify DNS configuration
- Check for wildcard DNS record
- Wait for DNS propagation (up to 48 hours)
- Use `dig` to verify DNS

### Connection Issues

**Problem:** Clients can't connect

**Solutions:**
- Check firewall rules
- Verify server is running
- Check DNS resolution
- Verify port is accessible

## Next Steps

- [Admin Guide](../admin/) - Ongoing server administration
- [Configuration](../configuration/) - Detailed configuration options
- [Security](../../developer/security/) - Security best practices
