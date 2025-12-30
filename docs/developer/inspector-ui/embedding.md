# Embedding Inspector UI in Crystal Binary

How the React Inspector UI is embedded into the Crystal binary for single-file distribution.

## Overview

The Inspector UI is embedded directly into the Crystal binary using the `baked_file_system` shard. This creates a single executable that contains both the backend server and the frontend UI, with no external file dependencies.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              sellia (Crystal Binary)                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Crystal Inspector Server (HTTP::Server)         │  │
│  │  - Serves baked assets                           │  │
│  │  - Provides REST API (/api/requests)             │  │
│  │  - Provides WebSocket (/api/live)                │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Baked Assets (compiled into binary)             │  │
│  │  - index.html                                    │  │
│  │  - JavaScript bundles                            │  │
│  │  - CSS files                                     │  │
│  │  - Images, fonts, etc.                           │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Build Process

### Development Build

```bash
# No baking - proxies to Vite dev server
shards build
./bin/sellia http 3000
```

**Characteristics:**
- `--release` flag NOT set
- Assets NOT baked into binary
- Inspector proxies to `localhost:5173` (Vite dev server)
- Faster compilation, suitable for development

---

### Production Build

```bash
# Step 1: Build UI
cd web
npm run build
# Creates: web/dist/

# Step 2: Build Crystal binary with baked assets
cd ..
shards build --release
```

**Characteristics:**
- `--release` flag set
- Assets baked into binary at compile time
- Self-contained executable
- Optimized for production

---

## Implementation

### Conditional Compilation

**Location:** `src/cli/inspector.cr:8-12`

```crystal
{% unless flag?(:release) %}
  # Development mode - no baked assets needed
{% else %}
  require "baked_file_system"
{% end %}
```

**How it works:**
- Crystal conditionally compiles code based on `--release` flag
- Development mode: Baking skipped
- Release mode: Baking enabled

---

### Baking Assets

**Location:** `src/cli/inspector.cr:15-20`

```crystal
{% if flag?(:release) %}
  class InspectorAssets
    extend BakedFileSystem

    bake_folder "../../web/dist", __DIR__
  end
{% end %}
```

**What happens:**
1. At compile time, `baked_file_system` reads `web/dist/`
2. Each file is converted to a Crystal string constant
3. Files are embedded in the binary
4. Runtime: Serve files from memory, no disk I/O

---

### Serving Baked Files

**Location:** `src/cli/inspector.cr:171-195`

```crystal
private def serve_baked_file(context : HTTP::Server::Context, path : String)
  # Try to get the file from baked assets
  file = InspectorAssets.get?(path)

  # If not found and not already index.html, try index.html (SPA fallback)
  if file.nil? && path != "/index.html" && !path.starts_with?("/assets/")
    file = InspectorAssets.get?("/index.html")
  end

  if file
    content_type = mime_type_for(path)
    context.response.content_type = content_type

    # Cache static assets aggressively
    if path.starts_with?("/assets/")
      context.response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
    end

    context.response.print(file.gets_to_end)
  else
    context.response.status_code = 404
    context.response.content_type = "text/plain"
    context.response.print("Not found: #{path}")
  end
end
```

**Key features:**
1. **Lookup:** `InspectorAssets.get?(path)` retrieves baked file
2. **SPA Fallback:** Non-existent routes return `index.html` (for React Router)
3. **MIME Types:** Correct content type based on file extension
4. **Caching:** Aggressive caching for assets (1 year)

---

### MIME Type Detection

**Location:** `src/cli/inspector.cr:197-228`

```crystal
private def mime_type_for(path : String) : String
  case path
  when .ends_with?(".html")
    "text/html; charset=utf-8"
  when .ends_with?(".js")
    "application/javascript; charset=utf-8"
  when .ends_with?(".css")
    "text/css; charset=utf-8"
  when .ends_with?(".svg")
    "image/svg+xml"
  when .ends_with?(".png")
    "image/png"
  when .ends_with?(".jpg"), .ends_with?(".jpeg")
    "image/jpeg"
  when .ends_with?(".gif")
    "image/gif"
  when .ends_with?(".ico")
    "image/x-icon"
  when .ends_with?(".woff")
    "font/woff"
  when .ends_with?(".woff2")
    "font/woff2"
  when .ends_with?(".ttf")
    "font/ttf"
  when .ends_with?(".json")
    "application/json"
  when .ends_with?(".map")
    "application/json"
  else
    "application/octet-stream"
  end
end
```

---

## File Routing

### Request Flow

```
1. HTTP request to inspector (e.g., GET /)
   ↓
2. Route determination in handle_request()
   ↓
3. If API endpoint (/api/*) → handle API request
   ↓
4. If root (/) → serve index.html
   ↓
5. Otherwise → serve file or fallback to index.html
```

