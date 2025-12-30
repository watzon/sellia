# Inspector UI Component Architecture

Overview of the React component structure and architecture of the Sellia Inspector UI.

## Overview

The Inspector UI is a single-page React application built with TypeScript and Tailwind CSS. It follows a functional component pattern with hooks for state management and side effects.

## File Structure

```
web/src/
├── main.tsx          # Application entry point
├── App.tsx           # Root component with all UI logic
└── index.css         # Global styles (Tailwind)
```

> **Note:** Currently the entire UI is contained in a single `App.tsx` file. As the UI grows, consider splitting into multiple components.

---

## Component Hierarchy

```
App (Root Component)
├── Header
│   ├── Title
│   ├── Connection Status Badge
│   └── Clear All Button
├── Main Content Area
│   ├── Request List (Left Panel)
│   │   └── Request Item (repeated)
│   └── Request Detail (Right Panel)
│       ├── Request Header
│       ├── Copy as curl Button
│       ├── Request Headers
│       ├── Route Info (if routed)
│       ├── Request Body (if present)
│       ├── Response Headers
│       └── Response Body (if present)
```

---

## Root Component: App

**Location:** `web/src/App.tsx`

The `App` component is the main and only component in the current implementation.

### Responsibilities

1. **State Management**
   - Request list
   - Selected request
   - WebSocket connection status
   - Reconnection handling

2. **Data Fetching**
   - Load historical requests on mount
   - Subscribe to live WebSocket updates

3. **UI Rendering**
   - Request list panel
   - Request detail panel
   - Connection status indicator

---

## Data Models

### Request Interface

```typescript
interface Request {
  id: string                      // Unique request ID
  method: string                  // HTTP method (GET, POST, etc.)
  path: string                    // Request path
  statusCode: number              // HTTP status code
  duration: number                // Request duration in ms
  timestamp: Date                 // Request timestamp
  requestHeaders: Record<string, string>
  requestBody?: string            // Optional request body
  responseHeaders: Record<string, string>
  responseBody?: string           // Optional response body
  matchedRoute?: string           // Matched route pattern
  matchedTarget?: string          // Target host:port
}
```

---

## State Management

### Component State

```typescript
const [requests, setRequests] = useState<Request[]>([])
const [selected, setSelected] = useState<Request | null>(null)
const [connected, setConnected] = useState(false)
const [reconnectCounter, setReconnectCounter] = useState(0)
```

#### State Variables

| State | Type | Purpose |
|-------|------|---------|
| `requests` | `Request[]` | List of all captured requests (max 1000) |
| `selected` | `Request \| null` | Currently selected request for detail view |
| `connected` | `boolean` | WebSocket connection status |
| `reconnectCounter` | `number` | Incremented to trigger WebSocket reconnect |

---

## Lifecycle Effects

### 1. Load Historical Requests

```typescript
useEffect(() => {
  fetch('/api/requests')
    .then(r => r.json())
    .then(data => setRequests(data))
    .catch(console.error)
}, [])
```

**Purpose:** Load previously captured requests on page load.

**Endpoint:** `GET /api/requests`

**Dependencies:** Runs once on mount (empty dependency array).

---

### 2. WebSocket Connection

