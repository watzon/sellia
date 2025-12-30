# Core Component Overview

This document provides a high-level overview of Sellia's core components and their interactions.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Sellia Server                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ HTTP Server  │    │ WS Endpoint  │    │ Admin API    │      │
│  │  (public)    │    │   (/ws)      │    │   (admin)    │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ HTTPIngress  │    │  WSGateway   │    │ AdminAPI     │      │
│  │  - Routing   │◄───│  - Message   │    │  - Mgmt      │      │
│  │  - Proxying  │    │    handling  │    │  - Stats     │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         └─────────┬─────────┘                   │               │
│                   │                             │               │
│                   ▼                             │               │
│          ┌────────────────┐                    │               │
│          │ ConnectionMgr  │                    │               │
│          │  - Track clients│                    │               │
│          └────────┬───────┘                    │               │
│                   │                             │               │
│    ┌──────────────┼──────────────┐             │               │
│    ▼              ▼              ▼             │               │
│ ┌────────┐  ┌──────────┐  ┌──────────┐         │               │
│ │Tunnel  │  │ Pending  │  │ Pending  │         │               │
│ │Registry│  │ Request  │  │ WebSocket│         │               │
│ └────────┘  └──────────┘  └──────────┘         │               │
│                                            ▲    │               │
│                                            │    │               │
│                                    ┌───────┴────┴───────┐      │
│                                    │   Storage Layer     │      │
│                                    │  - SQLite DB        │      │
│                                    │  - Reserved subdoms │      │
│                                    │  - API keys         │      │
│                                    └─────────────────────┘      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                          Sellia CLI                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ TunnelClient │    │  Inspector   │    │   Updater    │      │
│  │  - Connect   │    │  - Web UI    │    │  - Self-upd  │      │
│  │  - Proxy     │    │  - Debug     │    │              │      │
│  └──────┬───────┘    └──────┬───────┘    └──────────────┘      │
│         │                   │                                   │
│         ▼                   ▼                                   │
│  ┌──────────────┐    ┌──────────────┐                          │
│  │  Router     │    │ RequestStore │                          │
│  │  - Paths    │    │  - History   │                          │
│  │  - Routes   │    │  - Inspection│                          │
│  └──────┬───────┘    └──────────────┘                          │
│         │                                                        │
│    ┌────┴────┐                                                   │
│    ▼         ▼                                                   │
│ ┌────────┐ ┌──────────┐                                         │
│ │ Local  │ │   WS     │                                         │
│ │ Proxy  │ │   Proxy  │                                         │
│ └────────┘ └──────────┘                                         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Server Components

### HTTPIngress

**Purpose**: Handles incoming HTTP requests from the public internet

**Responsibilities**:
- Extract subdomain from `Host` header
- Find tunnel in registry
- Validate basic auth (if configured)
- Check rate limits
- Detect WebSocket upgrades
- Proxy HTTP requests to clients
- Proxy WebSocket connections to clients
- Serve root domain endpoints (health, TLS verification)
- Serve landing page

**Key Methods**:
- `handle(context)` - Main request handler
- `proxy_request()` - Forward HTTP to client
- `proxy_websocket()` - Forward WebSocket to client
- `extract_subdomain()` - Parse subdomain from host
- `serve_root()` - Handle root domain requests

**Dependencies**:
- `TunnelRegistry` - Find tunnels by subdomain
- `ConnectionManager` - Get client connections
- `PendingRequestStore` - Track in-flight requests
- `PendingWebSocketStore` - Track WebSocket connections
- `CompositeRateLimiter` - Enforce rate limits

### WSGateway

**Purpose**: Manages WebSocket connections from tunnel clients

**Responsibilities**:
- Accept WebSocket connections from clients
- Handle authentication flow
- Process tunnel open/close requests
- Forward responses from clients to HTTP handlers
- Forward WebSocket frames bidirectionally
- Send ping/pong for keep-alive
- Detect stale connections
- Clean up on disconnect

**Key Methods**:
- `handle(socket)` - Accept new WebSocket connection
- `handle_message()` - Route message to handler
- `handle_auth()` - Validate API key
- `handle_tunnel_open()` - Create new tunnel
- `handle_response_*()` - Forward response to HTTP handler
- `check_connections()` - Ping/pong and timeout stale connections
- `handle_disconnect()` - Cleanup on client disconnect

