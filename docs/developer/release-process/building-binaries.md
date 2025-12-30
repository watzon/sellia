# Building Release Binaries

Cross-compilation and build process for Sellia release binaries.

## Overview

Sellia is written in Crystal, which compiles to native binaries. Release builds are optimized single executables that include the embedded React UI.

---

## Prerequisites

### Build Tools

- **Crystal 1.10+** (shard.yml specifies >= 1.10.0)
- **Node.js 20+** (for React UI)
- **Git**

### Optional

- **Docker** (for cross-compilation)
- **GitHub Actions** (automated builds)

---

## Local Builds

### Development Build

Fast compilation for testing:

```bash
# From project root
shards build

# Output: ./bin/sellia (CLI) or ./bin/sellia-server (Server)
# Size: ~4-5 MB
# Features: Development mode (proxies to Vite dev server)
```

**Use for:** Development and testing

---

### Production Build

Optimized binary for distribution:

```bash
# Build React UI first
cd web
npm ci
npm run build

# Build Crystal binary with release flags
cd ..
shards build --release --Dembed_assets

# Output: ./bin/sellia (CLI) or ./bin/sellia-server (Server)
# Size: ~6-8 MB (includes baked UI assets for CLI)
# Features: Production mode (self-contained)
```

**Use for:** Production deployment

---

## Build Flags

### Crystal Compiler Flags

| Flag | Purpose | Effect |
|------|---------|--------|
| `--release` | Enable optimizations | Smaller, faster binary |
| `--debug` | Include debug info | Larger binary, stack traces |
| `--no-debug` | Strip debug symbols | Smaller binary |
| `-Dflag_name` | Define compile-time flag | Conditional compilation |

---

### Common Combinations

```bash
# Standard release
shards build --release

# Release with static linking (Linux)
shards build --release --static

# Release with specific target
shards build --release --target x86_64-linux-musl
```

---

## Building React UI

### Production Build

```bash
cd web

# Install dependencies
npm ci

# Build optimized bundle
npm run build

# Output: web/dist/
# - index.html
# - assets/*.js (minified, hashed)
# - assets/*.css (minified, hashed)
```

### Build Script

```bash
#!/bin/bash
set -e

echo "Building React UI..."
cd web
npm ci
npm run build
cd ..

echo "UI built successfully"
ls -lh web/dist/
```

---

## Cross-Compilation

### Using Docker

**Why:** Crystal requires matching target architecture for native compilation. Docker provides consistent build environments.

---

### Linux Build on macOS

```bash
# Use Crystal official Docker image
docker run --rm -v $(pwd):/app -w /app crystallang/crystal:latest-alpine \
  shards build --release --static

# Output: ./bin/sellia (Linux binary)
```

---

### Multi-Platform Build Script

```bash
#!/bin/bash
set -e

VERSION=$(grep VERSION src/core/version.cr | cut -d'"' -f2)
OUTPUT="./dist"

mkdir -p $OUTPUT

echo "Building Sellia v$VERSION for multiple platforms..."

# Build for current platform
echo "Building for $(uname -s)-$(uname -m)..."
shards build sellia --release -Dembed_assets
shards build sellia-server --release --static
cp bin/sellia "$OUTPUT/sellia-$VERSION-$(uname -s)-$(uname -m)"
cp bin/sellia-server "$OUTPUT/sellia-server-$VERSION-$(uname -s)-$(uname -m)"

# Build for Linux (requires Docker)
echo "Building for linux-amd64..."
docker run --rm -v $(pwd):/workspace -w /workspace amd64/alpine sh -c '
  apk add --no-cache crystal shards gcc musl-dev openssl-dev sqlite-static &&
  shards install --without-development &&
  shards build sellia --release --static -Dembed_assets &&
  shards build sellia-server --release --static
'
cp bin/sellia "$OUTPUT/sellia-$VERSION-linux-amd64"
cp bin/sellia-server "$OUTPUT/sellia-server-$VERSION-linux-amd64"

echo "Builds complete:"
ls -lh $OUTPUT/
```

---

## Automated Builds (GitHub Actions)

### CI/CD Pipeline

**Location:** `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Crystal
        uses: crystal-lang/install-crystal@v1

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

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: bin/sellia
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

### Multi-Platform CI

```yaml
jobs:
  release:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - name: Build
        run: shards build --release

      - name: Upload
        uses: actions/upload-artifact@v4
        with:
          name: sellia-${{ matrix.os }}
          path: bin/sellia
