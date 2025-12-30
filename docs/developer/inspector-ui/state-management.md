# Inspector UI State Management

How state is managed in the Sellia Inspector UI, including data flow, WebSocket communication, and React patterns.

## Overview

The Inspector UI uses React's built-in state management with hooks. There's no external state management library (no Redux, Zustand, etc.) - keeping it simple and maintainable.

## State Architecture

```
┌─────────────────────────────────────────────────────────┐
│                         App.tsx                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ requests[]   │  │ selected     │  │ connected    │ │
│  │ (useState)   │  │ (useState)   │  │ (useState)   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                 │           │
│         ▼                 ▼                 ▼           │
│  ┌──────────────────────────────────────────────────┐  │
│  │              WebSocket Effect                     │  │
│  │  (onmessage → setRequests)                       │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Fetch Effect                         │  │
│  │  (on mount → fetch /api/requests)                │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## State Variables

### 1. `requests` - Request List

```typescript
const [requests, setRequests] = useState<Request[]>([])
```

**Purpose:** Stores all captured HTTP requests.

**Type:** `Request[]`

**Max Size:** 1000 requests (enforced via `.slice(0, 1000)`)

**Updates:**
- Initial load from `/api/requests` REST API
- Live updates from `/api/live` WebSocket
- Cleared via `/api/requests/clear` POST request

---

### 2. `selected` - Selected Request

```typescript
const [selected, setSelected] = useState<Request | null>(null)
```

**Purpose:** Tracks which request is currently displayed in detail view.

**Type:** `Request | null`

**Updates:**
- Set when user clicks a request in the list
- Cleared when "Clear All" is clicked

---

### 3. `connected` - Connection Status

```typescript
const [connected, setConnected] = useState(false)
```

**Purpose:** Tracks WebSocket connection status.

**Type:** `boolean`

**Updates:**
- Set to `true` when WebSocket opens
- Set to `false` when WebSocket closes
- Displayed as "Live" (green) or "Disconnected" (red) badge

---

### 4. `reconnectCounter` - Reconnection Trigger

```typescript
const [reconnectCounter, setReconnectCounter] = useState(0)
```

**Purpose:** Triggers WebSocket reconnection by incrementing.

**Type:** `number`

**Updates:**
- Incremented after 3-second delay on WebSocket close
- Used as dependency in WebSocket effect to re-establish connection

---

## Data Flow

### Initial Load Flow

```
1. App mounts
   ↓
2. Fetch Effect runs
   ↓
3. GET /api/requests
   ↓
4. setRequests(data)
   ↓
5. UI renders request list
```

**Code:**

```typescript
useEffect(() => {
  fetch('/api/requests')
    .then(r => r.json())
    .then(data => setRequests(data))
    .catch(console.error)
}, [])
```

---

### Live Updates Flow

```
1. WebSocket connects
   ↓
2. setConnected(true)
   ↓
3. Server sends message
   ↓
4. ws.onmessage triggered
   ↓
5. JSON.parse(data)
   ↓
6. setRequests([newRequest, ...prev].slice(0, 1000))
   ↓
7. UI re-renders with new request at top
```

**Code:**

```typescript
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
```

---

### Selection Flow

```
1. User clicks request item
   ↓
2. onClick handler fires
   ↓
3. setSelected(request)
   ↓
4. Detail panel re-renders with new request data
```

**Code:**

```typescript
onClick={() => setSelected(req)}
```

---

### Clear Flow

```
1. User clicks "Clear All"
   ↓
2. POST /api/requests/clear
   ↓
3. Backend clears request store
   ↓
4. setRequests([])
   ↓
5. setSelected(null)
   ↓
6. UI shows empty state
```

**Code:**

```typescript
onClick={async () => {
  await fetch('/api/requests/clear', { method: 'POST' })
  setRequests([])
}}
```

---

## WebSocket Lifecycle

### Connection Phase

```typescript
const ws = new WebSocket(`ws://${window.location.host}/api/live`)

