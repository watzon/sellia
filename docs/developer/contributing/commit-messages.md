# Commit Messages

This document outlines the commit message conventions used in Sellia, based on [Conventional Commits](https://www.conventionalcommits.org/).

## Table of Contents

- [Overview](#overview)
- [Format](#format)
- [Types](#types)
- [Scopes](#scopes)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Reverting Commits](#reverting-commits)

## Overview

Sellia uses **Conventional Commits** to provide:
- Structured commit history
- Automated changelog generation
- Easier code review
- Clear intent of changes

### Why Conventional Commits?

- **Automated Versioning**: Commit types determine version bumps (major/minor/patch)
- **Changelog Generation**: Automatic changelog from commit history
- **Code Review**: Easier to understand changes at a glance
- **Git Hooks**: Can enforce commit message format

## Format

### Basic Structure

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Example

```
feat(cli): add custom timeout flag for connections

Add a new --timeout flag that allows users to specify a custom
connection timeout in seconds. The default timeout remains 30 seconds.

Closes #123
```

### Components Explained

#### Type (Required)

The type of change. See [Types](#types) below.

#### Scope (Optional)

The component/module affected. See [Scopes](#scopes) below.

#### Description (Required)

A brief summary of the change:
- Use imperative mood ("add" not "added" or "adds")
- Lowercase first letter
- No period at the end
- Max 72 characters

#### Body (Optional)

Additional context:
- What was changed and why
- Motivation for the change
- Contrasts with previous behavior
- Wrap at 72 characters per line

#### Footer (Optional)

Metadata:
- Breaking changes: "BREAKING CHANGE: description"
- Closes issues: "Closes #123"
- References issues: "Refs #456"

## Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor |
| `fix` | Bug fix | Patch |
| `docs` | Documentation only | Patch |
| `style` | Code style (formatting, etc.) | Patch |
| `refactor` | Code change that neither fixes a bug nor adds a feature | Patch |
| `perf` | Performance improvement | Patch |
| `test` | Adding or updating tests | Patch |
| `chore` | Maintenance tasks | Patch |
| `ci` | CI/CD changes | Patch |
| `build` | Build system changes | Patch |
| `revert` | Revert a previous commit | Patch |

### When to Use Each Type

#### `feat`: New Feature

New user-facing functionality:

```
feat(cli): add --timeout flag for connection timeout
feat(server): implement custom domain support
feat(web): add request replay functionality
```

#### `fix`: Bug Fix

Fixes for bugs or unexpected behavior:

```
fix(server): handle WebSocket close during request processing
fix(cli): prevent memory leak in tunnel client
fix(web): correct timestamp display in inspector
```

#### `docs`: Documentation Only

Changes to documentation only:

```
docs: update installation instructions for macOS
docs(api): add protocol message examples
docs: clarify usage of --auth flag
```

#### `style`: Code Style

Code style changes (formatting, missing semicolons, etc.):

```
style: format Crystal code with crystal tool format
style(web): fix indentation in RequestInspector component
```

#### `refactor`: Code Refactoring

Code changes that neither fix bugs nor add features:

```
refactor(server): simplify tunnel registry logic
refactor(cli): extract validation into separate module
refactor(core): consolidate protocol message types
```

#### `perf`: Performance Improvement

Performance improvements:

```
perf(server): optimize message serialization
perf(cli): reduce memory allocations in tunnel client
perf(web): improve rendering performance for large request lists
```

#### `test`: Tests

Adding or updating tests:

```
test(server): add tunnel registry duplicate detection tests
test(ws): add WebSocket reconnection tests
test(core): increase test coverage for protocol messages
```

#### `chore`: Maintenance

Maintenance tasks, dependency updates, etc.:

```
chore: upgrade Crystal to 1.10.0
chore: update dependencies to latest versions
chore: remove watchtower and add HTTP-to-HTTPS redirect
```

#### `ci`: CI/CD

Changes to CI configuration:

```
ci: add automated testing workflow
ci: upgrade GitHub Actions to latest versions
ci: fix broken build configuration
ci: require approval environment for PR CI
```

#### `build`: Build System

Changes to build system or dependencies:

```
build: add SQLite development dependency
build: update shard.lock for latest dependencies
build: add Vite configuration for inspector UI
```

## Scopes

Scopes indicate which component/module is affected.

### Defined Scopes

| Scope | Description |
|-------|-------------|
| `server` | Tunnel server components |
| `cli` | CLI client components |
| `core` | Shared protocol/types |
| `web` | Inspector UI |
| `ws` | WebSocket protocol/handling |
| `db` | Database/storage layer |
| `protocol` | Protocol message handling |
| `registry` | Tunnel registry |
| `gateway` | WebSocket gateway |
| `ingress` | HTTP ingress handler |
| `client` | Tunnel client logic |
| `inspector` | Request inspector |
| `caddy` | Caddy integration |

### Scope Examples

```
feat(server): add custom domain validation
feat(cli): implement auto-reconnect with backoff
feat(core): add WebSocket frame serialization
feat(web): add request/response filters
fix(ws): handle malformed WebSocket frames
fix(server): prevent race condition in tunnel registration
feat(cli): display route table on tunnel connect
```

## Examples

### Simple Commit (No Body)

```
feat(cli): add --timeout flag for connection timeout
```

### Commit with Body

```
feat(server): implement reserved subdomain persistence

Reserved subdomains are now persisted to SQLite and survive
server restarts. This prevents race conditions where clients
could claim previously reserved subdomains.

The implementation adds a new Storage module that handles all
database operations, keeping the registry logic clean.

Closes #78
```

### Bug Fix

```
fix(server): handle WebSocket disconnection gracefully

Previously, when a WebSocket connection closed unexpectedly,
pending requests would hang indefinitely. Now, all pending
requests are cleaned up and return 502 Bad Gateway.

Fixes #102
```

### Breaking Change

```
feat(server): change tunnel registration API format

The tunnel registration message format has changed to include
additional metadata. Old clients will not be compatible with
new servers.

BREAKING CHANGE: Tunnel registration now requires `metadata` field
in RegisterTunnel message. Clients must be updated to include this
field.
```

### Documentation

```
docs: clarify usage of --auth flag

The --auth flag now includes better examples and explains
the difference between tunnel authentication and API key
authentication.
```

### Refactoring

```
refactor(server): extract tunnel registry into separate module

The tunnel registry logic has been extracted from the main
server class into a dedicated TunnelRegistry module. This improves
testability and makes the code easier to understand.
```

### Performance

```
perf(server): optimize MessagePack serialization for protocol messages

MessagePack serialization is now 2x faster by reusing buffers and
reducing allocations. This is especially noticeable under high load
with many concurrent tunnels.
```

### Testing

```
test(core): add comprehensive protocol message serialization tests

Added tests for all protocol message types, including edge cases
like empty strings, large payloads, and malformed data.
```

### Chores

```
chore: upgrade to Crystal 1.10.0

This upgrade includes bug fixes and performance improvements.
All tests pass with the new version.
```

## Best Practices

### 1. Use Imperative Mood

```
# Good
feat(cli): add timeout flag

# Bad
feat(cli): added timeout flag
feat(cli): adding timeout flag
```

### 2. Keep Description Short

```
# Good
fix(server): handle WebSocket close during request

# Bad
fix(server): handle the case where WebSocket connection closes
during an active HTTP request
```

### 3. Explain What and Why in Body

```
# Good
feat(server): add rate limiting for tunnel registration

To prevent abuse, tunnel registration is now rate-limited to
10 registrations per minute per IP address. This prevents
a single client from exhausting available subdomains.

# Bad
feat(server): add rate limiting
```

### 4. Reference Issues

```
# Good
feat(cli): add custom timeout flag

Closes #123
Refs #456

# Bad
feat(cli): add custom timeout flag
# See issue 123
```

### 5. One Commit Per Logical Change

```
# Good: Separate commits
feat(cli): add timeout flag
test(cli): add timeout flag tests
docs: document timeout flag usage

# Bad: All in one commit
feat(cli): add timeout flag, tests, and documentation
```

### 6. Make Commits Atomic

Each commit should be a self-contained unit that can be reverted if needed:

```
# Good: Atomic commit
feat(server): add tunnel registration rate limiting

# Bad: Non-atomic (changes multiple things)
feat(server): add rate limiting and fix formatting bug
```

### 7. Limit Line Length

```
# Good: Lines wrapped at 72 characters
feat(server): add rate limiting for tunnel registration

To prevent abuse, tunnel registration is now rate-limited to
10 registrations per minute per IP address. This prevents
a single client from exhausting available subdomains.

# Bad: Long lines
feat(server): add rate limiting for tunnel registration

To prevent abuse, tunnel registration is now rate-limited to 10 registrations per minute per IP address. This prevents a single client from exhausting available subdomains.
```

## Reverting Commits

Use the `revert` type to revert previous commits:

```
revert: feat(cli): add custom timeout flag

This reverts commit abc123 which introduced the timeout flag
due to compatibility issues with older servers.

Refs #150
```

## Commit Message Template

Use this template for writing commit messages:

```bash
<type>(<scope>): <subject>

<body>

<footer>
```

### Example Template Filled Out

```bash
feat(cli): add custom timeout flag for connections

Add a new --timeout flag that allows users to specify a custom
connection timeout in seconds. The default timeout remains 30 seconds.

The timeout applies to:
- Initial connection to the server
- WebSocket handshake
- Tunnel registration

Closes #123
```

## Tools and Automation

### Commit Linting

The project may use commitlint to enforce commit message format:

```bash
# .commitlintrc.json
{
  "extends": [
    "@commitlint/config-conventional"
  ],
  "rules": {
    "type-enum": [2, "always", ["feat", "fix", "docs", "style", "refactor", "perf", "test", "chore", "ci", "build", "revert"]],
    "scope-enum": [2, "always", ["server", "cli", "core", "web", "db", "protocol"]]
  }
}
```

### Commit Message Hooks

Install git hooks to validate commit messages:

```bash
#!/bin/bash
# .git/hooks/commit-msg

commit_regex='^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)(\(.+\))?: .{1,72}$'

if ! grep -qE "$commit_regex" "$1"; then
  echo "Invalid commit message format. Please use conventional commits."
  echo "Example: feat(cli): add timeout flag"
  exit 1
fi
```

## Common Mistakes

### Mistake 1: Too General

```
# Bad
fix: fix bug

# Good
fix(server): handle WebSocket close during request
```

### Mistake 2: Missing Context

```
# Bad
feat: add flag

# Good
feat(cli): add --timeout flag for connection timeout
```

### Mistake 3: Mixing Types

```
# Bad
feat/fix: add flag and fix bug

# Good (split into two commits)
feat(cli): add --timeout flag
fix(cli): handle timeout error correctly
```

### Mistake 4: Not Following Format

```
# Bad
Added timeout flag to CLI

# Good
feat(cli): add --timeout flag for connection timeout
```

## Changelog Generation

Conventional commits enable automatic changelog generation using tools like [conventional-changelog](https://github.com/conventional-changelog/conventional-changelog):

```bash
# Generate changelog
npx conventional-changelog -p angular -i CHANGELOG.md -s

# Output:
## Features
* **cli:** add --timeout flag for connection timeout (abc123)

## Bug Fixes
* **server:** handle WebSocket close during request (def456)
```

## Further Reading

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Conventional Changelog](https://github.com/conventional-changelog/conventional-changelog)
- [Commitlint](https://commitlint.js.org/)
- [How to Write a Git Commit Message](https://chris.beams.io/posts/git-commit/)

## Next Steps

- [Code Style](code-style.md) - Write clean code
- [Workflow](workflow.md) - Submit your changes
- [Testing](../development/testing.md) - Test your changes
