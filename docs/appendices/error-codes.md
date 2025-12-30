# Error Codes Reference

Complete list of error messages, their meanings, and how to resolve them.

## Table of Contents

- [Authentication Errors](#authentication-errors)
- [Connection Errors](#connection-errors)
- [Tunnel Errors](#tunnel-errors)
- [Routing Errors](#routing-errors)
- [Inspector Errors](#inspector-errors)
- [Configuration Errors](#configuration-errors)
- [Network Errors](#network-errors)

---

## Authentication Errors

### `Authentication failed: Invalid API key`

**Cause:** The API key provided is invalid or has been revoked.

**Solution:**
1. Verify your API key is correct
2. Check if the key has expired or been revoked
3. Re-authenticate: `sellia auth login`

```bash
# Re-authenticate
sellia auth login
# Enter your new API key
```

---

### `Authentication failed: API key required`

**Cause:** The tunnel server requires an API key, but none was provided.

**Solution:**
1. Set API key via environment variable:
```bash
export SELLIA_API_KEY="your-api-key"
sellia http 3000
```

2. Or save it to config:
```bash
sellia auth login
```

3. Or pass via flag:
```bash
sellia http 3000 --api-key your-key
```

---

## Connection Errors

### `Connection failed: Connection refused`

**Cause:** Cannot reach the tunnel server. Server may be down or network unreachable.

**Solution:**
1. Check your internet connection
2. Verify the server URL is correct
3. Check if the tunnel server is running

```bash
# Test connectivity
curl -I https://sellia.me

# Use custom server if default is down
sellia http 3000 --server https://backup-server.com
```

---

### `Connection failed: Connection timeout`

**Cause:** Connection attempt timed out. Network issues or firewall blocking.

**Solution:**
1. Check network connectivity
2. Verify firewall settings
3. Check if proxy is required

```bash
# Test with curl
curl -v https://sellia.me

# Use with proxy if needed
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
```

---

### `Max reconnection attempts exceeded`

**Cause:** Lost connection and failed to reconnect after maximum attempts.

**Solution:**
1. Check network stability
2. Restart the tunnel
3. Check tunnel server status

```bash
# Restart tunnel
# Press Ctrl+C to stop, then:
sellia http 3000
```

---

## Tunnel Errors

### `Tunnel closed: Subdomain 'xxx' not available`

**Cause:** Requested subdomain is already taken or reserved.

**Solution:**
1. Try a different subdomain
2. Use random subdomain (omit `--subdomain` flag)
3. Check if you own the subdomain: `sellia auth status`

```bash
# Try different subdomain
sellia http 3000 --subdomain myapp2

# Let server assign random subdomain
sellia http 3000
```

---

### `Tunnel closed: Rate limit exceeded`

**Cause:** Too many tunnel creation attempts in short time.

**Solution:**
1. Wait a few minutes before retrying
2. Contact support if limit is too restrictive

---

### `Tunnel closed: Account suspended`

**Cause:** Your account has been suspended.

**Solution:**
1. Check your email for suspension notice
2. Contact support to resolve

---

## Routing Errors

### `No route matched path: /xxx`

**Cause:** Request path doesn't match any configured route and no fallback port.

**Solution:**
1. Check your route configuration
2. Ensure paths start with `/`
3. Add a catch-all route: `/*`

```yaml
# sellia.yml
tunnels:
  app:
    port: 3000  # Fallback
    routes:
      - path: /api
        port: 8080
      - path: /*
        port: 3000  # Catch-all
```

---

### `No route matched for /xxx`

**Cause:** WebSocket request path doesn't match any route.

**Solution:**
1. Add route for WebSocket path
2. Ensure route includes the WebSocket endpoint

```yaml
tunnels:
  app:
    port: 3000
    routes:
      - path: /ws
        port: 8080  # WebSocket server
```

---

## Inspector Errors

### `Failed to bind inspector to port 4040: Address already in use`

**Cause:** Inspector port is already in use by another application.

**Solution:**
1. Use a different port:
```bash
sellia http 3000 --inspector-port 4041
```

2. Or disable inspector:
```bash
sellia http 3000 --no-inspector
```

3. Or find and stop the process using the port:
```bash
# On macOS/Linux
lsof -i :4040
kill -9 <PID>
```

---

### `Vite Dev Server Not Running`

**Cause:** Inspector is trying to proxy to Vite dev server, but it's not running.

**Solution:**
1. Start Vite dev server in development mode:
```bash
cd web
npm run dev
```

2. Or build for production:
```bash
cd web
npm run build
cd ..
shards build --release
```

---

## Configuration Errors

### `Config file not found: /path/to/file`

**Cause:** Specified config file doesn't exist.

**Solution:**
1. Check file path is correct
2. Create config file if needed

```bash
# Create minimal config
cat > sellia.yml << EOF
tunnels:
  web:
    port: 3000
EOF
```

---

### `Warning: Failed to parse /path/to/sellia.yml`

**Cause:** YAML syntax error in config file.

**Solution:**
1. Validate YAML syntax
2. Check indentation (use spaces, not tabs)
3. Verify quotes and special characters

```bash
# Validate YAML
# Use online tool or:
ruby -ryaml -e "YAML.load_file('sellia.yml')"
```

---

### `Error: No tunnels defined in config`

**Cause:** Config file exists but has no tunnel definitions.

**Solution:**
1. Add at least one tunnel to config

```yaml
# sellia.yml
tunnels:
  web:
    port: 3000
```

---

## Network Errors

### `Internal proxy error: Connection refused`

**Cause:** Cannot connect to local service on specified port.

**Solution:**
1. Verify local service is running
2. Check port number is correct
3. Ensure service listens on correct interface

```bash
# Check if port is open
# macOS/Linux
lsof -i :3000

# Start your service
npm start  # or whatever starts your app
```

---

### `WebSocket connection failed`

**Cause:** Cannot establish WebSocket connection to local service.

**Solution:**
1. Verify local WebSocket server is running
2. Check port and path are correct
3. Ensure no firewall blocking

---

### `Failed to connect to local WebSocket service`

**Cause:** WebSocket upgrade failed at local service.

**Solution:**
1. Check local WebSocket server logs
2. Verify endpoint accepts WebSocket upgrades
3. Check route configuration

---

## Getting Help

If you encounter an error not listed here:

1. **Check logs:** Run with `LOG_LEVEL=debug` for more details
```bash
LOG_LEVEL=debug sellia http 3000
```

2. **GitHub Issues:** Search or create an issue at [https://github.com/watzon/sellia](https://github.com/watzon/sellia)

3. **Community:** Ask in community chat or forum

---

## Reporting Bugs

When reporting errors, include:

1. **Error message** (exact text)
2. **Command used** (full command with flags)
3. **Config file** (sanitize sensitive data)
4. **Debug logs** (`LOG_LEVEL=debug`)
5. **Environment:**
   - OS and version
   - Sellia version (`sellia version`)
   - Crystal version (if building from source)

---

## See Also

- [Troubleshooting Guide](../user/troubleshooting/index.md) - Common issues and solutions
- [Getting Started](../user/getting-started/index.md) - Basic setup
- [Configuration Reference](./config-reference.md) - Config file format
