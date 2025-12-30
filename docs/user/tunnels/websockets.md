# WebSocket Support

Sellia provides full WebSocket support through HTTP tunnels, allowing real-time bidirectional communication between clients and your local WebSocket servers.

## How WebSocket Tunnels Work

When a client initiates a WebSocket connection through a Sellia tunnel:

```
Client → Sellia Server → WebSocket Upgrade → Your Local WebSocket Server
```

1. Client sends HTTP request with `Upgrade: websocket` header
2. Sellia forwards the upgrade request to your local server
3. Your server accepts the WebSocket connection
4. Bidirectional communication flows through the tunnel

## Creating WebSocket Tunnels

### Basic WebSocket Tunnel

Create a tunnel to your WebSocket server just like any HTTP tunnel:

```bash
sellia http 8080 --subdomain ws-app
```

Your WebSocket server is now accessible at the tunnel URL (format depends on server configuration):
```
wss://ws-app.your-domain.com  (if server has --https)
ws://ws-app.your-domain.com:3000  (otherwise)
```

### Example: Node.js WebSocket Server

```javascript
// ws-server.js
const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
  console.log('Client connected');

  ws.on('message', (message) => {
    console.log('Received:', message.toString());
    ws.send(`Echo: ${message}`);
  });

  ws.on('close', () => {
    console.log('Client disconnected');
  });
});

console.log('WebSocket server running on port 8080');
```

Start the server:

```bash
node ws-server.js
```

Create the tunnel:

```bash
sellia http 8080 --subdomain ws-app
```

### Example: Python WebSocket Server

```python
# ws-server.py
import asyncio
import websockets

async def echo(websocket):
    print("Client connected")
    try:
        async for message in websocket:
            print(f"Received: {message}")
            await websocket.send(f"Echo: {message}")
    finally:
        print("Client disconnected")

async def main():
    async with websockets.serve(echo, "localhost", 8080):
        print("WebSocket server running on port 8080")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
```

Start the server:

```bash
python ws-server.py
```

Create the tunnel:

```bash
sellia http 8080 --subdomain ws-app
```

## Connecting to WebSocket Tunnels

### JavaScript Client

```javascript
const ws = new WebSocket('wss://ws-app.sellia.me');

ws.onopen = () => {
  console.log('Connected to WebSocket server');
  ws.send('Hello, Server!');
};

ws.onmessage = (event) => {
  console.log('Received:', event.data);
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};

ws.onclose = () => {
  console.log('WebSocket connection closed');
};
```

### Python Client

```python
import asyncio
import websockets

async def test_websocket():
    uri = "wss://ws-app.sellia.me"
    async with websockets.connect(uri) as websocket:
        print("Connected to WebSocket server")

        await websocket.send("Hello, Server!")
        response = await websocket.recv()
        print(f"Received: {response}")

asyncio.run(test_websocket())
```

### Browser Client

```html
<!DOCTYPE html>
<html>
<head>
    <title>WebSocket Test</title>
</head>
<body>
    <h1>WebSocket Test</h1>
    <button onclick="connect()">Connect</button>
    <button onclick="sendMessage()">Send Message</button>
    <div id="output"></div>

    <script>
        let ws;

        function connect() {
            ws = new WebSocket('wss://ws-app.sellia.me');

            ws.onopen = () => {
                log('Connected to WebSocket server');
            };

            ws.onmessage = (event) => {
                log(`Received: ${event.data}`);
            };

            ws.onerror = (error) => {
                log(`Error: ${error}`);
            };

            ws.onclose = () => {
                log('WebSocket connection closed');
            };
        }

        function sendMessage() {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send('Hello, Server!');
            }
        }

        function log(message) {
            const output = document.getElementById('output');
            output.innerHTML += `<p>${message}</p>`;
        }
    </script>
</body>
</html>
```

## WebSocket Features

### Automatic Upgrade Handling

Sellia automatically handles the WebSocket upgrade protocol:

- Properly forwards `Upgrade: websocket` headers
- Maintains the `Connection: Upgrade` header
- Passes through `Sec-WebSocket-Key` and other handshake headers
- Supports WebSocket subprotocols

### Full-Duplex Communication

Both client and server can send messages at any time:

