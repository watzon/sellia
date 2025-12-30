# Versioning Policy

Semantic versioning policy for Sellia releases.

## Overview

Sellia follows [Semantic Versioning 2.0.0](https://semver.org/).

Format: `MAJOR.MINOR.PATCH` (e.g., `1.2.3`)

- **MAJOR:** Incompatible API changes
- **MINOR:** New functionality (backwards compatible)
- **PATCH:** Bug fixes (backwards compatible)

---

## Version Number Format

### Examples

| Version | Type | Meaning |
|---------|------|---------|
| `0.1.0` | Initial | First release |
| `0.4.0` | Pre-release | Current development version |
| `1.0.0` | Major | Future stable release |

### Pre-Release Versions

Format: `MAJOR.MINOR.PATCH-prerelease.N`

Examples:
- `1.0.0-alpha.1`
- `1.0.0-beta.1`
- `1.0.0-rc.1`

---

## Version Bumping Rules

### MAJOR (X.0.0)

Increment when:

1. **CLI interface changes**
   - Removing commands or flags
   - Changing flag names or formats
   - Requiring new arguments

2. **Config file format changes**
   - Removing config fields
   - Renaming required fields
   - Changing config file structure

3. **Protocol changes**
   - Breaking protocol message changes
   - Removing message types
   - Required new fields in messages

4. **API key changes**
   - Requiring new API key format
   - Changing authentication method

**Examples:**
```
1.2.3 → 2.0.0
- Remove `--legacy-flag` option
- Change config from YAML to TOML
- Require API keys for all tunnels
```

---

### MINOR (x.Y.0)

Increment when:

1. **New features**
   - Adding new commands
   - Adding new CLI flags (optional)
   - Adding new config fields (optional)

2. **Enhancements**
   - New inspector features
   - Performance improvements
   - New protocol message types (backwards compatible)

3. **Non-breaking additions**
   - New tunnel types
   - New routing features
   - Additional output formats

**Examples:**
```
1.2.3 → 1.3.0
- Add `sellia admin` command
- Add WebSocket inspection in inspector
- Add path-based routing
```

---

### PATCH (x.y.Z)

Increment when:

1. **Bug fixes**
   - Fix crashes
   - Fix memory leaks
   - Fix incorrect behavior

2. **Internal changes**
   - Code refactoring
   - Performance optimizations
   - Documentation updates

3. **Backwards-compatible fixes**
   - Improve error messages
   - Add validation warnings
   - Fix edge cases

**Examples:**
```
1.2.3 → 1.2.4
- Fix connection timeout issue
- Fix inspector display bug
- Improve error message for invalid auth
```

---

## Pre-Release Versions

### Alpha

**Status:** Early development, unstable

**Usage:** Feature development, testing

**Examples:**
- `1.0.0-alpha.1` - First alpha
- `1.0.0-alpha.2` - Second alpha

---

### Beta

**Status:** Feature complete, testing needed

**Usage:** Public testing, feedback

**Examples:**
- `1.0.0-beta.1` - First beta
- `1.0.0-beta.2` - Second beta

---

### Release Candidate (RC)

**Status:** Ready for release unless bugs found

**Usage:** Final testing before GA

**Examples:**
- `1.0.0-rc.1` - First RC
- `1.0.0-rc.2` - Second RC

---

## Development Versions

### Nightly / Dev Builds

Format: `dev-YYYYMMDD` or commit hash

**Examples:**
- `dev-20241230`
- `dev-a1b2c3d`

**Status:** Unstable, not for production use

---

## Version Sources

### Source of Truth

1. **src/core/version.cr** - Crystal code (primary)
   ```crystal
   module Sellia
     VERSION = "0.4.0"
   end
   ```

2. **shard.yml** - Crystal dependencies
   ```yaml
   name: sellia
   version: 0.4.0
   ```

3. **package.json** - Web UI (if UI changed)
   ```json
   {
     "version": "0.4.0"
   }
   ```

4. **Git tags** - Releases
   ```
   v0.4.0
   ```

**They must be synchronized for releases.**

---

## Release Workflow

### 1. Development

```bash
# Work on main branch
git checkout main

# Make changes, commit
git commit -m "feat: add new feature"
```

**Version format:** `dev` or unreleased

---

### 2. Pre-Release

```bash
# Update version in src/core/version.cr
VERSION = "1.3.0-alpha.1"

# Commit
git commit -m "chore: bump version to 1.3.0-alpha.1"

# Tag
git tag v1.3.0-alpha.1
git push origin v1.3.0-alpha.1
```

---

### 3. Release

```bash
# Update version in src/core/version.cr
VERSION = "0.5.0"

# Update shard.yml
# version: 0.5.0

# Update package.json (if UI changed)
npm version 0.5.0

# Commit
git commit -am "chore: release v0.5.0"

# Tag
git tag v0.5.0
git push origin main v0.5.0

# GitHub Actions creates release and builds binaries
```

---

## Backwards Compatibility Policy

### Guaranteed Stable

These interfaces are stable within a MAJOR version:

1. **CLI Commands**
   - Existing command names
   - Existing flag names
   - Flag formats

2. **Config File**
   - Existing config keys
   - Config file format (YAML)

3. **Protocol**
   - Existing message types
   - Message field names

4. **Public URLs**
   - URL format for tunnels

---

### May Change

These interfaces may change in MINOR releases:

1. **Output format**
   - CLI text output
   - Log messages

2. **Internal APIs**
   - Database schema
   - Inspector API (not public)

3. **Default values**
   - Port numbers
   - Timeout durations

---

## Deprecation Policy

### Deprecation Process

1. **Announce deprecation** in release notes (MINOR version)
2. **Mark as deprecated** in code/docs
3. **Wait one MAJOR version** before removal
4. **Remove in next MAJOR version**

**Example:**
```
v1.2.0 - Add new feature
v1.3.0 - Mark old feature as deprecated (release notes)
v2.0.0 - Remove old feature
```

---

## Changelog Requirements

### For Each Release

Must include:

- **Version number** and date
- **Type** (MAJOR/MINOR/PATCH)
- **Changes** grouped by type:
  - Added
  - Changed
  - Deprecated
  - Removed
  - Fixed
  - Security

See: [Changelog Maintenance](./changelog.md)

---

## Migration Guides

### For MAJOR Releases

Provide migration guide when:

1. Config format changes
2. CLI flags change
3. Protocol changes

**Example:**
```markdown
## Migrating from 1.x to 2.0

### Config Changes

Old format:
```yaml
tunnel_port: 3000
```

New format:
```yaml
tunnels:
  default:
    port: 3000
```
```

---

## Version Detection

### Check Version

```bash
sellia version
# Output: Sellia v0.4.0

sellia-server --version
# Output: Sellia Server v0.4.0
```

### Check for Updates

```bash
sellia update --check
# Output: Current: 1.2.3, Latest: 1.2.4
```

---

## See Also

- [Changelog Maintenance](./changelog.md) - Maintaining CHANGELOG.md
- [Building Binaries](./building-binaries.md) - Cross-compilation
- [Docker Images](./docker-images.md) - Container releases
- [Release Process](./index.md) - Full release workflow