**Dependencies**:
- `ConnectionManager` - Track client connections
- `TunnelRegistry` - Register tunnels
- `AuthProvider` - Validate API keys
- `PendingRequestStore` - Match responses to requests
- `PendingWebSocketStore` - Track WebSocket connections
- `CompositeRateLimiter` - Rate limit tunnel creation

### TunnelRegistry

**Purpose**: In-memory registry of active tunnels

**Responsibilities**:
- Register tunnels by ID
- Find tunnels by ID, subdomain, or client
- Validate subdomain format and availability
- Generate random subdomains
- Unregister tunnels on close
- Unregister all tunnels for a client
- Reload reserved subdomains from database

**Data Structures**:
```crystal
@tunnels = {} of String => Tunnel          # id -> tunnel
@by_subdomain = {} of String => Tunnel     # subdomain -> tunnel
@by_client = {} of String => Array(Tunnel) # client_id -> tunnels
@reserved_subdomains = Set(String)         # Reserved names
```

**Validation Rules**:
- Length: 3-63 characters
- Characters: alphanumeric, hyphens
- Cannot start/end with hyphen
- No consecutive hyphens
- Cannot be reserved

**Thread Safety**: All operations protected by `Mutex`

### ConnectionManager

**Purpose**: Track active WebSocket client connections

**Responsibilities**:
- Add new client connections
- Find client by ID
- Remove client connections
- Iterate over all clients

**Use Cases**:
- HTTP ingress finds client to forward requests
- Cleanup on disconnect
- Broadcasting (future)

**Thread Safety**: Uses concurrent data structures

### AuthProvider

**Purpose**: Validate API keys and provide account information

**Modes**:
1. **No Auth**: Accept any connection (self-hosted mode)
2. **Master Key**: Single shared key (simple mode)
3. **Database**: Validate against stored API keys (production mode)

**Key Methods**:
- `validate(api_key)` - Check if key is valid
- `account_id_for(api_key)` - Get account identifier

**Database Integration**:
```crystal
if @use_database && Storage::Database.instance?
  if key_record = Storage::Repositories::ApiKeys.validate(api_key)
    return true
  end
end
```

### PendingRequestStore

**Purpose**: Track in-flight HTTP requests waiting for client response

**Flow**:
1. HTTPIngress creates `PendingRequest` before sending to client
2. WSGateway receives response and looks up by `request_id`
3. Response written to HTTP context
4. Request removed from store

**Implementation**:
```crystal
@pending : Hash(String, PendingRequest)
@mutex = Mutex.new

class PendingRequest
  property request_id : String
  property context : HTTP::Server::Context
  property tunnel_id : String
  property response_started : Bool = false
  @channel : Channel(Nil) = Channel(Nil).new

  def wait(timeout : Time::Span) : Bool
    @channel.receive(timeout: timeout)
    true
  rescue Channel::TimeoutError
    false
  end
end
```

**Timeout Handling**:
- Wait with timeout (default 30s)
- Remove on timeout or completion
- Send 504 on timeout if no response started

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/server/pending_request.cr`

### PendingWebSocketStore

**Purpose**: Track WebSocket upgrade handshakes

**Flow**:
1. HTTPIngress creates `PendingWebSocket`
2. Sends `WebSocketUpgrade` to client
3. Waits for `WebSocketUpgradeOk` or `WebSocketUpgradeError`
4. Once confirmed, stores `ws_protocol` for frame forwarding

**Implementation**:
```crystal
@pending : Hash(String, PendingWebSocket)
@mutex = Mutex.new

class PendingWebSocket
  property request_id : String
  property context : HTTP::Server::Context
  property tunnel_id : String
  property ws_protocol : HTTP::WebSocket::Protocol?
  property closed : Bool = false
  @on_frame : Proc(UInt8, Bytes, Nil)?
  @on_close : Proc(UInt16?, String?, Nil)?

  def wait_for_upgrade(timeout : Time::Span) : Bool
    # Wait for client to confirm WebSocket connection
  end
end
```

**Key Methods**:
- `add(pending_ws)` - Add new pending WebSocket
- `get(request_id)` - Look up pending WebSocket
- `remove(request_id)` - Remove from store
- `remove_by_tunnel(tunnel_id)` - Cleanup on tunnel close

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/server/pending_websocket.cr`

