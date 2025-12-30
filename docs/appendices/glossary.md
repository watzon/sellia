# Glossary

Definitions and explanations of Sellia terminology and concepts.

## A

### API Key
A secret token used to authenticate your Sellia client with the tunnel server. Required for creating protected tunnels and accessing premium features.

See: [Authentication](../user/authentication/index.md)

---

## B

### Basic Auth
A simple authentication scheme that sends a username and password with each HTTP request using the `Authorization` header.

Format: `username:password`

Example:
```bash
sellia http 3000 --auth admin:secret
```

---

## C

### Client
The `sellia` command-line tool running on your local machine that establishes and maintains tunnel connections.

Contrast with: [Server](#server)

---

## D

### Database (SQLite)
Sellia uses SQLite for persisting tunnel state, reserved subdomains, and other data. Can be disabled with `SELLIA_NO_DB=1`.

---

## F

### Fallback Port
The default port used when a request path doesn't match any configured route. If no routes match and port > 0, the fallback port receives the request.

---

## H

### Host Header
The HTTP `Host` header that specifies which host the client is trying to reach. Sellia preserves this header when forwarding requests.

---

## I

### Inspector
A built-in web UI for inspecting HTTP requests flowing through your tunnels in real-time. Runs on `http://127.0.0.1:4040` by default.

Features:
- Live request monitoring
- Request/response details
- Headers and bodies
- Status codes and timing
- cURL command generation

See: [Inspector UI Guide](../user/inspector/index.md)

---

### Inspector Port
The local port on which the inspector web server listens. Default: `4040`.

Can be changed via:
- `--inspector-port` flag
- `inspector.port` config value

---

## L

### Local Host
The hostname or IP address of your local service that Sellia forwards requests to. Default: `localhost`.

Example:
```bash
sellia http 3000 --host 192.168.1.100
```

---

### Local Port
The port on your local machine that Sellia forwards HTTP requests to.

Example:
```bash
sellia http 3000  # Forwards to localhost:3000
```

---

## M

### MessagePack
A binary serialization format used for the tunnel protocol. Efficient and compact compared to JSON.

---

## P

### Protocol
The MessagePack-based wire protocol used for communication between the Sellia client and server over WebSocket.

Message types:
- Auth: `auth`, `auth_ok`, `auth_error`
- Tunnel: `tunnel_open`, `tunnel_ready`, `tunnel_close`
- Request: `request_start`, `request_body`, `response_start`, `response_body`, `response_end`
- WebSocket: `websocket_upgrade`, `websocket_frame`, `websocket_close`
- Keepalive: `ping`, `pong`

---

### Public URL
The publicly accessible URL that external users use to reach your tunneled service.

Format: `https://<subdomain>.sellia.me`

Example: `https://myapp.sellia.me`

---

## R

### Request Inspector
See: [Inspector](#inspector)

---

### Route
A path-based rule that forwards requests matching a specific path pattern to a different port or host.

Example:
```yaml
tunnels:
  app:
    port: 3000
    routes:
      - path: /api
        port: 8080  # Forward /api* to port 8080
```

---

### Route Pattern
A path pattern used for matching incoming requests. Can be:
- Exact: `/api`
- Wildcard prefix: `/api/*`
- Wildcard catch-all: `/*`

---

### Reserved Subdomain
A subdomain that has been permanently reserved for your account, preventing others from using it.

Managed via:
```bash
sellia admin reserved add myapp
sellia admin reserved remove myapp
```

---

## S

### Server
The centralized tunnel server (e.g., `sellia.me`) that accepts WebSocket connections from clients and forwards incoming HTTP requests to the appropriate client.

Contrast with: [Client](#client)

---

### Subdomain
The hostname prefix that identifies your tunnel. Combined with the server domain to form your public URL.

Format: `<subdomain>.sellia.me`

Examples:
- `myapp.sellia.me`
- `demo-v2.sellia.me`

If not specified, a random subdomain is assigned (e.g., `a3f7b2c1.sellia.me` - 8 random hex characters).

---

## T

### Tunnel
A secure, persistent connection between your local machine and the Sellia server, allowing external users to access your local service via a public URL.

### Tunnel Client
See: [Client](#client)

---

### Tunnel ID
A unique identifier assigned by the server when a tunnel is created. Used internally for routing requests.

---

### Tunnel Registry
Server-side storage of active tunnels and their metadata, including reserved subdomains and account ownership.

---

## V

### Vite
A modern frontend build tool used for developing and building the inspector UI.

- Dev server: `localhost:5173`
- Build output: `web/dist/`

---

## W

### WebSocket
A communication protocol that provides full-duplex communication channels over a single TCP connection. Used for:
- Client-server tunnel connection
- Inspector live updates
- End-to-end WebSocket passthrough

---

### WebSocket Passthrough
The ability to tunnel WebSocket connections from the public URL through to your local service, maintaining the WebSocket protocol end-to-end.

---

## Common Patterns

### Forwarding
The process of relaying HTTP requests from the public URL to your local service and returning responses.

### Proxying
Acting as an intermediary between the public internet and your local service, forwarding requests and responses transparently.

---

## Acronyms

| Acronym | Meaning |
|---------|---------|
| CLI | Command-Line Interface |
| HMR | Hot Module Replacement (Vite feature) |
| HTTP | HyperText Transfer Protocol |
| HTTPS | HTTP Secure (TLS/SSL) |
| UI | User Interface |
| URL | Uniform Resource Locator |
| WSS | WebSocket Secure |

---

## Related Concepts

### Reverse Proxy
Unlike a traditional reverse proxy (like nginx), Sellia creates tunnels from inside your network, eliminating the need for:
- Public IP addresses
- Router port forwarding
- Firewall configuration

---

### Port Forwarding
Traditional method of exposing local services to the internet. Sellia eliminates the need for port forwarding by using outbound WebSocket connections.

---

### ngrok
A similar commercial tunneling service. Sellia is an open-source alternative with a focus on simplicity and developer experience.

---

## See Also

- [Architecture Overview](../developer/architecture/index.md) - System design
- [Getting Started](../user/getting-started/index.md) - Basic concepts
- [Protocol Reference](../developer/architecture/protocol.md) - Wire protocol details