```

---

## Binary Optimization

### Size Reduction

#### 1. Strip Symbols

```bash
strip bin/sellia
```

**Savings:** ~20-30% size reduction

#### 2. UPX Compression

```bash
# Install UPX
brew install upx  # macOS
apt install upx  # Linux

# Compress binary
upx --best --lzma bin/sellia
```

**Savings:** ~40-60% size reduction

**Trade-off:** Slight startup overhead (decompression)

---

#### 3. Static Linking

```bash
shards build --release --static
```

**Benefits:**
- No external library dependencies
- Portable across same OS/architecture

**Trade-off:** Larger binary size

---

## Platform-Specific Builds

### macOS

```bash
# Universal binary (Intel + Apple Silicon)
lipo -create \
  bin/sellia-x86_64 \
  bin/sellia-arm64 \
  -output bin/sellia-universal
```

---

### Linux

```bash
# Musl libc (fully static)
shards build --release --static

# GNU libc (dynamic, smaller)
shards build --release
```

---

### Windows

```bash
# Requires MSYS2/MinGW
shards build --release

# Output: sellia.exe
```

---

## Versioning

### Update Version

Before building releases, update version in:

1. **src/core/version.cr**
   ```crystal
   VERSION = "0.4.0"
   ```

2. **shard.yml**
   ```yaml
   version: 0.4.0
   ```

3. **package.json** (if UI changed)
   ```json
   {
     "version": "0.4.0"
   }
   ```

---

### Tag Release

```bash
git tag v1.2.3
git push origin v1.2.3
```

---

## Signing Binaries (macOS)

### Code Signing

```bash
# Import certificate
security import certificate.p12 -k ~/Library/Keychains/login.keychain

# Sign binary
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  bin/sellia

# Verify signature
codesign --verify --verbose bin/sellia
```

---

### Notarization

```bash
# Upload to Apple for notarization
xcrun notarytool submit bin/sellia \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAMID" \
  --wait

# Staple notarization ticket
xcrun stapler staple bin/sellia
```

---

## Distribution

### File Naming Convention

```
sellia-{version}-{os}-{arch}.{ext}
```

**Examples:**
- `sellia-1.2.3-linux-x86_64`
- `sellia-1.2.3-darwin-arm64`
- `sellia-1.2.3-windows-x86_64.exe`

---

### Checksums

Generate SHA256 checksums for integrity verification:

```bash
cd dist
shasum -a 256 * > SHA256SUMS
```

**Output:**
```
abc123...  sellia-1.2.3-linux-x86_64
def456...  sellia-1.2.3-darwin-arm64
```

---

## Testing Builds

### Smoke Test

```bash
# Check version
./bin/sellia version
# Expected: Sellia v0.4.0

# Check help
./bin/sellia help
# Expected: Usage message

# Check server version
./bin/sellia-server --version
# Expected: Sellia Server v0.4.0

# Check inspector works
./bin/sellia http 3000 &
# Open http://127.0.0.1:4040
```

---

### Integration Test

```bash
# Start a test server
python3 -m http.server 8080 &

# Start tunnel
./bin/sellia http 8080 --subdomain test-$$

# Make request
curl https://test-$$.sellia.me

# Check inspector shows request
curl http://127.0.0.1:4040/api/requests
```

---

## Troubleshooting

### Build Fails: "Error baking files"

**Cause:** React UI not built.

**Solution:**
```bash
cd web && npm run build && cd ..
shards build --release
```

---

### Binary Too Large

**Cause:** Debug symbols or lack of optimization.

**Solution:**
```bash
# Ensure --release flag
shards build --release

# Strip symbols
strip bin/sellia
```

---

### "Library not found" Error

**Cause:** Missing system libraries.

**Solution:**
```bash
# Use static linking
shards build --release --static

# Or install missing dependencies
sudo apt install libssl-dev libpcre3-dev  # Debian/Ubuntu
```

---

## See Also

- [Versioning Policy](./versioning.md) - Semantic versioning
- [Docker Images](./docker-images.md) - Container builds
- [Changelog Maintenance](./changelog.md) - Release notes
- [CI/CD Workflow](https://github.com/watzon/sellia/blob/main/.github/workflows/release.yml) - GitHub Actions
