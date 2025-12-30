# Code Style

This document outlines the code style conventions for Sellia, covering both Crystal and TypeScript/React code.

## Table of Contents

- [General Principles](#general-principles)
- [Crystal Style Guide](#crystal-style-guide)
- [TypeScript/React Style Guide](#typescriptreact-style-guide)
- [Documentation](#documentation)
- [File Organization](#file-organization)

## General Principles

### Self-Documenting Code

Write code that explains itself:

```crystal
# Good: Clear intent
def find_available_tunnel(subdomain : String) : Tunnel?
  @tunnels.find { |t| t.subdomain == subdomain && t.available? }
end

# Bad: Unclear purpose
def get(sub) : Tunnel?
  @t.find { |x| x.s == sub && x.a }
end
```

### Single Responsibility

Each function, class, and module should have one clear purpose:

```crystal
# Good: Single responsibility
class TunnelRegistry
  def register(tunnel : Tunnel)
    # Only handles registration
  end
end

class TunnelValidator
  def validate_subdomain(subdomain : String) : ValidationResult
    # Only handles validation
  end
end

# Bad: Multiple responsibilities
class TunnelHandler
  def register_and_validate_and_notify(subdomain, client_id)
    # Too many concerns
  end
end
```

### Keep Functions Short

Aim for functions that do one thing well:

```crystal
# Good: Focused
def register(tunnel : Tunnel) : Nil
  @mutex.synchronize do
    @tunnels[tunnel.id] = tunnel
    @by_subdomain[tunnel.subdomain] = tunnel

    @by_client[tunnel.client_id] ||= [] of Tunnel
    @by_client[tunnel.client_id] << tunnel
  end
end

# Bad: Too long, doing too much
def register(tunnel : Tunnel) : Nil
  # 100 lines of logic...
end
```

## Crystal Style Guide

### Follow Official Conventions

Sellia follows the [official Crystal style guide](https://crystal-lang.org/reference/conventions/coding_style.html).

Key conventions:

### Indentation and Formatting

Use **2 spaces** for indentation (no tabs):

```crystal
def process_request(request : HTTP::Request) : HTTP::Response
  if request.path == "/health"
    return health_response
  end

  # ... more code ...
end
```

### Naming Conventions

**Classes and Modules:** PascalCase

```crystal
class TunnelRegistry
  module Protocol
    class Message
    end
  end
end

# Actual code structure
module Sellia::Server
  class TunnelRegistry
    # ...
  end
end
```

**Methods and Variables:** snake_case

```crystal
def register(tunnel : Tunnel) : Nil
  tunnel_id = tunnel.id
  # ...
end

def find_by_subdomain(subdomain : String) : Tunnel?
  @mutex.synchronize { @by_subdomain[subdomain]? }
end
```

**Constants:** SCREAMING_SNAKE_CASE

```crystal
MAX_TUNNELS = 1000
DEFAULT_TIMEOUT = 30
```

**Type Variables:** PascalCase

```crystal
class Registry(T)
  def add(item : T)
    # ...
  end
end
```

### Type Annotations

**Public APIs:** Always include type annotations

```crystal
# Good: Clear types
def register(tunnel : Tunnel) : Nil
  # ...
end

def find_by_id(id : String) : Tunnel?
  # ...
end

# Bad: Unclear types
def register(tunnel)
  # ...
end
```

**Private Methods:** Can omit obvious types

```crystal
# Acceptable: Type is obvious
private def generate_id : String
  Random::Secure.hex(16)
end
```

### Method Definitions

**Use parentheses for method definitions with arguments:**

```crystal
# Good
def register(tunnel : Tunnel) : Nil
end

def find_by_subdomain(subdomain : String) : Tunnel?
end

# Good: No arguments, no parentheses
def size : Int32
  @mutex.synchronize { @tunnels.size }
end
```

**Method chaining:** Use block syntax for multi-line chains:

```crystal
# Good: Block syntax
result = tunnels
  .select { |t| t.active? }
  .map { |t| t.subdomain }
  .first?

# Avoid: Single-line chains that are too long
result = tunnels.select { |t| t.active? }.map { |t| t.subdomain }.first?
```

### Conditional Expressions

**Use `if` as an expression when it returns a value:**

```crystal
# Good
status = if tunnel.active?
  "active"
else
  "inactive"
end

# Also good for simple cases
status = tunnel.active? ? "active" : "inactive"

# Bad: Unnecessary ternary
result = some_condition ? true : false
# Use: result = some_condition
```

**Guard clauses** are preferred over deep nesting:

```crystal
# Good: Guard clause
def validate_subdomain(subdomain : String) : ValidationResult
  # Length check (DNS label: 1-63 chars, we require 3+ for usability)
  return ValidationResult.new(false, "Subdomain must be at least 3 characters") if subdomain.size < 3

  # Character validation
  return ValidationResult.new(false, "Subdomain can only contain lowercase letters, numbers, and hyphens") unless subdomain.matches?(/\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/i)

  # Main validation logic
  ValidationResult.new(true)
end
```

### String Interpolation

**Use double quotes and interpolation:**

```crystal
# Good
message = "Tunnel #{subdomain} registered for client #{client_id}"

# Good with method calls
Log.info { "Tunnel ready: #{message.url}" }
```

**Use single quotes for literal strings:**

```crystal
# Good
protocol = "MessagePack"
version = '1.0'

# Bad
protocol = "MessagePack"
version = "1.0"
```

### Exception Handling

**Specific exceptions:** Use specific exception types

```crystal
# Good
begin
  register_tunnel(subdomain, client_id)
rescue ex : TunnelExistsError
  handle_duplicate(ex)
rescue ex : ValidationError
  handle_invalid(ex)
end

# Acceptable: Generic exception when specific type doesn't matter
begin
  risky_operation
rescue ex : Exception
  log_error(ex)
  raise
end
```

### Comments

**When to add comments:**

```crystal
# Good: Explaining why
# We use a custom hash function here because the built-in
# hash doesn't handle Unicode subdomains correctly
def hash_subdomain(subdomain : String) : UInt64
  custom_hash(subdomain)
end

# Good: Documenting public APIs
# Validate subdomain according to DNS label rules and security constraints
#
# Parameters:
#   `subdomain`: The subdomain to validate
#
# Returns: A ValidationResult indicating success or containing an error message
def validate_subdomain(subdomain : String) : ValidationResult
  # ...
end

# Bad: Stating the obvious
# Increment the counter
counter += 1
```

### Structs vs Classes

**Use Struct for data objects:**

```crystal
# Good: Struct for immutable data
struct Tunnel
  property id : String
  property subdomain : String
  property client_id : String
  property created_at : Time
  property auth : String?

  def initialize(@id : String, @subdomain : String, @client_id : String, @auth : String? = nil)
    @created_at = Time.utc
  end
end

# Good: Struct for validation result
struct ValidationResult
  property valid : Bool
  property error : String?

  def initialize(@valid : Bool, @error : String? = nil)
  end
end

# Use Class for objects with identity/lifecycle
class TunnelRegistry
  # ... manages tunnel lifecycle
end
```

## TypeScript/React Style Guide

### Functional Components with Hooks

**Prefer functional components over class components:**

```typescript
// Good: Functional component with hooks
interface TunnelProps {
  subdomain: string;
  status: string;
}

export const TunnelCard: React.FC<TunnelProps> = ({ subdomain, status }) => {
  const [isActive, setIsActive] = useState(false);

  useEffect(() => {
    setIsActive(status === 'active');
  }, [status]);

  return (
    <div className={`tunnel-card ${isActive ? 'active' : ''}`}>
      <h3>{subdomain}</h3>
      <p>{status}</p>
    </div>
  );
};

// Avoid: Class components
class TunnelCard extends React.Component<TunnelProps, TunnelState> {
  // ...
}
```

### TypeScript Strict Mode

**Use TypeScript strict mode:**

```typescript
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true
  }
}

// Good: Explicit types
interface Tunnel {
  subdomain: string;
  client_id: string;
  created_at: Date;
}

// Bad: Implicit any
function processTunnel(tunnel: any) {
  // ...
}
```

### Component Structure

**Follow this order:**

1. Imports
2. Type definitions
3. Component declaration
4. Hooks
5. Event handlers
6. Helper functions
7. Render

```typescript
// 1. Imports
import { useState, useEffect } from 'react';
import { Tunnel } from '../types';

// 2. Types
interface TunnelListProps {
  tunnels: Tunnel[];
  onSelect: (tunnel: Tunnel) => void;
}

// 3. Component
export const TunnelList: React.FC<TunnelListProps> = ({ tunnels, onSelect }) => {
  // 4. Hooks
  const [filter, setFilter] = useState('');

  // 5. Event handlers
  const handleSelect = (tunnel: Tunnel) => {
    onSelect(tunnel);
  };

  // 6. Helper functions
  const filteredTunnels = tunnels.filter(t =>
    t.subdomain.includes(filter)
  );

  // 7. Render
  return (
    <div className="tunnel-list">
      {filteredTunnels.map(tunnel => (
        <TunnelCard
          key={tunnel.subdomain}
          tunnel={tunnel}
          onSelect={handleSelect}
        />
      ))}
    </div>
  );
};
```

### Naming Conventions

**Components:** PascalCase

```typescript
// Good
export const TunnelCard: React.FC<TunnelCardProps> = ({ ... }) => {
  // ...
};

// Bad
export const tunnelCard = ({ ... }) => {
  // ...
};
```

**Props interfaces:** PascalCase + "Props" suffix

```typescript
// Good
interface TunnelCardProps {
  subdomain: string;
}

// Bad
interface tunnelCard {
  subdomain: string;
}
```

**Event handlers:** "handle" prefix

```typescript
// Good
const handleClick = () => { };
const handleSubmit = () => { };
const handleTunnelSelect = (tunnel: Tunnel) => { };

// Bad
const click = () => { };
const submit = () => { };
```

### Hooks

**Custom hooks:** "use" prefix

```typescript
// Good: Custom hook
export const useTunnels = () => {
  const [tunnels, setTunnels] = useState<Tunnel[]>([]);

  useEffect(() => {
    fetchTunnels().then(setTunnels);
  }, []);

  return tunnels;
};

// Usage
const tunnels = useTunnels();
```

**Hook rules:**
- Only call hooks at the top level
- Don't call hooks inside loops, conditions, or nested functions
- Custom hooks should start with "use"

### Error Handling

**Use error boundaries for React errors:**

```typescript
class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  render() {
    if (this.state.hasError) {
      return <div>Something went wrong</div>;
    }
    return this.props.children;
  }
}
```

**Handle async errors properly:**

```typescript
// Good: Handle async errors
useEffect(() => {
  const fetchTunnels = async () => {
    try {
      const data = await api.getTunnels();
      setTunnels(data);
    } catch (error) {
      console.error('Failed to fetch tunnels:', error);
      setError(error.message);
    }
  };

  fetchTunnels();
}, []);

// Bad: Ignore errors
useEffect(() => {
  api.getTunnels().then(setTunnels);
}, []);
```

## Documentation

### Crystal Documentation

**Public APIs must be documented:**

```crystal
# Validate subdomain according to DNS label rules and security constraints
#
# Performs validation including:
# - Length checks (3-63 characters)
# - Character validation (alphanumeric and hyphens only)
# - Reserved subdomain checks
# - Availability checks
#
# Parameters:
#   `subdomain`: The subdomain to validate
#
# Returns: A ValidationResult indicating success or containing an error message
#
# Example:
# ```
# result = registry.validate_subdomain("myapp")
# result.valid? # => true
#
# result = registry.validate_subdomain("ab")
# result.error # => "Subdomain must be at least 3 characters"
# ```
def validate_subdomain(subdomain : String) : ValidationResult
  # ...
end
```

### TypeScript Documentation

**Use JSDoc comments:**

```typescript
/**
 * Handles incoming WebSocket messages from the server
 *
 * @param event - Message event containing JSON data
 * @returns void
 *
 * @example
 * ```typescript
 * ws.onmessage = (event) => {
 *   const data = JSON.parse(event.data);
 *   if (data.type === 'request') {
 *     setRequests(prev => [data.request, ...prev]);
 *   }
 * };
 * ```
 */
ws.onmessage = (event: MessageEvent) => {
  const data = JSON.parse(event.data);
  if (data.type === 'request') {
    setRequests(prev => [data.request, ...prev].slice(0, 1000));
  }
}
```

## File Organization

### Crystal Files

**One public class per file:**

```
src/server/
├── tunnel_registry.cr   # TunnelRegistry class
├── ws_gateway.cr        # WSGateway class
├── http_ingress.cr      # HTTPIngress class
├── connection_manager.cr # ConnectionManager class
└── storage/
    ├── database.cr      # Database class
    └── repositories.cr  # Repository classes
```

**File name matches class name:**
- `tunnel_registry.cr` contains `class TunnelRegistry`
- `ws_gateway.cr` contains `class WSGateway`
- Files are organized by module under `src/server/`, `src/cli/`, and `src/core/`

### TypeScript Files

**One component per file:**

```
web/src/
├── App.tsx                 # Main App component
├── main.tsx                # Entry point
└── components/
    ├── RequestList.tsx     # RequestList component (if extracted)
    └── [More components as the UI grows]
```

**Current structure (single-file components):**
The inspector UI currently uses a simple single-file structure with the main component in `App.tsx`. As the UI grows, consider extracting components:

```
web/src/
├── App.tsx                 # Main app component
├── components/
│   ├── RequestList.tsx
│   ├── RequestDetail.tsx
│   └── StatusIndicator.tsx
└── types.ts                # Shared types
```

## Formatting Tools

### Crystal Formatter

**Format all Crystal code:**

```bash
# Format all files
crystal tool format ./src

# Check formatting (CI will do this)
crystal tool format --check ./src

# Format specific file
crystal tool format ./src/server/tunnel_registry.cr
```

### TypeScript/React Formatter

**Use ESLint and Prettier:**

```bash
# Format all files
cd web
npm run format

# Check formatting
npm run format:check

# Format specific file
npm run format -- src/components/TunnelCard.tsx
```

## Code Review Checklist

Before submitting code, review:

- [ ] Code follows style guide
- [ ] Code is formatted (`crystal tool format --check`)
- [ ] Public APIs have documentation
- [ ] Tests are included and passing
- [ ] Complex logic has comments explaining "why"
- [ ] No commented-out code
- [ ] No console.log statements left in production code
- [ ] Error handling is appropriate
- [ ] No unnecessary complexity

## Additional Resources

- [Crystal Style Guide](https://crystal-lang.org/reference/conventions/coding_style.html)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [React Documentation](https://react.dev/)
- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)

## Next Steps

- [Commit Messages](commit-messages.md) - Write better commit messages
- [Testing](../development/testing.md) - Test your code
- [Workflow](workflow.md) - Understand the contribution process
