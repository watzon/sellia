# Architecture

System architecture and design of Sellia.

## Overview

Sellia is a tunneling system that exposes local servers to the internet through a secure WebSocket-based protocol. The architecture consists of three main components:

1. **Tunnel Server** - Public-facing server that receives external requests
2. **CLI Client** - Local client that connects to server and forwards requests
3. **Inspector UI** - Web interface for debugging requests

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Sellia Server                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ HTTP Ingress │──│   Tunnel     │──│   WebSocket  │     │
│  │              │  │   Registry   │  │   Gateway    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└────────────────────────┬────────────────────────────────────┘
                         │ WebSocket
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Sellia CLI Client                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Tunnel     │──│   Local      │  │  Inspector   │     │
│  │   Client     │  │   HTTP       │  │   Server     │     │
│  │              │  │   Proxy      │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  Local Development Server                    │
│                  (your application)                          │
└─────────────────────────────────────────────────────────────┘
```

## Components

### Tunnel Server

The server is responsible for:

- **HTTP Ingress** - Receives external HTTP requests
- **WebSocket Gateway** - Manages WebSocket connections from clients
- **Tunnel Registry** - Tracks active tunnels and their subdomains
- **Authentication** - Validates API keys and credentials (no auth, master key, or database modes)
- **Rate Limiting** - Prevents abuse (token bucket algorithm)
- **Admin API** - Administrative endpoints for server management

**Request Flow:**

1. External request arrives at `http://subdomain.domain.com`
2. Server looks up tunnel in registry
3. Server forwards request through WebSocket to client
4. Client processes request and sends response back through WebSocket
5. Server returns response to external caller

### CLI Client

The client is responsible for:

- **WebSocket Connection** - Maintains persistent connection to server
- **Tunnel Registration** - Registers tunnels with unique subdomains
- **Router** - Routes requests to local services based on path patterns
- **LocalProxy** - Forwards HTTP requests to local services
- **WebSocketProxy** - Forwards WebSocket connections to local services
- **Inspector Server** - Serves web UI for debugging
- **RequestStore** - Stores request/response history for inspector
- **Auto-Reconnection** - Reconnects with linear backoff (3s × attempt number, max 10 attempts)

**Request Flow:**

1. Client connects to server via WebSocket
2. Client registers tunnel with requested subdomain
3. Client receives requests from server through WebSocket
4. Client forwards requests to local service
5. Client receives response from local service
6. Client sends response back through WebSocket

### Inspector UI

The inspector provides:

- **Real-time Updates** - WebSocket connection to CLI client (Channel-based subscriptions)
- **Request Visualization** - Display all requests/responses (circular buffer, max 1000)
- **Debugging Tools** - Copy as cURL, view headers/bodies
- **Interactive UI** - React-based interface with TypeScript and Vite
- **Live Updates** - Subscribe to request stream via WebSocket

## Communication Protocol

Sellia uses **MessagePack over WebSocket** for efficient binary communication.

### Why MessagePack?

- **Binary Format** - More efficient than JSON
- **Type Preservation** - Maintains data types
- **Compact** - Smaller payload sizes
- **Fast** - Quick serialization/deserialization

### Message Types

Defined in `src/core/protocol/`:

```crystal
# Request from server to client
class TunnelRequest
  property request_id : String
  property method : String
  property headers : Hash(String, String)
  property body : Bytes?
end

# Response from client to server
class TunnelResponse
  property request_id : String
  property status_code : Int32
  property headers : Hash(String, String)
  property body : Bytes?
end

# Tunnel registration
class RegisterTunnel
  property subdomain : String
  property auth : String?
end
```

### WebSocket Flow

```
Client                                      Server
  │                                           │
  ├─── WebSocket Handshake ──────────────────>│
  │                                           │
  ├─── RegisterTunnel (MessagePack) ─────────>│
  │<─── TunnelRegistered (MessagePack) ───────┤
  │                                           │
  │<─── TunnelRequest (MessagePack) ──────────┤
  │    (forward to local service)             │
  ├─── TunnelResponse (MessagePack) ─────────>│
  │                                           │
  │        (repeat for each request)          │
```

