# Disabling the Inspector

The Sellia Inspector is enabled by default for debugging, but you can disable it to save resources or for production deployments. This guide explains when and how to disable the inspector.

## Why Disable the Inspector?

### Resource Usage

The inspector uses:
- **Memory**: ~1-5 KB per request for history
- **CPU**: Minimal overhead for request logging
- **File Descriptor**: One for the inspector UI

For high-traffic scenarios, this can add up.

### Production Deployments

In production, you typically:
- Use application-level logging instead
- Don't need real-time request inspection
- Want minimal resource overhead
- Have centralized monitoring

### Security Considerations

The inspector exposes:
- All request headers including auth tokens
- Request/response bodies
- Sensitive data in transit

Disable to prevent accidental exposure.

### Performance Optimization

For maximum tunnel performance:
- Eliminate any overhead
- Reduce memory footprint
- Minimize CPU usage

## How to Disable the Inspector

### Command Line Flag

Use the `--no-inspector` flag:

```bash
sellia http 8080 --no-inspector --server https://sellia.me
```

Output:
```
[Sellia] Tunnel established at: https://abc123.sellia.me
# No inspector URL shown
```

### Configuration and Environment

There is no config or environment variable to toggle the inspector. Use `--no-inspector` with `sellia http`. The `sellia start` command does not run the inspector.

## When to Disable

### 1. Production Tunnels

Always disable in production:

```bash
sellia http 8080 --no-inspector --server https://prod.sellia.me
```

### 2. High-Traffic Scenarios

For expected high load:

```bash
sellia http 8080 --no-inspector --server https://sellia.me
```

### 3. Sensitive Data

When handling sensitive information:

```bash
sellia http 8080 --no-inspector --auth secure:secret
```

### 4. Resource-Constrained Environments

Limited memory/CPU:

```bash
sellia http 8080 --no-inspector
```

### 5. Background/Service Tunnels

If you run a long-lived tunnel, use `sellia http --no-inspector` to avoid inspector overhead.

## When to Keep Inspector Enabled

### 1. Development

Always enable during development:

```bash
sellia http 8080 --open
```

### 2. Debugging

When troubleshooting issues:

```bash
sellia http 8080  # Inspector enabled by default
```

### 3. Testing

During API testing:

```bash
sellia http 8080 --open
```

### 4. Webhook Development

For webhook testing:

```bash
sellia http 3000 --subdomain webhooks --open
```

### 5. Low-Traffic Personal Tunnels

Personal use with low traffic:

```bash
sellia http 8080  # Fine to keep enabled
```

## Alternatives to Inspector

### Application Logging

Use your application's logging instead:

```javascript
// Express example
app.use((req, res, next) => {
  console.log({
    method: req.method,
    path: req.path,
    headers: req.headers,
    body: req.body
  });
  next();
});
```

### HTTP Logging Libraries

Use dedicated logging middleware:

```javascript
// Node.js - morgan
const morgan = require('morgan');
app.use(morgan('combined'));

// Python - logging
import logging
logging.basicConfig(level=logging.INFO)
```

### Centralized Logging

Send logs to logging services:

```javascript
// Send to Datadog, Loggly, etc.
const winston = require('winston');
require('winston-datadog-logs-transport');

const logger = winston.createLogger({
  transports: [
    new DatadogLogsTransport({
      apiKey: process.env.DD_API_KEY
    })
  ]
});
```

### APM Tools

Use Application Performance Monitoring:

- **Datadog**: Full request tracing
- **New Relic**: Performance monitoring
- **Prometheus + Grafana**: Metrics and dashboards
- **CloudWatch**: AWS integrated monitoring

## Performance Impact

### Memory Usage

With inspector (1000 requests):
```
Memory: ~5 MB
  - Request history: ~3 MB
  - UI overhead: ~2 MB
```

Without inspector:
```
Memory: ~0 MB (no additional overhead)
```

### CPU Overhead

With inspector:
```
CPU: +1-2% per 1000 req/min
```

Without inspector:
```
CPU: No overhead
```

### Request Latency

Inspector adds minimal latency:
```
Without inspector: 50ms average
With inspector: 51ms average (+1ms)
```

Disable to eliminate this overhead.

## CLI Examples

