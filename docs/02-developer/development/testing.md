# Testing

This guide covers running and writing tests for Sellia, including the test framework, test structure, and best practices.

## Running Tests

### Run All Tests

```bash
crystal spec
```

This runs all tests in the `spec/` directory.

### Run Specific Test File

```bash
crystal spec spec/server/tunnel_registry_spec.cr
```

### Run with Verbose Output

```bash
crystal spec --verbose
```

This shows detailed output for each test, including passing tests.

### Run with Error Details

```bash
crystal spec --error-trace
```

This shows full stack traces for errors, useful for debugging.

### Run Specific Test by Name

```bash
crystal spec spec/core/protocol/message_spec.cr -e "serialize"
```

Runs only tests matching the pattern "serialize".

## Test Structure

### Directory Layout

Tests mirror the source structure:

```
spec/
├── core/                    # Tests for src/core/
│   └── protocol/
│       └── message_spec.cr # Protocol message tests
├── server/                 # Tests for src/server/
│   ├── admin_api_spec.cr
│   ├── auth_provider_spec.cr
│   ├── connection_manager_spec.cr
│   ├── pending_request_spec.cr
│   ├── rate_limiter_spec.cr
│   ├── storage/
│   │   └── repositories_spec.cr
│   ├── tunnel_registry_spec.cr
│   └── ws_gateway_spec.cr
├── cli/                    # Tests for src/cli/
│   ├── config_spec.cr
│   ├── router_spec.cr
│   └── routing_integration_spec.cr
├── integration/            # Integration tests
│   ├── tunnel_spec.cr
│   └── websocket_spec.cr
├── spec_helper.cr          # Test configuration
└── sellia_spec.cr          # Basic tests
```

### Test File Naming

- Test files use the `_spec.cr` suffix
- Test files mirror the source file structure
- Example: `src/server/tunnel_registry.cr` → `spec/server/tunnel_registry_spec.cr`

## Writing Tests

### Basic Test Structure

```crystal
require "spec"
require "../../src/server/tunnel_registry"

describe Sellia::Server::TunnelRegistry do
  describe "#register_tunnel" do
    it "registers a new tunnel" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = registry.register_tunnel("my-subdomain", "client-id")

      tunnel.subdomain.should eq("my-subdomain")
      tunnel.client_id.should eq("client-id")
    end
  end

  describe "#get_tunnel" do
    it "returns existing tunnel" do
      registry = Sellia::Server::TunnelRegistry.new
      registry.register_tunnel("my-subdomain", "client-id")

      tunnel = registry.get_tunnel("my-subdomain")
      tunnel.should_not be_nil
      tunnel.subdomain.should eq("my-subdomain")
    end

    it "returns nil for non-existent tunnel" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = registry.get_tunnel("non-existent")

      tunnel.should be_nil
    end
  end
end
```

### Test Context and Setup

Use `before_each` for setup. Note that `spec_helper.cr` automatically handles database setup and cleanup:

```crystal
require "spec"
require "../../src/server/tunnel_registry"

describe Sellia::Server::TunnelRegistry do
  # The spec_helper already sets up the test database
  # and resets it before each test

  it "has no tunnels initially" do
    registry = Sellia::Server::TunnelRegistry.new
    registry.tunnel_count.should eq(0)
  end
end
```

### Testing Async Code

For testing WebSocket connections and async operations:

```crystal
describe Sellia::Server::WSGateway do
  it "handles client connection" do
    gateway = Sellia::Server::WSGateway.new(
      connection_manager: Sellia::Server::ConnectionManager.new,
      tunnel_registry: Sellia::Server::TunnelRegistry.new,
      auth_provider: Sellia::Server::AuthProvider.new(false, nil),
      pending_requests: Sellia::Server::PendingRequestStore.new,
      pending_websockets: Sellia::Server::PendingWebSocketStore.new,
      rate_limiter: Sellia::Server::CompositeRateLimiter.new(enabled: false),
      domain: "localhost",
      port: 3000,
      use_https: false
    )

    # Spawn server in background
    spawn do
      gateway.start("127.0.0.1", 0) # Port 0 = random available port
    end

    # Wait for server to start
    sleep 0.1

    # Connect client and test
    # ...
  end
end
```

### Testing Error Cases

```crystal
describe Sellia::Server::TunnelRegistry do
  it "raises error for duplicate subdomain" do
    registry = Sellia::Server::TunnelRegistry.new
    registry.register_tunnel("my-subdomain", "client-1")

    expect_raises(Sellia::Server::TunnelExistsError) do
      registry.register_tunnel("my-subdomain", "client-2")
    end
  end
end
```

### Mocking and Stubs

Crystal doesn't have built-in mocking, but you can use simple test doubles:

```crystal
# Test double for HTTP client
class FakeHTTPClient
  property responses = Hash(String, String).new

  def get(url : String) : String
    responses[url] || "default response"
  end
end

describe Sellia::Server::HTTPIngress do
  it "forwards request to tunnel" do
    fake_client = FakeHTTPClient.new
    fake_client.responses["http://localhost:8080"] = "tunnel response"

    ingress = Sellia::Server::HTTPIngress.new(
      tunnel_registry: Sellia::Server::TunnelRegistry.new,
      connection_manager: Sellia::Server::ConnectionManager.new,
      pending_requests: Sellia::Server::PendingRequestStore.new,
      pending_websockets: Sellia::Server::PendingWebSocketStore.new,
      rate_limiter: Sellia::Server::CompositeRateLimiter.new(enabled: false),
      domain: "localhost",
      landing_enabled: false
    )

    # Test forwarding logic
    # ...
  end
end
```

