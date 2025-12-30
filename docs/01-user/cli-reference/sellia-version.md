# `sellia version` - Show Version Information

Display the current version of Sellia.

## Synopsis

```bash
sellia version
sellia -v
sellia --version
```

## Description

Displays the currently installed version of Sellia. Useful for:
- Checking if you need to update
- Providing version information in bug reports
- Verifying installation

## Usage

### Using the `version` command

```bash
$ sellia version
Sellia v1.0.0
```

### Using the short flag

```bash
$ sellia -v
Sellia v1.0.0
```

### Using the long flag

```bash
$ sellia --version
Sellia v1.0.0
```

## Output Format

The output format is:

```
Sellia v<VERSION>
```

Where `<VERSION>` is the semantic version number (e.g., `1.0.0`).

## Examples

### Check current version

```bash
$ sellia version
Sellia v1.2.0
```

### Use in scripts

```bash
#!/bin/bash
VERSION=$(sellia -v | awk '{print $2}')
echo "Running Sellia version $VERSION"
```

### Compare versions

```bash
CURRENT=$(sellia -v | awk '{print $2}' | cut -d'v' -f2)
LATEST="1.2.0"

if [ "$CURRENT" != "$LATEST" ]; then
    echo "Update available!"
    sellia update
fi
```

### Check if Sellia is installed

```bash
if command -v sellia &> /dev/null; then
    echo "Sellia version: $(sellia -v)"
else
    echo "Sellia is not installed"
fi
```

## Version Format

Sellia uses semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR** - Breaking changes (e.g., `2.0.0`)
- **MINOR** - New features, backwards compatible (e.g., `1.1.0`)
- **PATCH** - Bug fixes (e.g., `1.0.1`)

### Pre-release Versions

Pre-release versions include a suffix:

```
Sellia v1.2.0-beta.1
Sellia v1.2.0-rc.1
Sellia v1.2.0-dev
```

### Development Versions

Development builds may include commit information:

```
Sellia v1.2.0-dev+a1b2c3d
```

## Usage in Bug Reports

When reporting bugs, always include the version:

```bash
$ sellia version
Sellia v1.2.0

$ sellia http 3000
# ... error message ...
```

This helps developers identify fixed issues and version-specific problems.

## Comparison with Update Check

The `version` command shows only the installed version:

```bash
$ sellia version
Sellia v1.0.0
```

To check for updates, use `sellia update --check`:

```bash
$ sellia update --check
Current version: 1.0.0
Latest version: 1.2.0

A new version is available!
```

## Environment Variable

You can also access the version programmatically:

```bash
# In Crystal code
puts Sellia::VERSION  # => "1.0.0"
```

## Exit Codes

- `0` - Version displayed successfully

## Related Commands

- [`sellia update`](./sellia-update.md) - Update to the latest version
- [`sellia help`](./index.md) - Show general help and usage information

## See Also

- [Changelog](https://github.com/watzon/sellia/blob/main/CHANGELOG.md) - Version history and changes
- [GitHub Releases](https://github.com/watzon/sellia/releases) - Release notes and downloads