### Route Table

| Path | Handler | Description |
|------|---------|-------------|
| `/api/live` | WebSocket | Live request updates |
| `/api/requests` | REST API | Get all requests |
| `/api/requests/clear` | REST API | Clear all requests |
| `/` | File | Serve index.html |
| `/*` | File or index.html | Serve file or SPA fallback |

---

## Development vs Production Behavior

### Development Mode

```crystal
private def serve_file(context : HTTP::Server::Context, path : String)
  {% unless flag?(:release) %}
    proxy_to_vite(context, path)
  {% else %}
    serve_baked_file(context, path)
  {% end %}
end
```

**Behavior:**
- Proxies requests to Vite dev server at `localhost:5173`
- Enables HMR (Hot Module Replacement)
- No compilation needed for UI changes
- Requires `npm run dev` running separately

---

### Production Mode

```crystal
private def serve_file(context : HTTP::Server::Context, path : String)
  {% if flag?(:release) %}
    serve_baked_file(context, path)
  {% end %}
end
```

**Behavior:**
- Serves baked assets from binary
- Single executable deployment
- No external file dependencies
- UI changes require rebuild

---

## Asset Caching Strategy

### Static Assets (JS, CSS, Images)

```crystal
if path.starts_with?("/assets/")
  context.response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
end
```

**Why:** Assets have content-hash in filename (e.g., `index-abc123.js`), so they can be cached indefinitely.

### HTML

```crystal
# No cache header for HTML
context.response.print(file.gets_to_end)
```

**Why:** HTML should always be fresh to ensure latest asset references.

---

## Build Script

### Manual Build

```bash
#!/bin/bash
set -e

echo "Building React UI..."
cd web
npm run build
cd ..

echo "Building Crystal binary..."
shards build --release

echo "Done! Binary: ./bin/sellia"
```

---

### Automated Build (GitHub Actions)

**Location:** `.github/workflows/release.yml`

```yaml
- name: Install Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'

- name: Build Inspector UI
  run: |
    cd web
    npm ci
    npm run build

- name: Build Crystal
  run: shards build --release
```

---

## Binary Size Impact

### Before Baking

```
-rwxr-xr-x  1 user  staff  4.2M  bin/sellia (no assets)
```

### After Baking

```
-rwxr-xr-x  1 user  staff  5.8M  bin/sellia (with assets)
```

**Overhead:** ~1.6MB for React UI bundle

**Optimization:**
- Assets compressed at compile time
- No runtime decompression overhead
- Acceptable trade-off for single-file deployment

---

## Updating the UI

### Development

1. Edit React code in `web/src/`
2. Vite HMR automatically reloads browser
3. No rebuild needed

### Production

1. Edit React code in `web/src/`
2. Build UI:
   ```bash
   cd web && npm run build && cd ..
   ```
3. Rebuild Crystal binary:
   ```bash
   shards build --release
   ```
4. Test new binary

---

## Troubleshooting

### UI Not Updating

**Symptom:** Changes to React code not reflected in inspector.

**Cause:** Using stale baked assets from previous build.

**Solution:**
```bash
# Clean and rebuild
cd web
rm -rf dist node_modules/.vite
npm run build
cd ..
shards build --release
```

---

### 404 for Assets

**Symptom:** Browser shows 404 for `/assets/index-xxx.js`.

**Cause:** Assets not baked or incorrect path.

**Solution:**
1. Ensure `npm run build` completed successfully
2. Check `web/dist/` exists and contains assets
3. Rebuild with `--release` flag

---

### Large Binary Size

**Symptom:** Binary > 10MB.

**Cause:** Debug build includes all assets unoptimized.

**Solution:**
1. Always use `--release` flag for production
2. Check `web/dist/` size (should be < 2MB)
3. Verify production build: `npm run build`

---

## Future Improvements

### Compression

Use gzip compression for baked assets:

```crystal
require "gzip"

{% if flag?(:release) %}
  class InspectorAssets
    extend BakedFileSystem

    bake_folder "../../web/dist", __DIR__, gzip: true
  end
{% end %}
```

**Benefit:** 60-70% size reduction for text assets.

---

### Lazy Loading

Load chunks on demand:

```typescript
// React.lazy + Suspense
const RequestDetail = React.lazy(() => import('./RequestDetail'))
```

**Benefit:** Smaller initial bundle size, faster first load.

---

## See Also

- [Setup Guide](./setup.md) - Development setup
- [Component Architecture](./component-architecture.md) - React components
- [State Management](./state-management.md) - State patterns
- [Backend Inspector](../cli-components/inspector.md) - Crystal server implementation
