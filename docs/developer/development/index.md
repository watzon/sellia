# Development

Setting up and working with the Sellia development environment.

## Overview

This section covers setting up a development environment, building the project, running tests, and workflow for contributing to Sellia.

## Prerequisites

### Required

- **Crystal** >= 1.10.0 - [Install Crystal](https://crystal-lang.org/install/)
- **Git** - Version control
- **Node.js** >= 18 - For inspector UI development
- **npm** or **yarn** - Node package manager

### Optional

- **Docker** - For containerized development
- **Docker Compose** - For multi-container setups
- **Make** - For using Makefile commands

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
```

### 2. Install Crystal Dependencies

```bash
# Install shards
shards install

# Verify installation
crystal --version
```

### 3. Install Node Dependencies

```bash
cd web
npm install
cd ..
```

### 4. Build Binaries

```bash
# Debug build (faster compilation)
shards build

# Release build (optimized)
shards build --release
```

Binaries will be in `./bin/`:
- `sellia` - CLI client
- `sellia-server` - Tunnel server

### 5. Run Tests

```bash
# Run all tests
crystal spec

# Run with verbose output
crystal spec --verbose

# Run specific test file
crystal spec spec/server/tunnel_registry_spec.cr
```

## Development Workflow

### Running Locally

#### Terminal 1: Start Server

```bash
LOG_LEVEL=debug ./bin/sellia-server --port 3000 --domain localhost
```

#### Terminal 2: Start Inspector UI (Dev Mode)

```bash
cd web
npm run dev
```

The CLI will proxy to Vite's dev server at `localhost:5173`.

#### Terminal 3: Create Tunnel

```bash
./bin/sellia http 3000 --open
```

Now access your local service at the tunnel URL and the inspector at `http://localhost:4040`.

### Making Changes

#### 1. Create Feature Branch

```bash
git checkout -b feature/amazing-feature
```

#### 2. Make Changes

Edit source files in:
- `src/server/` for server changes
- `src/cli/` for client changes
- `src/core/` for shared code
- `web/src/` for inspector UI changes

#### 3. Rebuild

```bash
# Crystal code
shards build

# Or for release
shards build --release

# Inspector UI (if changed)
cd web && npm run build
```

#### 4. Test Changes

```bash
# Run tests
crystal spec

# Test manually
./bin/sellia http 3000
```

#### 5. Commit Changes

```bash
git add .
git commit -m "feat: add amazing feature"
```

Use [conventional commits](https://www.conventionalcommits.org/):
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Adding tests
- `chore:` - Maintenance tasks

#### 6. Push and Create PR

```bash
git push origin feature/amazing-feature
```

Create pull request on GitHub.

## Development Tools

### Code Formatting

```bash
# Format Crystal code
crystal tool format src/

# Check formatting
crystal tool format --check src/
```

### Linting

```bash
# Inspector UI linting
cd web
npm run lint

# Fix linting issues
npm run lint:fix
```

### Type Checking

```bash
# Crystal type checking (automatic during compilation)
crystal build src/sellia.cr

# TypeScript type checking
cd web
npm run type-check
```

## Testing

### Crystal Tests

```bash
# All tests
crystal spec

# Verbose output
crystal spec --verbose

# Specific test file
crystal spec spec/server/tunnel_registry_spec.cr

# With line numbers
crystal spec --error-trace
```

### Writing Tests

Tests are in `spec/` directory:

```crystal
# spec/server/my_component_spec.cr
require "spec_helper"
require "../../src/server/my_component"

describe Sellia::MyComponent do
  it "does something" do
    component = Sellia::MyComponent.new
    component.do_something.should eq "expected result"
  end
end
```

### Inspector UI Tests

```bash
cd web

# Run tests
npm test

# Run in watch mode
npm test -- --watch

# Coverage
npm run test:coverage
```

## Debugging

### Crystal Debugging

```bash
# Enable debug output
LOG_LEVEL=debug ./bin/sellia-server --port 3000 --domain localhost

# Use error trace
crystal spec --error-trace

# Add debug output
puts "Debug: #{variable.inspect}"
```

### Inspector UI Debugging

```bash
cd web

# Start dev server with debugging
npm run dev

# Browser DevTools
# - React DevTools extension
# - Network tab for WebSocket
# - Console for errors
```

### WebSocket Debugging

Use browser DevTools or WebSocket clients:

```bash
# Install wscat
npm install -g wscat

# Connect to inspector WebSocket
wscat -c ws://localhost:4040
```

## Performance Profiling

### Crystal Profiling

```bash
# Build with profiling
crystal build --profile src/sellia-server.cr -o sellia-server-prof

# Run and generate profile
./sellia-server-prof
# ... use the application ...
# Kill with INT

# Analyze profile
crystal tool profile sellia-server-prof
```

### Memory Profiling

```bash
# Monitor memory usage
top -p $(pgrep sellia-server)

# Or with ps
ps aux | grep sellia
```

## Common Development Tasks

### Adding a New CLI Command

CLI commands are handled directly in `src/cli/main.cr`. To add a new command:

1. Add a new `when` clause in the `run` method:

```crystal
# In src/cli/main.cr
case command
when "mycommand"
  run_mycommand
# ... other commands
end
```

2. Implement the command method:

```crystal
private def self.run_mycommand
  # Command implementation
  puts "My custom command"
end
```

3. Add tests in `spec/cli/mycommand_spec.cr`

### Adding a New Protocol Message

1. Define in `src/core/protocol/messages/`:

```crystal
# src/core/protocol/messages/my_message.cr
module Sellia
  module Protocol
    class MyMessage
      include MessagePack::Serializable

      property field1 : String
      property field2 : Int32
    end
  end
end
```

2. Require it in `src/core/protocol.cr`

3. Handle in server and client

4. Add tests in `spec/core/protocol/message_spec.cr`

### Adding UI Components

1. Create in `web/src/components/`:

```tsx
// web/src/components/MyComponent.tsx
export function MyComponent() {
  return <div>My Component</div>;
}
```

2. Add to routing in `web/src/main.tsx`

3. Add styles in `web/src/styles/` or use Tailwind CSS classes

## Troubleshooting Development Issues

### Build Failures

**Problem:** Compilation errors

**Solutions:**
- Run `shards update`
- Clear cache: `rm -rf .crystal/`
- Check Crystal version: `crystal --version`

### Test Failures

**Problem:** Tests failing locally

**Solutions:**
- Ensure server is not using test ports
- Check for leftover processes: `lsof -i :3000`
- Run with `--error-trace` for details

### Inspector Not Working

**Problem:** Inspector UI not loading

**Solutions:**
- Ensure `npm install` was run
- Check Vite dev server is running
- Verify WebSocket connection in browser DevTools

## Continuous Integration

Sellia uses GitHub Actions for CI:

- Runs tests on every push
- Tests against multiple Crystal versions
- Lints code
- Runs on Linux and macOS

See `.github/workflows/` for CI configuration.

### Running CI Locally

```bash
# Install act (run GitHub Actions locally)
brew install act  # macOS

# Run CI
act push
```

## Best Practices

### Code Style

- Follow [Crystal style guide](https://crystal-lang.org/reference/conventions/)
- Use meaningful variable names
- Keep methods focused and small
- Add comments for complex logic

### Testing

- Write tests for new features
- Maintain test coverage
- Test edge cases
- Use descriptive test names

### Git Workflow

- Create feature branches
- Write meaningful commit messages
- Keep PRs focused
- Update documentation

## Next Steps

- [Project Structure](../project-structure/) - Understanding the codebase
- [Architecture](../architecture/) - System design
- [Contributing](../contributing/) - Contribution guidelines