### CompositeRateLimiter

**Purpose**: Enforce rate limits for connections, tunnels, and requests

**Rate Limiters**:
1. **Connection Limiter** - Connections per IP
2. **Tunnel Limiter** - Tunnel creation per client
3. **Request Limiter** - Requests per tunnel

**Algorithm**: Token bucket
- Max tokens (burst capacity)
- Refill rate (tokens per second)
- Consume token on action

**Default Limits**:
- Connections: 10 burst, 1/s refill
- Tunnels: 5 burst, 0.1/s (1 per 10s) refill
- Requests: 100 burst, 50/s refill

**Key Methods**:
- `allow_connection?(ip)` - Check if new connection allowed
- `allow_tunnel?(client_id)` - Check if tunnel creation allowed
- `allow_request?(tunnel_id)` - Check if request allowed
- `reset_client(client_id)` - Clear limits on disconnect
- `reset_tunnel(tunnel_id)` - Clear limits on tunnel close

### AdminAPI

**Purpose**: Administrative endpoints for server management

**Endpoints**:
- `GET /admin/tunnels` - List active tunnels
- `GET /admin/tunnels/:id` - Get tunnel details
- `POST /admin/tunnels/:id/close` - Force close tunnel
- `GET /admin/stats` - Server statistics
- `POST /admin/reserved-subdomains` - Add reserved subdomain
- `DELETE /admin/reserved-subdomains/:subdomain` - Remove reserved subdomain
- `GET /admin/api-keys` - List API keys
- `POST /admin/api-keys` - Create API key
- `DELETE /admin/api-keys/:prefix` - Revoke API key

**Authentication**: Basic auth with configured admin credentials

## CLI Components

### TunnelClient

**Purpose**: Main client that connects to server and forwards requests

**Responsibilities**:
- Establish WebSocket connection to server
- Authenticate with API key
- Open tunnels
- Receive incoming requests
- Route requests to local services
- Forward responses back to server
- Handle WebSocket upgrades
- Auto-reconnect on disconnect

**Key Methods**:
- `start()` - Start connection and message loop
- `connect()` - Establish WebSocket connection
- `authenticate()` - Send auth message
- `open_tunnel()` - Request tunnel creation
- `handle_message()` - Route incoming messages
- `forward_request()` - Proxy HTTP to local service
- `handle_websocket_upgrade()` - Proxy WebSocket to local service

**State**:
```crystal
@connected : Bool = false
@authenticated : Bool = false
@tunnel_id : String?
@public_url : String?
```

### Router

**Purpose**: Match incoming paths to local service targets

**Route Configuration**:
```crystal
RouteConfig.new(
  path: "/api/*",      # Glob pattern
  host: "api",         # Target host (nil = default)
  port: 8080           # Target port
)
```

**Matching**:
- First match wins
- Glob patterns: `/api/*` matches `/api/users`, `/api/posts/123`
- Exact patterns: `/socket` matches only `/socket`
- Fallback: If no match, use default port

**Example**:
```crystal
routes = [
  RouteConfig.new("/api/*", "api", 8080),
  RouteConfig.new("/socket", nil, 3000),
  RouteConfig.new("/admin/*", "admin", 8000)
]

# /api/users -> api:8080
# /socket -> localhost:3000
# /admin/dashboard -> admin:8000
# /other -> localhost:3000 (fallback)
```

### LocalProxy

**Purpose**: Make HTTP requests to local services

**Responsibilities**:
- Open HTTP connection to target
- Filter hop-by-hop headers
- Forward request body
- Read response
- Handle timeouts

**Timeouts**:
- Connect: 5 seconds
- Read: 30 seconds

**Error Handling**:
- `Socket::ConnectError` → 502 Bad Gateway
- `IO::TimeoutError` → 504 Gateway Timeout
- Other errors → 500 Internal Server Error

**Hop-by-Hop Headers Filtered**:
- Connection
- Keep-Alive
- Transfer-Encoding
- TE
- Trailer
- Upgrade
- Proxy-Authorization
- Proxy-Authenticate

### WebSocketProxy

**Purpose**: Proxy WebSocket connections to local services

**Responsibilities**:
- Connect to local WebSocket service
- Forward frames bidirectionally
- Handle close frames
- Notify on connection close

**Frame Flow**:
```
External WS ←→ Server ←→ Client ←→ WebSocketProxy ←→ Local WS
```

