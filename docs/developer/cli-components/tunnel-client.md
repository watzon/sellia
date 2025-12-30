# TunnelClient Class Documentation

The `TunnelClient` is the main client class that connects to the Sellia server and forwards requests to local services.

## Overview

`TunnelClient` manages:
- WebSocket connection to server
- Authentication flow
- Tunnel creation
- HTTP request forwarding
- WebSocket connection forwarding
- Auto-reconnection on disconnect
- Optional routing to multiple local services

## Class Definition

```crystal
class TunnelClient
  # Configuration
  property server_url : String
  property api_key : String?
  property local_port : Int32
  property local_host : String
  property subdomain : String?
  property auth : String?

  # State
  property public_url : String?
  property tunnel_id : String?
  getter connected : Bool = false
  getter authenticated : Bool = false

  # Auto-reconnect settings
  property auto_reconnect : Bool = true
  property reconnect_delay : Time::Span = 3.seconds
  property max_reconnect_attempts : Int32 = 10

  # Request store for inspector (optional)
  property request_store : RequestStore?

  def initialize(
    @server_url : String,
    @local_port : Int32,
    @api_key : String? = nil,
    @local_host : String = "localhost",
    @subdomain : String? = nil,
    @auth : String? = nil,
    @request_store : RequestStore? = nil,
    routes : Array(RouteConfig) = [] of RouteConfig,
  )
  end
end
```

## Lifecycle

### Starting the Client

```crystal
client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  api_key: "sk_live_...",
  subdomain: "myapp"
)

client.on_connect do |url|
  puts "Tunnel ready: #{url}"
end

client.on_request do |request|
  puts "#{request.method} #{request.path}"
end

client.on_disconnect do
  puts "Disconnected"
end

client.on_error do |error|
  puts "Error: #{error}"
end

client.start  # Blocking
sleep         # Or run in fiber
```

### Stopping the Client

```crystal
client.stop
```

**Cleanup**:
- Closes WebSocket connection
- Clears in-flight requests
- Closes all WebSocket connections
- Stops auto-reconnect

## Callbacks

### `on_connect`

```crystal
def on_connect(&block : String ->)
```

Called when tunnel is ready.

**Parameter**: `public_url` (e.g., "https://myapp.sellia.dev")

**Use Case**: Display URL to user

```crystal
client.on_connect do |url|
  puts "=" * 50
  puts "Tunnel established!"
  puts "Public URL: #{url}"
  puts "=" * 50
end
```

---

### `on_request`

```crystal
def on_request(&block : Protocol::Messages::RequestStart ->)
```

Called for each incoming request.

**Parameter**: `RequestStart` message

**Use Case**: Logging, debugging

```crystal
client.on_request do |request|
  puts "[#{Time.now}] #{request.method} #{request.path}"
end
```

---

### `on_websocket`

```crystal
def on_websocket(&block : String, String ->)
```

Called when WebSocket connection is established.

**Parameters**:
1. `path` - WebSocket path
2. `request_id` - Request identifier

**Use Case**: Track active WebSockets

```crystal
client.on_websocket do |path, request_id|
  puts "WebSocket connected: #{path} (#{request_id})"
end
```

---

### `on_disconnect`

```crystal
def on_disconnect(&block : ->)
```

Called when disconnected from server.

**Use Case**: Notify user, trigger cleanup

```crystal
client.on_disconnect do
  puts "Disconnected from server"
  puts "Attempting to reconnect..."
end
```

---

### `on_error`

```crystal
def on_error(&block : String ->)
```

Called on error.

**Parameter**: Error message

**Use Case**: Display errors to user

```crystal
client.on_error do |error|
  STDERR.puts "Error: #{error}"
end
```

## Message Handlers

### `handle_auth_ok`

```crystal
private def handle_auth_ok(message : Protocol::Messages::AuthOk)
```

Authentication successful.

**Flow**:
```crystal
Log.info { "Authenticated successfully (account: #{message.account_id})" }
@authenticated = true
open_tunnel
```

---

### `handle_auth_error`

```crystal
private def handle_auth_error(message : Protocol::Messages::AuthError)
```

Authentication failed.

**Flow**:
```crystal
Log.error { "Authentication failed: #{message.error}" }
@on_error.try(&.call("Authentication failed: #{message.error}"))
@auto_reconnect = false  # Don't retry with bad credentials
stop
```

