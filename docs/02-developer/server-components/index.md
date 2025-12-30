# Server Components

Server-side implementation details for Sellia.

## Overview

The Sellia server (`sellia-server`) is responsible for managing tunnel connections, routing HTTP requests, and handling authentication. This section covers the server architecture and key components.

## Architecture

```
External HTTP Request
         ↓
    HTTP Ingress
         ↓
  Tunnel Registry Lookup
         ↓
    WebSocket Gateway
         ↓
   Tunnel Client (WebSocket)
         ↓
    Local Service
```

## Key Components

### HTTP Ingress

**Location:** `src/server/http_ingress.cr`

Receives external HTTP requests and routes them to appropriate tunnels.

```crystal
class Sellia::Server::HTTPIngress
  def initialize(
    @tunnel_registry : TunnelRegistry,
    @connection_manager : ConnectionManager,
    @pending_requests : PendingRequestStore,
    @pending_websockets : PendingWebSocketStore,
    @rate_limiter : CompositeRateLimiter,
    @domain : String = "localhost",
    @request_timeout : Time::Span = 30.seconds,
    @landing_enabled : Bool = true,
  )
  end

  def handle(context : HTTP::Server::Context)
    # Extract subdomain from request
    subdomain = extract_subdomain(host)

    # Look up tunnel
    tunnel = @tunnel_registry.find_by_subdomain(subdomain)
    return context.response.status_code = 404 unless tunnel

    # Forward request through WebSocket
    proxy_request(context, client, tunnel)
  end
end
```

**Responsibilities:**
- Parse incoming HTTP requests
- Extract subdomain from Host header
- Validate tunnel exists
- Check basic auth if configured
- Enforce rate limits
- Forward requests through WebSocket tunnel
- Proxy WebSocket connections
- Return responses to client

### Tunnel Registry

**Location:** `src/server/tunnel_registry.cr`

Maintains registry of active tunnels and their mappings.

```crystal
class Sellia::Server::TunnelRegistry
  struct Tunnel
    property id : String
    property subdomain : String
    property client_id : String
    property created_at : Time
    property auth : String?
  end

  def initialize(@reserved_subdomains : Set(String) = Set(String).new)
    @tunnels = {} of String => Tunnel          # id -> tunnel
    @by_subdomain = {} of String => Tunnel     # subdomain -> tunnel
    @by_client = {} of String => Array(Tunnel) # client_id -> tunnels
    @mutex = Mutex.new
  end

  def register(tunnel : Tunnel) : Nil
    @mutex.synchronize do
      @tunnels[tunnel.id] = tunnel
      @by_subdomain[tunnel.subdomain] = tunnel
      @by_client[tunnel.client_id] ||= [] of Tunnel
      @by_client[tunnel.client_id] << tunnel
    end
  end

  def find_by_subdomain(subdomain : String) : Tunnel?
    @mutex.synchronize { @by_subdomain[subdomain]? }
  end

  def unregister(tunnel_id : String) : Tunnel?
    # Removes from all indices
  end
end
```

**Responsibilities:**
- Store active tunnels with multiple indices (by id, subdomain, client)
- Map subdomains to tunnel clients
- Validate subdomain availability and format
- Generate random subdomains
- Handle tunnel lifecycle

### WebSocket Gateway

**Location:** `src/server/ws_gateway.cr`

Manages WebSocket connections from tunnel clients.

```crystal
class Sellia::Server::WSGateway
  def initialize(
    @connection_manager : ConnectionManager,
    @tunnel_registry : TunnelRegistry,
    @auth_provider : AuthProvider,
    @pending_requests : PendingRequestStore,
    @pending_websockets : PendingWebSocketStore,
    @rate_limiter : CompositeRateLimiter,
    @domain : String = "localhost",
    @port : Int32 = 3000,
    @use_https : Bool = false,
  )
  end

  def handle(socket : HTTP::WebSocket)
    client = ClientConnection.new(socket)
    @connection_manager.add_connection(client)

    client.on_message do |message|
      handle_message(client, message)
    end

    client.on_close do
      handle_disconnect(client)
    end

    client.run
  end
end
```

**Responsibilities:**
- Accept WebSocket connections from tunnel clients
- Authenticate clients using API keys
- Register and manage tunnels
- Forward HTTP requests to tunnel clients
- Forward WebSocket frames to tunnel clients
- Handle keep-alive (ping/pong) with 30s interval
- Detect and clean up stale connections (60s timeout)
- Handle disconnections and cleanup

