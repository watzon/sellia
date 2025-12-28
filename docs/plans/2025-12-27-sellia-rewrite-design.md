# Sellia Design Document

**Date:** 2025-12-27
**Status:** Approved

## Overview

Sellia is an open-source ngrok alternative written in Crystal, targeting individual developers with fair pricing. Named after the Crystal Tunnel in Elden Ring.

**Business model:** Open-core. Tiers 1-2 are fully open source and self-hostable. Tier 3 (teams, billing, multi-tenancy) is proprietary for the hosted SaaS at sellia.me.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      sellia.me (or self-hosted)             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │   Ingress   │───▶│   Server    │───▶│  Tunnel Pool    │  │
│  │  (HTTPS)    │    │  (Router)   │    │  (WebSockets)   │  │
│  └─────────────┘    └─────────────┘    └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ WebSocket (MessagePack)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Developer Machine                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │  Local App  │◀──▶│  Sellia CLI │◀──▶│ Inspector UI    │  │
│  │  :3000      │    │             │    │ :4040 (React)   │  │
│  └─────────────┘    └─────────────┘    └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
sellia/
├── src/
│   ├── core/           # Shared protocol, types, MessagePack schemas
│   │   ├── protocol.cr
│   │   ├── messages.cr
│   │   └── repositories/
│   ├── server/         # Tunnel server
│   │   ├── main.cr
│   │   ├── http_ingress.cr
│   │   ├── ws_gateway.cr
│   │   └── ...
│   └── cli/            # Client + inspector
│       ├── main.cr
│       ├── tunnel.cr
│       ├── inspector.cr
│       └── ...
├── spec/               # Tests
├── web/                # React dashboard (Vite + Tailwind v4)
├── shard.yml
├── justfile
└── docs/
```

## Feature Tiers

### Tier 1 - Core (MVP, open source)

- HTTP/HTTPS tunnels with custom subdomains
- WebSocket passthrough (for Vite HMR, Socket.io, etc.)
- Static/reserved subdomains (persist across restarts)
- Basic auth protection (`--auth user:pass`)
- Local request inspector (React UI at localhost:4040)
  - Live request stream
  - Expand headers/body, JSON pretty-print
  - Copy as curl
- API key authentication
- SQLite storage
- Config file support (`sellia.yml`)
- Self-hosted single binary deployment

### Tier 2 - Advanced (open source)

- TCP tunnels (databases, SSH, game servers)
- Path-based routing (single URL → multiple local ports)
- Custom domains (bring your own domain)
- Request replay
- IP allowlisting
- Webhook signature verification helpers
- Multiple simultaneous tunnels
- Request/response modification (headers)
- PostgreSQL storage option

### Tier 3 - SaaS (proprietary, sellia.me)

- Multi-tenancy
- User accounts & billing (Stripe)
- Team accounts with member management
- Usage analytics dashboard
- SSO/SAML
- Audit logs
- Reserved capacity / SLA
- Multiple edge regions

## Protocol & Transport

**Transport:** WebSocket over HTTPS (port 443). Firewall-friendly, well-supported in Crystal stdlib.

**Serialization:** MessagePack for all messages. Binary-efficient, handles raw bytes natively.

### Connection Flow

```
CLI                                     Server
 │                                         │
 │──── WSS connect to sellia.me/ws ───────▶│
 │                                         │
 │◀─── connection_ack ────────────────────│
 │                                         │
 │──── auth { api_key: "sk_..." } ────────▶│
 │                                         │
 │◀─── auth_ok { account_id, limits } ────│
 │                                         │
 │──── tunnel_open { type: http,          │
 │      subdomain: "myapp" } ─────────────▶│
 │                                         │
 │◀─── tunnel_ready { url, tunnel_id } ───│
 │                                         │
 │         ... tunnel established ...      │
 │                                         │
 │◀─── request_start { id, method,        │
 │      path, headers } ──────────────────│
 │                                         │
 │◀─── request_body { id, chunk } ────────│
 │                                         │
 │──── response_start { id, status,       │
 │      headers } ────────────────────────▶│
 │                                         │
 │──── response_body { id, chunk } ───────▶│
 │                                         │
 │──── response_end { id } ───────────────▶│
