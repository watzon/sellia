# Reporting Bugs

This guide explains how to report bugs effectively to help us fix them quickly.

## Table of Contents

- [Before Reporting](#before-reporting)
- [How to Report](#how-to-report)
- [Bug Report Template](#bug-report-template)
- [What to Include](#what-to-include)
- [After Reporting](#after-reporting)

## Before Reporting

### Check for Existing Issues

Search [existing issues](https://github.com/watzon/sellia/issues) to avoid duplicates:

1. Use the search bar at the top of the Issues page
2. Try different keywords related to your problem
3. Check both open and closed issues

**Search terms to try:**
- Error message text
- Component name (e.g., "WebSocket", "tunnel", "inspector")
- Action you were performing (e.g., "connecting", "registering")

### Verify You're Using the Latest Version

Bugs may already be fixed in newer versions:

```bash
# Check your version
./bin/sellia version

# Or
./bin/sellia-server --help
```

If you're not using the latest version:

```bash
# Update your installation
git pull origin main
shards build --release

# Verify version
./bin/sellia version
```

### Try to Reproduce the Issue

Before reporting, try to reproduce the bug consistently:

1. Write down the exact steps you took
2. Note when the bug occurs (every time? sometimes?)
3. Try on a fresh installation
4. Try with minimal configuration

### Check for Common Issues

Review [common issues and solutions](../development/debugging.md) to see if your problem is already documented.

## How to Report

### Create a GitHub Issue

1. Go to [github.com/watzon/sellia/issues](https://github.com/watzon/sellia/issues)
2. Click "New Issue"
3. Choose "Bug Report" template (if available)
4. Fill in the required information
5. Submit the issue

### Use a Clear Title

A good title helps us understand the problem immediately:

**Good titles:**
- "WebSocket connection fails after 30 seconds on macOS"
- "Tunnel registration throws 'subdomain exists' error for unique subdomain"
- "Inspector UI shows corrupted response body for binary data"

**Poor titles:**
- "Bug"
- "Help me"
- "Not working"
- "Sellia is broken"

## Bug Report Template

Use this template when reporting bugs:

```markdown
### Description

A clear and concise description of what the bug is.

### Reproduction Steps

1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected Behavior:**

A clear description of what you expected to happen.

**Actual Behavior:**

A clear description of what actually happened.

### Environment

- **OS:** [e.g., macOS 14.0, Ubuntu 22.04]
- **Crystal Version:** [e.g., 1.10.0]
- **Node.js Version:** [e.g., 18.17.0]
- **Sellia Version:** [e.g., 0.1.0]
- **Browser (if applicable):** [e.g., Chrome 118, Safari 17]

### Logs/Error Messages

```
Paste error messages or logs here
```

### Screenshots

If applicable, add screenshots to help explain your problem.

### Additional Context

Add any other context about the problem here.

- Configuration files (redact sensitive data)
- Network setup
- Proxy/firewall configuration
- Related issues or PRs
```

## What to Include

### 1. Clear Description

Explain the bug in plain language:

```markdown
### Description

When creating a tunnel with a custom subdomain using the --subdomain flag,
the tunnel is created but requests to the tunnel URL return 404 Not Found.
This happens every time, regardless of the subdomain used.
```

### 2. Reproduction Steps

Provide detailed, numbered steps to reproduce:

```markdown
### Reproduction Steps

1. Start the server:
   `./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io`

2. Start a simple HTTP server on port 8080:
   `python3 -m http.server 8080`

3. Create a tunnel with custom subdomain:
   `./bin/sellia http 8080 --server http://127.0.0.1:3000 --subdomain myapp`

4. Try to access the tunnel:
   `curl http://myapp.127.0.0.1.nip.io:3000`

5. Observe 404 error instead of expected response
```

### 3. Expected vs Actual Behavior

Clearly state what should happen vs. what does happen:

```markdown
**Expected Behavior:**

The curl request should return the directory listing from the Python HTTP
server running on port 8080.

**Actual Behavior:**

The request returns "404 Not Found" with no response body.
```

### 4. Environment Details

Include your system information:

```markdown
### Environment

- **OS:** macOS 14.0 (Sonoma)
- **Crystal Version:** 1.10.1
- **Node.js Version:** 18.17.0
- **Sellia Version:** 0.1.2 (built from source at commit abc123)
- **Architecture:** arm64 (Apple Silicon)
```

### 5. Error Messages and Logs

Include complete error messages and relevant logs:

```markdown
### Logs/Error Messages

**Server logs:**
```
[INFO] [Sellia Server] Listening on http://0.0.0.0:3000
[INFO] [Sellia Server] Domain: 127.0.0.1.nip.io
[DEBUG] [WSGateway] Client connecting from 127.0.0.1:54321
[DEBUG] [Registry] Registering tunnel: myapp -> client-123
[DEBUG] [HTTPIngress] Incoming request: GET / HTTP/1.1
[ERROR] [HTTPIngress] Tunnel not found: myapp
```

**CLI logs:**
```
[INFO] [Sellia] Connecting to server: http://127.0.0.1:3000
[INFO] [Sellia] Tunnel registered: myapp.127.0.0.1.nip.io:3000
[DEBUG] [TunnelClient] Waiting for requests...
```
```

**Tips for logs:**
- Use debug logging: `LOG_LEVEL=debug`
- Redact sensitive information (API keys, passwords)
- Include timestamps if relevant
- Show both server and client logs if applicable

### 6. Screenshots

For UI issues, screenshots are very helpful:

```markdown
### Screenshots

**Inspector UI showing corrupted response:**
![inspector-bug](https://i.imgur.com/...)

**Expected display:**
![expected](https://i.imgur.com/...)
```

**Tips for screenshots:**
- Show the entire window when relevant
- Highlight the problematic area
- Include before/after when applicable
- Keep file sizes reasonable (< 2MB)

### 7. Configuration Files

If the bug is configuration-related, include sanitized config:

```markdown
### Configuration

**sellia.yml:**
```yaml
server: http://127.0.0.1:3000
api_key: <redacted>

tunnels:
  myapp:
    port: 3000
    subdomain: myapp
```
```

**Important:** Redact sensitive information before sharing!

### 8. Minimal Reproduction Case

If possible, provide a minimal example that reproduces the bug:

```markdown
### Minimal Reproduction

I've created a minimal example that reproduces the issue:

```bash
# Start server
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Create simple echo server
echo 'require "http/server"; server = HTTP::Server.new { |ctx| ctx.response.print("OK") }; server.bind(8080); server.listen' > echo_server.cr
crystal run echo_server.cr

# Create tunnel
./bin/sellia http 8080 --server http://127.0.0.1:3000 --subdomain test

# Test
curl http://test.127.0.0.1.nip.io:3000
# Returns: 404 Not Found (expected: "OK")
```
```

## Bug Categories

### Connection Issues

When reporting connection problems:

```markdown
### Category: Connection Issue

**Problem:** Tunnel connects but immediately disconnects

**Network Setup:**
- Direct connection (no proxy)
- Firewall: macOS built-in firewall enabled
- Network: Home WiFi

**Connection Test:**
```
ping 127.0.0.1.nip.io - OK
telnet 127.0.0.1 3000 - OK
```
```

### Performance Issues

When reporting slow performance:

```markdown
### Category: Performance

**Problem:** Requests take > 5 seconds to complete

**Expected:** < 100ms response time
**Actual:** 5-10 seconds

**Load:** ~10 concurrent tunnels, ~100 requests/second

**Profiling Data:**
```
Request timing breakdown:
- WebSocket receive: 10ms
- Processing: 4950ms
- Response send: 40ms
```
```

### Security Issues

**Do NOT report security vulnerabilities through public issues!**

See [Security Disclosure](../security/vulnerability-disclosure.md) for reporting security issues privately.

### Documentation Issues

For documentation bugs or unclear documentation:

```markdown
### Category: Documentation

**Page:** https://github.com/watzon/sellia/blob/main/README.md
**Section:** Installation
**Problem:** Step 3 mentions running `shards build` but doesn't explain where shards comes from

**Suggested Fix:**
Add note that shards is installed with Crystal, or add to prerequisites section.
```

## After Reporting

### What to Expect

1. **Confirmation:** We'll respond within 48 hours
2. **Clarification:** We may ask for more information
3. **Triaging:** The issue will be tagged and prioritized
4. **Updates:** We'll provide updates on progress

### Stay Engaged

- Respond to follow-up questions promptly
- Test proposed fixes if asked
- Provide additional information as needed
- Confirm if the issue is resolved

### Issue Labels

We use labels to track issue status:

- `bug`: Confirmed bug
- `confirmed`: Reproduced by maintainers
- `needs-info`: Needs more information
- `in-progress`: Being worked on
- `good first issue`: Good for new contributors
- `help wanted`: Contributions welcome

## Best Practices

### DO:

- **Search before reporting** - Avoid duplicates
- **Be specific** - Provide exact steps and details
- **Use debug mode** - Enable `LOG_LEVEL=debug`
- **Redact sensitive data** - Remove API keys, passwords
- **Test on latest version** - Ensure bug still exists
- **Provide minimal reproduction** - Help us isolate the issue
- **Use appropriate template** - Fill out all required fields
- **One bug per issue** - Don't report multiple bugs in one issue

### DON'T:

- **Report sensitive issues publicly** - Security vulnerabilities go to email
- **Use vague titles** - "Help me" or "Broken" are not helpful
- **Forget environment details** - OS, version, etc. are essential
- **Include irrelevant logs** - Don't paste entire log files
- **Demand immediate fixes** - We're volunteers with limited time
- **Submit the same issue multiple times** - Bumping doesn't help

## Examples of Good Bug Reports

### Example 1: Clear and Complete

```markdown
### WebSocket connection fails after server running for > 1 hour

**Description:**
After the server runs for approximately 1 hour, new tunnel connections
fail with "WebSocket handshake timeout" error. Existing tunnels continue
to work.

**Reproduction Steps:**
1. Start server: `./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io`
2. Wait ~1 hour (no tunnels active during this time)
3. Try to create tunnel: `./bin/sellia http 8080 --server http://127.0.0.1:3000`
4. Observe error

**Expected Behavior:** Tunnel should connect successfully

**Actual Behavior:**
```
[ERROR] [TunnelClient] WebSocket handshake timeout after 30s
```

**Environment:**
- OS: Ubuntu 22.04 LTS
- Crystal: 1.10.1
- Sellia: 0.1.2 (commit: abc123)

**Additional Context:**
Restarting the server fixes the issue temporarily. Happens consistently
after ~1 hour of idle time.
```

### Example 2: Minimal Reproduction

```markdown
### Tunnel subdomain allows invalid characters

**Description:**
The CLI accepts subdomains with invalid characters like @ and !, but
the server then rejects them with unclear error message.

**Minimal Reproduction:**
```bash
./bin/sellia http 8080 --subdomain "test@domain"
# Returns: "Tunnel registered" but tunnel doesn't work

curl http://test@domain.127.0.0.1.nip.io:3000
# Returns: "Bad Request" from server
```

**Expected Behavior:** CLI should reject invalid subdomains with clear error

**Actual Behavior:** CLI accepts but server fails later

**Suggested Fix:** Validate subdomain format in CLI before sending to server
```

## Getting Help

If you're not sure if something is a bug:

1. **Check the docs** - Ensure you're using it correctly
2. **Search issues** - See if others have reported it
3. **Join discussions** - Comment on relevant issues
4. **Ask a question** - Open an issue with the "question" label

## Related Resources

- [Contributing Guidelines](workflow.md)
- [Debugging Guide](../development/debugging.md)
- [Security Disclosure](../security/vulnerability-disclosure.md)
- [Existing Issues](https://github.com/watzon/sellia/issues)

## Next Steps

- [Feature Requests](suggesting-features.md) - Suggest new features
- [Contributing Workflow](workflow.md) - Submit a fix
- [Development Setup](../development/prerequisites.md) - Start contributing