### Inspector

**Purpose**: Web UI for debugging tunneled requests

**Components**:
1. **HTTP Server** - Serves UI and API
2. **RequestStore** - Stores request/response history
3. **WebSocket** - Pushes real-time updates to UI

**Endpoints**:
- `/` - Serve React UI (baked in release, proxied to Vite in dev)
- `/api/live` - WebSocket for real-time updates
- `/api/requests` - Get all stored requests
- `/api/requests/clear` - Clear history

**Request Storage**:
```crystal
StoredRequest.new(
  id: request_id,
  method: "GET",
  path: "/api/users",
  status_code: 200,
  duration: 45_i64,
  timestamp: Time.utc,
  request_headers: {...},
  request_body: "...",
  response_headers: {...},
  response_body: "...",
  matched_route: "/api/*",
  matched_target: "api:8080"
)
```

### Updater

**Purpose**: Self-update mechanism for CLI

**Flow**:
1. Fetch latest release from GitHub API
2. Compare versions
3. Download binary for current platform
4. Replace executable
5. Clean up old binary

**Update Sources**:
- Latest release: `https://api.github.com/repos/watzon/sellia/releases/latest`
- Specific version: `https://api.github.com/repos/watzon/sellia/releases/tags/v{version}`

**Platform Detection**:
- OS: darwin, linux, windows
- Arch: amd64, arm64

**Binary Naming**:
- `sellia-darwin-amd64`
- `sellia-linux-arm64`
- `sellia-windows-amd64.exe`

## Storage Layer

### Database

**Purpose**: SQLite database for persistent data

**Features**:
- Singleton pattern (one connection per process)
- WAL mode for better concurrency
- Shared cache for in-memory mode
- Connection pooling

**Configuration**:
- File-based: `sqlite3://path?journal_mode=WAL&synchronous=NORMAL`
- In-memory: `sqlite3://:memory:?mode=memory&cache=shared`

**Models**:
- `ReservedSubdomain` - Reserved subdomain names
- `ApiKey` - API keys for authentication

### Repositories

**ReservedSubdomains**:
- `all()` - Get all reserved subdomains
- `exists?(subdomain)` - Check if subdomain is reserved
- `create(subdomain, reason)` - Add reserved subdomain
- `delete(subdomain)` - Remove reserved subdomain
- `to_set()` - Convert to Set for fast lookup

**ApiKeys**:
- `find_by_hash(key_hash)` - Find by key hash
- `find_by_prefix(prefix)` - Find by key prefix (for listing)
- `validate(plaintext_key)` - Validate and update last_used_at
- `create(plaintext_key, name)` - Create new API key
- `revoke(prefix)` - Revoke API key (set active=0)
- `count_active()` - Count active API keys
- `all()` - Get all API keys

## Data Flow Summary

### HTTP Request Flow

```
User → HTTPIngress → TunnelRegistry → ConnectionManager
     ↓
PendingRequestStore → WSGateway → Client
     ↓
Router → LocalProxy → Local Service
     ↓
ResponseStart → ResponseBody* → ResponseEnd
     ↓
PendingRequestStore → HTTPIngress → User
```

### WebSocket Flow

```
User → HTTPIngress → PendingWebSocketStore → WSGateway → Client
     ↓
Router → WebSocketProxy → Local WS Service
     ↓
WebSocketUpgradeOk
     ↓
Frame Loop: Frames ↔ WSGateway ↔ Client ↔ WebSocketProxy ↔ Local WS
```

## Security Architecture

### Authentication

1. **Client → Server**: API key in `Auth` message
2. **Server**: Validates against database or master key
3. **Tunnel Auth**: Optional basic auth per tunnel

### TLS/SSL

1. **Server**: Terminates TLS (Caddy/reverse proxy)
2. **Client → Server**: WSS (WebSocket Secure)
3. **Public → Server**: HTTPS

### Rate Limiting

1. **Per-IP**: Connection limits
2. **Per-Client**: Tunnel creation limits
3. **Per-Tunnel**: Request limits
4. **Token bucket algorithm**

### Subdomain Validation

1. **Format checks**: Length, characters, pattern
2. **Availability check**: Not already in use
3. **Reserved check**: Not in reserved list
4. **Database persistence**: Reserved subdomains stored in DB