```

### Message Types

- **Control:** `auth`, `auth_ok`, `tunnel_open`, `tunnel_ready`, `tunnel_close`, `ping`, `pong`
- **Data:** `request_start`, `request_body`, `response_start`, `response_body`, `response_end`
- **TCP (Tier 2):** `tcp_connect`, `tcp_data`, `tcp_close`

Single WebSocket carries multiple tunnels and concurrent requests. Each request/connection gets a unique ID for routing.

## CLI Interface

### Commands

```bash
# Quick tunnels (flat commands)
sellia http 3000                      # HTTP tunnel to localhost:3000
sellia http 3000 --subdomain myapp    # Request specific subdomain
sellia http 3000 --auth user:pass     # Basic auth protection
sellia tcp 5432                       # TCP tunnel (Tier 2)

# From config file
sellia start                          # Launch tunnels from sellia.yml
sellia start --config ./other.yml     # Specify config path

# Account management
sellia auth login                     # Authenticate with API key
sellia auth logout
sellia auth status                    # Show current account

# Tunnel management
sellia status                         # List active tunnels
sellia stop <tunnel-id>               # Stop specific tunnel

# Self-hosted server
sellia serve                          # Start server
sellia serve --port 8080 --domain example.com
```

### Config Resolution (lowest to highest priority)

```
~/.config/sellia/sellia.yml    # User defaults (API key, default server)
         ↓ merge
~/.sellia.yml                   # User overrides
         ↓ merge
./sellia.yml                    # Project-specific tunnels
         ↓ merge
--config ./custom.yml           # Explicit config file
         ↓ merge
--subdomain, --port, etc.       # CLI flags (highest priority)
```

### Config File Example

```yaml
# ~/.config/sellia/sellia.yml (user defaults)
server: https://sellia.me
api_key: sk_live_xxxxx
inspector:
  port: 4040
  open: true
