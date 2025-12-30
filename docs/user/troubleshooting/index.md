# Troubleshooting

Solutions to common issues when using Sellia.

## Overview

This section covers common problems and their solutions when working with Sellia.

## Installation Issues

### Build Failures

#### Crystal Version Too Old

**Problem:** "Crystal version >= 1.10.0 required"

**Solution:**
```bash
# Check Crystal version
crystal --version

# Update Crystal
# See https://crystal-lang.org/install/
```

#### Dependency Errors

**Problem:** "Could not find dependency"

**Solution:**
```bash
# Update shards
shards update

# Clear cache and reinstall
rm -rf lib/
shards install
```

#### Compilation Errors

**Problem:** Compilation fails with errors

**Solutions:**
- Ensure Crystal >= 1.10.0
- Run `shards update`
- Check for conflicting shard versions
- Try `shards build --release` for production build

## Connection Issues

### Can't Connect to Server

#### Server Not Running

**Problem:** "Connection refused" when creating tunnel

**Solutions:**
```bash
# Check if server is running
ps aux | grep sellia

# Start server
sellia server --port 3000 --domain yourdomain.com
```

#### Wrong Server Address

**Problem:** Can't connect to tunnel server

**Solutions:**
```bash
# Verify server URL
sellia http 3000 --server ws://localhost:3000

# Check server is listening
netstat -an | grep :3000
```

#### Firewall Blocking

**Problem:** Connection times out

**Solutions:**
```bash
# Check firewall status
sudo ufw status

# Allow port (Ubuntu/Debian)
sudo ufw allow 3000/tcp

# Check firewall (CentOS/RHEL)
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=3000/tcp --permanent
```

### Tunnel Connection Drops

#### Automatic Reconnection

**Problem:** Tunnel disconnects intermittently

**Solution:** Sellia auto-reconnects with linear backoff (3s, 6s, 9s... up to 30s max, 10 attempts). If it doesn't reconnect:

```bash
# Check server logs for errors
# Verify network stability
# Check for rate limiting
# Note: Client gives up after 10 failed attempts
```

#### Network Changes

**Problem:** Tunnel drops when network changes

**Solutions:**
- Sellia should auto-reconnect
- If not, restart the tunnel
- Check for IP changes

## Tunnel Issues

### Subdomain Already Taken

**Problem:** "Subdomain already in use"

**Solutions:**
```bash
# Use a different subdomain
sellia http 3000 --subdomain myapp2

# Let Sellia assign random subdomain
sellia http 3000
```

### Local Service Not Accessible

**Problem:** Tunnel works but returns connection errors

**Solutions:**
```bash
# Verify local service is running
lsof -i :3000

# Check correct host (default: localhost)
sellia http 3000 --host 127.0.0.1

# Test local access
curl http://localhost:3000
```

### Wrong Local Port

**Problem:** Tunnel created but can't reach service

**Solutions:**
```bash
# Verify port number
sellia http 8080  # correct port

# Check what's listening
netstat -an | grep LISTEN
```

## Authentication Issues

### API Key Authentication Failed

**Problem:** "Authentication failed" error

**Solutions:**
```bash
# Verify API key
sellia http 3000 --api-key your-key

# Check server requires auth
sellia-server --require-auth --master-key your-key

# Regenerate key if needed
openssl rand -hex 32
```

### Basic Auth Not Working

**Problem:** "Unauthorized" when accessing tunnel

**Solutions:**
```bash
# Verify auth format (username:password)
sellia http 3000 --auth admin:secret

# Test with curl
curl -u admin:secret http://abc123.yourdomain.com

# Check for special characters (use quotes)
sellia http 3000 --auth "admin:p@ssw0rd"
```

## Inspector Issues

### Inspector Not Loading

**Problem:** Can't access inspector at localhost:4040

**Solutions:**
```bash
# Check if inspector is enabled
sellia http 3000  # inspector enabled by default

# Check firewall
sudo ufw allow 4040/tcp

# Try different port
sellia http 3000 --inspector-port 5000
```

### Inspector Shows No Requests

**Problem:** Inspector loads but no requests appear

**Solutions:**
```bash
# Verify tunnel is working
curl http://your-subdomain.yourdomain.com

# Check tunnel is still running
# Look for errors in terminal

# Try disabling and re-enabling
sellia http 3000 --no-inspector
sellia http 3000
```

## Performance Issues

### Slow Connection

**Problem:** Tunnels are slow

**Solutions:**
- Check network bandwidth
- Verify server resources
- Check for rate limiting
- Try different server region

