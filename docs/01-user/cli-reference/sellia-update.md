# `sellia update` - Update to Latest Version

Update the Sellia CLI to the latest version or a specific version.

## Synopsis

```bash
sellia update [options]
```

## Description

Checks for updates and installs the latest version of Sellia. Can also check for updates without installing, force reinstall, or update to a specific version.

The update process downloads the latest release from GitHub and replaces the current binary.

## Options

### `-c, --check`

Check for updates without installing.

Displays the currently installed version and the latest available version, but doesn't perform any installation.

**Example:**
```bash
$ sellia update --check
Current version: 1.0.0
Latest version: 1.2.0
A new version is available!
Run 'sellia update' to install
```

### `-f, --force`

Force reinstall even if already up-to-date.

Reinstalls the current version or downloads again if the latest version is already installed. Useful for troubleshooting or if the previous download was corrupted.

**Example:**
```bash
sellia update --force
```

### `-v, --version VER`

Update to a specific version.

Instead of updating to the latest release, install a specific version. Useful for downgrading or testing.

**Example:**
```bash
# Install specific version
sellia update --version 1.1.0

# Downgrade to older version
sellia update --version 1.0.0
```

### `-h, --help`

Show help message and exit.

## Usage Examples

### Check for updates (no install)

```bash
$ sellia update --check
Current: v1.0.0
Latest:  v1.2.0

Run 'sellia update' to install v1.2.0
```

### Update to latest version

```bash
$ sellia update
Current: v1.0.0
Latest:  v1.2.0

Updating... Done!

Updated to v1.2.0
```

### Update to specific version

```bash
$ sellia update --version 1.1.0
Current: v1.0.0
Latest:  v1.1.0

Updating... Done!

Updated to v1.1.0
```

### Force reinstall current version

```bash
$ sellia update --force
Current: v1.2.0
Latest:  v1.2.0

Updating... Done!

Updated to v1.2.0
```

### Check with no updates available

```bash
$ sellia update --check
Current: v1.2.0
Latest:  v1.2.0

Already up to date (v1.2.0)
```

## Update Process

The update command:

1. Checks your current version
2. Queries GitHub releases for the latest version
3. Downloads the appropriate binary for your OS and architecture
4. Replaces the current binary
5. Verifies the installation

### Supported Platforms

Updates are available for:
- Linux (x86_64, aarch64)
- macOS (x86_64, aarch64/Apple Silicon)
- Windows (x86_64)

### Binary Location

The update command replaces the binary at its current location. Common locations:

- **Linux**: `/usr/local/bin/sellia`, `~/.local/bin/sellia`
- **macOS**: `/usr/local/bin/sellia`, `/opt/homebrew/bin/sellia`
- **Windows**: `C:\Users\<user>\.sellia\bin\sellia.exe`

## Download Progress

The update command downloads the binary without showing detailed progress. It displays "Updating..." and shows "Done!" when complete.

```bash
$ sellia update
Current: v1.0.0
Latest:  v1.2.0

Updating... Done!

Updated to v1.2.0
```

## Exit Codes

- `0` - Update successful or already up to date
- `1` - Update failed (network error, permission error, etc.)

## Error Handling

### Network Error

```bash
Error: Failed to fetch release information
```

**Solution:** Check your internet connection and try again.

### Permission Error

```bash
Error: Cannot determine executable path
```

or

```bash
Error: [Errno 13] Permission denied
```

**Solution:** Ensure you have write permissions to the binary location or run with appropriate permissions.

### Platform Not Supported

```bash
Error: No binary available for this platform
Platform: unknown-unknown
```

**Solution:** Install from source manually.

## Update Check Behavior

The command checks for updates by:

1. Reading the current version from the binary
2. Fetching the latest release information from GitHub
3. Comparing version numbers
4. Downloading and installing if newer

No automatic update checks are performed. Updates are only run when you explicitly run `sellia update`.

## Version Format

Sellia uses semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR** - Breaking changes
- **MINOR** - New features, backwards compatible
- **PATCH** - Bug fixes

Example versions:
- `1.0.0` - Initial release
- `1.0.1` - Bug fix
- `1.1.0` - New feature
- `2.0.0` - Breaking changes

## Related Commands

- [`sellia version`](./sellia-version.md) - Show current version
- [`sellia help`](./index.md) - Show general help

## See Also

- [GitHub Releases](https://github.com/watzon/sellia/releases) - View release notes and download manually
- [Installation Guide](../getting-started/installation.md) - Manual installation instructions