```

```yaml
# ./sellia.yml (project config)
tunnels:
  api:
    type: http
    port: 3000
    subdomain: myapp
    auth: user:pass

  frontend:
    type: http
    port: 5173
    subdomain: myapp-dev

  # Tier 2: path-based routing
  combined:
    type: http
    subdomain: myapp
    routes:
      - path: /api/*
        port: 3000
      - path: /*
        port: 5173

  # Tier 2: TCP
  database:
    type: tcp
    port: 5432
```

## Storage & Data Layer

### Database Abstraction

Repository pattern abstracts storage, allowing SQLite (default) or PostgreSQL (optional) backends.

### Server-side Storage

| Data | SQLite (self-hosted) | PostgreSQL (SaaS) |
|------|---------------------|-------------------|
| API keys | Yes | Yes |
| Reserved subdomains | Yes | Yes |
| Active tunnels | In-memory | In-memory + Redis |
| Request logs | No (client-side) | Optional opt-in |
| Usage metrics | Basic | Full analytics |

### Client-side Storage

| Data | Location |
|------|----------|
| API key | `~/.config/sellia/sellia.yml` |
| Request history | In-memory (session only) |
| Inspector preferences | `~/.config/sellia/sellia.yml` |

### Database Location

```bash
# Default
~/.local/share/sellia/sellia.db

# Or configured via
sellia serve --db ./data/sellia.db
SELLIA_DATABASE_URL=sqlite:./sellia.db
SELLIA_DATABASE_URL=postgres://user:pass@host/sellia
```

## Request Inspector

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Sellia CLI Process                      │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │  Tunnel Manager │───▶│  Request Store (in-memory)      │ │
│  │                 │    │  - Circular buffer, ~1000 reqs  │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│           │                            │                     │
│           │                            ▼                     │
│           │             ┌─────────────────────────────────┐ │
│           │             │  Inspector HTTP Server (:4040)  │ │
│           │             │  ├── GET /          → React SPA │ │
│           │             │  ├── GET /api/requests → list   │ │
│           │             │  └── WS  /api/live    → stream  │ │
│           │             └─────────────────────────────────┘ │
│           ▼                                                  │
│  ┌─────────────────┐                                        │
│  │  Local App      │                                        │
│  │  :3000          │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

### MVP Features

- Live request stream via WebSocket
- Click to expand request/response details
- JSON pretty-printing with syntax highlighting
- Copy as curl
- Status code color coding
- Basic text filter

## Server Architecture

### Components

```
src/server/
├── main.cr               # Entrypoint
├── http_ingress.cr       # Public HTTPS listener
├── ws_gateway.cr         # Client WebSocket handler
├── router.cr             # Subdomain → tunnel routing
├── tunnel_registry.cr    # Active tunnel state
├── tcp_allocator.cr      # Dynamic port management (Tier 2)
└── middleware/
    ├── auth.cr           # API key validation
    ├── rate_limit.cr     # Per-key rate limiting
    └── metrics.cr        # Request counting
```

### Request Flow (HTTP tunnel)

1. Browser hits `https://myapp.sellia.me/api/users`
2. HTTP Ingress receives request, extracts subdomain from Host header
3. Router looks up tunnel via `tunnel_registry.find_by_subdomain("myapp")`
4. Forward to client via WebSocket (request_start + request_body messages)
5. Client proxies to local app at `localhost:3000/api/users`
6. Response flows back (response_start + response_body + response_end)
7. HTTP Ingress sends response to browser

### Tunnel Lifecycle

```
Connected → Authenticated → Ready → Active → Closing → Closed
                                      ↑
                              (reconnect on drop)
```

### Graceful Shutdown

- SIGTERM triggers shutdown
- Stop accepting new tunnels
- Drain active requests (30s timeout)
- Close WebSocket connections with close frame
- Exit

## Build & Distribution

### Development

```bash
# Terminal 1: Vite dev server for inspector UI
cd web && npm run dev

# Terminal 2: CLI (proxies inspector to Vite)
shards run cli -- http 3000

# Terminal 3: Server
shards run server -- serve
```

Without `-Dembed_assets`, the CLI proxies inspector requests to `localhost:5173` for hot reload.

### Release Build

```bash
# Build React dashboard
cd web && npm run build

# Build all Crystal targets with embedded assets
shards build --release -Dembed_assets

# Outputs to:
#   bin/sellia
#   bin/sellia-server
```

### shard.yml Targets

```yaml
targets:
  sellia:
    main: src/cli/main.cr
  sellia-server:
    main: src/server/main.cr
```

### justfile

```just
# Development
dev-web:
    cd web && npm run dev

dev-cli *args:
    shards run cli -- {{args}}

dev-server *args:
    shards run server -- {{args}}

# Build
build-web:
    cd web && npm run build

build: build-web
    shards build --release -Dembed_assets

build-dev:
    shards build

# Testing
test:
    crystal spec

test-watch:
    watchexec -e cr crystal spec

# Release
release version:
    git tag v{{version}}
    git push origin v{{version}}

# Install locally
install: build
    cp bin/sellia /usr/local/bin/
    cp bin/sellia-server /usr/local/bin/

# Clean
clean:
    rm -rf bin/ web/dist/
```

### Distribution

| Platform | Method |
|----------|--------|
| macOS | Homebrew tap, direct binary |
| Linux | Direct binary, AUR, .deb/.rpm |
| Windows | Scoop, direct binary |
| Docker | `ghcr.io/watzon/sellia` |

### Install Script

```bash
curl -fsSL https://sellia.me/install.sh | sh
```

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | Crystal | Performance, Ruby-like syntax, single binary |
| HTTP Server | Built-in HTTP::Server | Simple routing needs, max control over WebSocket |
| Frontend | Vite + React + Tailwind v4 | Interactivity for inspector, modern tooling |
| Protocol | WebSocket + MessagePack | Firewall-friendly, efficient, good Crystal support |
| Auth | API keys (JWT later) | Simple for self-hosters, evolve for SaaS |
| Database | SQLite / PostgreSQL | Zero-ops default, scale when needed |
| Asset embedding | Compile-time with build flag | Single binary, dev hot-reload |

## Vite Dev Server Support

WebSocket passthrough is a Tier 1 requirement to support Vite HMR:

- HTTP tunnels handle `Upgrade: websocket` requests
- Headers preserved (`Host`, `Origin`, `Sec-WebSocket-*`)
- Bidirectional streaming for WebSocket connections

Vite config for tunneled HMR:

```js
export default defineConfig({
  server: {
    hmr: {
      host: 'myapp-vite.sellia.me',
      protocol: 'wss'
    }
  }
})
```

Path-based routing (Tier 2) will allow single URL for both app and Vite.

## TCP Tunnels (Tier 2)

Dynamic port allocation from configured range (e.g., 10000-20000). Server allocates on connection, client receives assigned port.

## Next Steps

1. Set up repository structure
2. Implement core protocol (MessagePack messages)
3. Build minimal server (auth + single HTTP tunnel)
4. Build minimal CLI (connect + proxy)
5. Add request inspector
6. Polish and release Tier 1