## Data Flow

### Incoming Request

```
1. External HTTP Request
   ↓
2. Server HTTP Ingress
   ↓
3. Tunnel Registry Lookup
   ↓
4. Find WebSocket Connection
   ↓
5. MessagePack Encode Request
   ↓
6. Send via WebSocket
   ↓
7. Client Receives Request
   ↓
8. Forward to Local Service
   ↓
9. Local Service Processes
   ↓
10. Response Received
   ↓
11. MessagePack Encode Response
   ↓
12. Send via WebSocket
   ↓
13. Server Receives Response
   ↓
14. Return HTTP Response
```

### Inspector Data Flow

```
1. Client Receives Request
   ↓
2. Send to Inspector (local WebSocket)
   ↓
3. Inspector UI Displays
   ↓
4. User Interacts
   ↓
5. Inspector Sends Commands
   ↓
6. Client Executes Commands
```

## Security Architecture

### Authentication Layers

1. **Server Authentication** - API key validation
2. **Tunnel Authentication** - HTTP basic auth per tunnel
3. **Rate Limiting** - Prevent abuse
4. **Subdomain Validation** - Prevent conflicts

### TLS/SSL

- Server can require HTTPS
- TLS certificates managed externally
- Certificates loaded from `certs/` directory

### Data Security

- WebSocket connections can be secured with WSS
- API keys stored securely (environment variables)
- Basic auth passwords never logged

## Concurrency Model

### Server

- **Fiber-based concurrency** - Crystal's lightweight threads
- **Per-connection fibers** - Each WebSocket connection runs in fiber
- **Shared state** - Tunnel registry with synchronization

### Client

- **Multi-fiber design** - Separate fibers for:
  - WebSocket connection
  - HTTP proxy
  - Inspector server
  - Heartbeat/reconnection

## Error Handling

### Connection Errors

- **Auto-reconnection** - Linear backoff
- **Heartbeat** - Detect stale connections
- **Graceful degradation** - Continue on non-critical errors

### Request Errors

- **Timeout handling** - Configurable timeouts
- **Error responses** - Proper HTTP error codes
- **Logging** - All errors logged for debugging

## Performance Considerations

### Memory

- **MessagePack** - Efficient binary format reduces memory
- **Streaming** - Large bodies streamed when possible
- **Inspector limits** - Configurable history size

### Network

- **Connection pooling** - Reuse WebSocket connections
- **Compression** - Optional compression support
- **Keep-alive** - Maintain persistent connections

### Scalability

- **Stateless design** - Server can be scaled (with shared storage)
- **Fiber-based** - Handle many concurrent connections
- **Efficient protocol** - MessagePack minimizes bandwidth

## Extension Points

### Custom Protocols

Message types defined in `src/core/protocol/` can be extended for new features.

### Middleware

Server and client support middleware for:
- Authentication
- Logging
- Rate limiting
- Custom processing

### Storage

Storage backend abstracted to support:
- In-memory (default)
- SQLite (planned)
- PostgreSQL (future)

## Design Decisions

### Why WebSocket?

- **Bidirectional** - Server can push requests to client
- **Efficient** - Single connection for multiple requests
- **Real-time** - Low latency communication
- **Widely supported** - Available in most languages/browsers

### Why MessagePack?

- **Binary** - More efficient than text-based protocols
- **Schema-less** - Flexible data structures
- **Fast** - Quick serialization/deserialization
- **Cross-language** - Available in most languages

### Why Crystal?

- **Performance** - Compiled, fast execution
- **Concurrency** - Excellent fiber-based concurrency
- **Type safety** - Compile-time type checking
- **Ease of use** - Ruby-like syntax

## Next Steps

- [Project Structure](../project-structure/) - Code organization
- [Server Components](../server-components/) - Server implementation
- [CLI Components](../cli-components/) - Client implementation
