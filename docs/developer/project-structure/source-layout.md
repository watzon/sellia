# Source Layout

This document describes the organization of Sellia's source code and the purpose of each directory and module.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Core Components](#core-components)
- [Server Components](#server-components)
- [CLI Components](#cli-components)
- [Inspector UI](#inspector-ui)
- [Tests](#tests)
- [Configuration Files](#configuration-files)

## Overview

Sellia is organized as a Crystal application with a React-based inspector UI. The codebase follows a modular architecture with clear separation of concerns:

```
sellia/
├── src/              # Crystal source code
│   ├── core/         # Shared protocol and types
│   ├── server/       # Tunnel server implementation
│   └── cli/          # CLI client implementation
├── web/              # React inspector UI
├── spec/             # Crystal tests
└── docs/             # Documentation
```

## Directory Structure

### Root Directory

```
sellia/
├── bin/              # Compiled binaries (generated)
│   ├── sellia        # CLI client binary
│   └── sellia-server # Server binary
├── src/              # Crystal source code
├── spec/             # Crystal test files
├── web/              # Inspector UI (React + TypeScript)
├── docs/             # Documentation
├── docker/           # Docker configurations
├── .github/          # GitHub workflows and templates
├── shard.yml         # Crystal dependencies
└── package.json      # Node.js dependencies (web/)
```

### Top-Level Files

| File | Purpose |
|------|---------|
| `shard.yml` | Crystal dependency manifest |
| `shard.lock` | Locked Crystal dependencies |
| `package.json` | Node.js dependencies for inspector UI |
| `LICENSE` | MIT license |
| `README.md` | Project overview and usage |
| `CONTRIBUTING.md` | Contribution guidelines |
| `SECURITY.md` | Security policy and disclosure |
| `ROADMAP.md` | Project roadmap and feature plans |
| `.gitignore` | Git ignore patterns |
| `Dockerfile` | Server container image |
| `docker-compose.yml` | Development Docker setup |
| `docker-compose.prod.yml` | Production Docker setup |

## Core Components

The `src/core/` directory contains shared protocol definitions and types used by both server and CLI.

### Directory Structure

```
src/core/
├── protocol/
│   ├── message.cr                     # Base Message class
│   └── messages/
│       ├── auth.cr                    # Authentication messages
│       ├── tunnel.cr                  # Tunnel management messages
│       ├── request.cr                 # HTTP request/response messages
│       └── websocket.cr               # WebSocket messages
└── version.cr                          # Protocol version
```

### Module: `Sellia::Core`

**Purpose:** Shared functionality and protocol definitions

#### Protocol Messages (`src/core/protocol/messages.cr`)

Defines the MessagePack-based protocol for client-server communication:

```crystal
module Sellia::Core::Protocol
  # Message Types
  class RegisterTunnel
    property subdomain : String
    property auth_token : String?
  end

  class TunnelRegistered
    property url : String
    property inspector_url : String
  end

  class HttpRequest
    property id : String
    property method : String
    property path : String
    property headers : Hash(String, String)
    property body : Bytes?
  end

  class HttpResponse
    property request_id : String
    property status_code : Int32
    property headers : Hash(String, String)
    property body : Bytes?
  end

  # ... more message types
end
```

**Purpose:**
- Define all protocol message types
- Serialize/deserialize MessagePack
- Handle protocol versioning
- Validate message format

**Dependencies:**
- `msgpack` crystal shard
- Crystal standard library

#### Types (`src/core/types/tunnel.cr`)

Shared data structures:

```crystal
module Sellia::Core::Types
  class Tunnel
    property subdomain : String
    property client_id : String
    property auth_token : String?
    property created_at : Time
    property last_heartbeat : Time

    def active?
      # Check if tunnel is still active
    end
  end
end
```

**Purpose:**
- Define domain models
- Shared between server and CLI
- No protocol-specific logic

## Server Components

The `src/server/` directory contains the tunnel server implementation.

### Directory Structure

```
src/server/
├── main.cr                   # Server entry point
├── server.cr                 # Server orchestration
├── tunnel_registry.cr        # Tunnel registration and tracking
├── ws_gateway.cr             # WebSocket gateway/handler
├── http_ingress.cr           # HTTP request ingress handler
├── rate_limiter.cr           # Rate limiting logic
├── auth_provider.cr          # Authentication provider
├── connection_manager.cr     # Client connection tracking
├── client_connection.cr      # Client connection wrapper
├── pending_request.cr        # Pending HTTP request tracking
├── pending_websocket.cr      # Pending WebSocket tracking
├── landing.cr                # Landing page
├── admin_api.cr              # Admin API endpoints
├── storage/
│   ├── database.cr           # Database connection singleton
│   ├── migrations.cr         # Database migrations
│   ├── models.cr             # Database models
│   ├── repositories.cr       # Database repositories
│   └── storage.cr            # Storage module
└── public/                   # Public static assets
```

### Module: `Sellia::Server`

**Purpose:** Tunnel server that accepts client connections and routes traffic

#### Main Server (`src/server/server.cr`)

Entry point and server orchestration:

```crystal
class Sellia::Server
  def initialize(@host : String, @port : Int32, @domain : String)
    # Initialize components
  end

  def start
    # Start WebSocket listener
    # Start HTTP server
    # Handle signals
  end
end
```

**Responsibilities:**
- Parse command-line arguments
- Initialize all server components
- Coordinate startup and shutdown
- Handle graceful shutdown

#### Tunnel Registry (`src/server/tunnel_registry.cr`)

Manages tunnel registration and lookup:

```crystal
class Sellia::TunnelRegistry
  def register_tunnel(subdomain : String, client_id : String) : Tunnel
    # Validate subdomain
    # Check for duplicates
    # Register tunnel
  end

  def get_tunnel(subdomain : String) : Tunnel?
    # Look up tunnel by subdomain
  end

  def remove_tunnel(client_id : String) : Bool
    # Remove tunnel when client disconnects
  end
end
```

**Responsibilities:**
- Track active tunnels
- Validate subdomain uniqueness
- Map subdomains to clients
- Handle client disconnection
- Query tunnel information

#### WebSocket Gateway (`src/server/ws_gateway.cr`)

Handles WebSocket connections from tunnel clients:

```crystal
class Sellia::WSGateway
  def handle_client(ws : HTTP::WebSocket)
    # Authenticate if required
    # Wait for RegisterTunnel message
    # Register with tunnel registry
    # Forward HTTP requests to client
    # Handle responses from client
    # Detect disconnection
  end
end
```

**Responsibilities:**
- Accept WebSocket connections
- Authenticate clients (if enabled)
- Parse protocol messages
- Forward HTTP requests to tunnels
- Forward responses from tunnels
- Detect client disconnection

#### HTTP Ingress (`src/server/http_ingress.cr`)

Handles incoming HTTP requests and routes them to tunnels:

```crystal
class Sellia::HTTPIngress
  def handle_request(request : HTTP::Request) : HTTP::Response
    # Extract subdomain from Host header
    # Look up tunnel in registry
    # Forward request to tunnel client
    # Wait for response
    # Return response to client
  end
end
```

**Responsibilities:**
- Listen for HTTP requests
- Extract subdomain from request
- Route to appropriate tunnel
- Handle tunnel not found
- Handle timeout
- Return response to caller

#### Rate Limiter (`src/server/rate_limiter.cr`)

Token bucket rate limiting:

```crystal
class Sellia::RateLimiter
  def check_rate_limit(identifier : String, action : String) : Bool
    # Check if action is allowed
    # Update token bucket
  end
end
```

**Responsibilities:**
- Limit connection rate per IP
- Limit tunnel registration rate
- Limit request rate per tunnel
- Token bucket algorithm

#### Subdomain Validator (`src/server/subdomain_validator.cr`)

DNS label validation:

```crystal
class Sellia::SubdomainValidator
  def validate(subdomain : String) : Bool
    # Check length (max 63)
    # Check characters (alphanumeric + hyphen)
    # Check no consecutive hyphens
    # Check not a reserved name
  end
end
```

**Responsibilities:**
- Validate subdomain format
- Enforce DNS label rules
- Check reserved subdomains
- Provide clear error messages

#### Storage Layer (`src/server/storage/`)

Persistence for API keys and reserved subdomains:

```
src/server/storage/
├── database.cr               # Database singleton
├── migrations.cr             # Database migrations
├── models.cr                 # Database models (ReservedSubdomain, ApiKey)
├── repositories.cr           # Database repositories
└── storage.cr                # Storage module
```

**SQLite Store (`sqlite_store.cr`):**
- Database connection management
- Schema migrations
- CRUD operations for API keys
- CRUD operations for reserved subdomains

**Models:**
- `ApiKey`: API key with metadata
- `ReservedSubdomain`: Reserved subdomain claims

## CLI Components

The `src/cli/` directory contains the CLI client implementation.

### Directory Structure

```
src/cli/
├── main.cr                   # CLI entry point
├── config.cr                 # Configuration management
├── tunnel_client.cr          # Tunnel client logic
├── router.cr                 # Request routing to local services
├── local_proxy.cr            # HTTP proxy to local services
├── websocket_proxy.cr        # WebSocket proxy to local services
├── inspector.cr              # Request inspector server
├── request_store.cr          # Request storage for inspector
├── updater.cr                # Self-update mechanism
└── admin_commands.cr         # Admin CLI commands
```

### Module: `Sellia::CLI`

**Purpose:** Command-line client for creating tunnels

#### Main CLI (`src/cli/cli.cr`)

Entry point and command parsing:

```crystal
class Sellia::CLI
  def run(args : Array(String))
    # Parse arguments
    # Execute appropriate command
    # Handle errors
  end
end
```

**Responsibilities:**
- Parse command-line arguments
- Dispatch to appropriate command
- Handle global flags (--server, --api-key)
- Error handling and user feedback

#### Tunnel Client (`src/cli/tunnel_client.cr`)

Core tunnel client logic:

```crystal
class Sellia::TunnelClient
  def connect(server_url : String)
    # Connect to server via WebSocket
    # Send RegisterTunnel message
    # Wait for TunnelRegistered response
    # Start forwarding local traffic
  end

  def forward_request(request : HttpRequest)
    # Forward request to local service
    # Get response
    # Send response to server
  end
end
```

**Responsibilities:**
- Connect to server
- Register tunnel
- Forward requests to local service
- Forward responses to server
- Handle reconnection
- Manage connection lifecycle

#### Inspector (`src/cli/inspector.cr`)

Request inspector server:

```crystal
class Sellia::Inspector
  def start(port : Int32)
    # Start HTTP server for inspector UI
    # Serve React UI or proxy to Vite
    # WebSocket for live updates
  end

  def record_request(request : HttpRequest, response : HttpResponse)
    # Store request/response pair
    # Broadcast to WebSocket clients
  end
end
```

**Responsibilities:**
- HTTP server for inspector UI
- WebSocket for real-time updates
- Store request/response history
- Serve embedded UI or proxy to Vite
- Handle "clear history" command

#### Configuration (`src/cli/config/`)

Configuration management:

**Loader (`loader.cr`):**
- Load YAML config files
- Parse configuration
- Validate configuration

**Resolver (`resolver.cr`):**
- Layered configuration resolution:
  1. `~/.config/sellia/sellia.yml`
  2. `~/.sellia.yml`
  3. `./sellia.yml`
  4. CLI flags

#### Commands (`src/cli/commands/`)

Individual command implementations:

**HTTP Command (`http_command.cr`):**
- Create HTTP tunnel
- Handle --subdomain, --auth, etc.
- Start tunnel client

**Start Command (`start_command.cr`):**
- Read config file
- Start multiple tunnels
- Manage tunnel processes

**Auth Command (`auth_command.cr`):**
- Manage API keys
- Store credentials
- Login/logout

## Inspector UI

The `web/` directory contains the React-based inspector UI.

### Directory Structure

```
web/
├── index.html                # HTML entry point
├── vite.config.ts            # Vite configuration
├── tsconfig.json             # TypeScript configuration
├── package.json              # Node.js dependencies
├── src/
│   ├── main.tsx              # React entry point
│   ├── App.tsx               # Root component
│   ├── components/           # React components
│   │   ├── RequestList.tsx   # Request list view
│   │   ├── RequestDetail.tsx # Single request detail
│   │   ├── Header.tsx        # Request/response headers
│   │   ├── Body.tsx          # Request/response body
│   │   └── Controls.tsx      # Control buttons
│   ├── hooks/                # Custom React hooks
│   │   ├── useWebSocket.ts   # WebSocket connection
│   │   └── useRequests.ts    # Request state
│   ├── types/                # TypeScript types
│   │   └── index.ts          # Type definitions
│   └── utils/                # Utilities
│       ├── format.ts         # Formatters
│       └── copy.ts           # Copy to clipboard
└── dist/                     # Built assets (generated)
```

### Module: Inspector UI

**Purpose:** Web-based request inspection and debugging

**Technology Stack:**
- React 18 with TypeScript
- Vite for development/building
- TailwindCSS for styling (optional)
- WebSocket for real-time updates

**Key Components:**
- **RequestList:** Live stream of requests
- **RequestDetail:** Detailed request/response view
- **Controls:** Clear history, pause/resume, filters
- **WebSocket:** Real-time connection to CLI

**Development:**
```bash
cd web
npm install
npm run dev      # Development server (port 5173)
npm run build    # Production build (outputs to dist/)
```

**Asset Embedding:**
- Production: Built into Crystal binary
- Development: Proxied from Vite dev server

## Tests

The `spec/` directory contains test files mirroring the `src/` structure.

### Directory Structure

```
spec/
├── spec_helper.cr             # Test configuration
├── core/
│   └── protocol/
│       └── messages_spec.cr   # Protocol message tests
├── server/
│   ├── tunnel_registry_spec.cr
│   ├── ws_gateway_spec.cr
│   ├── http_ingress_spec.cr
│   └── rate_limiter_spec.cr
└── cli/
    ├── tunnel_client_spec.cr
    └── config_spec.cr
```

### Test Organization

**Naming Convention:** `<source_file>_spec.cr`

**Mirror Source Structure:**
- `spec/server/` tests `src/server/`
- `spec/cli/` tests `src/cli/`
- etc.

**Running Tests:**
```bash
crystal spec                    # All tests
crystal spec spec/server/       # Server tests only
crystal spec --verbose          # Detailed output
```

## Configuration Files

### Crystal Configuration

**`shard.yml`** - Crystal dependencies:
```yaml
name: sellia
version: 0.1.2
targets:
  sellia:
    main: src/cli.cr
  sellia-server:
    main: src/server.cr

dependencies:
  msgpack:
    github: crystal-community/msgpack-crystal
  # ... more dependencies
```

**`shard.lock`** - Locked dependency versions (generated)

### Node.js Configuration

**`package.json`** - Inspector UI dependencies:
```json
{
  "name": "sellia-inspector",
  "version": "0.1.2",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build"
  },
  "dependencies": {
    "react": "^18.2.0"
  }
}
```

**`vite.config.ts`** - Vite build configuration
**`tsconfig.json`** - TypeScript configuration

### Docker Configuration

**`Dockerfile`** - Server container image:
```dockerfile
FROM crystallang/crystal:latest
# ... build steps
```

**`docker-compose.yml`** - Development environment
**`docker-compose.prod.yml`** - Production deployment

### Git Configuration

**`.gitignore`** - Ignored files:
```
/bin/
/lib/
/node_modules/
*.db
.env
```

**`.github/workflows/`** - CI/CD workflows
**`.github/ISSUE_TEMPLATE/`** - Issue templates

## Data Flow

### Tunnel Registration Flow

```
CLI                          Server
 |                             |
 |--[WebSocket]--------------->|
 |                             |
 |--[RegisterTunnel]---------->|
 |                             |--[Validate subdomain]
 |                             |--[Check rate limit]
 |                             |--[Create tunnel]
 |<--[TunnelRegistered]--------|
 |                             |
 |--[Heartbeat]-------------->|
 |                             |
```

### HTTP Request Flow

```
Client          Server                 CLI
  |               |                    |
  |--[GET /]----->|                    |
  |               |--[Lookup tunnel]   |
  |               |--[Get client WS]   |
  |               |--[HttpRequest]---->|
  |               |                    |--[Forward to localhost:8080]
  |               |                    |--[Get response]
  |<--[Response]--|<--[HttpResponse]---|
```

## Adding New Features

### Adding a New Protocol Message

1. Define message in `src/core/protocol/messages.cr`
2. Add serializer in same file
3. Add tests in `spec/core/protocol/messages_spec.cr`
4. Update server handler in `src/server/`
5. Update client in `src/cli/`

### Adding a New CLI Command

1. Create command file in `src/cli/commands/`
2. Implement command class
3. Register in `src/cli/cli.cr`
4. Add tests in `spec/cli/`
5. Update README with usage

### Adding Inspector UI Feature

1. Create component in `web/src/components/`
2. Add TypeScript types in `web/src/types/`
3. Add WebSocket handler if needed
4. Update CLI to push data
5. Test in development (`npm run dev`)

## Module Dependencies

```
┌─────────────────────────────────────────┐
│            src/core/                    │
│  (Protocol & Types - No dependencies)   │
└─────────────────────────────────────────┘
          ▲               ▲
          │               │
    ┌─────┴─────┐   ┌─────┴─────┐
    │ src/server│   │  src/cli  │
    └───────────┘   └───────────┘
          │               │
          │               │
          └───────┬───────┘
                  ▼
         ┌─────────────────┐
         │  Crystal StdLib │
         └─────────────────┘

┌─────────────────────────────────────────┐
│          web/ (Inspector UI)            │
│  (React + TypeScript - Independent)     │
└─────────────────────────────────────────┘
```

## Code Organization Principles

### Separation of Concerns

- **Core:** Protocol and types only, no server/CLI logic
- **Server:** Tunnel routing and management
- **CLI:** Client-side tunnel creation and forwarding
- **Inspector:** Independent UI, communicates via WebSocket

### Shared Code

- Place shared code in `src/core/`
- Avoid duplicating logic between server and CLI
- Use protocol messages for communication

### Entry Points

- `src/server.cr` → `bin/sellia-server`
- `src/cli.cr` → `bin/sellia`
- `web/src/main.tsx` → Inspector UI

## Related Documentation

- [Prerequisites](../development/prerequisites.md) - Build dependencies
- [Building](../development/building.md) - Compile the codebase
- [Testing](../development/testing.md) - Test organization
- [Architecture](../architecture/) - System architecture overview