```typescript
useEffect(() => {
  const ws = new WebSocket(`ws://${window.location.host}/api/live`)

  ws.onopen = () => setConnected(true)

  ws.onclose = () => {
    setConnected(false)
    setTimeout(() => {
      setReconnectCounter(prev => prev + 1)
    }, 3000)
  }

  ws.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data)
      if (data.type === 'request') {
        setRequests(prev => [data.request, ...prev].slice(0, 1000))
      }
    } catch (e) {
      console.error('Failed to parse message:', e)
    }
  }

  return () => ws.close()
}, [reconnectCounter])
```

**Purpose:** Establish WebSocket connection for live updates.

**Behaviors:**
- Connects to `/api/live` WebSocket endpoint
- Updates connection status
- Auto-reconnects after 3 seconds on disconnect
- Adds new requests to beginning of list
- Limits to 1000 most recent requests
- Cleans up WebSocket on unmount

**Dependencies:** Re-runs when `reconnectCounter` changes (triggers reconnect).

---

## UI Components

> **Current Implementation:** All UI components are implemented inline within `App.tsx`. The following sections describe the actual implementation structure.

### Header

```tsx
<header className="border-b border-gray-700 px-4 py-3 flex items-center justify-between">
  <div className="flex items-center gap-3">
    <h1 className="text-lg font-semibold">Sellia Inspector</h1>
    <span className={`text-xs px-2 py-0.5 rounded ${
      connected ? 'bg-green-600' : 'bg-red-600'
    }`}>
      {connected ? 'Live' : 'Disconnected'}
    </span>
  </div>
  <button
    onClick={async () => {
      await fetch('/api/requests/clear', { method: 'POST' })
      setRequests([])
    }}
    className="text-sm text-gray-400 hover:text-white"
  >
    Clear All
  </button>
</header>
```

**Features:**
- Title and connection status
- Live/Disconnected badge (green/red)
- Clear All button to reset request list

---

### Request List (Left Panel)

```tsx
<div className="w-1/2 border-r border-gray-700 overflow-y-auto">
  {requests.length === 0 ? (
    <div className="p-8 text-center text-gray-500">
      Waiting for requests...
    </div>
  ) : (
    requests.map(req => (
      <div
        key={req.id}
        onClick={() => setSelected(req)}
        className={`px-4 py-2 border-b border-gray-800 cursor-pointer hover:bg-gray-800 ${
          selected?.id === req.id ? 'bg-gray-800' : ''
        }`}
      >
        <div className="flex items-center gap-3">
          <span className={`font-mono ${statusColor(req.statusCode)}`}>
            {req.statusCode}
          </span>
          <span className="font-mono text-sm text-gray-300">
            {req.method}
          </span>
          <span className="font-mono text-sm truncate flex-1">
            {req.path}
          </span>
          {req.matchedTarget && (
            <span className="text-xs text-gray-500 font-mono">
              → {req.matchedTarget}
            </span>
          )}
          <span className="text-xs text-gray-500">
            {req.duration}ms
          </span>
        </div>
      </div>
    ))
  )}
</div>
```

**Features:**
- Shows "Waiting for requests..." when empty
- Lists up to 1000 requests
- Highlights selected request
- Click to select for detail view

**Request Item Display:**
- Status code (color-coded)
- HTTP method
- Request path
- Target (if routed)
- Duration in ms

---

### Request Detail (Right Panel)

```tsx
<div className="w-1/2 overflow-y-auto p-4">
  {selected ? (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-lg font-semibold">
          {selected.method} {selected.path}
        </h2>
        <button
          onClick={() => copyAsCurl(selected)}
          className="text-sm px-3 py-1 bg-gray-700 rounded hover:bg-gray-600"
        >
          Copy as curl
        </button>
      </div>

      <section>
        <h3 className="text-sm font-semibold text-gray-400 mb-2">Request Headers</h3>
        <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
          {JSON.stringify(selected.requestHeaders, null, 2)}
        </pre>
      </section>

      {selected.matchedRoute && (
        <section>
          <h3 className="text-sm font-semibold text-gray-400 mb-2">Route</h3>
          <div className="bg-gray-800 p-3 rounded text-sm font-mono">
            {selected.matchedRoute} → {selected.matchedTarget}
          </div>
        </section>
      )}

      {selected.requestBody && (
        <section>
          <h3 className="text-sm font-semibold text-gray-400 mb-2">Request Body</h3>
          <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
            {selected.requestBody}
          </pre>
        </section>
      )}

      <section>
        <h3 className="text-sm font-semibold text-gray-400 mb-2">Response Headers</h3>
        <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
          {JSON.stringify(selected.responseHeaders, null, 2)}
        </pre>
      </section>

      {selected.responseBody && (
        <section>
          <h3 className="text-sm font-semibold text-gray-400 mb-2">Response Body</h3>
          <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto whitespace-pre-wrap">
            {selected.responseBody}
          </pre>
        </section>
      )}
    </div>
  ) : (
    <div className="h-full flex items-center justify-center text-gray-500">
      Select a request to view details
    </div>
  )}
