# WebSocket Issues Troubleshooting

Guide to fixing WebSocket and HMR (Hot Module Replacement) problems.

## Common Problems

### WebSocket Connection Fails

**Symptoms**:
- Error: "WebSocket upgrade failed"
- Error: "502 Bad Gateway"
- HMR not working in development

**Diagnosis**:

1. Check WebSocket upgrade headers:
```bash
curl -I -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://myapp.your-domain.com/socket
```

Expected:
```
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
```

2. Check browser console:
```javascript
// Look for WebSocket errors
// "WebSocket connection to 'ws://...' failed"
```

3. Check server logs:
```bash
tail -f /var/log/sellia/server.log | grep -i websocket
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
}
```

2. **Check local service supports WebSocket**:
```bash
# Test direct connection
wscat -c ws://localhost:3000/socket

# If this fails, issue is with local service, not Sellia
```

3. **Check WebSocket frame forwarding**:
```crystal
// In TunnelClient
@on_websocket do |path, request_id|
  puts "WebSocket connected: #{path} (#{request_id})"
end
```

---

### HMR Not Working in Development

**Symptoms**:
- File changes not reflected in browser
- Error: "WebSocket connection closed"
- Dev server shows disconnected client

**Diagnosis**:

1. Check Vite/Webpack dev server is running:
```bash
# Vite
cd web
npm run dev

# Should see: "Local: http://localhost:5173"
```

2. Check WebSocket connection in browser:
```javascript
// Browser console
// Look for: "[HMR] Connected" or "[HMR] Waiting for update signal..."
```

3. Test WebSocket directly:
```bash
# Test Vite HMR endpoint
wscat -c ws://localhost:5173
```

**Solutions**:

1. **Start Vite dev server**:
```bash
cd web
npm run dev
```

2. **Check Vite configuration**:
```javascript
// vite.config.js
export default {
  server: {
    hmr: {
      protocol: 'ws',
      host: 'localhost',
    },
    ws: {
      port: 5173,
    },
  },
}
```

3. **Configure inspector proxy**:
```crystal
# In Inspector#proxy_to_vite
# Vite HMR WebSocket proxying is NOT supported
# Use direct connection to Vite instead
```

4. **Use production build instead**:
```bash
# Build frontend
cd web
npm run build

# Build Sellia with baked assets
shards build --release

# HMR not needed in production
```

---

### WebSocket Frame Dropping

**Symptoms**:
- WebSocket connects but messages lost
- Intermittent communication
- Frames arrive out of order

**Diagnosis**:

1. Check for buffer overflows:
```bash
# Check message sizes
# Large messages may be dropped
```

2. Check for congestion:
```bash
# Too many concurrent WebSocket connections
netstat -an | grep :3000 | grep ESTABLISHED | wc -l
```

3. Monitor frame loop:
```crystal
// In HTTPIngress#run_websocket_frame_loop
Log.debug { "WebSocket #{request_id}: received frame opcode=#{info.opcode}, size=#{info.size}" }
```

**Solutions**:

1. **Increase buffer size**:
```crystal
// In HTTPIngress
buffer = Bytes.new(16384)  # Increase from 8192
```

2. **Implement backpressure**:
```crystal
// Don't send frames if congestion detected
if pending_ws.congestion?
  // Queue or drop frames
  next
end
```

3. **Use multiple tunnels**:
```bash
# Spread WebSocket connections across tunnels
# One tunnel for HTTP, one for WebSocket
```

---

### WebSocket Timeout Errors

**Symptoms**:
- Error: "WebSocket upgrade timeout"
- Connection closes after 30 seconds
- Intermittent failures

**Diagnosis**:

1. Check timeout settings:
```crystal
// In HTTPIngress
@property request_timeout : Time::Span = 30.seconds
```

2. Check for slow local service:
```bash
# Time WebSocket connection
time curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:3000/socket
```

**Solutions**:

1. **WebSocket timeout settings**:
   - HTTPIngress request_timeout: 30 seconds (default)
   - WSGateway PING_INTERVAL: 30 seconds
   - WSGateway PING_TIMEOUT: 60 seconds
   - These are hardcoded in the server implementation

2. **Optimize local service**:
```bash
# Reduce WebSocket handshake time
# Optimize database queries
# Use connection pooling
```

3. **Check for blocking operations**:
```crystal
// Ensure handshake is non-blocking
// Don't block in WebSocket frame loop
```

---

### WebSocket Close Errors

**Symptoms**:
- Error: "WebSocket closed unexpectedly"
- Error code: 1006 (abnormal closure)
- Connection drops randomly

**Diagnosis**:

1. Check close codes:
```javascript
// Browser console
websocket.onclose = (event) => {
  console.log('Close code:', event.code);
  console.log('Close reason:', event.reason);
};
```

Common codes:
- `1000` - Normal closure
- `1001` - Endpoint going away
- `1006` - Abnormal closure (network issue)
- `1008` - Policy violation
- `1011` - Internal error

