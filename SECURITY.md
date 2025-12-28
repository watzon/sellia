# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to:

**chris@watzon.tech**

Include the following information:

- Type of vulnerability (e.g., XSS, SQL injection, buffer overflow)
- Full path to the affected source file(s)
- Step-by-step instructions to reproduce
- Proof-of-concept or exploit code (if available)
- Impact assessment

### What to Expect

- **Acknowledgment**: Within 48 hours of your report
- **Initial Assessment**: Within 1 week
- **Resolution Timeline**: Depends on severity, typically 30-90 days

We will keep you informed of our progress and may ask for additional information.

### Disclosure Policy

- We follow coordinated disclosure practices
- We will credit reporters in release notes (unless you prefer anonymity)
- Please allow us reasonable time to fix issues before public disclosure

## Security Best Practices for Self-Hosting

When running your own Sellia server:

### Network Security

- **Use HTTPS**: Place Sellia behind a reverse proxy (nginx, Caddy) with TLS termination
- **Firewall**: Restrict access to the WebSocket port if not needed publicly
- **Rate Limiting**: Keep rate limiting enabled in production (`--no-rate-limit` is for development only)

### Authentication

- **API Keys**: Use `--master-key` and `--require-auth` in production
- **Rotate Keys**: Periodically rotate API keys
- **Secure Storage**: Store API keys securely, not in version control

### Subdomain Security

- Reserved subdomains (api, www, admin, etc.) are blocked by default
- Custom subdomain validation prevents path traversal and injection attacks

### Monitoring

- Enable debug logging (`SELLIA_DEBUG=true`) to monitor for suspicious activity
- Monitor for unusual connection patterns or high request volumes

## Known Limitations

- Basic auth credentials for tunnel protection are transmitted in base64 (use HTTPS)
- In-memory state only; no persistence across restarts
- No built-in TLS termination (use a reverse proxy)

## Security Features

Sellia includes several security features:

- **Rate Limiting**: Token bucket algorithm for connections, tunnels, and requests
- **Subdomain Validation**: DNS label rules, length limits, reserved name blocklist
- **Input Validation**: Request size limits, header validation
- **Connection Timeouts**: WebSocket ping/pong heartbeat detects stale connections
- **Graceful Degradation**: Pending requests cleaned up on client disconnect