</div>
```

**Features:**
- Shows full request/response details
- Copy as cURL button
- Headers display
- Body display (if present)
- Route information (if routed)

---

## Helper Functions

### Status Color Coding

```typescript
const statusColor = (code: number) => {
  if (code < 300) return 'text-green-500'
  if (code < 400) return 'text-blue-500'
  if (code < 500) return 'text-yellow-500'
  return 'text-red-500'
}
```

**Purpose:** Returns Tailwind class for status code coloring.

| Range | Color | Meaning |
|-------|-------|---------|
| 2xx | Green | Success |
| 3xx | Blue | Redirect |
| 4xx | Yellow | Client Error |
| 5xx | Red | Server Error |

---

### Copy as cURL

```typescript
const copyAsCurl = (req: Request) => {
  const headers = Object.entries(req.requestHeaders)
    .map(([k, v]) => `-H '${k}: ${v}'`)
    .join(' ')
  const curl = `curl -X ${req.method} ${headers} '${window.location.origin}${req.path}'`
  navigator.clipboard.writeText(curl)
}
```

**Purpose:** Generate and copy cURL command to clipboard.

**Format:**
```bash
curl -X GET -H 'User-Agent: ...' -H 'Accept: ...' 'https://myapp.sellia.me/path'
```

---

## Styling

### Tailwind CSS

All styling uses Tailwind utility classes:

```tsx
// Dark theme colors
bg-gray-900        // Dark background
text-gray-100      // Light text
border-gray-700    // Borders
hover:bg-gray-800  // Hover states

// Status colors
text-green-500     // 2xx status
text-blue-500      // 3xx status
text-yellow-500    // 4xx status
text-red-500       // 5xx status
```

### Layout

- **Flexbox** for one-dimensional layouts
- **Fixed dimensions** for panel split (50/50)
- **Overflow scroll** for list and detail panels
- **Spacing** using Tailwind spacing scale

---

## Future Component Structure (Suggested)

As the UI grows, consider splitting into:

```
src/
├── components/
│   ├── Header/
│   │   ├── Header.tsx
│   │   └── ConnectionStatus.tsx
│   ├── RequestList/
│   │   ├── RequestList.tsx
│   │   └── RequestItem.tsx
│   ├── RequestDetail/
│   │   ├── RequestDetail.tsx
│   │   ├── RequestHeaders.tsx
│   │   ├── RequestBody.tsx
│   │   └── CopyAsCurlButton.tsx
│   └── shared/
│       ├── StatusBadge.tsx
│       └── Timestamp.tsx
├── hooks/
│   ├── useWebSocket.ts
│   └── useRequests.ts
├── types/
│   └── request.ts
└── utils/
    └── curl.ts
```

---

## Performance Considerations

### Request Limit

```typescript
setRequests(prev => [data.request, ...prev].slice(0, 1000))
```

**Why:** Limits memory usage by keeping only 1000 most recent requests.

### WebSocket Reconnection

```typescript
setTimeout(() => {
  setReconnectCounter(prev => prev + 1)
}, 3000)
```

**Why:** Prevents tight reconnect loops, gives server time to recover.

---

## Accessibility

### Keyboard Navigation

- Currently limited
- Future: Add keyboard shortcuts for:
  - Up/Down arrows to navigate requests
  - Escape to deselect
  - Ctrl+C to copy cURL

### ARIA Labels

Future improvements:
- Add `aria-label` to buttons
- Use semantic HTML elements
- Add `role` attributes where needed

---

## See Also

- [Setup Guide](./setup.md) - Development environment setup
- [State Management](./state-management.md) - State management patterns
- [Embedding in Binary](./embedding.md) - Production deployment
