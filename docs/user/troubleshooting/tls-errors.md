# TLS and Certificate Errors Troubleshooting

Guide to fixing HTTPS/TLS issues with Sellia tunnels.

## Common Problems

### "Certificate Not Found" Error

**Symptoms**:
- Browser shows "NET::ERR_CERT_AUTHORITY_INVALID"
- Error: "certificate not found for domain"
- Caddy fails to get certificate

**Diagnosis**:

1. Check Caddy TLS verification endpoint:
```bash
curl "http://your-server.com/tunnel/verify?domain=myapp.your-domain.com"
```

2. Check Caddy logs:
```bash
journalctl -u caddy -f
```

**Solutions**:

1. **Ensure tunnel is active**:
```bash
# Certificate is only issued for active tunnels
sellia http --subdomain myapp

# Then test verification
curl "http://your-server.com/tunnel/verify?domain=myapp.your-domain.com"
```

2. **Check DNS is pointing correctly**:
```bash
# Should be CNAME or A record to your server
dig myapp.your-domain.com

# Expected: points to your server IP
```

3. **Wait for DNS propagation**:
```bash
# DNS can take up to 24 hours to propagate
# But usually takes 5-10 minutes
```

---

### "Cannot Verify Domain" Error

**Symptoms**:
- Caddy log: "verifying domain availability"
- Certificate issuance fails
- HTTP works but HTTPS doesn't

**Diagnosis**:

1. Check `/tunnel/verify` endpoint:
```bash
curl -v "http://your-server.com/tunnel/verify?domain=test.your-domain.com"
```

Expected response:
- `200 OK` if tunnel active
- `404 Not Found` if no tunnel

**Solutions**:

1. **Check base domain is allowed**:
```crystal
# In HTTPIngress#verify_tunnel_for_tls (actual implementation)
# Returns 200 if:
# 1. domain_param == base domain (for WebSocket connections from clients)
# 2. subdomain exists and has an active tunnel
# Otherwise returns 404
```

2. **Ensure tunnel is created before HTTPS request**:
```bash
# Start tunnel
sellia http --subdomain myapp &

# Wait for "Tunnel ready" message
# Then access via HTTPS
curl https://myapp.your-domain.com
```

3. **Check Caddy on-demand TLS config**:
```caddyfile
# Caddyfile
{
  # Enable on-demand TLS
  on_demand_tls {
    ask http://localhost:3000/tunnel/verify
  }
}

your-domain.com {
    reverse_proxy localhost:3000
}
```

---

### Mixed Content Warnings

**Symptoms**:
- Browser console shows "Mixed Content" errors
- Some resources fail to load
- Error: "was loaded over HTTPS, but requested an insecure resource"

**Diagnosis**:

Check browser console for:
```
The page at 'https://myapp.your-domain.com' was loaded over HTTPS, 
but requested an insecure resource 'http://myapp.your-domain.com/api'.
```

**Solutions**:

1. **Fix absolute URLs in your app**:
```html
<!-- BAD -->
<script src="http://myapp.your-domain.com/app.js"></script>

<!-- GOOD -->
<script src="/app.js"></script>

<!-- GOOD -->
<script src="https://myapp.your-domain.com/app.js"></script>
```

2. **Use protocol-relative URLs** (deprecated):
```html
<script src="//myapp.your-domain.com/app.js"></script>
```

3. **Update API calls**:
```javascript
// BAD
fetch('http://api.example.com/data')

// GOOD - use relative path
fetch('/api/data')

// GOOD - use HTTPS
fetch('https://api.example.com/data')
```

---

### "SSL_ERROR_BAD_CERT_DOMAIN"

**Symptoms**:
- Browser error: "SSL_ERROR_BAD_CERT_DOMAIN"
- Error: "certificate does not match domain name"

**Diagnosis**:

1. Check certificate:
```bash
openssl s_client -connect myapp.your-domain.com:443 -servername myapp.your-domain.com
```

2. Check certificate CN/SAN:
```bash
# Look for:
# subject=CN = myapp.your-domain.com
# subjectAltName=DNS:myapp.your-domain.com
```

**Solutions**:

1. **Clear browser cache**:
```
Sometimes browsers cache old certificates
```

2. **Wait for certificate renewal**:
```bash
# Caddy will retry every few minutes
# Check logs for progress
journalctl -u caddy -f | grep certificate
```

3. **Force certificate renewal**:
```bash
# Restart Caddy
systemctl restart caddy
```

---

### HSTS / PKIX Errors

**Symptoms**:
- Browser: "HSTS policy"
- Error: "PKIX path building failed"
- Cannot access even after fixing certificate

**Diagnosis**:

Check if site has HSTS:
```bash
curl -I https://myapp.your-domain.com | grep Strict-Transport-Security
```

**Solutions**:

1. **Clear HSTS in browser**:

**Chrome**:
1. Go to chrome://net-internals/#hsts
2. Enter domain under "Delete domain security policies"
3. Click Delete

