# Prerequisites

This document outlines the requirements and dependencies needed to develop and build Sellia from source.

## Core Requirements

### Crystal Language

Sellia is written in Crystal and requires **Crystal >= 1.10.0**. (Tested with Crystal 1.18.2)

**Installation:**

Visit [crystal-lang.org/install](https://crystal-lang.org/install/) for platform-specific instructions.

**Common installation methods:**

- **macOS (Homebrew):**
  ```bash
  brew install crystal
  ```

- **Ubuntu/Debian:**
  ```bash
  curl -fsSL https://crystal-lang.org/install.sh | sudo bash
  ```

- **Arch Linux:**
  ```bash
  sudo pacman -S crystal
  ```

**Verification:**

```bash
crystal --version
# Should output: Crystal 1.10.0 or higher
```

### Node.js

Node.js is required for the inspector UI (React application built with Vite).

**Required version:** **Node.js >= 18** (Tested with Node.js 20+)

**Installation:**

- **macOS (Homebrew):**
  ```bash
  brew install node
  ```

- **Ubuntu/Debian:**
  ```bash
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
  ```

- **Using nvm (recommended):**
  ```bash
  nvm install --lts
  nvm use lts
  ```

**Verification:**

```bash
node --version
# Should output: v18.0.0 or higher
```

### Package Managers

#### Shards (Crystal Dependencies)

Shards is included with Crystal and manages Crystal library dependencies.

**Verification:**

```bash
shards --version
```

#### npm (Node.js Dependencies)

npm is included with Node.js and manages the inspector UI dependencies.

**Verification:**

```bash
npm --version
```

### Git

Git is required for cloning the repository and managing version control.

**Installation:**

- **macOS:** Included with Xcode Command Line Tools: `xcode-select --install`
- **Ubuntu/Debian:** `sudo apt-get install git`
- **Windows:** [git-scm.com](https://git-scm.com/)

**Verification:**

```bash
git --version
```

## Optional Dependencies

### OpenSSL (for SSL/TLS support)

OpenSSL development headers are required for SSL support in Crystal.

**macOS:** Usually included with the system.

**Ubuntu/Debian:**
```bash
sudo apt-get install libssl-dev
```

**Arch Linux:**
```bash
sudo pacman -S openssl
```

### SQLite Development Libraries

Required for SQLite storage backend (API keys, reserved subdomains).

**Ubuntu/Debian:**
```bash
sudo apt-get install sqlite3 libsqlite3-dev
```

**macOS:** Usually included with the system.

### Docker (for containerized development)

Optional, for testing Docker deployments locally.

**Installation:** [docker.com](https://www.docker.com/)

## Development Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
```

### 2. Add Upstream Remote

If you're planning to contribute, add the upstream repository:

```bash
git remote add upstream https://github.com/watzon/sellia.git
```

### 3. Install Dependencies

```bash
# Install Crystal dependencies
shards install

# Install inspector UI dependencies
cd web && npm install && cd ..
```

### 4. Build the Project

```bash
# Build debug binaries
shards build

# Or build release binaries (optimized)
shards build --release
```

Binaries will be output to `./bin/`:
- `sellia` - CLI client
- `sellia-server` - Tunnel server

### 5. Run Tests

Verify your environment is correctly set up:

```bash
crystal spec
```

## Platform-Specific Notes

### macOS

- Ensure you have Xcode Command Line Tools installed: `xcode-select --install`
- Homebrew is the recommended package manager

### Linux

- Ensure you have build essentials: `sudo apt-get install build-essential` (Debian/Ubuntu)
- Some distributions may require additional development headers for Crystal

### Windows

Sellia is primarily developed and tested on Unix-like systems. Windows support via WSL2 is recommended.

## Version Compatibility

| Component | Minimum Version | Tested Version |
|-----------|----------------|----------------|
| Crystal   | 1.10.0         | 1.18.2         |
| Node.js   | 18             | 20+            |
| npm       | 9              | Latest bundled with Node.js |

## Troubleshooting

### Crystal compilation errors

Ensure you have the latest Crystal version and all development headers installed:

```bash
crystal --version
```

### Node.js module build failures

Try clearing the npm cache and reinstalling:

```bash
cd web
rm -rf node_modules package-lock.json
npm cache clean --force
npm install
```

### Shards installation failures

If `shards install` fails, try:

```bash
shards update
```

This updates `shard.lock` to the latest compatible versions.

## Next Steps

- [Building from Source](building.md)
- [Running Locally](running-locally.md)
- [Testing](testing.md)
