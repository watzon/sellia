# Inspector Class Documentation

The `Inspector` provides a web UI for debugging tunneled HTTP requests in real-time.

## Overview

`Inspector` consists of:
- HTTP server serving React UI
- WebSocket endpoint for real-time updates
- REST API for request history
- Integration with `RequestStore`
- Development mode (Vite proxy) and production mode (baked assets)

## Class Definition

```crystal
class Sellia::CLI::Inspector
  property port : Int32
  property store : RequestStore

  @server : HTTP::Server?
  @running : Bool = false

  def initialize(@port : Int32, @store : RequestStore)
  end
end
```

## Methods

### `start`

```crystal
def start
```

Start the inspector HTTP server.

**Flow**:
```crystal
@running = true

server = HTTP::Server.new do |context|
  handle_request(context)
end

@server = server

begin
  address = server.bind_tcp("127.0.0.1", @port)
  Log.info { "Inspector running at http://#{address}" }
  server.listen
rescue ex : Socket::BindError
  Log.error { "Failed to bind inspector to port #{@port}: #{ex.message}" }
  @running = false
end
```

**Binds to**: 127.0.0.1 (localhost only)

**Default Port**: 4040

---

### `stop`

```crystal
def stop
```

Stop the inspector server.

```crystal
@running = false
@server.try(&.close)
```

---

### `running?`

```crystal
def running? : Bool
```

Check if inspector is running.

**Returns**: `true` if server is listening

## Endpoints

### `/` - Serve UI

Serve React UI (index.html)

**Development Mode**: Proxies to Vite dev server (localhost:5173)

**Production Mode**: Serves baked assets from compiled binary

```crystal
when "/"
  serve_file(context, "/index.html")
```

### `/api/live` - WebSocket Endpoint

WebSocket connection for real-time request updates.

```crystal
when "/api/live"
  handle_websocket(context)
```

**WebSocket Messages**:
```json
{
  "type": "request",
  "request": {
    "id": "req_123",
    "method": "GET",
    "path": "/api/users",
    "statusCode": 200,
    "duration": 45,
    "timestamp": "2024-01-15T10:30:00Z",
    "requestHeaders": {...},
    "requestBody": "...",
    "responseHeaders": {...},
    "responseBody": "...",
    "matchedRoute": "/api/*",
    "matchedTarget": "api:8080"
  }
}
```

### `/api/requests` - Get All Requests

Get all stored requests.

```crystal
when "/api/requests"
  context.response.content_type = "application/json"
  context.response.print(@store.all.to_json)
```

**Response**:
```json
[
  {
    "id": "req_123",
    "method": "GET",
    "path": "/api/users",
    "statusCode": 200,
    "duration": 45,
    "timestamp": "2024-01-15T10:30:00Z",
    "requestHeaders": {"Host": ["myapp.sellia.dev"]},
    "requestBody": null,
    "responseHeaders": {"Content-Type": ["application/json"]},
    "responseBody": "[{\"id\":1}]",
    "matchedRoute": "/api/*",
    "matchedTarget": "api:8080"
  }
]
```

### `/api/requests/clear` - Clear History

Clear all stored requests.

```crystal
when "/api/requests/clear"
  if context.request.method == "POST"
    @store.clear
    context.response.content_type = "application/json"
    context.response.print(%({"status":"ok"}))
  else
    context.response.status_code = 405
    context.response.print("Method not allowed")
  end
```

**Method**: POST only

## WebSocket Implementation

### Connection Handler

```crystal
def handle_websocket(context)
  if context.request.headers["Upgrade"]?.try(&.downcase) == "websocket"
    ws_handler = HTTP::WebSocketHandler.new do |socket, ctx|
      handle_websocket_connection(socket)
    end
    ws_handler.call(context)
  else
    context.response.status_code = 400
    context.response.print("WebSocket connection required")
  end
end
```

### Message Loop

```crystal
def handle_websocket_connection(socket)
  channel = @store.subscribe
  closed = Atomic(Bool).new(false)

  # Send updates to WebSocket client
  spawn do
    loop do
      break if closed.get
      begin
        select
        when request = channel.receive?
          break if request.nil?
          message = {type: "request", request: request}.to_json
          socket.send(message)
        when timeout(1.second)
          next
        end
      rescue Channel::ClosedError
        break
      end
    end
  end

  socket.on_close do
    closed.set(true)
    @store.unsubscribe(channel)
  end

  socket.run
end
```

**Flow**:
1. Subscribe to RequestStore channel
2. Spawn fiber to receive updates
3. Send each request as JSON message
4. On close, unsubscribe from channel

## Asset Serving

### Production Mode (Release Build)

Assets are baked into binary using `baked_file_system`:

```crystal
{% if flag?(:release) %}
  class InspectorAssets
    extend BakedFileSystem
    bake_folder "../../web/dist", __DIR__
  end
{% end %}
```

**Serving**:
```crystal
private def serve_baked_file(context, path)
  file = InspectorAssets.get?(path)

  # SPA fallback
  if file.nil? && path != "/index.html" && !path.starts_with?("/assets/")
    file = InspectorAssets.get?("/index.html")
  end

  if file
    content_type = mime_type_for(path)
    context.response.content_type = content_type

    # Cache static assets
    if path.starts_with?("/assets/")
      context.response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
    end

    context.response.print(file.gets_to_end)
  else
    context.response.status_code = 404
    context.response.print("Not found: #{path}")
  end
end
```

