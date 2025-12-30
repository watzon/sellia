# Client Connection and Request Flow

This document describes how the Sellia client establishes connections and proxies incoming requests to local services.

## Overview

The Sellia client (`TunnelClient`) runs on the user's machine, establishes a WebSocket connection to the Sellia server, and forwards incoming HTTP/WebSocket requests to local services.

## Connection Lifecycle

### 1. Initialization

```crystal
client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  api_key: "key_...",
  subdomain: "myapp",      # optional
  auth: "user:pass"        # optional basic auth
)
```

Configuration includes:
- **server_url**: WebSocket server URL
- **local_port**: Default local service port
- **api_key**: Optional authentication key
- **subdomain**: Optional custom subdomain
- **auth**: Optional basic auth for tunnel

### 2. WebSocket Connection

```
Client                      Server
  |                           |
  |--- WebSocket Connect ---> |
  |                           |
  |<----- Connected ----------|
```

The client:
1. Parses the server URL to extract host and port
2. Creates a WebSocket connection to `/ws`
3. Sets up message handlers
4. Spawns a fiber to run the socket

### 3. Authentication Flow

```
Client                      Server
  |                           |
  |--- Auth (api_key) ------> |
  |                           |
  |<---- AuthOk --------------|
  |     (account_id, limits)  |
```

If auth is disabled, client skips to `TunnelOpen`.

### 4. Tunnel Opening

```
Client                      Server
  |                           |
  |-- TunnelOpen -----------> |
  |   (subdomain, auth)       |
  |                           |
  |<--- TunnelReady ----------|
  |     (tunnel_id, url)      |
```

The client:
1. Sends `TunnelOpen` with desired configuration
2. Receives `TunnelReady` with tunnel details
3. Stores `tunnel_id` and `public_url`
4. Triggers `on_connect` callback

If the subdomain is unavailable:
```
Client                      Server
  |                           |
  |-- TunnelOpen -----------> |
  |   (subdomain: "taken")    |
  |                           |
  |<--- TunnelClose ----------|
  |     (reason: "not available") |
```

The client will disable auto-reconnect and stop if the tunnel was closed due to subdomain conflict.

### 5. Keep-Alive

```
Client                      Server
  |                           |
  |<---- Ping ----------------|
  |                           |
  |--- Pong ----------------->|
  |                           |
  |      (every 30s)          |
```

- Server sends `Ping` every 30 seconds
- Client responds with `Pong`
- If no activity for 60 seconds, server closes connection

### 6. Reconnection

```
Client                      Server
  |                           |
  |--- Disconnection -------->|
  |                           |
  | [wait: 3s * attempts]     |
  |                           |
  |--- Reconnect ------------>|
  |                           |
```

On disconnect:
1. Clear all in-flight requests
2. Close all active WebSocket connections
3. Trigger `on_disconnect` callback
4. Wait with linear backoff (3s × attempt number)
5. Attempt reconnection up to 10 times

## HTTP Request Flow

### Request Reception

```
External User               Server                    Client                   Local Service
     |                         |                          |                          |
     |-- HTTP Request ------>  |                          |                          |
     |  (myapp.sellia.dev)     |                          |                          |
     |                         |                          |                          |
     |                         |-- RequestStart --------> |                          |
     |                         |   (method, path,         |                          |
     |                         |    headers)              |                          |
     |                         |                          |                          |
     |                         |-- RequestBody ---------> |                          |
     |                         |   (chunk, final=false)  |                          |
     |                         |                          |                          |
     |                         |-- RequestBody ---------> |                          |
     |                         |   (chunk, final=true)   |                          |
     |                         |                          |                          |
     |                         |                          |-- [Router] ------------->|
     |                         |                          |  (match route)           |
     |                         |                          |                          |
     |                         |                          |-- HTTP Request -------->|
     |                         |                          |  (filtered headers)      |
     |                         |                          |                          |
     |                         |                          |<-- HTTP Response --------|
     |                         |                          |  (status, headers, body) |
     |                         |                          |                          |
     |                         |<-- ResponseStart --------|                          |
     |                         |   (status, headers)      |                          |
     |                         |                          |                          |
     |                         |<-- ResponseBody ---------|                          |
     |                         |   (chunk)                |                          |
     |                         |                          |                          |
     |                         |<-- ResponseBody ---------|                          |
     |                         |   (chunk)                |                          |
     |                         |                          |                          |
     |                         |<-- ResponseEnd ----------|                          |
     |                         |                          |                          |
     |<-- HTTP Response -------|                          |                          |
     |  (reassembled body)     |                          |                          |
```