**Firefox**:
1. Clear browser history
2. Or wait for HSTS to expire (max-age)

2. **Use private/incognito window**:
```
HSTS not enforced in private browsing
```

3. **Check HSTS header**:
```crystal
# Your app should not set HSTS if using dynamic certificates
# Or set max-age appropriately
response.headers["Strict-Transport-Security"] = "max-age=31536000"
```

---

### Caddy Cannot Obtain Certificate

**Symptoms**:
- Caddy log: "obtaining certificate"
- Caddy log: "no solution found"
- HTTPS works after delay (1-2 minutes)

**Diagnosis**:

1. Check Caddy logs:
```bash
journalctl -u caddy -n 50 | grep -i certificate
```

2. Check Let's Encrypt rate limits:
```bash
# Check if you hit rate limits
# https://letsencrypt.net/docs/rate-limits/
```

**Solutions**:

1. **Wait for rate limit reset**:
```
Let's Encrypt limit: 50 certificates per domain per week
```

2. **Use staging environment for testing**:
```caddyfile
{
  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}
```

3. **Reduce certificate requests**:
```bash
# Don't recreate tunnels frequently
# Use same subdomain for testing
```

---

### "Certificate Expired" Error

**Symptoms**:
- Browser: "certificate has expired"
- Connection refused

**Diagnosis**:

```bash
# Check certificate expiration
echo | openssl s_client -servername myapp.your-domain.com -connect myapp.your-domain.com:443 2>/dev/null | openssl x509 -noout -dates
```

**Solutions**:

1. **Caddy auto-renews**:
```
Certificates are automatically renewed 30 days before expiration
```

2. **Force renewal if needed**:
```bash
systemctl restart caddy
```

3. **Check system time**:
```bash
# Wrong system time can cause certificate validation to fail
timedatectl status
```

---

### TLS Handshake Timeout

**Symptoms**:
- Connection hangs
- Error: "TLS handshake timeout"
- No response from server

**Diagnosis**:

```bash
# Test TLS handshake
timeout 10 openssl s_client -connect myapp.your-domain.com:443
```

**Solutions**:

1. **Check firewall allows port 443**:
```bash
sudo ufw allow 443/tcp
sudo firewall-cmd --add-port=443/tcp --permanent
```

2. **Check reverse proxy is running**:
```bash
systemctl status caddy
systemctl status nginx
```

3. **Increase timeout**:
```caddyfile
your-domain.com {
    reverse_proxy localhost:3000 {
        transport http {
            read_timeout 30s
            write_timeout 30s
        }
    }
}
```

---

## Configuration Examples

### Caddy with On-Demand TLS

```caddyfile
# Caddyfile
{
    # On-demand TLS configuration
    on_demand_tls {
        # Ask Sellia server if domain should get certificate
        ask http://localhost:3000/tunnel/verify
    }
}

your-domain.com {
    # Reverse proxy to Sellia server
    reverse_proxy localhost:3000 {
        # WebSocket support (automatic in Caddy)
    }
}
```

### Caddy with Rate Limiting

```caddyfile
your-domain.com {
    reverse_proxy localhost:3000

    # Rate limit certificate issuance
    @on_demand_tls {
        rate_limit {
            zone tls {
                key {tls_on_demand}
                events 100
                window 1m
            }
        }
    }
}
```

### Nginx with SSL

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL certificate (use Let's Encrypt/Certbot)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # Reverse proxy
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

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

---

## Prevention

### Use Stable Subdomains

```bash
# In production, don't use random subdomains
# They change each time, requiring new certificates

# BAD - random subdomain
sellia http

# GOOD - fixed subdomain
sellia http --subdomain myapp-prod
```

### Monitor Certificate Expiration

```bash
# Check certificate expiration
echo | openssl s_client -servername myapp.your-domain.com -connect myapp.your-domain.com:443 2>/dev/null | openssl x509 -noout -dates

# Set up monitoring to alert at 30 days
```

### Test Certificate Configuration

```bash
# Use SSL Labs to test configuration
# https://www.ssllabs.com/ssltest/analyze.html?d=myapp.your-domain.com

# Should get A or A+ grade
```

### Use Proper DNS

```bash
# Wildcard DNS (simple)
*.your-domain.com A 1.2.3.4

# Or individual subdomains
myapp.your-domain.com A 1.2.3.4
```

---

## Let's Encrypt Limits

### Rate Limits

- **Certificates per Registered Domain**: 50 per week
- **Certificates per Certificate Name**: 5 per week
- **Duplicate Certificate limit**: 1 per 3 days

### Check Limits

```bash
# Check staging environment first
{
  acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

# Use production after testing
{
  acme_ca https://acme-v02.api.letsencrypt.org/directory
}
```

### Failed Attempts Count

Failed validation attempts count against rate limits. Ensure:
- DNS is correct
- Server is accessible
- Firewall allows connections
