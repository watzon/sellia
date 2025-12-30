# Security

Security considerations and best practices for Sellia.

## Overview

This section covers security aspects of Sellia, including authentication, encryption, and secure deployment practices.

## Security Model

### Threat Model

Sellia is designed to protect against:

- **Unauthorized tunnel creation** - API key authentication
- **Tunnel hijacking** - Subdomain validation and reservation
- **Data interception** - TLS/WSS encryption
- **Abuse** - Rate limiting and authentication
- **Information leakage** - Secure credential storage

### Security Layers

1. **Transport Security** - TLS/WSS for encrypted communication
2. **Server Authentication** - API key validation
3. **Tunnel Authentication** - HTTP basic auth per tunnel
4. **Access Control** - Subdomain reservation and validation
5. **Rate Limiting** - Abuse prevention

## Authentication

### Server Authentication

API keys control who can create tunnels:

```bash
# Enable authentication
sellia-server --require-auth --master-key secure-key

# Or with environment
export SELLIA_MASTER_KEY=$(openssl rand -hex 32)
export SELLIA_REQUIRE_AUTH=true
```

**Best Practices:**
- Generate strong master keys (32+ bytes)
- Rotate keys regularly
- Store keys securely (environment variables, secrets managers)
- Never commit keys to repository
- Use different keys for different environments

### Tunnel Authentication

Protect individual tunnels with HTTP basic auth:

```bash
sellia http 3000 --auth user:password
```

**Best Practices:**
- Use strong, unique passwords per tunnel
- Rotate credentials periodically
- Use password managers for storage
- Share credentials securely

### API Key Storage

**Environment Variables (Recommended):**
```bash
export SELLIA_API_KEY=$(openssl rand -hex 32)
```

**Configuration Files:**
```yaml
# sellia.yml - Use environment variables
server: https://sellia.me
api_key: ${SELLIA_API_KEY}  # From environment
```

**Never Do:**
```yaml
# NEVER commit actual keys
api_key: "abc123"  # BAD
```

## Transport Security

### TLS/WSS Encryption

Encrypt all traffic with TLS:

```bash
# The server typically runs behind a reverse proxy (Caddy, nginx, Traefik)
# for HTTPS/WSS termination. The server itself supports HTTP/WebSocket.

# Example with Caddy reverse proxy:
sellia-server --port 3000 --domain yourdomain.com
```

**Certificate Setup:**
- Use valid TLS certificates
- Keep certificates up to date
- Use strong cipher suites
- Enable HSTS

### Certificate Sources

**Cloudflare Origin Certificate (Recommended):**
- Free for Cloudflare users
- 15-year validity
- Wildcard certificates

**Let's Encrypt:**
- Free, automated certificates
- 90-day validity
- Auto-renewal with certbot

**Commercial CA:**
- Trusted by all clients
- Varying costs
- Different validation levels

## Input Validation

### Subdomain Validation

Validate subdomains to prevent injection:

```crystal
def validate_subdomain(subdomain : String) : Bool
  return false if subdomain.empty?
  return false if subdomain.size > 63
  return false unless subdomain.matches?(/^[a-z0-9-]+$/)
  return false if subdomain.starts_with?('-')
  return false if subdomain.ends_with?('-')
  true
end
```

### Reserved Subdomains

Prevent reservation of system subdomains:

```crystal
RESERVED_SUBDOMAINS = %w[
  www
  api
  admin
  mail
  ftp
  localhost
  test
  dev
  staging
  production
]
```

### Host Header Validation

Validate Host headers to prevent attacks:

```crystal
def validate_host_header(host : String) : Bool
  # Check format
  return false unless host.includes?(@domain)

  # Check for port
  return false if host.includes?(':') && !valid_port?(host)

  true
end
```

## Rate Limiting

### Configuration

Enable rate limiting to prevent abuse:

```bash
# Rate limiting enabled by default
sellia-server

# Disable (not recommended in production)
sellia-server --no-rate-limit
```

### Implementation

Track requests per client:

```crystal
class RateLimiter
  REQUESTS_PER_MINUTE = 60

  def allow?(client_ip : String) : Bool
    # Check request count
    # Enforce limit
    # Return true/false
  end
end
```

