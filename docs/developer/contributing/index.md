# Contributing

How to contribute to Sellia.

## Overview

Thank you for your interest in contributing to Sellia! This document provides guidelines and instructions for contributing.

## Ways to Contribute

### Code Contributions

- **Bug fixes** - Fix reported issues
- **New features** - Add functionality (discuss first)
- **Performance** - Improve performance
- **Tests** - Increase test coverage
- **Documentation** - Improve documentation

### Non-Code Contributions

- **Bug reports** - Report issues with details
- **Feature requests** - Suggest improvements
- **Documentation** - Improve docs
- **Code review** - Review pull requests

## Getting Started

### 1. Fork and Clone

```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/your-username/sellia.git
cd sellia

# Add upstream remote
git remote add upstream https://github.com/watzon/sellia.git
```

### 2. Set Up Development Environment

See [Development](../development/) for complete setup instructions.

```bash
# Install dependencies
shards install
cd web && npm install && cd ..

# Build
shards build

# Run tests
crystal spec
```

### 3. Create Branch

```bash
# Update from upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/amazing-feature
```

## Code Style

### Crystal Code

Follow [Crystal style guide](https://crystal-lang.org/reference/conventions/):

- Two-space indentation
- Snake_case for methods and variables
- CamelCase for classes and modules
- Meaningful names
- Comments for complex logic

**Example:**

```crystal
# Good
module Sellia::Server
  class TunnelRegistry
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
  end
end

# Bad
class tunnelRegistry
  def Register(s, t)
    return false if @tunnels.has_key?(s)
    @tunnels[s] = t
  end
end
```

### TypeScript/React Code

- Use functional components with hooks
- TypeScript for all files
- Props interfaces
- Meaningful component names

**Example:**

```tsx
// Good
interface RequestListProps {
  requests: Request[];
  onSelect: (id: string) => void;
}

export function RequestList({ requests, onSelect }: RequestListProps) {
  return (
    <div className="request-list">
      {requests.map(req => (
        <RequestItem key={req.id} request={req} onClick={onSelect} />
      ))}
    </div>
  );
}

// Bad
export const RL = ({ r, o }) => (
  <div>
    {r.map(x => <Item k={x.id} r={x} c={o} />)}
  </div>
);
```

## Commit Messages

Use [conventional commits](https://www.conventionalcommits.org/):

### Format

```
<type>: <description>

[optional body]

[optional footer]
```

### Types

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks
- `perf:` - Performance improvements

### Examples

```bash
# Good
feat: add custom subdomain support
fix: prevent duplicate tunnel registrations
docs: update installation instructions
test: add tunnel registry tests
refactor: simplify message handling

# Bad
added stuff
fixed bug
update
changes
```

### Multi-Line Commits

```bash
feat(cli): add tunnel authentication

Add basic auth protection for tunnels.

- Add --auth flag to http command
- Require credentials for protected tunnels
- Update documentation

Closes #123
```