```javascript
// Server can push messages anytime
setInterval(() => {
  ws.send(`Server time: ${new Date().toISOString()}`);
}, 1000);
```

### Connection Persistence

WebSocket connections remain open as long as:
- The client maintains the connection
- Your local server is running
- The Sellia tunnel is active

If the connection drops, the client should reconnect:

```javascript
let reconnectAttempts = 0;
const maxReconnectAttempts = 5;

function connect() {
  ws = new WebSocket('wss://ws-app.sellia.me');

  ws.onclose = () => {
    if (reconnectAttempts < maxReconnectAttempts) {
      reconnectAttempts++;
      setTimeout(() => connect(), 1000 * reconnectAttempts);
    }
  };

  ws.onopen = () => {
    reconnectAttempts = 0;
  };
}
```

## Use Cases

### 1. Real-Time Chat

```bash
# Start chat server
node chat-server.js

# Create tunnel
sellia http 3000 --subdomain chat-app
```

Now users can connect via WebSocket to your local chat server from anywhere.

### 2. Live Collaboration

```bash
# Start collaborative editing server
node collab-server.js

# Create tunnel
sellia http 4000 --subdomain collab-edit
```

Multiple users can collaborate in real-time through the tunnel.

### 3. Live Data Streaming

```bash
# Start data streaming server
python stream-server.py

# Create tunnel
sellia http 5000 --subdomain live-data
```

Stream real-time data (sensor readings, stock prices, etc.) to clients.

### 4. Online Gaming

```bash
# Start game server
node game-server.js

# Create tunnel
sellia http 8080 --subdomain multiplayer-game
```

Enable multiplayer gameplay with WebSocket-based game server.

### 5. Real-Time Notifications

```bash
# Start notification server
node notify-server.js

# Create tunnel
sellia http 6000 --subdomain push-notifications
```

Push real-time notifications to connected clients.

## WebSocket Inspector

The Sellia inspector can monitor WebSocket connections:

```bash
sellia http 8080 --open --server https://sellia.me
```

View at `http://localhost:4040`:
- See WebSocket upgrade requests
- Monitor connection lifecycle
- View message count and timing

### Monitoring WebSocket Messages

While Sellia shows connection details, actual WebSocket message content isn't logged (to avoid overhead). Use your server's logging for message debugging.

## Configuration Options

### Subprotocols

Specify WebSocket subprotocols if needed:

```javascript
const ws = new WebSocket('wss://ws-app.sellia.me', ['chat', 'superchat']);
```

Your server will receive the protocol in the handshake:

```javascript
wss.on('connection', (ws, request) => {
  const protocol = request.headers['sec-websocket-protocol'];
  console.log('Subprotocol:', protocol);
});
```

### Custom Headers

WebSocket doesn't support custom headers in the initial request, but you can send them in the first message:

```javascript
ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'auth',
    token: 'your-token'
  }));
};
```

## Performance Considerations

### Connection Limits

- Each WebSocket connection uses a persistent connection
- Monitor active connections in the inspector
- Consider connection pooling for many clients

### Bandwidth Usage

WebSocket tunnels use minimal overhead:
- No HTTP headers per message
- Binary message framing is efficient
- Compression can be enabled at application level

### Latency

WebSocket tunnel latency is typically:
- Same as HTTP: 5-200ms depending on location
- No additional overhead for established connections
- Suitable for real-time applications

## Troubleshooting

### Connection Not Upgrading

If WebSocket connections don't upgrade:

1. Check your server logs for errors
2. Verify the tunnel is running:
   ```bash
   sellia http 8080 --open
   ```
3. Inspect the upgrade request in the inspector
4. Ensure no intermediate proxy blocks WebSocket

### Frequent Disconnections

If connections drop frequently:

1. Check your internet connection stability
2. Verify server uptime and logs
3. Implement client-side reconnection logic
4. Check for rate limiting

### Messages Not Arriving

If messages don't reach their destination:

1. Verify both ends are connected
2. Check server logs for errors
3. Ensure message format is correct
4. Test with a simple echo server first

### High Latency

If WebSocket latency is high:

1. Use a geographically closer server
2. Check your network speed
3. Monitor server performance
4. Consider message batching if appropriate

## Best Practices

### 1. Implement Heartbeats

Keep connections alive and detect dead connections:

