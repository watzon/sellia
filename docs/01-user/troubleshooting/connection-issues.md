# Connection Issues Troubleshooting

Guide to diagnosing and fixing connection problems with Sellia tunnels.

## Common Problems

### "Failed to Connect to Server"

**Symptoms**:
- Error: "Connection refused"
- Error: "Connection timeout"
- Client exits immediately

**Diagnosis**:

1. Check server is running:
```bash
# Check if server process is running
ps aux | grep sellia

# Check server port is listening
netstat -an | grep 3000  # Replace with your server port
```

2. Test server connectivity:
```bash
# Test HTTP endpoint
curl http://your-server.com/health

# Expected output:
# {"status":"ok","tunnels":0}
```

3. Check firewall rules:
```bash
# Server - check firewall allows connections
sudo ufw status
sudo firewall-cmd --list-all
```

**Solutions**:

1. **Start the server**:
```bash
sellia server
```

2. **Check server URL**:
```bash
# Wrong
sellia http --server ws://localhost:3000

# Correct (if server is remote)
sellia http --server wss://your-server.com
```

3. **Configure firewall**:
```bash
# UFW (Ubuntu)
sudo ufw allow 3000/tcp

# firewalld (CentOS/RHEL)
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --reload
```

4. **Check reverse proxy** (if using Caddy/Nginx):
```bash
# Caddy
curl http://localhost/health

# Nginx
curl http://localhost:8080/health
```

---

### "Authentication Failed"

**Symptoms**:
- Error: "Authentication failed: Invalid API key"
- Server immediately closes connection

**Diagnosis**:

1. Check if auth is required:
```bash
# Check server config
sellia server --help
```

2. Verify API key:
```bash
# List keys (if using database)
sellia admin api-keys list
```

**Solutions**:

1. **Don't require auth** (development):
```bash
sellia server --no-auth
```

2. **Provide correct API key**:
```bash
sellia http --api-key key_abc123...
```

3. **Create new API key**:
```bash
sellia admin api-keys create --name "My Key"

# Output: Created API key: key_abc123...
```

4. **Set master key** (simple deployment):
```bash
export SELLIA_MASTER_KEY="your-secret-key"
sellia server

# Client
sellia http --api-key "your-secret-key"
```

---

### "Tunnel Client Disconnected"

**Symptoms**:
- Tunnel works initially then stops
- Error: "Tunnel client disconnected"
- Intermittent 502 errors

**Diagnosis**:

1. Check client logs:
```bash
sellia http --verbose
```

2. Check for network instability:
```bash
# Ping server
ping -c 100 your-server.com

# Check for packet loss
# Look for "packet loss" percentage
```

3. Check keep-alive settings:
```bash
# Check ping interval (default 30s)
# Check timeout (default 60s)
```

**Solutions**:

1. **Auto-reconnect is enabled by default**:
   - Linear backoff: 3s, 6s, 9s, ... up to 30s
   - Max attempts: 10 (configurable in code)
   - Client will automatically reconnect if connection drops

2. **Check network stability**:
```bash
# Use wired connection instead of WiFi
# Check router logs for drops
# Contact ISP if issues persist
```

3. **Default timeout settings** (WSGateway):
   - PING_INTERVAL = 30 seconds (server sends ping)
   - PING_TIMEOUT = 60 seconds (server marks client stale)
   - Request timeout = 30 seconds (HTTPIngress)

4. **Check for NAT timeouts**:
```bash
# Some routers kill idle connections after 5 minutes
# Solution: Keep-alive should prevent this
```

---

### "Max Reconnection Attempts Exceeded"

**Symptoms**:
- Error: "Max reconnection attempts exceeded"
- Client gives up trying to reconnect

**Diagnosis**:

1. Check if server is down:
```bash
curl http://your-server.com/health
```

2. Check for IP blocks:
```bash
# Check server logs for ban messages
tail -f /var/log/sellia/server.log
```

**Solutions**:

1. **Fix server issues**:
```bash
# Start/restart server
systemctl restart sellia
```

2. **Wait and retry**:
```bash
# Linear backoff means delays increase by a fixed step
# Just wait a few minutes and try again
```

3. **Increase max attempts**:
```crystal
client.max_reconnect_attempts = 20  # Default is 10
```

---

### Connection Intermittently Drops

**Symptoms**:
- Connection works, drops, reconnects
- Pattern repeats every few minutes

**Diagnosis**:

1. Check for NAT issues:
```bash
# Many routers have 5-minute timeout for idle connections
# Sellia sends ping every 30s to prevent this
```

2. Check for ISP interference:
```bash
# Some ISPs reset connections periodically
# Check with ISP for connection stability
```

3. Check server logs:
```bash
tail -f /var/log/sellia/server.log | grep "timeout"
```

**Solutions**:

1. **Understanding keep-alive**:
   - Server sends ping every 30 seconds (PING_INTERVAL)
   - Server marks client stale after 60 seconds of no activity (PING_TIMEOUT)
   - This prevents NAT timeout issues automatically