### Authentication

**Location:** `src/server/auth_provider.cr`

Handles API key authentication with three modes.

```crystal
class Sellia::Server::AuthProvider
  property require_auth : Bool
  property master_key : String?
  property use_database : Bool

  def initialize(@require_auth : Bool = false, @master_key : String? = nil, @use_database : Bool = false)
  end

  def validate(api_key : String) : Bool
    return true unless @require_auth
    return false if api_key.empty?

    # Check database first if enabled
    if @use_database && Storage::Database.instance?
      if found = Storage::Repositories::ApiKeys.validate(api_key)
        return true
      end
    end

    # Fallback to master key
    if master = @master_key
      api_key == master
    else
      true
    end
  end

  def account_id_for(api_key : String) : String
    # Returns account ID from database or SHA256 hash
  end
end
```

**Responsibilities:**
- Validate API keys
- Support three modes: no auth, master key, database
- Provide account identifiers for rate limiting
- Track API key usage in database mode

### Rate Limiter

**Location:** `src/server/rate_limiter.cr`

Prevents abuse through token bucket rate limiting.

```crystal
class Sellia::Server::RateLimiter
  struct Config
    property max_tokens : Float64
    property refill_rate : Float64
    property window : Time::Span
  end

  def allow?(key : String, cost : Float64 = 1.0) : Bool
    # Token bucket algorithm
  end

  def remaining(key : String) : Float64
    # Get remaining tokens
  end
end

class Sellia::Server::CompositeRateLimiter
  def allow_connection?(ip : String) : Bool
  end

  def allow_tunnel?(client_id : String) : Bool
  end

  def allow_request?(tunnel_id : String) : Bool
  end
end
```

**Responsibilities:**
- Track connection rate per IP
- Track tunnel creation rate per client
- Track request rate per tunnel
- Use token bucket algorithm for smooth rate limiting
- Auto-cleanup stale entries with 1-hour window

## Middleware

### Connection Manager

**Location:** `src/server/connection_manager.cr`

Manages active WebSocket client connections.

```crystal
class Sellia::Server::ConnectionManager
  def add_connection(client : ClientConnection)
  end

  def find(client_id : String) : ClientConnection?
  end

  def unregister(client_id : String)
  end

  def each
    # Yields each connected client
  end
end
```

**Responsibilities:**
- Track active client connections
- Provide lookup by client ID
- Support iteration for health checks

## Message Handling

### Incoming Messages from Tunnel Clients

```crystal
private def handle_message(client : ClientConnection, message : Protocol::Message)
  case message
  when Protocol::Messages::Auth
    handle_auth(client, message)
  when Protocol::Messages::TunnelOpen
    handle_tunnel_open(client, message)
  when Protocol::Messages::TunnelClose
    handle_tunnel_close(client, message)
  when Protocol::Messages::ResponseStart
    handle_response_start(client, message)
  when Protocol::Messages::ResponseBody
    handle_response_body(client, message)
  when Protocol::Messages::ResponseEnd
    handle_response_end(client, message)
  when Protocol::Messages::Ping
    client.send(Protocol::Messages::Pong.new(message.timestamp))
  when Protocol::Messages::WebSocketUpgradeOk
    handle_ws_upgrade_ok(client, message)
  when Protocol::Messages::WebSocketUpgradeError
    handle_ws_upgrade_error(client, message)
  when Protocol::Messages::WebSocketFrame
    handle_ws_frame(client, message)
  when Protocol::Messages::WebSocketClose
    handle_ws_close(client, message)
  end
end
```

### Outgoing Messages to Tunnel Clients

```crystal
# Forward HTTP request
client.send(Protocol::Messages::RequestStart.new(
  request_id: request_id,
  tunnel_id: tunnel.id,
  method: context.request.method,
  path: context.request.resource,
  headers: headers
))

# Forward WebSocket upgrade
client.send(Protocol::Messages::WebSocketUpgrade.new(
  request_id: request_id,
  tunnel_id: tunnel.id,
  path: context.request.resource,
  headers: headers
))

# Forward WebSocket frame
client.send(Protocol::Messages::WebSocketFrame.new(
  request_id: request_id,
  opcode: opcode,
  payload: payload
))
```

## Configuration

### Server Configuration

Server configuration is typically loaded from environment variables.

```crystal
# Example environment variables:
# SELLIA_DOMAIN=sellia.dev
# SELLIA_PORT=3000
# SELLIA_MASTER_KEY=sk_master_...
# SELLIA_REQUIRE_AUTH=true
# SELLIA_USE_HTTPS=true
```