### Step-by-Step

1. **Server receives request** from external user to `myapp.sellia.dev`

2. **Server sends `RequestStart`** with:
   - `request_id`: Unique identifier
   - `tunnel_id`: Tunnel identifier
   - `method`: HTTP method
   - `path`: Full path with query string
   - `headers`: All HTTP headers (multi-value)

3. **Client stores request metadata**:
   ```crystal
   @pending_requests[request_id] = message
   @request_bodies[request_id] = IO::Memory.new
   @request_start_times[request_id] = Time.monotonic
   ```

4. **Server sends `RequestBody` chunks**:
   - Multiple chunks for large bodies
   - `final=true` on last chunk

5. **Client buffers body chunks**:
   ```crystal
   @request_bodies[request_id].write(message.chunk)
   ```

6. **On final chunk, client spawns fiber** to forward request:
   ```crystal
   spawn { forward_request(request_id) }
   ```

7. **Router matches path** to route configuration:
   ```crystal
   match_result = @router.match(path)

   # Returns target host:port or nil
   # Examples:
   # "/api/*" -> api:8080
   # "/socket" -> ws:3000 (fallback)
   ```

8. **LocalProxy forwards to local service**:
   - Filters hop-by-hop headers
   - Opens HTTP connection to target
   - Streams request body
   - Reads response

9. **Client sends response back to server**:
   - `ResponseStart`: Status code and headers
   - `ResponseBody`: Body chunks (8KB each)
   - `ResponseEnd`: Signals completion

10. **Server reassembles and responds** to external user

### Error Handling

If local service is unavailable:
```
Client -> ResponseStart (502)
Client -> ResponseBody ("Local service unavailable")
Client -> ResponseEnd
```

If no route matches:
```
Client -> ResponseStart (502)
Client -> ResponseBody ("No route matched path: /path")
Client -> ResponseEnd
```

## WebSocket Request Flow

### WebSocket Upgrade

```
External User               Server                    Client                   Local Service
     |                         |                          |                          |
     |-- WS Upgrade --------> |                          |                          |
     |  (myapp.sellia.dev)     |                          |                          |
     |                         |                          |                          |
     |                         |-- WebSocketUpgrade ----> |                          |
     |                         |   (path, headers)        |                          |
     |                         |                          |                          |
     |                         |                          |-- [Router] ------------->|
     |                         |                          |                          |
     |                         |                          |-- WS Connect --------->|
     |                         |                          |  (to local service)     |
     |                         |                          |                          |
     |                         |                          |<-- Connected ------------|
     |                         |                          |                          |
     |                         |<-- WebSocketUpgradeOk ---|                          |
     |                         |   (headers)              |                          |
     |                         |                          |                          |
     |<-- Switching Protocols -|                          |                          |
     |  (101 status)           |                          |                          |
```

### Frame Forwarding (Bidirectional)

```
External User    Server    Client    Local Service
    |              |          |            |
    |-- Frame ---> |          |            |
    |  (text)      |          |            |
    |              |          |            |
    |              |-- Frame >|            |
    |              |          |            |
    |              |          |-- Frame ->|
    |              |          |            |
    |              |          |<- Frame --|
    |              |          |            |
    |              |<- Frame --|            |
    |              |          |            |
    |<- Frame -----|          |            |
```

