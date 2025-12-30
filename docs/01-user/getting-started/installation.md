# Installing Sellia

Sellia can be installed from source or using pre-built binaries. Choose the method that best fits your workflow.

## Prerequisites

Before installing Sellia, ensure you have the following dependencies:

- **Crystal** >= 1.10.0 - [Install Crystal](https://crystal-lang.org/install/)
- Git (for building from source)

## Installation from Source

Building from source gives you the latest features and allows you to modify the code.

### Step 1: Clone the Repository

```bash
git clone https://github.com/watzon/sellia.git
cd sellia
```

### Step 2: Install Dependencies

Sellia uses [Shards](https://crystal-lang.org/reference/the_shards_command.html), Crystal's built-in dependency manager.

```bash
shards install
```

### Step 3: Build Binaries

For development/testing (faster compilation):

```bash
shards build
```

For production use (optimized binaries):

```bash
shards build --release
```

### Step 4: Verify Installation

The build process creates two binaries in the `./bin/` directory:

- `sellia` - CLI client for creating tunnels
- `sellia-server` - Tunnel server for self-hosting

Check that the binaries are built:

```bash
ls -lh ./bin/
```

You should see:
```
sellia
sellia-server
```

### Step 5: Make Binaries Available (Optional)

To use `sellia` from anywhere, add the binaries to your PATH:

```bash
# Temporary (current session only)
export PATH="$PATH:$(pwd)/bin"

# Permanent (add to ~/.bashrc, ~/.zshrc, or equivalent)
echo 'export PATH="$PATH:'$(pwd)'/bin"' >> ~/.bashrc
source ~/.bashrc
```

Verify the installation:

```bash
sellia version
sellia-server --help
```

## Pre-built Binaries

Pre-built binaries are coming soon. This will allow you to download and install Sellia without needing to compile from source.

### Planned Availability

- macOS (Intel and Apple Silicon)
- Linux (x86_64, ARM64)
- Windows (x86_64)

## Installation via Package Manager

Package manager installation is planned for future releases:

- Homebrew (macOS/Linux)
- AUR (Arch Linux)
- Snap Store (Linux)
- Chocolatey (Windows)

## Verifying Your Installation

After installing Sellia, verify that everything is working correctly:

```bash
# Check CLI version
sellia version

# View CLI help
sellia help

# View server help
sellia-server --help
```

## Next Steps

After installation, you can:

1. [Quick Start Guide](./quickstart.md) - Get up and running in 5 minutes
2. [Self-Hosting Quick Start](./self-hosting-quickstart.md) - Set up your own tunnel server
3. [Configuration Guide](../configuration/config-file.md) - Configure Sellia for your needs

## Troubleshooting

### Crystal Version Issues

If you encounter issues with Crystal version, ensure you're using Crystal >= 1.10.0:

```bash
crystal --version
```

### Build Failures

If the build fails, try:

```bash
# Clean build directory
rm -rf ./bin

# Try again
shards build --release

# Or update dependencies first
shards update
shards build --release
```

### Permission Issues

If you get permission errors when running binaries:

```bash
# Make binaries executable
chmod +x ./bin/sellia
chmod +x ./bin/sellia-server
```

## System Requirements

### Minimum Requirements

- **CPU**: x86_64 or ARM64
- **RAM**: 512 MB
- **Disk**: 50 MB for binaries

### Recommended for Server

- **CPU**: 2+ cores
- **RAM**: 2 GB+
- **Disk**: 100 MB+
- **Network**: Stable internet connection with sufficient bandwidth

## Development Installation

If you're planning to contribute to Sellia or modify the code:

1. Follow the "Installation from Source" steps above
2. Install Node.js >= 18 for inspector UI development
3. See the [Development Guide](../../developer/development/index.md)

For inspector UI development:

```bash
cd web
npm install
npm run dev
```