### Development (inspector on)

```bash
sellia http 3000 --open --server https://dev.sellia.me
```

### Production (inspector off)

```bash
sellia http 3000 --no-inspector --server https://prod.sellia.me
```

### Temporary debugging

```bash
sellia http 3000 --open
```

## Troubleshooting

### Inspector Still Running

If the inspector appears when you expect it to be disabled:

1. Confirm the command includes `--no-inspector`.
2. Ensure you are running `sellia http` (the inspector is not used by `sellia start`).
3. Check that an older `sellia http` process isn’t still running.

### Need Inspector Temporarily

If inspector is disabled but you need it:

1. Enable temporarily:
   ```bash
   sellia http 8080  # Remove --no-inspector flag
   ```

2. Use different tunnel for debugging:
   ```bash
   # Main tunnel (no inspector)
   sellia http 3000 --subdomain app-prod --no-inspector &

   # Debug tunnel (with inspector)
   sellia http 3001 --subdomain app-debug --open
   ```

3. If you need the inspector temporarily, run `sellia http` without `--no-inspector`.

### Port Already in Use

If inspector port (4040) is in use:

1. Use custom port:
   ```bash
   sellia http 8080 --inspector-port 5000
   ```

2. Disable inspector:
   ```bash
   sellia http 8080 --no-inspector
   ```

## Best Practices

### 1. Environment-Based Commands

Use shell aliases or scripts for consistent behavior:

```bash
# Development
alias sellia-dev='sellia http 3000 --open'

# Production
alias sellia-prod='sellia http 3000 --no-inspector'
```

### 2. Explicit in Production

Always include `--no-inspector` in production commands or service definitions.

### 3. Document Decision

Note in runbooks or deployment scripts why the inspector is disabled (e.g., security or performance).

### 4. Use Alternatives

Set up proper monitoring before disabling (e.g., centralized logging and APM).

## Migration Guide

### From Inspector to Logging

1. **Keep inspector during development**
   ```bash
   sellia http 8080 --open
   ```

2. **Add application logging**
   ```javascript
   app.use(morgan('combined'));
   ```

3. **Test with both enabled**
   ```bash
   # Compare inspector vs. application logs
   ```

4. **Deploy with logging only**
   Use `sellia http --no-inspector` in production.

5. **Monitor logs in production**
   ```bash
   tail -f /var/log/app.log
   ```

## Verification

### Verify Inspector is Disabled

```bash
# Start tunnel with --no-inspector
sellia http 8080 --no-inspector

# Output should NOT show:
# [Sellia] Inspector available at: http://localhost:4040

# Verify port not in use
lsof -i :4040
# Should return nothing
```

### Verify Inspector is Enabled

```bash
# Start tunnel without flag
sellia http 8080

# Output should show:
# [Sellia] Inspector available at: http://localhost:4040

# Verify port is in use
lsof -i :4040
# Should show sellia process
```

## Decision Tree

```
Is this a production tunnel?
├─ Yes → Disable inspector (--no-inspector)
│        Use application logging instead
│
└─ No (development/testing)
    ├─ Need to debug requests?
    │  ├─ Yes → Enable inspector (--open)
    │  └─ No → Optional (enabled by default)
    │
    └─ High traffic expected (>1000 req/min)?
       ├─ Yes → Consider disabling
       └─ No → Keep enabled
```

## Next Steps

- [Live Monitoring](./live-monitoring.md) - Using the inspector
- [Application Logging](../configuration/config-file.md) - Alternative logging
- [Production Deployment](../deployment/docker.md) - Production setup

## Quick Reference

| Scenario | Command |
|----------|---------|
| Disable inspector | `sellia http 8080 --no-inspector` |
| Enable inspector | `sellia http 8080` (default) |
| Auto-open inspector | `sellia http 8080 --open` |
| Custom inspector port | `sellia http 8080 --inspector-port 5000` |

## Checklist

Before disabling inspector in production:

- [ ] Application logging configured
- [ ] Centralized logging set up (optional)
- [ ] Team knows how to access logs
- [ ] Monitoring/alerting configured
- [ ] Debug procedures documented
- [ ] Can reproduce issues with logs only
- [ ] Performance metrics being collected
- [ ] Tested without inspector in staging