**Best Practices:**
- Keep rate limiting enabled in production
- Adjust limits based on capacity
- Log rate limit violations
- Consider per-user limits for authenticated users

## Data Security

### Request Logging

Be careful logging sensitive data:

```crystal
# Don't log sensitive headers
SENSITIVE_HEADERS = %w[
  authorization
  cookie
  set-cookie
  x-api-key
]

def sanitize_headers(headers : HTTP::Headers) : HTTP::Headers
  headers.dup.tap do |h|
    SENSITIVE_HEADERS.each do |name|
      h[name] = "[REDACTED]" if h[name]?
    end
  end
end
```

### Password Storage

Never log passwords:

```crystal
# Bad
Log.info { "Tunnel created with auth: #{user}:#{pass}" }

# Good
Log.info { "Tunnel created with auth: #{user}:[REDACTED]" }
```

### Inspector Data

Clear sensitive data from inspector:

```bash
# Clear history periodically
sellia http 3000  # Auto-clear on exit (future)
```

## Deployment Security

### Firewall Rules

Restrict access to server:

```bash
# Allow only necessary ports
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable
```

### Docker Security

```yaml
# docker-compose.yml
services:
  sellia-server:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

### File Permissions

Set appropriate permissions:

```bash
# Configuration files
chmod 600 sellia.yml

# Certificate directory
chmod 755 /var/lib/sellia/
chmod 640 /var/lib/sellia/cert.pem
chmod 600 /var/lib/sellia/key.pem
```

## Dependency Security

### Regular Updates

Keep dependencies updated:

```bash
# Update Crystal dependencies
shards update

# Update Node dependencies
cd web
npm update
npm audit fix
```

### Vulnerability Scanning

Scan for vulnerabilities:

```bash
# Crystal (manual review)
shards list
# Check for known issues

# Node
npm audit
```

## Security Headers

### HTTP Security Headers

```crystal
def add_security_headers(response : HTTP::Server::Response)
  response.headers["X-Content-Type-Options"] = "nosniff"
  response.headers["X-Frame-Options"] = "DENY"
  response.headers["X-XSS-Protection"] = "1; mode=block"
  response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
  response.headers["Content-Security-Policy"] = "default-src 'self'"
end
```

## Best Practices

### Development

- Never commit credentials
- Use environment variables
- Enable debug logging only in development
- Test with authentication enabled

### Staging

- Mirror production security settings
- Use separate API keys
- Test certificate renewal
- Monitor rate limiting

### Production

- Always require authentication
- Use strong master keys
- Enable rate limiting
- Use HTTPS/WSS
- Monitor logs for suspicious activity
- Regular security audits
- Keep dependencies updated

## Incident Response

### Security Incident Process

1. **Identify** - Detect security issue
2. **Contain** - Limit impact
3. **Eradicate** - Remove threat
4. **Recover** - Restore service
5. **Post-Mortem** - Document and improve

### Reporting Vulnerabilities

If you discover a security vulnerability:

1. **Do not create public issue**
2. **Email privately**: chris@watzon.tech
3. **Include details**:
   - Vulnerability description
   - Steps to reproduce
   - Impact assessment
   - Suggested fix

4. **Response timeline**:
   - Acknowledgment within 48 hours
   - Fix timeline discussion
   - Coordinated disclosure

## Security Checklist

### Before Deployment

- [ ] Strong master key generated
- [ ] Authentication required
- [ ] TLS certificates installed
- [ ] Firewall rules configured
- [ ] Rate limiting enabled
- [ ] Secrets not in repository
- [ ] Dependencies updated
- [ ] Logging configured

### Ongoing

- [ ] Monitor logs for suspicious activity
- [ ] Regular dependency updates
- [ ] Certificate expiration monitoring
- [ ] Security audit periodic
- [ ] Access review
- [ ] Backup verification

## Next Steps

- [Deployment](../../user/deployment/) - Secure deployment guide
- [Authentication](../../user/authentication/) - Authentication setup
- [Contributing](../contributing/) - Secure development practices