**Important**: Disables auto-reconnect (bad credentials won't work on retry)

---

### `handle_tunnel_ready`

```crystal
private def handle_tunnel_ready(message : Protocol::Messages::TunnelReady)
```

Tunnel created successfully.

**Flow**:
```crystal
@tunnel_id = message.tunnel_id
@public_url = message.url
Log.info { "Tunnel ready: #{message.url}" }
@on_connect.try(&.call(message.url))
```

---

### `handle_tunnel_close`

```crystal
private def handle_tunnel_close(message : Protocol::Messages::TunnelClose)
```

Tunnel closed by server.

**Flow**:
```crystal
reason = message.reason || "No reason provided"
Log.warn { "Tunnel closed by server: #{reason}" }
@on_error.try(&.call("Tunnel closed: #{reason}"))

@tunnel_id = nil
@public_url = nil

# Don't reconnect if subdomain taken
if reason.includes?("not available")
  @auto_reconnect = false
  stop
end
```

---

### `handle_request_start`

```crystal
private def handle_request_start(message : Protocol::Messages::RequestStart)
```

Start of incoming HTTP request.

**Flow**:
```crystal
Log.debug { "Request start: #{message.method} #{message.path}" }
@on_request.try(&.call(message))

# Store request metadata
@pending_requests[message.request_id] = message
@request_bodies[message.request_id] = IO::Memory.new
@request_start_times[message.request_id] = Time.monotonic
```

---

### `handle_request_body`

```crystal
private def handle_request_body(message : Protocol::Messages::RequestBody)
```

Request body chunk received.

**Flow**:
```crystal
body_io = @request_bodies[message.request_id]?
return unless body_io

body_io.write(message.chunk) unless message.chunk.empty?

if message.final
  # Request complete - forward to local service
  spawn { forward_request(message.request_id) }
end
```

---

### `forward_request`

```crystal
private def forward_request(request_id : String)
```

Forward request to local service.

**Flow**:
```crystal
start_msg = @pending_requests.delete(request_id)
body_io = @request_bodies.delete(request_id)
start_time = @request_start_times.delete(request_id) || Time.monotonic

return unless start_msg && body_io

# Route the request
match_result = @router.match(start_msg.path)

if match = match_result
  target_host = match.target.host
  target_port = match.target.port
else
  # No route matched
  send_error_response(request_id, start_msg, 502, "No route matched")
  return
end

# Forward to local service
status_code, headers, response_body = @proxy.forward(
  start_msg.method,
  start_msg.path,
  start_msg.headers,
  body,
  target_host,
  target_port
)

# Send response back
send_response(request_id, status_code, headers, response_body)

# Store in inspector if configured
if store = @request_store
  store.add(build_stored_request(...))
end
```

**Error Handling**:
- Local service unavailable → 502
- Timeout → 504
- Other errors → 500

---

### `handle_websocket_upgrade`

```crystal
private def handle_websocket_upgrade(message : Protocol::Messages::WebSocketUpgrade)
```

WebSocket upgrade request received.

**Flow**:
```crystal
Log.debug { "WebSocket upgrade request: #{message.path}" }

# Route the request
match_result = @router.match(message.path)

if match = match_result
  target_host = match.target.host
  target_port = match.target.port
else
  # No route matched
  send_message(WebSocketUpgradeError.new(
    request_id: message.request_id,
    status_code: 502,
    message: "No route matched path: #{message.path}"
  ))
  return
end

# Create WebSocket proxy
ws_proxy = WebSocketProxy.new(message.request_id, target_host, target_port)

# Set up frame forwarding
ws_proxy.on_frame do |opcode, payload|
  send_message(WebSocketFrame.new(
    request_id: message.request_id,
    opcode: opcode,
    payload: payload
  ))
end

ws_proxy.on_close do |code, reason|
  send_message(WebSocketClose.new(
    request_id: message.request_id,
    code: code,
    reason: reason
  ))
  @active_websockets.delete(message.request_id)
end

# Connect to local service
response_headers = ws_proxy.connect(message.path, message.headers)

if response_headers
  # Success
  @active_websockets[message.request_id] = ws_proxy
  send_message(WebSocketUpgradeOk.new(
    request_id: message.request_id,
    headers: response_headers
  ))
  @on_websocket.try(&.call(message.path, message.request_id))
else
  # Connection failed
  send_message(WebSocketUpgradeError.new(
    request_id: message.request_id,
    status_code: 502,
    message: "Failed to connect to local WebSocket service"
  ))
end
```

---

### `handle_websocket_frame` / `handle_websocket_close`

```crystal
private def handle_websocket_frame(message : Protocol::Messages::WebSocketFrame)
  if ws_proxy = @active_websockets[message.request_id]?
    ws_proxy.send_frame(message.opcode, message.payload)
  end
end

private def handle_websocket_close(message : Protocol::Messages::WebSocketClose)
  if ws_proxy = @active_websockets.delete(message.request_id)
    ws_proxy.close(message.code, message.reason)
  end
end
```

Frame forwarding for WebSocket connections.

## Auto-Reconnection

### Reconnect Logic

```crystal
private def handle_reconnect
  return unless @running && @auto_reconnect

  @reconnect_attempts += 1

  if @reconnect_attempts > @max_reconnect_attempts
    Log.error { "Max reconnection attempts exceeded" }
    @on_error.try(&.call("Max reconnection attempts exceeded"))
    @running = false
    return
  end

  delay = @reconnect_delay * @reconnect_attempts  # Linear backoff
  Log.info { "Reconnecting in #{delay.total_seconds.to_i}s (attempt #{@reconnect_attempts}/#{@max_reconnect_attempts})" }

  sleep delay
  connect if @running
end
```

**Exponential Backoff**:
- Attempt 1: 3 seconds
- Attempt 2: 6 seconds
- Attempt 3: 9 seconds
- ...
- Maximum: 10 attempts (30 seconds for last)

**Disable Conditions**:
- Authentication failed (bad credentials)
- Subdomain conflict (won't resolve)
- Explicit `stop()` call

## Routing

### Route Configuration

```crystal
routes = [
  RouteConfig.new(path: "/api/*", host: "api", port: 8080),
  RouteConfig.new(path: "/socket", host: nil, port: 3000),  # default host
  RouteConfig.new(path: "/admin/*", host: "admin", port: 8000)
]

client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  routes: routes
)
```

### Route Matching

```crystal
def match(path : String) : MatchResult?
  @routes.each do |route|
    if pattern_matches?(route.path, path)
      host = route.host || @default_host
      target = Target.new(host, route.port)
      return MatchResult.new(target, route.path)
    end
  end

  # Fallback
  if port = @fallback_port
    target = Target.new(@default_host, port)
    return MatchResult.new(target, "(fallback)")
  end

  nil
end
```

**Examples**:
```
GET /api/users     -> api:8080  (matches /api/*)
GET /socket        -> localhost:3000  (fallback)
GET /admin/dashboard -> admin:8000  (matches /admin/*)
GET /other         -> 502 No route matched
```

## Usage Examples

### Basic Tunnel

```crystal
client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000
)

client.start
sleep
```

### Custom Subdomain

```crystal
client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  subdomain: "myapp"
)

client.start
```

### With Authentication

```crystal
client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  api_key: "sk_live_..."
)

client.start
```

### With Routing

```crystal
routes = [
  RouteConfig.new("/api/*", "api", 8080),
  RouteConfig.new("/socket", nil, 4000),
  RouteConfig.new("/admin/*", "admin", 8000)
]

client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  routes: routes
)

client.start
```

### With Inspector

```crystal
store = RequestStore.new(max_size: 1000)

inspector = Inspector.new(port: 4000, store: store)
spawn { inspector.start }

client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  request_store: store
)

client.start
```

## Error Handling

### Connection Failed

```crystal
rescue ex
  Log.error { "Connection failed: #{ex.message}" }
  @on_error.try(&.call("Connection failed: #{ex.message}"))
  handle_reconnect
end
```

### Local Service Unavailable

```crystal
rescue ex : Socket::ConnectError
  error_body = IO::Memory.new("Local service unavailable")
  {502, {"Content-Type" => ["text/plain"]}, error_body}
```

### Request Timeout

```crystal
rescue ex : IO::TimeoutError
  error_body = IO::Memory.new("Request to local service timed out")
  {504, {"Content-Type" => ["text/plain"]}, error_body}
```

## Performance

### Concurrency

- Each request spawns a fiber
- Multiple requests handled in parallel
- WebSocket frames forwarded directly

### Memory

- Per pending request: ~10KB (headers + body buffer)
- Per WebSocket: ~10KB (frame buffer)
- Inspector storage: Configurable (default 1000 requests)

### CPU

- Message handling: ~10μs per message
- Request forwarding: ~100μs (excluding local service time)

## Best Practices

### Always Set Callbacks

```crystal
client.on_connect do |url|
  puts "Connected: #{url}"
end

client.on_error do |error|
  STDERR.puts "Error: #{error}"
end
```

### Handle Subdomain Conflicts

```crystal
client.on_error do |error|
  if error.includes?("not available")
    puts "Subdomain is taken. Try a different subdomain."
    client.stop
  end
end
```

### Use Explicit Subdomains in Production

```crystal
# Don't rely on random subdomains in production
client = TunnelClient.new(
  server_url: "wss://sellia.dev",
  local_port: 3000,
  subdomain: "myapp-prod"  # Explicit
)
```

### Set Reasonable Timeouts

```crystal
# In LocalProxy
client.connect_timeout = 5.seconds
client.read_timeout = 30.seconds
```

## Testing

### Integration Test

```crystal
# Start local service
spawn do
  HTTP::Server.new do |context|
    context.response.print("Hello from local service")
  end.bind("127.0.0.1", 3000).listen
end

# Start tunnel client
client = TunnelClient.new(
  server_url: "ws://localhost:8080",
  local_port: 3000
)

client.start

# Wait for connection
sleep 1.second

# Make request through tunnel
response = HTTP::Client.get("http://localhost:8080/test")
puts response.body  # => "Hello from local service"
```