2. Check server logs:
```bash
tail -f /var/log/sellia/server.log | grep -i "websocket.*close"
```

3. Test network stability:
```bash
# Ping server
ping -c 100 your-server.com

# Look for packet loss
```

**Solutions**:

1. **Fix network issues**:
```bash
# Use wired connection
# Check router logs
# Contact ISP if issues persist
```

2. **Implement graceful close**:
```crystal
// Send close frame before closing
ws_protocol.close

// Then close connection
pending_ws.close
```

3. **Handle close in client**:
```javascript
websocket.onclose = (event) => {
  if (event.code === 1006) {
    // Abnormal closure - reconnect
    setTimeout(() => reconnect(), 1000);
  }
};
```

4. **Increase ping interval**:
```crystal
// More frequent keep-alive
PING_INTERVAL = 15.seconds  // Reduce from 30s
```

---

### Mixed Content with WebSocket

**Symptoms**:
- Error: "Mixed Content: WebSocket connection from HTTPS page"
- Browser blocks WebSocket

**Diagnosis**:

Check browser console:
```
Mixed Content: The page at 'https://myapp.your-domain.com' 
was loaded over HTTPS, but attempted to connect to 
ws://myapp.your-domain.com/socket (insecure WebSocket)
```

**Solutions**:

1. **Use WSS instead of WS**:
```javascript
// BAD
const ws = new WebSocket('ws://myapp.your-domain.com/socket');

// GOOD
const ws = new WebSocket('wss://myapp.your-domain.com/socket');
```

2. **Let browser choose**:
```javascript
// Use protocol-relative URL
const ws = new WebSocket(`//${window.location.host}/socket`);

// Or use current protocol
const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
const ws = new WebSocket(`${protocol}//${window.location.host}/socket`);
```

3. **Configure reverse proxy for WSS**:

**Caddy** (automatic):
```caddyfile
your-domain.com {
    reverse_proxy localhost:3000
}
```

**Nginx**:
```nginx
location /socket {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    # WSS support
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

## Reverse Proxy Configuration

### Caddy (Recommended)

```caddyfile
your-domain.com {
    # WebSocket support is automatic
    reverse_proxy localhost:3000 {
        # Increase timeouts for long-running connections
        transport http {
            read_timeout 120s
            write_timeout 120s
            dial_timeout 10s
        }
    }
}
```

### Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # WebSocket upgrade
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts for long-running WebSockets
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # For specific WebSocket path
    location /socket {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400;
    }
}
```

---

## Testing

### Test WebSocket Connection

```bash
# Using wscat
wscat -c ws://myapp.your-domain.com/socket

# Using websocat
websocat ws://myapp.your-domain.com/socket

# Send message
echo "hello" | websocat ws://myapp.your-domain.com/socket
```

### Test with Script

```javascript
// test-websocket.js
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:3000/socket');

ws.on('open', () => {
  console.log('Connected');
  ws.send('Hello from test');
});

ws.on('message', (data) => {
  console.log('Received:', data.toString());
  ws.close();
});

ws.on('close', () => {
  console.log('Disconnected');
});

ws.on('error', (error) => {
  console.error('Error:', error.message);
});
```

Run:
```bash
node test-websocket.js
```

### Monitor WebSocket Traffic

```bash
# Using tcpdump
sudo tcpdump -i any -A -s 0 'tcp port 3000 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'

# Or use tshark
tshark -f "tcp port 3000" -V
```

---

## Prevention

### Use Caddy for Automatic WebSocket Support

Caddy automatically handles WebSocket upgrades:
```caddyfile
your-domain.com {
    reverse_proxy localhost:3000
}
```

### Set Appropriate Timeouts

```crystal
// Server
PING_INTERVAL = 30.seconds
PING_TIMEOUT = 60.seconds

// Client
client.request_timeout = 60.seconds
```

### Monitor WebSocket Connections

```bash
# Track active WebSocket connections
watch 'netstat -an | grep :3000 | grep ESTABLISHED | wc -l'
```

### Implement Heartbeat

```javascript
// Client-side heartbeat
setInterval(() => {
  if (ws.readyState === WebSocket.OPEN) {
    ws.ping();
  }
}, 30000); // Every 30 seconds
```

### Use Connection Pooling

For applications with many WebSocket connections:
```bash
# Use multiple tunnels
# Distribute connections across tunnels
```

---

## Common Error Codes

| Code | Name | Meaning | Solution |
|------|------|---------|----------|
| 1000 | Normal | Normal closure | None expected |
| 1001 | Going Away | Server shutting down | Reconnect when server back |
| 1006 | Abnormal | Network issue | Check network, reconnect |
| 1008 | Policy | Violation of policy | Check authentication |
| 1009 | Too Big | Message too large | Reduce message size |
| 1010 | Missing Extension | Required extension missing | Check client configuration |
| 1011 | Internal | Server error | Check server logs |
| 1012 | Service Restart | Server restarting | Reconnect when ready |