ws.onopen = () => {
  setConnected(true)
}
```

**Events:**
- WebSocket opens → Update connection status
- Ready to receive live updates

---

### Message Phase

```typescript
ws.onmessage = (event) => {
  const data = JSON.parse(event.data)
  if (data.type === 'request') {
    setRequests(prev => [data.request, ...prev].slice(0, 1000))
  }
}
```

**Message Format:**

```typescript
{
  type: 'request',
  request: {
    id: string,
    method: string,
    path: string,
    statusCode: number,
    duration: number,
    timestamp: Date,
    requestHeaders: Record<string, string>,
    requestBody?: string,
    responseHeaders: Record<string, string>,
    responseBody?: string,
    matchedRoute?: string,
    matchedTarget?: string
  }
}
```

---

### Disconnection Phase

```typescript
ws.onclose = () => {
  setConnected(false)
  setTimeout(() => {
    setReconnectCounter(prev => prev + 1)
  }, 3000)
}
```

**Events:**
1. WebSocket closes → Update status to disconnected
2. Wait 3 seconds
3. Increment reconnection counter
4. Effect re-runs and establishes new WebSocket

---

### Cleanup Phase

```typescript
return () => ws.close()
```

**Events:**
- Component unmounts
- WebSocket connection closed
- Prevents memory leaks

---

## Reconnection Strategy

### Exponential Backoff

Currently uses **fixed 3-second delay**:

```typescript
setTimeout(() => {
  setReconnectCounter(prev => prev + 1)
}, 3000)
```

**Future improvement:** Implement exponential backoff:

```typescript
const [retryCount, setRetryCount] = useState(0)

useEffect(() => {
  const delay = Math.min(1000 * Math.pow(2, retryCount), 30000)
  const timeout = setTimeout(() => {
    setReconnectCounter(prev => prev + 1)
    setRetryCount(prev => prev + 1)
  }, delay)

  return () => clearTimeout(timeout)
}, [connected])
```

---

## State Synchronization

### Backend → Frontend

**REST API (initial load):**
```
Crystal Backend → /api/requests → React State
```

**WebSocket (live updates):**
```
Crystal Backend → /api/live → WebSocket → React State
```

**State mutation:** Only via `setRequests()`

---

### Frontend → Backend

**Clear requests:**
```
React State → /api/requests/clear → Crystal Backend
```

**No bidirectional sync needed:**
- Backend is source of truth
- Frontend is display layer
- Actions are fire-and-forget

---

## Performance Optimizations

### 1. Request Limit

```typescript
setRequests(prev => [data.request, ...prev].slice(0, 1000))
```

**Benefit:** Prevents unbounded memory growth.

**Trade-off:** Loses oldest requests beyond 1000.

---

### 2. Immutability

```typescript
[request, ...prev]  // Creates new array
```

**Benefit:** React can efficiently detect changes and re-render.

---

### 3. Conditional Rendering

```typescript
{selected ? <RequestDetail /> : <Placeholder />}
```

**Benefit:** Only renders detail panel when request selected.

---

### 4. WebSocket Message Batching

**Current:** Each request sent immediately.

**Future:** Batch multiple requests:

```typescript
ws.onmessage = (event) => {
  const data = JSON.parse(event.data)
  if (data.type === 'requests') {
    setRequests(prev => [...data.requests, ...prev].slice(0, 1000))
  }
}
```

---

## Error Handling

### Fetch Errors

```typescript
fetch('/api/requests')
  .catch(console.error)
```

**Behavior:** Errors logged to console, UI shows empty state.

---

### WebSocket Errors

```typescript
ws.onerror = (error) => {
  console.error('WebSocket error:', error)
}
```

**Behavior:** Error logged, reconnection triggered via `onclose`.

---

### Parse Errors

```typescript
try {
  const data = JSON.parse(event.data)
} catch (e) {
  console.error('Failed to parse message:', e)
}
```

**Behavior:** Bad messages ignored, connection maintained.

---

## State Persistence

### Current: No Persistence

- Request list lives in memory only
- Lost on page refresh
- Lost on WebSocket reconnect

### Future: LocalStorage Persistence

```typescript
// Save to localStorage
useEffect(() => {
  localStorage.setItem('requests', JSON.stringify(requests))
}, [requests])

// Load from localStorage
useEffect(() => {
  const saved = localStorage.getItem('requests')
  if (saved) {
    setRequests(JSON.parse(saved))
  }
}, [])
```

**Trade-offs:**
- ✅ Survives page refresh
- ❌ Limited storage (5-10MB)
- ❌ Requires serialization/deserialization overhead

---

## Testing State Management

### Unit Testing (Future)

```typescript
test('adding request updates state', () => {
  const { result } = renderHook(() => useApp())
  act(() => {
    result.current.addRequest(mockRequest)
  })
  expect(result.current.requests).toHaveLength(1)
})
```

### Integration Testing (Future)

```typescript
test('WebSocket message adds request', async () => {
  const ws = new WebSocket('ws://localhost:4040/api/live')
  await waitFor(() => {
    expect(screen.getByText('GET /api')).toBeInTheDocument()
  })
})
```

---

## See Also

- [Component Architecture](./component-architecture.md) - Component structure
- [Setup Guide](./setup.md) - Development setup
- [Embedding in Binary](./embedding.md) - Production deployment
- [Backend Inspector](../cli-components/inspector.md) - Crystal backend