## Server Lifecycle

### Initialization

```crystal
# Create shared components
connection_manager = ConnectionManager.new
tunnel_registry = TunnelRegistry.new(reserved_subdomains)
auth_provider = AuthProvider.new(use_database: true)
pending_requests = PendingRequestStore.new
pending_websockets = PendingWebSocketStore.new
rate_limiter = CompositeRateLimiter.new

# Create main components
ws_gateway = WSGateway.new(
  connection_manager: connection_manager,
  tunnel_registry: tunnel_registry,
  auth_provider: auth_provider,
  pending_requests: pending_requests,
  pending_websockets: pending_websockets,
  rate_limiter: rate_limiter,
  domain: "sellia.dev",
  port: 3000
)

http_ingress = HTTPIngress.new(
  tunnel_registry: tunnel_registry,
  connection_manager: connection_manager,
  pending_requests: pending_requests,
  pending_websockets: pending_websockets,
  rate_limiter: rate_limiter,
  domain: "sellia.dev",
  request_timeout: 30.seconds
)
```

### Starting the Server

```crystal
server = HTTP::Server.new("0.0.0.0", 3000) do |context|
  http_ingress.handle(context)
end

# Add WebSocket handler at /ws path
ws_handler = HTTP::WebSocketHandler.new do |socket, context|
  ws_gateway.handle(socket)
end

server.bind_tcp("0.0.0.0", 3000)
server.listen
```

## Testing

### Unit Tests

**Location:** `spec/server/`

Tests should verify individual component behavior:

```crystal
describe Sellia::Server::TunnelRegistry do
  it "registers a tunnel" do
    registry = TunnelRegistry.new
    tunnel = TunnelRegistry::Tunnel.new(
      id: "test123",
      subdomain: "myapp",
      client_id: "client1"
    )

    registry.register(tunnel)
    registry.find_by_id("test123").should eq tunnel
  end

  it "validates subdomains" do
    registry = TunnelRegistry.new

    result = registry.validate_subdomain("ab")
    result.valid.should be_false

    result = registry.validate_subdomain("myapp")
    result.valid.should be_true
  end
end
```

## Performance Considerations

### Memory

- Per tunnel: ~200 bytes
- Per client: ~1 KB
- Rate limiting: ~100 bytes per tracked key
- Pending requests: ~1 KB each
- WebSocket connections: ~2 KB each

### Concurrency

- Each connection runs in its own fiber
- All shared state protected by mutexes
- Lock contention is minimal (fast operations)
- No long-running critical sections

### Scalability

- Fiber-based concurrency handles thousands of connections
- Token bucket rate limiting prevents resource exhaustion
- Automatic cleanup of stale state (1-hour window)
- O(1) lookups for all critical operations

## Security

### Input Validation

```crystal
# Subdomain validation (handled by TunnelRegistry)
def validate_subdomain(subdomain : String) : ValidationResult
  # Length: 3-63 characters
  # Characters: alphanumeric and hyphens
  # Pattern: cannot start/end with hyphen
  # No consecutive hyphens
  # Not in reserved set
  # Not already in use
end
```

### Authentication

- Three modes: no auth (dev), master key (simple), database (production)
- API keys validated against SHA256 hashes
- Database mode tracks usage and supports revocation
- Master key fallback supported

### Rate Limiting

- Connection rate: per IP (10 burst, 1/s)
- Tunnel creation: per client (5 burst, 1/10s)
- Request rate: per tunnel (100 burst, 50/s)
- Token bucket algorithm for smooth limiting
- Automatic cleanup after 1 hour

### TLS/SSL

- HTTPS support via reverse proxy (use_https flag)
- On-demand TLS verification endpoint at `/tunnel/verify`
- Compatible with Caddy automatic TLS

## Debugging

### Logging

```crystal
Log.setup(:debug)

Log.debug { "Registering tunnel: #{subdomain}" }
Log.info { "Tunnel registered: #{subdomain}" }
Log.warn { "Rate limit exceeded: #{client_ip}" }
Log.error { "WebSocket error: #{error}" }
```

### Monitoring

```crystal
# Track metrics
struct Metrics
  property requests_total = 0
  property requests_active = 0
  property tunnels_active = 0
end

@metrics = Metrics.new
```

## Next Steps

- [CLI Components](../cli-components/) - Client-side implementation
- [Project Structure](../project-structure/) - Code organization
- [Development](../development/) - Development setup
