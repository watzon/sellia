# Building from Source

This guide covers building Sellia binaries from source code, including both debug and release builds.

## Quick Build

### Prerequisites

Ensure you have [installed all prerequisites](prerequisites.md):

- Crystal >= 1.10.0
- Node.js >= 18
- Shards (included with Crystal)
- npm (included with Node.js)

### Build Steps

```bash
# Clone the repository
git clone https://github.com/watzon/sellia.git
cd sellia

# Install Crystal dependencies
shards install

# Install inspector UI dependencies
cd web && npm install && cd ..

# Build the binaries
shards build
```

The built binaries will be in `./bin/`:
- `sellia` - CLI client for creating tunnels
- `sellia-server` - Tunnel server

**Note:** If the `bin/` directory doesn't exist yet, `shards build` will create it automatically.

## Build Types

### Debug Build

Debug builds include debugging symbols and no optimizations. Useful for development.

```bash
shards build
```

**Characteristics:**
- Faster compilation
- Larger binary size
- Includes debug symbols
- No optimization passes
- Suitable for development and testing

### Release Build

Release builds are optimized for performance and size. Use these for production deployments.

```bash
shards build --release
```

**Characteristics:**
- Slower compilation
- Smaller binary size
- No debug symbols
- Full optimization (`--release` flag)
- Suitable for production use

## Build Artifacts

After building, you'll find the following binaries in `./bin/`:

| Binary | Description |
|--------|-------------|
| `sellia` | CLI client that creates tunnels to local services |
| `sellia-server` | Server that accepts tunnel connections and routes traffic |

## Building Individual Components

### CLI Client Only

To build only the CLI client:

```bash
crystal build src/cli/main.cr -o bin/sellia
```

### Server Only

To build only the server:

```bash
crystal build src/server/main.cr -o bin/sellia-server
```

### Inspector UI (Development)

The inspector UI is a React application that runs during development via Vite's dev server:

```bash
cd web
npm run dev
```

For production, the UI is embedded into the Crystal binary during the build process automatically.

## Inspector UI Assets

### Development Mode

During development, the CLI proxies to Vite's dev server:

```bash
cd web
npm run dev
# Runs on http://localhost:5173
```

### Production Assets

For release builds, the UI must be built first:

```bash
cd web
npm run build
# Outputs to web/dist/
```

The Crystal build process automatically embeds these assets. When built assets are present at `web/dist/`, they are compiled into the binary. Otherwise, the CLI proxies to the Vite dev server.

### Asset Embedding

The Crystal code checks for the presence of built assets:

```crystal
# If web/dist/ exists, assets are embedded
# Otherwise, proxy to Vite dev server at localhost:5173
```

This allows for rapid development without rebuilding the Crystal binary.

## Build Options

### Static Linking (Optional)

For creating fully self-contained binaries:

```bash
crystal build src/cli.cr --static -o bin/sellia-static
```

**Note:** Static linking may require additional system libraries.

### Custom Output Path

To specify a custom output directory:

```bash
crystal build src/cli/main.cr -o /custom/path/sellia
```

### Parallel Compilation

Crystal compiles modules in parallel by default. To limit parallelism:

```bash
crystal build src/cli.cr --threads 4
```

## Build Verification

After building, verify the binaries work correctly:

```bash
# Check CLI version
./bin/sellia version

# Check server help
./bin/sellia-server --help

# Run tests
crystal spec
```

## Cross-Compilation

Cross-compiling Crystal binaries is possible but challenging due to the need for target-specific libraries.

### Linux to macOS

Not recommended due to library differences.

### macOS to Linux

Possible with Docker or a Linux VM:

```bash
# Using Docker
docker run --rm -v $(pwd):/workspace -w /workspace crystallang/crystal:latest shards build --release
```

### Using GitHub Actions

The project uses GitHub Actions for automated builds across multiple platforms. See `.github/workflows/` for build configurations.

## Clean Build

To start fresh and remove all build artifacts:

```bash
# Remove build artifacts
rm -rf bin/

# Remove Crystal dependencies
rm -rf lib/
rm shard.lock

# Remove Node.js dependencies
cd web && rm -rf node_modules/ package-lock.json

# Reinstall and rebuild
shards install
cd web && npm install && cd ..
shards build --release
```

## Build Troubleshooting

### Compilation Errors

**Issue:** Type errors or missing dependencies

**Solution:**
```bash
# Update dependencies
shards update

# Check for missing dependencies
shards check

# Verify formatting
crystal tool format --check
```

### Missing OpenSSL

**Issue:** Error about OpenSSL not found

**Solution:**
```bash
# macOS (Homebrew)
brew install openssl

# Ubuntu/Debian
sudo apt-get install libssl-dev
```

### Inspector UI Build Failures

**Issue:** npm install or npm run build fails

**Solution:**
```bash
cd web
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

### Permission Denied on Binary

**Issue:** Cannot execute `./bin/sellia`

**Solution:**
```bash
chmod +x bin/sellia bin/sellia-server
```

## Optimizing Build Performance

### Use Project-Specific Compilation Flags

Create a `.crystal` config file in your home directory:

```yaml
# ~/.crystal
crystal_path: /usr/lib/crystal
```

### Cache Dependencies

Dependencies are cached in `lib/` after the first `shards install`. Subsequent builds are faster.

### Incremental Compilation

Crystal only recompiles changed files, making rebuilds fast during development.

## Continuous Integration Builds

The project includes CI/CD configuration for automated builds:

- **GitHub Actions:** `.github/workflows/ci.yml`
- **Platforms:** Linux, macOS
- **Build types:** Debug and release
- **Artifact storage:** Build artifacts are stored as CI artifacts

## Next Steps

After building Sellia:

- [Run Locally](running-locally.md) - Test your build
- [Run Tests](testing.md) - Verify everything works
- [Development Workflow](../contributing/workflow.md) - Start contributing
