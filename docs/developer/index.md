# Developer Guide

Guide for contributing to and extending Sellia.

## Overview

This section is for developers who want to contribute to Sellia, understand its architecture, or extend its functionality.

## Getting Started

### Prerequisites

- [Crystal](https://crystal-lang.org/install/) >= 1.10.0
- [Node.js](https://nodejs.org/) >= 18 (for inspector UI)
- Git
- Basic familiarity with WebSocket and HTTP protocols

### Setup Development Environment

```bash
# Clone repository
git clone https://github.com/watzon/sellia.git
cd sellia

# Install Crystal dependencies
shards install

# Install Node dependencies (for inspector UI)
cd web
npm install
cd ..

# Build debug binaries
shards build

# Run tests
crystal spec
```

## Development Workflow

### Making Changes

1. Create feature branch
2. Make changes
3. Add tests
4. Run tests
5. Submit pull request

```bash
# Create feature branch
git checkout -b feature/amazing-feature

# Make changes and test
crystal spec

# Commit changes
git commit -m "feat: add amazing feature"

# Push and create PR
git push origin feature/amazing-feature
```

## Documentation Sections

- [Architecture](architecture/) - System design and components
- [Project Structure](project-structure/) - Code organization
- [Development](development/) - Development setup and workflow
- [Inspector UI](inspector-ui/) - Web interface development
- [Server Components](server-components/) - Server-side code
- [CLI Components](cli-components/) - Client-side code
- [Contributing](contributing/) - Contribution guidelines
- [Release Process](release-process/) - How releases are made
- [Security](security/) - Security considerations

## Quick Reference

### Build Commands

```bash
# Debug build
shards build

# Release build (optimized)
shards build --release

# Run tests
crystal spec

# Run specific test
crystal spec spec/server_spec.cr
```

### Inspector UI Development

```bash
cd web

# Development server
npm run dev

# Build for production
npm run build

# Run tests
npm test

# Lint code
npm run lint
```

### Running Locally

```bash
# Terminal 1: Start server
LOG_LEVEL=debug ./bin/sellia-server --port 3000 --domain localhost

# Terminal 2: Start inspector UI dev server
cd web && npm run dev

# Terminal 3: Create tunnel
./bin/sellia http 3000 --open
```

## Code Quality

### Style Guide

- Follow [Crystal style guide](https://crystal-lang.org/reference/conventions/)
- Use meaningful variable names
- Add comments for complex logic
- Keep methods focused and small

### Testing

- Write tests for new features
- Maintain test coverage
- Test edge cases
- Use descriptive test names

### Documentation

- Document public APIs
- Update README for user-facing changes
- Add inline comments for complex code
- Keep documentation in sync with code

## Architecture Overview

Sellia consists of three main components:

### Server (`sellia-server`)
- WebSocket gateway for tunnel connections
- HTTP ingress for external requests
- Tunnel registry for active tunnels
- Rate limiting and authentication

### CLI Client (`sellia`)
- Tunnel client connecting to server
- WebSocket connection management
- Local HTTP proxy
- Request inspector server

### Inspector UI (React)
- Real-time request visualization
- WebSocket connection to CLI
- Request/response details
- Interactive debugging

## Communication Protocol

Sellia uses MessagePack over WebSocket for efficient binary communication:

- **Connection:** WebSocket handshake
- **Messages:** MessagePack-encoded binary data
- **Types:** Requests, responses, heartbeat, etc.

See [Architecture](architecture/) for details.

## Contributing

### Types of Contributions

- **Bug fixes:** Always welcome
- **Features:** Open an issue first to discuss
- **Documentation:** Improvements welcome
- **Tests:** Help improve coverage

### Pull Request Process

1. Fork the repository
2. Create your feature branch
3. Write tests for your changes
4. Ensure all tests pass
5. Update documentation if needed
6. Submit pull request

See [Contributing](contributing/) for detailed guidelines.

## Getting Help

### Resources

- [Crystal Documentation](https://crystal-lang.org/reference/)
- [MessagePack Spec](https://github.com/msgpack/msgpack)
- [WebSocket Protocol](https://websockets.spec.whatwg.org/)

### Community

- [GitHub Issues](https://github.com/watzon/sellia/issues)
- [GitHub Discussions](https://github.com/watzon/sellia/discussions)

## Development Topics

### Want to add a feature?

1. Check [Architecture](architecture/) to understand system design
2. Review [Project Structure](project-structure/) for code organization
3. Read [Development](development/) for setup and workflow
4. Follow [Contributing](contributing/) guidelines

### Want to improve the UI?

1. See [Inspector UI](inspector-ui/) for frontend development
2. UI is built with React + Vite
3. Uses WebSocket for real-time updates

### Want to understand the protocol?

1. Check [Architecture](architecture/) for protocol overview
2. See `src/core/protocol/` for message definitions
3. MessagePack over WebSocket

## Next Steps

- **New Contributors:** Start with [Contributing](contributing/)
- **Architecture:** See [Architecture](architecture/)
- **Setup:** Follow [Development](development/)
- **UI Work:** Check [Inspector UI](inspector-ui/)
