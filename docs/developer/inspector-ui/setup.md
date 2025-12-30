# Inspector UI Setup

Guide for setting up the development environment for the Sellia Inspector UI.

## Overview

The Inspector UI is a React application built with Vite that provides real-time request monitoring for Sellia tunnels. It communicates with the Crystal backend via WebSocket and REST APIs.

## Prerequisites

- Node.js 18+ and npm
- Crystal 1.10+ (for backend)
- Git

## Project Structure

```
web/
├── src/
│   ├── App.tsx          # Main React component
│   ├── main.tsx         # Application entry point
│   └── index.css        # Global styles
├── public/              # Static assets
├── index.html           # HTML template
├── package.json         # Node dependencies
├── vite.config.ts       # Vite configuration
├── tsconfig.json        # TypeScript configuration
└── dist/                # Build output (generated)
```

## Initial Setup

### 1. Install Dependencies

```bash
cd web
npm install
```

This installs:
- `react` ^19.2.0 - UI framework
- `react-dom` ^19.2.0 - React DOM bindings
- `vite` ^7.2.4 - Build tool and dev server
- `typescript` ~5.9.3 - Type checking
- `tailwindcss` ^4.1.18 - Styling
- `@vitejs/plugin-react` ^5.1.1 - React plugin for Vite

### 2. Development Server

Start the Vite dev server (port 5173):

```bash
npm run dev
```

The UI will be available at `http://localhost:5173`

### 3. Start Crystal Backend

In a separate terminal, start Sellia in development mode (no `--release` flag):

```bash
# From project root
shards build
./bin/sellia http 3000
```

The inspector will proxy requests to the Vite dev server automatically.

---

## Development Workflow

### Live Development

1. **Start Vite dev server:**
   ```bash
   cd web
   npm run dev
   ```

2. **Start Sellia (in separate terminal):**
   ```bash
   shards build
   ./bin/sellia http 3000
   ```

3. **Access inspector:**
   - Open `http://127.0.0.1:4040` in your browser
   - Changes to React code will hot-reload via Vite HMR

### File Watching

Vite automatically watches for changes in `web/src/` and triggers fast hot module replacement (HMR).

### Linting

Run ESLint:

```bash
npm run lint
```

Fix issues automatically:

```bash
npm run lint -- --fix
```

---

## Configuration

### Vite Config (`vite.config.ts`)

```typescript
export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 5173,
  },
})
```

**Key settings:**
- `port`: Dev server port (default 5173)
- `outDir`: Production build output directory
- `plugins`: React and Tailwind CSS integration

### TypeScript Config

Two TypeScript configs:

1. **`tsconfig.json`** - Application code
2. **`tsconfig.node.json`** - Build tooling (Vite config)

Both extend from base configurations and enable strict type checking.

---

## Building for Production

### Production Build

Create optimized production build:

```bash
cd web
npm run build
```

This creates `web/dist/` with:
- Minified JavaScript
- Optimized assets
- Source maps (if enabled)

### Build Output

```
dist/
├── index.html              # Entry HTML
├── assets/
│   ├── index-[hash].js     # Bundled JavaScript
│   ├── index-[hash].css    # Bundled CSS
│   └── ...                 # Other assets
```

### Production Binary

After building the UI, create release binary:

```bash
# From project root
cd web && npm run build && cd ..
shards build --release
```

The `--release` flag:
- Bakes `web/dist/` into the binary
- Enables asset serving from binary instead of Vite proxy

---

## Development vs Production Modes

### Development Mode (Default)

```bash
shards build
./bin/sellia http 3000
```

**Characteristics:**
- Inspector proxies to Vite dev server (`localhost:5173`)
- Fast refresh with HMR
- Source maps available
- Larger binary size
- Requires both `npm run dev` and Sellia running

### Production Mode

```bash
shards build --release
./bin/sellia http 3000
```

**Characteristics:**
- UI assets baked into binary
- No external dev server needed
- Optimized, minified assets
- Single binary deployment
- Faster startup

---

## Troubleshooting

### "Vite Dev Server Not Running"

**Cause:** Vite dev server is not running or not accessible.

**Solution:**
1. Start Vite dev server:
   ```bash
   cd web && npm run dev
   ```
2. Ensure it's running on port 5173
3. Or build for production:
   ```bash
   npm run build && shards build --release
   ```

### HMR Not Working

**Cause:** WebSocket connection to Vite failed (can't proxy WebSocket upgrades).

**Solution:**
- This is expected behavior. Direct your browser to `http://localhost:5173` for HMR.
- Or manually refresh the inspector page at `http://127.0.0.1:4040`.

### Port 5173 Already in Use

**Cause:** Another process is using the Vite port.

**Solution:**
1. Find and stop the process:
   ```bash
   lsof -i :5173
   kill -9 <PID>
   ```
2. Or change Vite port in `vite.config.ts`:
   ```typescript
   server: {
     port: 5174,  # Use different port
   }
   ```

### Build Errors

**Cause:** TypeScript errors or missing dependencies.

**Solution:**
1. Check TypeScript errors:
   ```bash
   npx tsc --noEmit
   ```
2. Reinstall dependencies:
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

---

## Environment Variables

The inspector UI respects some environment variables:

| Variable | Description |
|----------|-------------|
| `VITE_PORT` | Override Vite dev server port |
| `NODE_ENV` | Set to `production` for production builds |

Example:
```bash
VITE_PORT=5174 npm run dev
```

---

## API Endpoints

The inspector communicates with the Crystal backend via:

### REST API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/requests` | GET | Get all stored requests |
| `/api/requests/clear` | POST | Clear all requests |

### WebSocket

| Endpoint | Description |
|----------|-------------|
| `/api/live` | Real-time request updates |

---

## Styling with Tailwind CSS

The inspector uses Tailwind CSS v4 for styling.

### Usage

```tsx
<div className="bg-gray-900 text-white p-4">
  Content here
</div>
```

### Configuration

Tailwind is configured via Vite plugin in `vite.config.ts`. No separate config file needed for v4.

---

## Testing

Currently no automated tests are set up. Manual testing:

1. Start a tunnel:
   ```bash
   ./bin/sellia http 3000
   ```

2. Make requests to public URL

3. Open inspector: `http://127.0.0.1:4040`

4. Verify requests appear in real-time

---

## See Also

- [Component Architecture](./component-architecture.md) - React component structure
- [State Management](./state-management.md) - How state is managed
- [Embedding in Binary](./embedding.md) - Production deployment
- [Inspector User Guide](../../user/inspector/index.md) - End-user documentation