2. **Use wired connection**:
```
WiFi is more prone to interference and drops
```

3. **Check router settings**:
```
Disable: SIP ALG, Flood Protection, Port Scan Detection
Enable: Keep-alive, NAT Loopback
```

4. **Use stable network**:
```
Avoid: Public WiFi, cellular data
Prefer: Wired ethernet, stable WiFi
```

---

### WebSocket Connection Fails

**Symptoms**:
- HTTP works but WebSocket fails
- Error: "WebSocket handshake failed"
- HMR not working in development

**Diagnosis**:

1. Check WebSocket upgrade headers:
```bash
# Should see:
# Upgrade: websocket
# Connection: upgrade
```

2. Check reverse proxy configuration:
```bash
# Caddy Caddyfile
your-domain.com {
    reverse_proxy localhost:3000 {
        # WebSocket support is automatic
    }
}
```

3. Test WebSocket directly:
```bash
# Bypass proxy and test directly
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:3000/ws
```

**Solutions**:

1. **Configure reverse proxy for WebSocket**:

**Caddy** (automatic):
```caddyfile
your-domain.com {
    reverse_proxy localhost:3000
}
```

**Nginx**:
```nginx
location / {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400;
}
```

2. **Check firewall allows WebSocket**:
```bash
# Should allow established connections
sudo iptables -L -n | grep ESTABLISHED
```

3. **Increase timeouts**:
```crystal
# In TunnelClient
client.connect_timeout = 10.seconds
client.request_timeout = 60.seconds
```

---

### "Connection Refused" Immediately

**Symptoms**:
- Error occurs instantly (< 1 second)
- No delay before error

**Diagnosis**:

```bash
# This confirms nothing is listening
nc -zv localhost 3000

# Output: Connection refused
```

**Causes**:
1. Server not running
2. Wrong port
3. Server bound to different interface

**Solutions**:

1. **Start server**:
```bash
sellia server --port 3000
```

2. **Check correct port**:
```bash
# Server
sellia server --port 3000

# Client
sellia http --server ws://localhost:3000
```

3. **Check binding address**:
```bash
# Server binds to 127.0.0.1 - localhost only
sellia server --bind 127.0.0.1

# Server binds to 0.0.0.0 - all interfaces
sellia server --bind 0.0.0.0
```

---

### "Connection Timeout"

**Symptoms**:
- Error after 30+ seconds
- Network request hangs

**Diagnosis**:

```bash
# Test TCP connectivity
telnet your-server.com 3000

# Or with nc
nc -zv your-server.com 3000
```

**Causes**:
1. Firewall blocking
2. Server overloaded
3. Network routing issue

**Solutions**:

1. **Check firewall**:
```bash
# Server
sudo ufw allow 3000/tcp

# Client (if outgoing blocked)
sudo ufw allow out 3000/tcp
```

2. **Check server health**:
```bash
# Check CPU/memory
htop

# Check connection count
netstat -an | grep 3000 | wc -l
```

3. **Test from different network**:
```bash
# Try from mobile hotspot
# Try from different location
# If works: ISP or local network issue
```

4. **Check reverse proxy**:
```bash
# If behind proxy, check proxy is running
systemctl status caddy
systemctl status nginx
```

---

## Diagnostic Commands

### Test Server Health

```bash
# Health endpoint
curl http://your-server.com/health

# Expected output
{"status":"ok","tunnels":5}
```

### Test WebSocket

```bash
# Using websocat
websocat ws://your-server.com/ws

# Or with wscat
wscat -c ws://your-server.com/ws
```

### Check Network Path

```bash
# Trace route to server
traceroute your-server.com

# Check DNS
nslookup your-server.com
dig your-server.com

# Check MTU
ping -c 1 -M do -s 1472 your-server.com
```

### Monitor Connection

```bash
# Watch connection count
watch 'netstat -an | grep :3000 | wc -l'

# Monitor with tcpdump
sudo tcpdump -i any -n host your-server.com
```

---

## Prevention

### Use Stable Network

- Prefer wired ethernet over WiFi
- Avoid public WiFi
- Check router logs for drops

### Configure Timeouts Appropriately

```crystal
# Server
PING_INTERVAL = 30.seconds   # Keep-alive frequency
PING_TIMEOUT = 60.seconds    # Time before disconnect

# Client
client.auto_reconnect = true
client.reconnect_delay = 3.seconds
client.max_reconnect_attempts = 10
```

### Monitor Health

```bash
# Use health endpoint in monitoring
curl http://your-server.com/health

# Set up alerting
# Alert if status != "ok"
# Alert if tunnels drop unexpectedly
```

### Use Reverse Proxy

For production, use Caddy or Nginx:
- Handles TLS termination
- Better connection management
- Built-in retry logic

### Log Everything

```bash
# Enable verbose logging
sellia server --log-level debug
sellia http --verbose

# Send to log file
sellia server 2>&1 | tee /var/log/sellia/server.log
```