### High Memory Usage

**Problem:** CLI or server using too much memory

**Solutions:**
```bash
# Disable inspector
sellia http 3000 --no-inspector

# Clear request history regularly
# Restart tunnel periodically

# Check memory usage
ps aux | grep sellia
```

## TLS/SSL Issues

### Certificate Errors

**Problem:** "SSL certificate error"

**Solutions:**
```bash
# Verify certificate files exist
ls -l certs/cert.pem certs/key.pem

# Check certificate not expired
openssl x509 -in certs/cert.pem -noout -dates

# Verify certificate matches domain
openssl x509 -in certs/cert.pem -noout -text | grep DNS
```

### HTTPS Not Working

**Problem:** HTTPS URLs not generated

**Solutions:**
```bash
# Enable HTTPS on server
sellia-server --https --domain yourdomain.com

# Set environment variable
export SELLIA_USE_HTTPS=true

# Verify certificates are in place
ls certs/
```

## Docker Issues

### Container Won't Start

**Problem:** Docker container fails to start

**Solutions:**
```bash
# Check logs
docker compose -f docker-compose.prod.yml logs

# Verify environment variables
cat .env

# Check port conflicts
docker ps
netstat -an | grep :3000
```

### Volume Mount Issues

**Problem:** Can't access files in container

**Solutions:**
```bash
# Verify volume configuration
docker compose config

# Check volume exists
docker volume ls

# Inspect volume
docker volume inspect sellia-data
```

## DNS Issues

### Subdomain Not Resolving

**Problem:** Tunnel URL doesn't resolve

**Solutions:**
```bash
# Check DNS configuration
dig yoursubdomain.yourdomain.com

# Verify DNS has propagated (can take 48 hours)
# Check for wildcard DNS record

# Test with IP directly
curl http://your-server-ip:3000
```

### Cloudflare DNS

**Problem:** Cloudflare DNS not working

**Solutions:**
- Verify DNS record in Cloudflare dashboard
- Check proxy status (orange cloud)
- Verify SSL/TLS mode
- Wait for propagation

## Development Issues

### Changes Not Reflected

**Problem:** Code changes don't affect running Sellia

**Solutions:**
```bash
# Rebuild
shards build --release

# Restart server
kill $(pgrep sellia-server)
sellia-server

# Clear cache if needed
rm -rf .crystal/
```

### Inspector UI Not Updating

**Problem:** UI changes not showing

**Solutions:**
```bash
# For development
cd web
npm run dev

# Rebuild embedded assets
cd web
npm run build
cd ..
shards build --release
```

## Debug Mode

### Enable Debug Logging

**Problem:** Need more information to diagnose issue

**Solution:**
```bash
# Enable debug logging
LOG_LEVEL=debug sellia-server --port 3000 --domain localhost

# Or for client
LOG_LEVEL=debug sellia http 3000
```

### Check Logs

```bash
# Docker logs
docker compose -f docker-compose.prod.yml logs -f

# System logs
journalctl -u sellia -f

# Server logs to file
sellia-server 2>&1 | tee server.log
```

## Getting Help

### Report Issues

If you can't solve your issue:

1. Check [GitHub Issues](https://github.com/watzon/sellia/issues)
2. Search for similar problems
3. Create new issue with:
   - Sellia version
   - OS and version
   - Crystal version
   - Full error message
   - Steps to reproduce

### Useful Information for Bug Reports

```bash
# Sellia version
sellia version

# Crystal version
crystal --version

# OS version
uname -a

# Docker version (if applicable)
docker --version

# Copy exact error message
```

### Community Resources

- [GitHub Issues](https://github.com/watzon/sellia/issues)
- [GitHub Discussions](https://github.com/watzon/sellia/discussions)
- [Documentation](../)

## Common Error Messages

### "Address already in use"

Port is already in use by another process.

**Solution:** Kill existing process or use different port.

### "Connection refused"

Server is not running or not accessible.

**Solution:** Start server or check firewall.

### "Authentication failed"

Invalid or missing API key.

**Solution:** Verify API key or check server auth settings.

### "Subdomain already taken"

Requested subdomain is in use.

**Solution:** Use different subdomain or random one.

### "Certificate not found"

TLS certificate files missing.

**Solution:** Place `cert.pem` and `key.pem` in `certs/` directory.

## Next Steps

- [Getting Started](../getting-started/) - Setup verification
- [Configuration](../configuration/) - Configuration help
- [GitHub Issues](https://github.com/watzon/sellia/issues) - Report bugs
