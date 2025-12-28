# Contributing to Sellia

Thank you for your interest in contributing to Sellia! This document provides guidelines and information about contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Commit Messages](#commit-messages)
- [Testing](#testing)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Be kind to others, welcome newcomers, and focus on constructive feedback.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment (see [Development Setup](#development-setup))
4. Create a branch for your changes
5. Make your changes
6. Run tests to ensure nothing is broken
7. Submit a pull request

## How to Contribute

### Reporting Bugs

Before reporting a bug, please:

1. Search [existing issues](https://github.com/watzon/sellia/issues) to avoid duplicates
2. Use the latest version to see if the bug persists

When reporting a bug, include:

- **Clear title** describing the issue
- **Steps to reproduce** the behavior
- **Expected behavior** vs actual behavior
- **Environment details** (OS, Crystal version, Sellia version)
- **Logs or error messages** if applicable
- **Screenshots** if relevant

### Suggesting Features

Feature suggestions are welcome! Please:

1. Search existing issues to avoid duplicates
2. Describe the problem your feature would solve
3. Explain your proposed solution
4. Consider alternatives you've thought about

### Pull Requests

1. **Keep PRs focused** — one feature or fix per PR
2. **Update documentation** if your changes affect user-facing behavior
3. **Add tests** for new functionality
4. **Ensure all tests pass** before submitting
5. **Follow the code style** guidelines

## Development Setup

### Prerequisites

- [Crystal](https://crystal-lang.org/install/) >= 1.10.0
- [Node.js](https://nodejs.org/) >= 18 (for inspector UI)
- Git

### Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/sellia.git
cd sellia

# Add upstream remote
git remote add upstream https://github.com/watzon/sellia.git

# Install Crystal dependencies
shards install

# Install web UI dependencies
cd web && npm install && cd ..

# Build
shards build

# Run tests
crystal spec
```

### Running Locally

```bash
# Terminal 1: Start the server
./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# Terminal 2: Start a tunnel
./bin/sellia http 8080 --server http://127.0.0.1:3000

# Terminal 3 (optional): Run web UI in dev mode
cd web && npm run dev
```

## Code Style

### Crystal

- Follow the [Crystal style guide](https://crystal-lang.org/reference/conventions/coding_style.html)
- Use `crystal tool format` to format code
- Keep methods short and focused
- Add type annotations for public APIs
- Document public methods with comments

### TypeScript/React (Inspector UI)

- Use functional components with hooks
- Follow existing patterns in the codebase
- Use TypeScript strict mode

### General

- Write self-documenting code
- Add comments for complex logic
- Keep files focused on a single responsibility

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/). Format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Code style (formatting, etc.) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks |

### Scopes

- `server` — Tunnel server components
- `cli` — CLI client components
- `core` — Shared protocol/types
- `web` — Inspector UI

### Examples

```
feat(cli): add --timeout flag for connection timeout
fix(server): handle WebSocket close during request
docs: update installation instructions
test(core): add protocol message serialization tests
```

## Testing

### Running Tests

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/server/tunnel_registry_spec.cr

# Run with verbose output
crystal spec --verbose
```

### Writing Tests

- Place tests in `spec/` mirroring the `src/` structure
- Use descriptive test names
- Test both success and error cases
- Mock external dependencies when appropriate

### Test Coverage

Aim to maintain or improve test coverage with your changes. Currently tested:
- Protocol message serialization
- Tunnel registry operations
- Connection management
- End-to-end tunnel flow

## Questions?

Feel free to open an issue for questions or join discussions on existing issues. We're happy to help!