### Development Mode

Proxies to Vite dev server (localhost:5173):

```crystal
private def proxy_to_vite(context, path)
  vite_url = "http://localhost:5173#{path}"

  # WebSocket upgrade not supported for HMR
  if context.request.headers["Upgrade"]?.try(&.downcase) == "websocket"
    context.response.status_code = 502
    context.response.print("WebSocket proxying not supported")
    return
  end

  response = HTTP::Client.get(vite_url)
  context.response.status_code = response.status_code

  # Forward headers
  response.headers.each do |key, values|
    next if key.downcase.in?("transfer-encoding", "connection", "content-length")
    context.response.headers[key] = values.first
  end

  context.response.print(response.body)
end
```

**Vite Not Running**: Returns friendly error page

## MIME Types

```crystal
private def mime_type_for(path) : String
  case path
  when .ends_with?(".html") then "text/html; charset=utf-8"
  when .ends_with?(".js") then "application/javascript; charset=utf-8"
  when .ends_with?(".css") then "text/css; charset=utf-8"
  when .ends_with?(".svg") then "image/svg+xml"
  when .ends_with?(".png") then "image/png"
  when .ends_with?(".json") then "application/json"
  else "application/octet-stream"
  end
end
```

## Usage Example

```crystal
# Create request store
store = RequestStore.new(max_size: 1000)

# Start inspector
inspector = Inspector.new(port: 4000, store: store)
spawn { inspector.start }

# Configure tunnel client to use store
client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  request_store: store
)

# Start client
client.on_connect do |url|
  puts "Tunnel: #{url}"
  puts "Inspector: http://localhost:4000"
end

client.start
```

## Request Storage

### StoredRequest Structure

```crystal
struct StoredRequest
  include JSON::Serializable

  property id : String
  property method : String
  property path : String
  property status_code : Int32
  property duration : Int64
  property timestamp : Time
  property request_headers : Hash(String, Array(String))
  property request_body : String?
  property response_headers : Hash(String, Array(String))
  property response_body : String?
  property matched_route : String?
  property matched_target : String?
end
```

**JSON Field Names** (camelCase in JSON):
- `id`
- `method`
- `path`
- `statusCode` (not `status_code`)
- `duration`
- `timestamp`
- `requestHeaders` (not `request_headers`)
- `requestBody` (not `request_body`)
- `responseHeaders` (not `response_headers`)
- `responseBody` (not `response_body`)
- `matchedRoute` (not `matched_route`)
- `matchedTarget` (not `matched_target`)

### Body Truncation

Bodies are truncated to 100KB for display:

```crystal
max_body_size = 100_000
if request_body_content && request_body_content.size > max_body_size
  request_body_content = request_body_content[0, max_body_size] + "\n... (truncated)"
end
```

## Performance

### Memory

Per stored request: ~10-100KB (depending on body size)

Default max size: 1000 requests

For 1000 avg requests (50KB each): ~50 MB

### CPU

- WebSocket send: ~100μs per request
- JSON serialization: ~50μs per request
- Asset serving: ~1ms per file

### Concurrency

- Each WebSocket connection in separate fiber
- Channel-based pub/sub for updates
- Thread-safe store operations

## Best Practices

### Set Reasonable Max Size

```crystal
# For development: keep all requests
store = RequestStore.new(max_size: 10_000)

# For production: limit memory
store = RequestStore.new(max_size: 1000)
```

### Bind to Localhost Only

```crystal
# GOOD - only accessible from this machine
server.bind_tcp("127.0.0.1", @port)

# BAD - accessible from network
server.bind_tcp("0.0.0.0", @port)
```

### Use in Development Only

Inspector adds overhead:
- Memory for storing requests
- CPU for JSON serialization
- WebSocket connections

**Don't use in production** unless needed for debugging.

## Troubleshooting

### Inspector Not Accessible

**Symptom**: Can't connect to http://localhost:4040

**Causes**:
1. Inspector not started
2. Port already in use
3. Firewall blocking

**Solutions**:
1. Check inspector is running: `inspector.running?`
2. Check port is available: `lsof -i :4040`
3. Try different port: `Inspector.new(port: 4041, store)`

### Vite Dev Server Not Running

**Symptom**: "Vite Dev Server Not Running" page

**Cause**: Vite dev server not started

**Solution**: Start Vite dev server
```bash
cd web
npm run dev
```

Or build for production:
```bash
npm run build
shards build --release
```

### Requests Not Showing

**Symptom**: No requests in inspector

**Causes**:
1. Request store not configured
2. Tunnel client not using store
3. WebSocket not connected

**Solutions**:
1. Create store: `RequestStore.new`
2. Pass to client: `TunnelClient.new(..., request_store: store)`
3. Check browser console for WebSocket errors

### Memory Usage Growing

**Symptom**: Memory increases over time

**Cause**: Store not limiting size

**Solution**: Set max_size:
```crystal
store = RequestStore.new(max_size: 1000)  # Max 1000 requests
```
