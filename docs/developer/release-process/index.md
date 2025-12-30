# Release Process

How Sellia releases are managed and published.

## Overview

This section covers the release process for Sellia, including versioning, changelog generation, and publishing releases.

## Versioning

Sellia uses [Semantic Versioning](https://semver.org/):

- **MAJOR** - Incompatible API changes
- **MINOR** - Backwards-compatible functionality
- **PATCH** - Backwards-compatible bug fixes

Format: `MAJOR.MINOR.PATCH`

Examples:
- `1.0.0` → `1.0.1` (Bug fix)
- `1.0.0` → `1.1.0` (New feature)
- `1.0.0` → `2.0.0` (Breaking change)

## Release Checklist

### Pre-Release

1. **All tests passing**
   ```bash
   crystal spec
   ```

2. **Documentation updated**
   - Update README if needed
   - Update docs/ for new features
   - Update CHANGELOG.md

3. **Version bumped**
   - Update version in `src/core/version.cr`
   - Update version in `shard.yml`
   - Update version in `web/package.json` (if UI changed)

### Creating Release

1. **Create release branch**
   ```bash
   git checkout -b release/v1.0.0
   ```

2. **Update version files**
   - `src/core/version.cr`: `VERSION = "0.4.0"`
   - `shard.yml`: `version: 0.4.0`
   - `web/package.json`: `version: "0.4.0"` (if UI changed)

3. **Update CHANGELOG.md**
   ```markdown
   ## [1.0.0] - 2025-01-30

   ### Added
   - New feature X
   - New feature Y

   ### Fixed
   - Bug fix Z

   ### Changed
   - Updated dependency A
   ```

4. **Commit changes**
   ```bash
   git add src/core/version.cr shard.yml web/package.json CHANGELOG.md
   git commit -m "chore: release v0.4.0"
   ```

5. **Build and test**
   ```bash
   cd web && npm ci && npm run build && cd ..
   shards build sellia --release -Dembed_assets
   shards build sellia-server --release --static
   crystal spec
   ```

6. **Merge to main**
   ```bash
   git checkout main
   git merge release/v1.0.0
   ```

7. **Tag release**
   ```bash
   git tag -a v0.4.0 -m "Release v0.4.0"
   git push origin main
   git push origin v0.4.0
   ```

### Post-Release

1. **Create GitHub Release**
   - Go to GitHub releases page
   - Click "Draft a new release"
   - Choose tag `v0.4.0`
   - Copy changelog from CHANGELOG.md
   - GitHub Actions will automatically build and publish binaries and Docker images
   - Publish release

2. **Build release binaries** (future)
   ```bash
   # Build for multiple platforms
   # Upload to GitHub release
   ```

3. **Announce release**
   - Update documentation
   - Post announcement
   - Update website

## Changelog Format

Sellia uses [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Upcoming features

### Changed
- Upcoming changes

## [1.0.0] - 2025-01-30

### Added
- Initial release
- HTTP tunnel support
- Request inspector
- Basic authentication
- Subdomain routing

### Fixed
- Connection stability issues

## [0.1.0] - 2025-01-15

### Added
- First beta release
```

## Categories

### Added
New features:
- New commands
- New configuration options
- New protocol features

### Changed
Changes to existing functionality:
- Updated dependencies
- Improved performance
- Enhanced features

### Deprecated
Soon-to-be removed features:
- Mark deprecated features
- Migration path

### Removed
Removed features:
- Remove deprecated features
- Breaking changes

### Fixed
Bug fixes:
- Crash fixes
- Incorrect behavior
- Security issues

### Security
Security fixes:
- Vulnerability patches
- Security improvements

## Release Branch Strategy

### Main Branch
- Active development and stable releases
- Tags for each release
- Production-ready code

### Feature Branches
- New features
- Bug fixes
- Merged to main via pull requests

## Hotfix Process

For urgent fixes:

1. **Create hotfix branch**
   ```bash
   git checkout -b hotfix/v0.4.1
   ```

2. **Implement fix**
   ```bash
   # Make changes
   git commit -m "fix: critical bug"
   ```

3. **Build and test**
   ```bash
   crystal spec
   ```

4. **Merge to main**
   ```bash
   git checkout main
   git merge hotfix/v0.4.1
   ```

5. **Tag and release**
   ```bash
   git tag -a v0.4.1 -m "Hotfix v0.4.1"
   git push origin main --tags
   ```

## Dependency Updates

### Crystal Dependencies

Update `shard.yml`:

```yaml
dependencies:
  message-pack:
    github: crystal-community/message-pack-crystal
    version: ~> 1.0.0  # Update version
```

Run update:

```bash
shards update
```

### Node Dependencies

Update `web/package.json`:

```json
{
  "dependencies": {
    "react": "^18.2.0"
  }
}
```

Run update:

```bash
cd web
npm update
```

## Testing Before Release

### Full Test Suite

```bash
# Crystal tests
crystal spec

# UI tests
cd web
npm test
cd ..

# Integration tests
./scripts/integration-test.sh
```

### Manual Testing

1. **Server startup**
   ```bash
   ./bin/sellia-server --port 3000 --domain localhost
   ```

2. **Tunnel creation**
   ```bash
   ./bin/sellia http 3000
   ```

3. **Version check**
   ```bash
   ./bin/sellia version
   ./bin/sellia-server --version
   ```

3. **Request handling**
   - Make requests through tunnel
   - Verify responses
   - Check inspector

4. **Configuration**
   - Test config file loading
   - Verify environment variables
   - Check CLI flags

### Platform Testing

Test on supported platforms:
- Linux (Ubuntu, Debian, CentOS)
- macOS (Intel, Apple Silicon)
- Docker

## Release Communication

### GitHub Release

Create release with:
- Version number
- Release notes
- Upgrade instructions
- Download links

### Announcement Template

```
## Sellia v1.0.0 Released

I'm excited to announce Sellia v1.0.0!

### Highlights
- Feature A
- Feature B
- Feature C

### What's New
[Brief description of major changes]

### Upgrade Guide
[Steps for upgrading from previous version]

### Downloads
- [Source](https://github.com/watzon/sellia/archive/refs/tags/v1.0.0.tar.gz)
- Docker image: `docker pull sellia:1.0.0`

### Documentation
[Link to updated documentation]

### Thank You
Special thanks to contributors:
- @contributor1
- @contributor2
```

## Post-Release Tasks

1. **Monitor issues**
   - Watch for regression reports
   - Respond to release feedback

2. **Update website**
   - Update version numbers
   - Add release notes

3. **Plan next release**
   - Review feature requests
   - Prioritize backlog

## Version Bumping Examples

### Patch Release (Bug Fix)

```bash
# 1.0.0 → 1.0.1
git checkout -b release/v1.0.1
# Update shard.yml: version: 1.0.1
git commit -m "chore: release v1.0.1"
git tag -a v1.0.1 -m "Release v1.0.1"
```

### Minor Release (New Feature)

```bash
# 1.0.0 → 1.1.0
git checkout -b release/v1.1.0
# Update shard.yml: version: 1.1.0
git commit -m "chore: release v1.1.0"
git tag -a v1.1.0 -m "Release v1.1.0"
```

### Major Release (Breaking Change)

```bash
# 1.0.0 → 2.0.0
git checkout -b release/v2.0.0
# Update shard.yml: version: 2.0.0
git commit -m "chore: release v2.0.0"
git tag -a v2.0.0 -m "Release v2.0.0"
```

## Next Steps

- [Contributing](../contributing/) - Contribution guidelines
- [Development](../development/) - Development setup
- [Security](../security/) - Security considerations
