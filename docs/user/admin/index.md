# Admin Guide

Administrative tasks for managing your Sellia server.

## Overview

This section covers server administration, monitoring, and maintenance tasks for running a Sellia tunnel server.

## Server Management

### Starting the Server

Basic server start:

```bash
sellia-server --port 3000 --domain your-domain.com
```

With authentication:

```bash
sellia-server \
  --port 3000 \
  --domain your-domain.com \
  --require-auth \
  --master-key your-master-key
```

With HTTPS:

```bash
sellia-server \
  --port 3000 \
  --domain your-domain.com \
  --https \
  --require-auth \
  --master-key your-master-key
```

### Environment Configuration

Use environment variables for production:

```bash
# .env
SELLIA_HOST=0.0.0.0
SELLIA_PORT=3000
SELLIA_DOMAIN=yourdomain.com
SELLIA_REQUIRE_AUTH=true
SELLIA_MASTER_KEY=your-master-key
SELLIA_USE_HTTPS=true
SELLIA_RATE_LIMITING=true
LOG_LEVEL=warn
```

Start with environment:

```bash
source .env
sellia-server
```

## Monitoring

### Log Monitoring

Monitor server logs for issues:

```bash
# Follow logs
sellia-server 2>&1 | tee server.log

# Check for errors
grep -i error server.log

# Check for authentication attempts
grep -i auth server.log
```

### Connection Monitoring

Monitor active tunnels:

```bash
# View active connections (implementation varies)
# Check server logs for tunnel registrations
```

### Resource Monitoring

Monitor server resources:

```bash
# CPU and memory
top -p $(pgrep sellia-server)

# Network connections
netstat -an | grep :3000

# Tunnel connections
netstat -an | grep ESTABLISHED | grep :3000
```

## Maintenance

### Certificate Renewal

If using TLS certificates:

```bash
# Check certificate expiration
openssl x509 -in certs/cert.pem -noout -dates

# Renew with certbot (if using Let's Encrypt)
certbot renew

# Restart server after renewal
kill $(pgrep sellia-server)
sellia-server
```

### Backup Configuration

Backup important files:

```bash
# Backup configuration
cp .env .env.backup
cp sellia.yml sellia.yml.backup

# Backup certificates
tar -czf certs-backup-$(date +%Y%m%d).tar.gz certs/
```

### Update Server

Update to latest version:

```bash
# Stop server
kill $(pgrep sellia-server)

# Pull latest code
git pull origin main

# Rebuild
shards build --release

# Restart server
sellia-server
```

## Rate Limiting

### Overview

Sellia includes rate limiting to prevent abuse:

- Enabled by default
- Configurable limits per client
- Prevents brute force attacks
- Protects server resources

### Configure Rate Limiting

Enable/disable rate limiting:

```bash
# Disable (not recommended)
sellia-server --no-rate-limit

# Enable with environment variable
export SELLIA_RATE_LIMITING=true
```

### Custom Limits

Configure rate limits (implementation varies):

```bash
# Example: requests per minute
RATE_LIMIT=100
```

## Security

### Firewall Rules

Configure firewall to protect server:

```bash
# Allow Sellia server port
ufw allow 3000/tcp

# Allow SSH
ufw allow 22/tcp

# Enable firewall
ufw enable
```

### API Key Management

Generate and manage API keys:

```bash
# Generate new key
openssl rand -hex 32

# Set as master key
export SELLIA_MASTER_KEY=$(openssl rand -hex 32)

# Distribute to users securely
```

### Audit Logs

Enable audit logging:

```bash
# Enable debug logging for audit trail
export LOG_LEVEL=debug

# Rotate logs
logrotate -f /etc/logrotate.d/sellia
```

## Troubleshooting

### Server Won't Start

**Problem:** Server fails to start

**Solutions:**
- Check port is available: `lsof -i :3000`
- Verify configuration syntax
- Check file permissions
- Review error logs

### High Memory Usage

**Problem:** Server using excessive memory

**Solutions:**
- Check number of active tunnels
- Review rate limit settings
- Monitor for memory leaks
- Restart server periodically

### Connection Issues

**Problem:** Clients can't connect

**Solutions:**
- Verify server is running
- Check firewall rules
- Verify DNS configuration
- Check network connectivity

## Docker Deployment

### Using Docker Compose

Easiest deployment method:

```bash
# Start server
docker compose -f docker-compose.prod.yml up -d

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Stop server
docker compose -f docker-compose.prod.yml down

# Restart
docker compose -f docker-compose.prod.yml restart
```

### Docker Management

```bash
# View container stats
docker stats

# Execute command in container
docker exec -it sellia-server bash

# View logs
docker logs -f sellia-server

# Update container
docker compose pull
docker compose up -d
```

## Performance Tuning

### Connection Limits

Adjust connection limits:

```bash
# Increase file descriptor limit
ulimit -n 65536
```

### Caching

Configure HTTP caching (if applicable):

```bash
# Enable HTTP caching headers
```

### Load Balancing

For high-availability setups:

- Use multiple Sellia servers behind load balancer
- Configure shared storage for session state
- Use health checks for failover

## Disaster Recovery

### Backup Strategy

1. **Configuration** - Back up `.env`, `sellia.yml`
2. **Certificates** - Back up `certs/` directory
3. **Data** - Back up any persistent storage
4. **Scripts** - Back up deployment scripts

### Restore Procedure

```bash
# Stop server
docker compose down

# Restore configuration
cp .env.backup .env
cp sellia.yml.backup sellia.yml

# Restore certificates
tar -xzf certs-backup-YYYYMMDD.tar.gz

# Restart server
docker compose up -d
```

## Next Steps

- [Deployment](../deployment/) - Production deployment guide
- [Security](../../developer/security/) - Security best practices
- [Storage](../storage/) - Data persistence options
