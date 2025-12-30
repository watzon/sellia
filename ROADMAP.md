# Sellia Roadmap

Updated: 2025-12-30

Scope: Open-source features only (Tier 1 + Tier 2 from the design doc). Multi-tenancy, billing, teams, and other enterprise SaaS features are intentionally excluded.

Legend: [x] done, [~] in progress, [ ] planned

## Status Snapshot (vs. 2025-12-27 plan)

### Tier 1 (Core)
- [x] HTTP/HTTPS tunnels with subdomain routing
- [x] WebSocket passthrough (HMR/Socket.io compatible)
- [x] Basic auth per tunnel
- [x] Request inspector (live stream, request/response details, copy as curl, clear history)
- [x] API key auth (single master key or optional auth)
- [x] Config file support + layered config resolution
- [x] Multiple tunnels via config (`sellia start`)
- [x] Auto-reconnect with backoff
- [x] Rate limiting and subdomain validation
- [ ] Reserved subdomains that persist across restarts
- [ ] SQLite-backed storage for API keys/reserved subdomains
- [ ] Documentation polish for self-hosted single-binary workflow

### Tier 2 (Advanced)
- [x] Path-based routing (single URL -> multiple local ports)
- [ ] TCP tunnels (databases, SSH, etc.)
- [ ] Custom domains (bring your own domain)
- [ ] Request replay
- [ ] IP allowlisting
- [ ] Request/response header modification
- [ ] Webhook signature verification helpers
- [ ] PostgreSQL storage option (optional, for larger self-hosted setups)
- [ ] Inspector UX polish (filters, JSON pretty-print, better search)

## Roadmap

### Milestone: Complete Tier 1 Storage + Stability
- [ ] Add SQLite persistence for API keys and reserved subdomains
- [ ] Reserved subdomain claims (persisted across server restarts)
- [ ] Clarify self-hosted binary + asset embedding docs
- [ ] Harden error handling and edge cases (timeouts, disconnects)

### Milestone: Tier 2 Protocol + Tunnel Expansion
- [ ] TCP tunnel protocol messages and server/CLI handlers
- [ ] TCP port allocation strategy (configurable ranges)
- [ ] Custom domain support and validation
- [ ] Request replay endpoints + inspector UI

### Milestone: Advanced Controls
- [ ] IP allowlisting (per tunnel or per account)
- [ ] Request/response header rewrites
- [ ] Webhook signature verification helpers (CLI + docs)
- [ ] Optional PostgreSQL storage backend

### Milestone: Distribution + Ops
- [x] Docker deployment (Dockerfile + compose)
- [ ] Homebrew/Scoop package definitions
- [ ] Release automation and signed binaries

## Non-Goals (Open Source)
- Multi-tenancy, billing, teams, SSO/SAML, audit logs, multi-region
