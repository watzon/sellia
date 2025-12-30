# Inspector UI

Development guide for the Sellia Inspector web interface.

## Overview

The Inspector UI is a React-based web application that provides real-time visualization of HTTP traffic through Sellia tunnels. It connects to the local CLI client via WebSocket and displays requests and responses as they occur.

## Technology Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **Tailwind CSS** - Styling (optional)
- **WebSocket API** - Real-time communication

## Project Structure

```
web/
├── src/
│   ├── App.tsx            # Root component (contains all UI logic)
│   ├── main.tsx           # Application entry point
│   └── index.css          # Global styles (Tailwind)
├── public/                # Static assets
├── index.html             # HTML template
├── package.json
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
└── vite.config.ts
```

> **Note:** Currently the entire UI is contained in a single `App.tsx` file. As the UI grows, consider splitting into multiple components.

## Getting Started

### Development Setup

```bash
cd web

# Install dependencies
npm install

# Start dev server
npm run dev
```

The CLI will proxy to Vite's dev server at `localhost:5173` when not built with embedded assets.

### Build for Production

```bash
cd web

# Build
npm run build

# Preview build
npm run preview
```

Built assets are embedded in the Crystal binary for distribution.

## Core Concepts

### WebSocket Connection

The inspector connects to the local CLI client via WebSocket:

```typescript
const ws = new WebSocket(`ws://${window.location.host}/api/live`);

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.type === 'request') {
    setRequests(prev => [data.request, ...prev]);
  }
};
```

### Message Types

Messages sent over WebSocket:

```typescript
interface RequestMessage {
  type: 'request';
  request: {
    id: string;
    method: string;
    path: string;
    statusCode: number;
    duration: number;
    timestamp: Date;
    requestHeaders: Record<string, string>;
    requestBody?: string;
    responseHeaders: Record<string, string>;
    responseBody?: string;
    matchedRoute?: string;
    matchedTarget?: string;
  };
}
```

### State Management

React state for managing requests:

```typescript
const [requests, setRequests] = useState<Request[]>([]);
const [selected, setSelected] = useState<Request | null>(null);
const [connected, setConnected] = useState(false);
```

## Components

> **Current Implementation:** All components are currently implemented inline in `App.tsx`. The examples below show the suggested structure for future refactoring.

### RequestList (Planned)

Displays list of all requests.

**Planned Location:** `src/components/RequestList.tsx`

```tsx
interface RequestListProps {
  requests: Request[];
  selected: Request | null;
  onSelect: (request: Request) => void;
}

export function RequestList({ requests, selected, onSelect }: RequestListProps) {
  return (
    <div className="w-1/2 border-r border-gray-700 overflow-y-auto">
      {requests.map(request => (
        <RequestItem
          key={request.id}
          request={request}
          selected={selected?.id === request.id}
          onClick={() => onSelect(request)}
        />
      ))}
    </div>
  );
}
```

### RequestDetail (Planned)

Shows details of selected request.

**Planned Location:** `src/components/RequestDetail.tsx`

```tsx
interface RequestDetailProps {
  request: Request;
}

export function RequestDetail({ request }: RequestDetailProps) {
  return (
    <div className="w-1/2 overflow-y-auto p-4">
      <h2>{request.method} {request.path}</h2>
      <RequestHeaders headers={request.requestHeaders} />
      {request.requestBody && <RequestBody body={request.requestBody} />}
      <RequestHeaders headers={request.responseHeaders} />
      {request.responseBody && <ResponseBody body={request.responseBody} />}
    </div>
  );
}
```

## TypeScript Types

**Location:** `src/App.tsx` (defined inline)

```typescript
interface Request {
  id: string;
  method: string;
  path: string;
  statusCode: number;
  duration: number;
  timestamp: Date;
  requestHeaders: Record<string, string>;
  requestBody?: string;
  responseHeaders: Record<string, string>;
  responseBody?: string;
  matchedRoute?: string;
  matchedTarget?: string;
}
```

## Styling

### Tailwind CSS

The inspector uses Tailwind CSS v4 for styling.

```tsx
export function Component() {
  return (
    <div className="bg-gray-900 text-white p-4">
      {/* Content */}
    </div>
  );
}
```

**Location:** `src/index.css` imports Tailwind:
```css
@import "tailwindcss";
```

### Configuration

Tailwind is configured via Vite plugin in `vite.config.ts`:
```typescript
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
})
```

## Best Practices

### Current Implementation

- All UI logic is in a single `App.tsx` file for simplicity
- Uses React hooks for state management (no external state library)
- Direct WebSocket integration
- Tailwind CSS v4 for styling

### Future Improvements

When refactoring into multiple components:

- Keep components focused and single-purpose
- Use TypeScript for all components
- Extract reusable logic into hooks
- Use memoization for expensive operations
- Virtualize long lists if they grow beyond 100 items

### Performance Considerations

- Request list is limited to 1000 items
- New requests are added to the beginning of the list
- Immutable state updates for efficient re-rendering
- Conditional rendering of detail panel

### Error Handling

```typescript
useEffect(() => {
  const ws = new WebSocket(`ws://${window.location.host}/api/live`);

  ws.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      if (data.type === 'request') {
        setRequests(prev => [data.request, ...prev].slice(0, 1000));
      }
    } catch (e) {
      console.error('Failed to parse message:', e);
    }
  };

  ws.onclose = () => {
    setConnected(false);
    setTimeout(() => {
      setReconnectCounter(prev => prev + 1);
    }, 3000);
  };

  return () => ws.close();
}, [reconnectCounter]);
```

## Testing

### Current Status

No automated tests are currently set up. Testing is manual:

1. Start a tunnel:
   ```bash
   ./bin/sellia http 3000
   ```

2. Make requests to public URL

3. Open inspector: `http://127.0.0.1:4040`

4. Verify requests appear in real-time

## Building for Production

### Embed in Crystal Binary

1. Build UI:
   ```bash
   cd web
   npm run build
   ```

2. Build Crystal binary with assets:
   ```bash
   cd ..
   shards build --release
   ```

The `--release` flag causes Crystal to bake the `web/dist/` folder into the binary using the `baked_file_system` shard.

### Development Mode

For development, simply run:

```bash
cd web
npm run dev
```

And start Sellia without the `--release` flag. The inspector will proxy requests to the Vite dev server.

## Troubleshooting

### WebSocket Connection Issues

**Problem:** Can't connect to WebSocket

**Solutions:**
- Verify CLI is running with inspector enabled
- Check firewall allows port 4040
- Verify using correct WebSocket URL: `ws://${window.location.host}/api/live`

### Dev Server Issues

**Problem:** Vite dev server not working

**Solutions:**
- Ensure `npm install` was run
- Check port 5173 is available
- Clear node_modules and reinstall

### Build Errors

**Problem:** Production build fails

**Solutions:**
- Check TypeScript errors: `npx tsc --noEmit`
- Fix linting errors: `npm run lint`
- Check for missing dependencies

## Next Steps

- [Component Architecture](./component-architecture.md) - Detailed component structure
- [State Management](./state-management.md) - State management patterns
- [Setup Guide](./setup.md) - Development environment setup
- [Embedding in Binary](./embedding.md) - Production deployment details
