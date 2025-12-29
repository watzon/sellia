# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2025-12-28

### Added
- Multi-platform binary releases (Linux AMD64/ARM64, macOS Intel/ARM, Alpine)
- Watchtower for automatic container updates in deployment

### Changed
- Restructure public assets and add Open Graph tags for landing page

### Fixed
- Use native Docker for Linux builds instead of run-on-arch-action
- Update macOS Intel runner to macos-15-intel
- Add missing static libraries for Alpine builds

## [0.2.3] - 2025-12-28

### Added
- WebSocket passthrough support for Vite HMR

### Fixed
- Support multi-value HTTP headers for proper cookie handling
- Signal WebSocket upgrade success before spawning handler
- Prevent crash on WebSocket upgrade timeout race condition

## [0.2.2] - 2025-12-28

### Fixed
- Add mutex to prevent concurrent WebSocket writes
- Use Log.setup_from_env for consistent log configuration

### Changed
- Docker builds only server image, removed CLI and web stages

## [0.2.1] - 2025-12-28

### Fixed
- Prevent tunnel disconnection from unhandled exceptions

## [0.2.0] - 2025-12-28

### Added
- Embedded landing page with crystal theme
- Cloudflare DNS challenge support for instant wildcard certs

### Fixed
- Prevent 'Headers already sent' errors

### Changed
- Simplify TLS config to use Cloudflare DNS by default

## [0.1.1] - 2025-12-28

### Added
- `/tunnel/verify` endpoint for Caddy on-demand TLS

### Fixed
- Allow base domain in TLS verification endpoint
- Remove deprecated Caddy on_demand_tls options
- Load .env file in production compose
- Don't append internal port when behind HTTPS proxy

### Changed
- Default server changed to to.sellia.me

## [0.1.0] - 2025-12-28

Initial release.

### Added
- Custom MessagePack protocol over WebSockets for tunnel communication
- Server with HTTP ingress, WebSocket gateway, and tunnel registry
- CLI with tunnel client, local proxy, and layered configuration
- Request inspector with embedded React UI at localhost:4040
- Docker deployment with Caddy for TLS
- GitHub Actions for CI and multi-arch Docker builds
- Production hardening features (health checks, timeouts, graceful shutdown)

[Unreleased]: https://github.com/watzon/sellia/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/watzon/sellia/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/watzon/sellia/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/watzon/sellia/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/watzon/sellia/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/watzon/sellia/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/watzon/sellia/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/watzon/sellia/releases/tag/v0.1.0
