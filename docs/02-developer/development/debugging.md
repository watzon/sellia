# Debugging

This guide covers debugging techniques and tools for Sellia development.

## Table of Contents

- [Debug Logging](#debug-logging)
- [Crystal Debugger](#crystal-debugger)
- [Common Debugging Scenarios](#common-debugging-scenarios)
- [Debugging Tools](#debugging-tools)
- [Performance Profiling](#performance-profiling)
- [Network Debugging](#network-debugging)

## Debug Logging

### Enable Debug Output

Set the `LOG_LEVEL` environment variable:

```bash
# Server
LOG_LEVEL=debug ./bin/sellia-server --port 3000 --domain 127.0.0.1.nip.io

# CLI
LOG_LEVEL=debug ./bin/sellia http 8080 --server http://127.0.0.1:3000
```

**Note:** The `LOG_LEVEL` environment variable accepts: `debug`, `info`, `warn`, `error`, `fatal`. Default is `warn`.

### Debug Output Levels

Debug logs include:
- Connection lifecycle events
- Message serialization/deserialization
- Request/response details
- Error stack traces
- Performance metrics

Example debug output:
```
[DEBUG] [sellia.server.ws_gateway] Client connecting: ws://127.0.0.1:45678
[DEBUG] [sellia.server.ws_gateway] Received message: RegisterTunnel(subdomain: "myapp")
[DEBUG] [sellia.server.tunnel_registry] Registered tunnel: myapp -> client-123
[DEBUG] [sellia.server.http_ingress] Incoming request: GET /api/test
[DEBUG] [sellia.server.http_ingress] Forwarding to client: client-123
[DEBUG] [sellia.server.http_ingress] Response received: 200 OK (45ms)
```

### Selective Debugging

Modify the code temporarily to add specific debug output using the Log module:

```crystal
# In src/server/http_ingress.cr
Log = ::Log.for("sellia.server.http_ingress")

def handle_request(request)
  # Temporary debug output
  Log.debug { "Request headers: #{request.headers.inspect}" }
  Log.debug { "Request body size: #{request.body.size}" }

  # ... rest of code
end
```

## Crystal Debugger

### Using the Built-in Debugger

Crystal includes a command-line debugger:

```crystal
require "debug"

def some_function(x : Int32)
  y = x * 2
  breakpoint  # Execution pauses here
  y + 10
end
```

Run with debugging enabled:

```bash
crystal build src/debug_me.cr --debug
./debug_me
```

### Debugger Commands

When the debugger stops at a breakpoint:
- `step` or `s`: Step to next line
- `next` or `n`: Next line (step over function calls)
- `continue` or `c`: Continue execution
- `break <file>:<line>`: Set breakpoint
- `break <function>`: Set breakpoint at function
- `delete <n>`: Delete breakpoint n
- `backtrace` or `bt`: Show stack trace
- `locals`: Show local variables
- `help`: Show all commands

### Example Debugging Session

```crystal
# src/server/tunnel_registry.cr
def register_tunnel(subdomain : String, client_id : String) : Tunnel
  validate_subdomain(subdomain)
  breakpoint  # Add this for debugging

  if @tunnels.has_key?(subdomain)
    raise TunnelExistsError.new("Subdomain #{subdomain} already registered")
  end

  tunnel = Tunnel.new(subdomain, client_id)
  @tunnels[subdomain] = tunnel
  tunnel
end
```

```bash
# Run with debugger
crystal build src/server/main.cr --debug -o bin/sellia-server-debug
./bin/sellia-server-debug

# When breakpoint hits:
[1] breakpoint at src/server/tunnel_registry.cr:42
step
[2] step at src/server/tunnel_registry.cr:43
locals
  subdomain => "myapp"
  client_id => "client-123"
continue
```

## Common Debugging Scenarios

### Debugging Connection Issues

#### Scenario: Tunnel Not Connecting

```bash
# 1. Enable debug logging
LOG_LEVEL=debug ./bin/sellia http 8080 --server http://127.0.0.1:3000

# 2. Check server logs
# Look for: "Client connecting" messages

# 3. Verify WebSocket connection
# Use websocat or similar tool:
websocat ws://127.0.0.1:3000
```

#### Scenario: Requests Not Reaching Tunnel

```bash
# 1. Verify tunnel is registered
LOG_LEVEL=debug ./bin/sellia-server | grep "Registered tunnel"

# 2. Check HTTP ingress logs
LOG_LEVEL=debug ./bin/sellia-server 2>&1 | grep "http_ingress"

# 3. Test direct connection to local service
curl http://localhost:8080
```

### Debugging Protocol Issues

#### Scenario: Message Serialization Failures

```crystal
# Add debug output in protocol handler
Log = ::Log.for("sellia.protocol")

def serialize_message(message : Message) : Bytes
  Log.debug { "Serializing: #{message.class}" }
  Log.debug { "Message fields: #{message.inspect}" }

  MessagePack.pack(message)
rescue ex : Exception
  Log.error { "Serialization failed: #{ex.message}" }
  Log.error { "Message: #{message.inspect}" }
  raise ex
end
```

### Debugging Memory Issues

#### Check for Memory Leaks

```bash
# Run with memory tracking
crystal spec --time

# Use external tools
valgrind --leak-check=full ./bin/sellia-server
```

#### Monitor Memory Usage

```crystal
# Add memory monitoring
require "system"

def print_memory_usage
  usage = System.memory_usage
  puts "[DEBUG] Memory: #{usage.used_mb}MB used / #{usage.total_mb}MB total"
end
```

## Debugging Tools

### Logging Tools

#### Custom Logger

Create a custom logger for specific components:

```crystal
# src/utils/logger.cr
class DebugLogger
  INSTANCE = new

  def log(component : String, message : String)
    puts "[DEBUG] [#{component}] #{message}"
  end

  def log_request(request : HTTP::Request)
    log("HTTP", "#{request.method} #{request.path}")
    request.headers.each do |key, values|
      log("HTTP", "  #{key}: #{values.join(", ")}")
    end
  end
end

# Usage
DebugLogger::INSTANCE.log("Tunnel", "Connection established")
DebugLogger::INSTANCE.log_request(request)
```

### Network Debugging Tools

#### curl with Verbose Output

```bash
curl -v http://myapp.127.0.0.1.nip.io:3000/api/test
```

#### websocat for WebSocket Testing

```bash
# Install websocat
cargo install websocat

# Connect to WebSocket
websocat ws://127.0.0.1:3000

# Send MessagePack message
echo -e '\x81\xa7message\xahello' | websocat ws://127.0.0.1:3000
```

#### tcpdump for Packet Inspection

```bash
# Capture WebSocket traffic
sudo tcpdump -i lo -s 0 -w capture.pcap port 3000

# Analyze with Wireshark
wireshark capture.pcap
```

### Debugging Inspector UI

#### Browser DevTools

1. Open browser DevTools (F12)
2. Go to Network tab
3. Filter by WS (WebSocket)
4. Inspect WebSocket frames
5. View MessagePack payloads

#### React DevTools

```bash
cd web
npm install --save-dev @types/react

# Add to dev server
npm run dev
```

## Performance Profiling

### Crystal Built-in Profiling

```bash
# Run with timing
crystal spec --time

# Run with profiling
crystal build src/server.cr --release
time ./bin/sellia-server --port 3000
```

### Benchmark Critical Paths

```crystal
require "benchmark"

# Benchmark message serialization
message = create_test_message

Benchmark.bm do |x|
  x.report("serialize:") do
    10000.times { message.serialize }
  end
end
```

### Profile Memory Allocations

```crystal
# Track allocations
GC.stats

# Before operation
before = GC.stats.heap_size

# ... perform operation ...

# After operation
after = GC.stats.heap_size
puts "[DEBUG] Allocated: #{after - before} bytes"
```

## Network Debugging

### Test WebSocket Connection

```bash
# Using websocat
websocat -v ws://127.0.0.1:3000
```

### Inspect HTTP Headers

```bash
# View full headers
curl -v http://myapp.127.0.0.1.nip.io:3000/test

# View specific headers
curl -I http://myapp.127.0.0.1.nip.io:3000/test
```

### Monitor TCP Connections

```bash
# List all connections
lsof -i :3000

# Monitor connections in real-time
watch 'lsof -i :3000'
```

## Debugging Tips

### 1. Isolate the Problem

- Reproduce the issue consistently
- Simplify the scenario
- Test components in isolation

### 2. Add Strategic Logging

```crystal
# Log entry/exit of functions
def process_request(request)
  log_debug "Entering process_request"

  # ... code ...

  log_debug "Exiting process_request"
end
```

### 3. Use Assertions

```crystal
# Add temporary assertions
def validate_subdomain(subdomain : String)
  # Temporary: Catch invalid input early
  raise "Invalid subdomain: #{subdomain}" if subdomain.empty?

  # ... normal validation ...
end
```

### 4. Binary Search for Bugs

If you're not sure where the bug is:
1. Add logging at multiple points
2. Narrow down the location
3. Focus on that area

### 5. Check External Dependencies

```crystal
# Verify external service is working
begin
  response = HTTP::Client.get("http://localhost:8080")
  log_debug "External service reachable: #{response.status_code}"
rescue ex : Exception
  log_debug "External service error: #{ex.message}"
end
```

## Common Issues and Solutions

### Issue: "Address already in use"

```bash
# Find process using the port
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use a different port
./bin/sellia-server --port 3001
```

### Issue: "Connection refused"

```bash
# Verify server is running
lsof -i :3000

# Check firewall
sudo ufw status  # Linux
# System Preferences > Security > Firewall  # macOS
```

### Issue: WebSocket handshake fails

```bash
# Check server logs for errors
LOG_LEVEL=debug ./bin/sellia-server

# Verify WebSocket upgrade headers
curl -v -H "Upgrade: websocket" \
     -H "Connection: Upgrade" \
     -H "Sec-WebSocket-Key: test" \
     http://127.0.0.1:3000
```

### Issue: Subdomain not resolving

```bash
# Test DNS resolution
nslookup myapp.127.0.0.1.nip.io

# For nip.io, should resolve to 127.0.0.1
# If not, try using localhost as domain
```

## Remote Debugging

For production issues:

### Enable Remote Debugging (Caution)

```bash
# Only do this in a trusted environment
LOG_LEVEL=debug ./bin/sellia-server --port 3000 --domain example.com
```

### Collect Debug Information

```bash
# Server info
./bin/sellia-server --version

# System info
uname -a
crystal --version
node --version

# Network info
netstat -an | grep 3000
```

## Getting Help

When unable to resolve an issue:

1. Check existing [GitHub Issues](https://github.com/watzon/sellia/issues)
2. Enable debug logging and capture output
3. Create a minimal reproduction case
4. File a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Debug logs
   - Environment details (OS, Crystal version, etc.)

## Next Steps

- [Testing](testing.md) - Write tests to prevent bugs
- [Contributing Workflow](../contributing/workflow.md) - Submit fixes
- [Project Structure](../project-structure/source-layout.md) - Understand the codebase
