# Sellia - Development and Build Commands

# Default recipe shows available commands
default:
    @just --list

# ==================
# Development
# ==================

# Start the Vite dev server for the web inspector UI
dev-web:
    cd web && npm run dev

# Run the CLI in development mode (pass arguments after --)
dev-cli *args:
    shards run sellia -- {{args}}

# Run the server in development mode (pass arguments after --)
dev-server *args:
    shards run sellia-server -- {{args}}

# Run a test tunnel server on localhost:3000
dev-test-server:
    shards run sellia-server -- --port 3000 --domain localhost:3000

# Run the CLI connecting to local test server
dev-test-cli port="8080":
    shards run sellia -- http {{port}} --server http://localhost:3000

# ==================
# Building
# ==================

# Build the web inspector UI
build-web:
    cd web && npm run build

# Build CLI and server (development mode, no embedded assets)
build-dev:
    shards build

# Build for release with embedded web assets
build: build-web
    shards build --release -Dembed_assets

# Build only CLI for release
build-cli: build-web
    shards build sellia --release -Dembed_assets

# Build only server for release
build-server:
    shards build sellia-server --release

# ==================
# Testing
# ==================

# Run all tests
test:
    crystal spec

# Run tests with verbose output
test-verbose:
    crystal spec -v

# Run specific test file
test-file file:
    crystal spec {{file}}

# Watch for changes and run tests (requires watchexec)
test-watch:
    watchexec -e cr crystal spec

# ==================
# Dependencies
# ==================

# Install all dependencies (Crystal shards and Node packages)
install:
    shards install
    cd web && npm install

# Update Crystal shards
update-shards:
    shards update

# Update Node packages
update-npm:
    cd web && npm update

# ==================
# Code Quality
# ==================

# Format Crystal code
fmt:
    crystal tool format

# Check Crystal code formatting
fmt-check:
    crystal tool format --check

# Lint web code
lint-web:
    cd web && npm run lint

# ==================
# Cleanup
# ==================

# Remove build artifacts
clean:
    rm -rf bin/ web/dist/ lib/

# Clean and reinstall dependencies
clean-all: clean
    rm -rf web/node_modules/ shard.lock web/package-lock.json
    just install

# ==================
# Docker
# ==================

# Build Docker image for server
docker-build:
    docker build -t sellia-server .

# Run server in Docker
docker-run port="3000" domain="localhost:3000":
    docker run -p {{port}}:3000 -e SELLIA_DOMAIN={{domain}} sellia-server

# ==================
# Utilities
# ==================

# Show version information
version:
    @echo "Sellia version: $(grep 'VERSION' src/core/version.cr | cut -d'"' -f2)"

# Generate a random API key
generate-key:
    @openssl rand -hex 32
