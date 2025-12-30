# Live Request Monitoring

The Sellia Inspector provides real-time visibility into all HTTP requests flowing through your tunnels. Debug issues, analyze traffic, and understand your application's behavior without adding any logging code.

## What is the Inspector?

The inspector is a web-based UI that shows:
- All incoming requests to your tunnels
- Request details (headers, body, timing)
- Response information (status, headers, body)
- Real-time streaming of new requests
- Request history and search

Access it at `http://localhost:4040` when a tunnel is running.

## Starting the Inspector

The inspector starts automatically when you create a tunnel:

```bash
sellia http 8080 --server https://sellia.me
```

Output:
```
[Sellia] Tunnel established at: https://abc123.sellia.me
[Sellia] Inspector available at: http://localhost:4040
```

Open `http://localhost:4040` in your browser to see the inspector.

## Inspector Interface

### Main View

The main inspector interface shows:

1. **Request List** - Stream of incoming requests
2. **Request Details** - Click any request to see full details
3. **Status Bar** - Active tunnel info and connection status
4. **Toolbar** - Search, filter, and clear options

### Request Entry

Each request in the list shows:
- **Method** - GET, POST, PUT, DELETE, etc.
- **Path** - Request path and query string
- **Status** - HTTP status code with color coding
- **Time** - Timestamp of request
- **Duration** - Request processing time
- **Source IP** - Client IP address

### Status Code Colors

- **2xx (Green)** - Successful responses
- **3xx (Yellow)** - Redirects
- **4xx (Orange)** - Client errors
- **5xx (Red)** - Server errors

## Real-Time Streaming

### Automatic Updates

Requests appear in the inspector as they arrive:

1. Make a request to your tunnel
2. Request appears instantly in the inspector
3. No page refresh needed

### Example

```bash
# Terminal 1: Start tunnel
sellia http 8080 --open

# Terminal 2: Make requests
curl https://abc123.sellia.me/api/users
curl https://abc123.sellia.me/api/products
curl -X POST https://abc123.sellia.me/api/data
```

Watch all three requests appear in real-time in the inspector.

## Inspector Features

### 1. Live Streaming

Watch requests as they happen:

```
10:23:45  GET    /api/users          200  45ms
10:23:47  POST   /api/data           201  123ms
10:23:50  GET    /api/products       200  38ms
10:23:55  DELETE /api/users/123      204  52ms
```

### 2. Request Details

Click any request to see full details:

#### Request Information
- Full URL
- Method and path
- Query parameters
- Request headers
- Request body (if present)

#### Response Information
- Status code and message
- Response headers
- Response body (if present)
- Response size

#### Timing Information
- Total duration
- Time to first byte
- Processing time

### 3. Search and Filter

Find specific requests:

```bash
# In the inspector UI
# Search box in top right

# Search by path
/api/users

# Search by method
POST

# Search by status
404

# Search by content type
application/json
```

### 4. Clear History

Reset the request log:

```bash
# Click "Clear" button in toolbar
# Or use keyboard shortcut (Ctrl/Cmd + K)
```

### 5. Copy as cURL

Reproduce any request:

```bash
# Click on a request
# Click "Copy as cURL" button
# Paste in terminal to reproduce
```

See [Copy as cURL](./copy-as-curl.md) for details.

## Inspector Options

### Automatic Browser Opening

Open inspector automatically when tunnel starts:

```bash
sellia http 8080 --open
```

### Custom Inspector Port

Change the default port (4040) if needed:

```bash
sellia http 8080 --inspector-port 5000
```

Access at `http://localhost:5000`

### Disable Inspector

If you don't need the inspector:

```bash
sellia http 8080 --no-inspector
```

This saves resources and is useful for production tunnels.

## Use Cases

### 1. Debugging Webhooks

See exactly what webhook payloads you're receiving:

```bash
# Start tunnel with inspector
sellia http 3000 --subdomain webhooks --open

# Configure webhook URL in service
# https://webhooks.sellia.me/callback

# Watch webhook requests appear in real-time
```

### 2. API Development

Monitor API calls during development:

```bash
sellia http 4000 --subdomain api-dev --open

# Test your API from frontend
# See all requests in inspector
# Debug authentication, headers, responses
```

### 3. Performance Analysis

Identify slow requests:

```bash
sellia http 3000 --open

# Use your application
# Watch for requests with high duration
# Optimize slow endpoints
```

### 4. Testing Integrations

Verify third-party service integrations:

```bash
sellia http 5000 --subdomain stripe-test --open

# Configure Stripe webhook
# Make a test payment
# Inspect the webhook payload
```

### 5. Mobile App Development

Debug mobile app API calls:

```bash
sellia http 4000 --subdomain mobile-api --open

# Point mobile app to tunnel URL
# See all API requests from app
# Debug headers, auth, payloads
```

## Inspector vs. Application Logging

### Inspector Advantages

- No code changes needed
- See all requests, including ones your app doesn't log
- Real-time streaming
- Easy search and filtering
- Visual request details

### Application Logging Advantages

- Persistent across restarts
- Can log application-specific data
- Can log to files/services
- Custom formatting

### Best Practice

Use both:
- Inspector for real-time debugging
- Application logs for persistent records and production

## Performance Impact

### Minimal Overhead

The inspector adds negligible overhead:
- ~1-2ms per request
- No impact on tunnel performance
- Can be disabled with `--no-inspector`

### Memory Usage

Inspector maintains request history in memory:
- Each request: ~1-5 KB depending on size
- Typical usage: <100 MB for thousands of requests
- Clear history to free memory

### Disabling for Production

For high-traffic production tunnels, consider disabling:

```bash
sellia http 8080 --no-inspector
```

## Inspector Workflows

### Debugging a 404 Error

1. Start inspector: `sellia http 8080 --open`
2. Make request that returns 404
3. Click request in inspector
4. Check:
   - Request path is correct
   - Query parameters are present
   - Headers are correct
   - Compare to working requests

### Debugging Authentication

1. Start inspector
2. Make authenticated request
3. Click request in inspector
4. Check headers:
   - Authorization header format
   - Cookie values
   - Custom auth headers

### Debugging POST/PUT Data

1. Start inspector
2. Make POST/PUT request
3. Click request in inspector
4. Check request body:
   - JSON format
   - Form data
   - File uploads
   - Content-Type header

### Performance Debugging

1. Start inspector
2. Use your application
3. Sort requests by duration
4. Investigate slowest requests:
   - Check response size
   - Look at database queries
   - Profile application code

## Tips and Tricks

### 1. Keep Inspector Open

Leave the inspector open while developing:
- See all requests in real-time
- No need to refresh
- Instant feedback

### 2. Use Multiple Monitors

If you have multiple monitors:
- Monitor 1: Your application
- Monitor 2: Inspector
- Watch requests as you interact with app

### 3. Search by Status Code

Quickly find errors:

```bash
# Search for server errors
500

# Search for client errors
404

# Search for redirects
302
```

### 4. Compare Requests

Open multiple requests in tabs:
- Compare working vs. broken requests
- Spot differences in headers/body
- Identify what changed

### 5. Clear Before Testing

Clear history before specific test:

```bash
# Click "Clear" button
# Run specific test scenario
# Only see test requests
```

## Limitations

### Request History

- Stored in memory only
- Lost when tunnel stops
- Use application logging for persistence

### Large Bodies

Very large request/response bodies may be truncated:
- Maximum display size: ~1 MB
- Full data still forwarded through tunnel
- Check application logs for complete data

### Concurrent Tunnels

Each `sellia http` process has its own inspector:
- Use different `--inspector-port` values when running multiple processes
- There is no single view that aggregates multiple tunnels

## Troubleshooting

### Inspector Not Loading

If inspector won't load:

1. Verify tunnel is running:
   ```bash
   ps aux | grep sellia
   ```

2. Check inspector port:
   ```bash
   lsof -i :4040
   ```

3. Try different port:
   ```bash
   sellia http 8080 --inspector-port 5000
   ```

### No Requests Showing

If inspector is empty:

1. Make a test request:
   ```bash
   curl https://your-tunnel.sellia.me
   ```

2. Check tunnel is active:
   ```bash
   # Should see "Tunnel established"
   ```

3. Verify browser console for errors

### Inspector Slow

If inspector is slow:

1. Clear request history
2. Close other browser tabs
3. Check system resources
4. Consider disabling for high-traffic scenarios

## Next Steps

- [Request Details](./request-details.md) - Deep dive into request information
- [Copy as cURL](./copy-as-curl.md) - Reproduce requests
- [Disabling Inspector](./disabling-inspector.md) - When to disable
- [HTTP Tunnels](../tunnels/http-tunnels.md) - Tunnel basics

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl/Cmd + K` | Clear history |
| `Ctrl/Cmd + F` | Focus search |
| `Escape` | Close request details |
| `↑` / `↓` | Navigate requests |
| `Enter` | Open request details |