```javascript
// Server
const heartbeatInterval = setInterval(() => {
  ws.isAlive = false;
  ws.ping();
}, 30000);

ws.on('pong', () => {
  ws.isAlive = true;
});

// Client
setInterval(() => {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'ping' }));
  }
}, 30000);
```

### 2. Handle Reconnection

Always implement reconnection logic:

```javascript
let ws;
const connect = () => {
  ws = new WebSocket('wss://ws-app.sellia.me');
  ws.onclose = () => setTimeout(connect, 1000);
};
connect();
```

### 3. Use Message Queues

Buffer messages when disconnected:

```javascript
const messageQueue = [];

function sendOrQueue(message) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(message);
  } else {
    messageQueue.push(message);
  }
}

ws.onopen = () => {
  messageQueue.forEach(msg => ws.send(msg));
  messageQueue.length = 0;
};
```

### 4. Monitor Connections

Use the inspector to monitor connection health:

```bash
sellia http 8080 --open
```

### 5. Graceful Shutdown

Handle connection closure properly:

```javascript
window.addEventListener('beforeunload', () => {
  if (ws) {
    ws.close(1000, 'Page closing');
  }
});
```

## Security Considerations

### Authentication

Implement authentication after connection:

```javascript
ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'auth',
    token: getUserToken()
  }));
};

// Server
ws.on('message', (data) => {
  const msg = JSON.parse(data);
  if (msg.type === 'auth') {
    if (validateToken(msg.token)) {
      ws.authenticated = true;
    } else {
      ws.close(4001, 'Authentication failed');
    }
  }
});
```

### Origin Validation

Validate the `Origin` header on the server:

```javascript
const allowedOrigins = ['https://yourdomain.com'];

wss.on('connection', (ws, request) => {
  const origin = request.headers['origin'];
  if (!allowedOrigins.includes(origin)) {
    ws.close(4003, 'Origin not allowed');
    return;
  }
  // ... rest of connection logic
});
```

### Rate Limiting

Implement message rate limiting to prevent abuse:

```javascript
const rateLimiter = new Map();

wss.on('connection', (ws) => {
  const clientId = generateId();
  rateLimiter.set(clientId, { count: 0, lastReset: Date.now() });

  ws.on('message', () => {
    const client = rateLimiter.get(clientId);
    if (Date.now() - client.lastReset > 60000) {
      client.count = 0;
      client.lastReset = Date.now();
    }
    client.count++;

    if (client.count > 100) {
      ws.close(4002, 'Rate limit exceeded');
      return;
    }
    // ... process message
  });
});
```

## Next Steps

- [HTTP Tunnels](./http-tunnels.md) - Basic tunnel usage
- [Basic Authentication](./basic-auth.md) - Secure your tunnels
- [Request Inspector](../inspector/live-monitoring.md) - Monitor connections
- [Advanced Configuration](../configuration/config-file.md) - Multiple tunnels

## Examples

### Complete Example: Real-Time Dashboard

Server:

```javascript
const WebSocket = require('ws');
const express = require('express');
const http = require('http');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Serve static files
app.use(express.static('public'));

// Broadcast to all clients
const broadcast = (data) => {
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(data));
    }
  });
};

// Generate random metrics
setInterval(() => {
  broadcast({
    type: 'metrics',
    cpu: Math.random() * 100,
    memory: Math.random() * 100,
    timestamp: Date.now()
  });
}, 1000);

server.listen(3000, () => {
  console.log('Server running on port 3000');
});
```

Client (`public/index.html`):

```html
<!DOCTYPE html>
<html>
<head>
    <title>Real-Time Dashboard</title>
</head>
<body>
    <h1>Live Metrics</h1>
    <div>
        <p>CPU: <span id="cpu">0</span>%</p>
        <p>Memory: <span id="memory">0</span>%</p>
    </div>

    <script>
        const ws = new WebSocket(`wss://metrics.${window.location.hostname}`);

        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === 'metrics') {
                document.getElementById('cpu').textContent = data.cpu.toFixed(2);
                document.getElementById('memory').textContent = data.memory.toFixed(2);
            }
        };
    </script>
</body>
</html>
```

Create tunnel:

```bash
sellia http 3000 --subdomain metrics --server https://sellia.me
```

Now you have a real-time dashboard accessible from anywhere!