### Step-by-Step

1. **Server receives WebSocket upgrade** request

2. **Server sends `WebSocketUpgrade`** with:
   - `request_id`: Unique identifier
   - `path`: WebSocket path
   - `headers`: All headers including `Sec-WebSocket-*`

3. **Client routes to local service** via router

4. **WebSocketProxy connects** to local service:
   ```crystal
   ws_proxy = WebSocketProxy.new(request_id, target_host, target_port)
   response_headers = ws_proxy.connect(path, headers)
   ```

5. **On success, client sends `WebSocketUpgradeOk`**

6. **Server completes handshake** with external user

7. **Frame forwarding begins**:
   - External → Server → Client → Local Service
   - Local Service → Client → Server → External

8. **On close**:
   ```
   WebSocketClose (bidirectional)
   ```

### WebSocket Error Handling

If local service rejects WebSocket:
```
Client -> WebSocketUpgradeError (502, "Failed to connect")
Server -> 502 response to external user
```

If no route matches:
```
Client -> WebSocketUpgradeError (502, "No route matched path: /socket")
```

## Inspector Integration

### Request Storage

If `RequestStore` is configured, the client stores:

```crystal
StoredRequest.new(
  id: request_id,
  method: "GET",
  path: "/api/users",
  status_code: 200,
  duration: 45_i64,  # milliseconds
  timestamp: Time.utc,
  request_headers: {...},
  request_body: "...",      # truncated to 100KB
  response_headers: {...},
  response_body: "...",     # truncated to 100KB
  matched_route: "/api/*",
  matched_target: "api:8080"
)
```

The inspector UI:
- Subscribes to `RequestStore` via WebSocket
- Receives real-time request updates
- Displays request/response details

## Routing

### Route Configuration

```crystal
routes = [
  RouteConfig.new(path: "/api/*", host: "api", port: 8080),
  RouteConfig.new(path: "/socket", host: nil, port: 3000),  # uses default host
  RouteConfig.new(path: "/admin/*", host: "admin", port: 8000)
]

client = TunnelClient.new(..., routes: routes)
```

### Route Matching

The router matches paths in order (first match wins):

```crystal
def match(path : String) : MatchResult?
  @routes.each do |route|
    if pattern_matches?(route.path, path)
      return MatchResult.new(target, route.path)
    end
  end

  # Try fallback port if configured
  if port = @fallback_port
    return MatchResult.new(Target.new(@default_host, port), "(fallback)")
  end

  nil  # No match
end
```

Pattern matching:
- Exact match: `/socket` matches only `/socket`
- Glob match: `/api/*` matches `/api/users`, `/api/posts/123`, etc.

### Example Routes

```
GET /api/users     -> api:8080  (matches /api/*)
GET /socket        -> localhost:3000  (fallback)
GET /admin/dashboard -> admin:8000  (matches /admin/*)
GET /other         -> 502 No route matched
```

## Performance Considerations

### Concurrency

- Each request spawns a fiber for forwarding
- Multiple requests handled in parallel
- Mutex protects WebSocket writes (no concurrent sends)

### Memory

- Request bodies buffered in memory
- Chunks limited to 8KB
- Inspector truncates bodies to 100KB

### Timeouts

- Local proxy: 5s connect timeout, 30s read timeout
- Server request timeout: 30s (configurable)
- WebSocket frame loop: No timeout (relies on connection close)

## Error Recovery

### Local Service Restart

If local service restarts:
1. In-flight requests fail with 502/504
2. New requests succeed once service is back
3. WebSocket connections close and reconnect

### Network Interruption

1. WebSocket connection closes
2. Client attempts reconnection with backoff
3. Tunnel reopens after reconnection
4. Existing tunnels receive new `tunnel_id`

### Subdomain Conflicts

If subdomain is taken:
1. Server sends `TunnelClose` with "not available"
2. Client disables auto-reconnect
3. User must choose different subdomain