## Test Coverage

### Currently Tested Areas

- **Protocol Message Serialization**
  - MessagePack encoding/decoding
  - All message types (register, request, response, etc.)
  - Protocol version compatibility

- **Tunnel Registry**
  - Tunnel registration and removal
  - Subdomain validation
  - Duplicate detection
  - Client tracking

- **Connection Management**
  - WebSocket connection lifecycle
  - Client registration/deregistration
  - Heartbeat/timeout handling

- **HTTP Ingress**
  - Request routing to tunnels
  - Header forwarding
  - Response proxying

- **End-to-End Tunnel Flow**
  - Complete request/response cycle
  - WebSocket communication
  - Error handling

### Coverage Goals

Aim to maintain or improve test coverage with new changes:

- **Core Protocol:** 100% coverage (critical)
- **Server Components:** >80% coverage
- **CLI Components:** >70% coverage
- **Edge Cases:** Always test error paths

## Running Specific Test Suites

### Protocol Tests

```bash
crystal spec spec/core/protocol/
```

### Server Tests

```bash
crystal spec spec/server/
```

### CLI Tests

```bash
crystal spec spec/cli/
```

### Integration Tests

```bash
# End-to-end tunnel tests
crystal spec spec/integration/tunnel_spec.cr

# WebSocket integration tests
crystal spec spec/integration/websocket_spec.cr
```

Integration tests typically:
1. Start a test server
2. Create a tunnel client
3. Make HTTP requests
4. Verify complete flow
5. Clean up resources

## Test Best Practices

### 1. Descriptive Test Names

```crystal
# Good
it "returns existing tunnel for valid subdomain"

# Bad
it "works"
```

### 2. Test Both Success and Failure Cases

```crystal
describe "#get_tunnel" do
  context "with existing tunnel" do
    it "returns the tunnel"
  end

  context "with non-existent tunnel" do
    it "returns nil"
    it "does not raise error"
  end
end
```

### 3. Use Context for Related Tests

```crystal
describe "subdomain validation" do
  context "with valid subdomain" do
    it "accepts alphanumeric characters"
    it "accepts hyphens"
  end

  context "with invalid subdomain" do
    it "rejects special characters"
    it "rejects spaces"
    it "rejects reserved names"
  end
end
```

### 4. Keep Tests Focused

```crystal
# Good: One behavior per test
it "returns tunnel for existing subdomain"

# Bad: Testing multiple things
it "registers, retrieves, and deletes tunnel" # Split into 3 tests
```

### 5. Use Matchers Appropriately

```crystal
# Equality
tunnel.subdomain.should eq("my-subdomain")

# Nil checks
tunnel.should be_nil
tunnel.should_not be_nil

# Truthiness
result.should be_true
result.should be_false

# Collections
tunnels.size.should eq(5)
tunnels.should contain(tunnel)
```

### 6. Clean Up Resources

```crystal
describe Sellia::Server::TunnelRegistry do
  # Note: The spec_helper automatically handles database cleanup
  # between tests, so you don't need to manually clear resources

  it "cleans up after itself" do
    registry = Sellia::Server::TunnelRegistry.new
    # The database will be reset before the next test
  end
end
```

## Performance Testing

### Benchmarking

For performance-critical code:

```crystal
require "benchmark"

describe "message serialization" do
  it "serializes messages quickly" do
    message = create_test_message

    time = Benchmark.measure do
      1000.times do
        message.serialize
      end
    end

    # Should serialize < 1ms per message
    (time.total * 1000).should be < 1000
  end
end
```

## Continuous Integration

Tests run automatically on:
- Every pull request
- Every push to main branch
- Before release deployment

### CI Configuration

See `.github/workflows/ci.yml` for the complete CI configuration.

**Note:** The CI workflow runs both Crystal tests (`crystal spec`) and web tests (`npm test` in the `web/` directory).

## Debugging Tests

### Using --verbose

```bash
crystal spec --verbose
```

Shows all passing and failing tests with details.

### Using --error-trace

```bash
crystal spec --error-trace
```

Shows full stack traces for debugging failures.

### printf Debugging

```crystal
it "debugs something" do
  result = some_function

  # Temporary debug output
  puts "Result: #{result.inspect}"

  result.should eq(expected)
end
```

### Using debugger

Crystal has a built-in debugger:

```crystal
require "debug"

it "debugs with breakpoint" do
  result = some_function

  breakpoint  # Execution pauses here

  result.should eq(expected)
end
```

Run with:
```bash
crystal spec spec/some_spec.cr --debug
```

## Writing Testable Code

### Dependency Injection

```crystal
# Hard to test
class TunnelClient
  def initialize
    @http = HTTP::Client.new
  end
end

# Easy to test
class TunnelClient
  def initialize(@http : HTTP::Client)
  end
end

# In tests
fake_http = FakeHTTPClient.new
client = TunnelClient.new(fake_http)
```

### Avoid Global State

```crystal
# Hard to test
class Config
  @@instance = Config.new

  def self.instance
    @@instance
  end
end

# Easy to test
class Config
  def self.new(file_path : String)
    # Load from file
  end
end
```

## Next Steps

- [Debugging](debugging.md) - Debug techniques
- [Contributing Workflow](../contributing/workflow.md) - Submit your changes
