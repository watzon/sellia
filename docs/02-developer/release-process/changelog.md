# Changelog Maintenance

How to maintain the CHANGELOG.md file for Sellia releases.

## Overview

The CHANGELOG.md file follows the [Keep a Changelog](https://keepachangelog.com/) format, which is human-readable and machine-parseable.

## Changelog Location

```
CHANGELOG.md (project root)
```

---

## Format

### Header

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
```

---

### Version Entry

```markdown
## [0.4.0] - 2025-12-30

### Added
- New feature description (#123)

### Changed
- Modified feature behavior (#124)

### Deprecated
- Old feature now deprecated (#125)

### Removed
- Removed deprecated feature (#126)

### Fixed
- Bug fix description (#127)

### Security
- Security fix description (#128)
```

---

## Categories

### Added

New features and functionality.

**Examples:**
```markdown
### Added
- Add WebSocket inspection in inspector UI (#45)
- Add `--subdomain` flag to `sellia http` command (#67)
- Add support for custom tunnel servers (#89)
```

---

### Changed

Changes to existing functionality (backwards compatible).

**Examples:**
```markdown
### Changed
- Improve error messages for connection failures (#102)
- Update default timeout from 30s to 60s (#134)
- Improve request display performance in inspector (#156)
```

---

### Deprecated

Features that will be removed in future releases.

**Examples:**
```markdown
### Deprecated
- Deprecated `--old-flag` option, use `--new-flag` instead (#178)
- Deprecated legacy config format, will be removed in 2.0.0 (#201)
```

---

### Removed

Features removed in this release (must be in previous release's Deprecated section).

**Examples:**
```markdown
### Removed
- Removed `--old-flag` option (deprecated in 1.2.0) (#223)
- Removed legacy authentication method (deprecated in 1.0.0) (#245)
```

---

### Fixed

Bug fixes.

**Examples:**
```markdown
### Fixed
- Fix inspector not showing WebSocket requests (#267)
- Fix memory leak in request store (#289)
- Fix crash on invalid subdomain characters (#312)
```

---

### Security

Security vulnerability fixes.

**Examples:**
```markdown
### Security
- Fix API key leakage in debug logs (#334)
- Update dependencies to address CVE-2024-xxxxx (#356)
```

---

## Entry Guidelines

### What to Include

**DO include:**
- User-facing changes
- New features
- Bug fixes
- Breaking changes
- Security updates
- Performance improvements (if significant)

**DON'T include:**
- Internal refactoring
- Code style changes
- Test updates
- Documentation-only changes
- CI/CD changes

---

### Format Rules

1. **Use imperative mood**
   - ✅ "Add new feature"
   - ❌ "Added new feature" or "Adds new feature"

2. **One change per bullet**
   - ✅ Separate bullets for each change
   - ❌ Multiple changes in one bullet

3. **Link to issues/PRs**
   - ✅ "Add feature (#123)"
   - ❌ "Add feature"

4. **Group by category**
   - Keep categories in order: Added, Changed, Deprecated, Removed, Fixed, Security

---

## Workflow

### During Development

```bash
# Make changes
git commit -m "feat: add new feature"

# Don't update CHANGELOG yet
```

**Why:** Keep CHANGELOG clean by only updating during release prep.

---

### Release Preparation

1. **Review all commits since last release**

```bash
git log v0.3.0..v0.4.0 --oneline
```

2. **Categorize changes**

```bash
# List all commit messages
git log v0.3.0..v0.4.0 --pretty=format:"%s"

# Group into:
# - Added (feat:)
# - Changed (chore:, refactor: with user impact)
# - Fixed (fix:)
# - Breaking (BREAKING CHANGE:)
```

3. **Draft CHANGELOG entry**

```markdown
## [0.4.0] - 2025-12-30

### Added
- Add feature A (#123)
- Add feature B (#124)

### Fixed
- Fix bug C (#125)
```

4. **Update version links at bottom**

```markdown
[0.4.0]: https://github.com/watzon/sellia/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/watzon/sellia/compare/v0.2.3...v0.3.0
```

---

### Example Workflow

```bash
# 1. Checkout main branch
git checkout main
git pull origin main

# 2. Create release branch
git checkout -b release/v0.4.0

# 3. Update version in src/core/version.cr
VERSION = "0.4.0"

# 4. Update CHANGELOG.md
# Add new version entry at top

# 5. Commit
git commit -am "chore: release v0.4.0"

# 6. Tag
git tag v0.4.0

# 7. Push
git push origin release/v0.4.0
git push origin v0.4.0

# 8. Create PR and merge to main
```

---

## Automation

### Conventional Commits

If using conventional commits, can auto-generate changelog:

```bash
# Install git-chglog
brew install git-chglog

# Generate changelog
git-chglog --next-tag v1.2.3 -o CHANGELOG.md
```

---

### GitHub Integration

Use GitHub release notes:

```bash
# GitHub Actions can auto-generate release notes
# See: .github/workflows/release.yml
```

---

## Version Links

### Format

At the bottom of CHANGELOG.md:

```markdown
[Unreleased]: https://github.com/watzon/sellia/compare/v1.2.3...HEAD
[1.2.3]: https://github.com/watzon/sellia/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/watzon/sellia/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/watzon/sellia/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/watzon/sellia/compare/v1.1.0...v1.2.0
```

**Purpose:** Allow users to click version numbers to see diff on GitHub.

---

## Unreleased Section

### Keep at Top

```markdown
## [Unreleased]

### Added
- (Upcoming features)

### Changed
- (Upcoming changes)
```

**Purpose:** Show what's coming in next release.

**When to use:**
- During active development
- Remove/clear when creating release

---

## Release Notes Integration

### GitHub Releases

Copy CHANGELOG entry to GitHub release description:

```markdown
## Release v1.2.3

## [1.2.3] - 2024-12-30

### Added
- Add feature A (#123)

### Fixed
- Fix bug B (#124)

**Full Changelog**: https://github.com/watzon/sellia/compare/v1.2.2...v1.2.3
```

---

## Examples

### Major Release

```markdown
## [1.0.0] - 2025-XX-XX

### Added
- Add admin command for subdomain management (#100)
- Add SQLite persistence for reserved subdomains (#101)

### Changed
- Require API key for all tunnels (#102)
- Improve connection error messages (#103)

### Removed
- Remove legacy config format support (deprecated in 0.3.0) (#104)

### Fixed
- Fix tunnel reconnection issues (#105)

### Migration Guide
Include upgrade notes in the release notes when a migration is required.
```

---

### Minor Release

```markdown
## [0.5.0] - 2025-XX-XX

### Added
- Add path-based routing support (#80)
- Add WebSocket inspection in inspector (#81)
- Add `--open` flag to auto-open inspector (#82)

### Changed
- Improve inspector performance with virtual scrolling (#83)
```

---

### Patch Release

```markdown
## [0.4.1] - 2025-XX-XX

### Fixed
- Fix crash on invalid subdomain characters (#70)
- Fix inspector not showing request bodies (#71)
- Fix memory leak in WebSocket proxy (#72)
```

---

## Best Practices

1. **Keep it user-focused**
   - Describe what changed, not how
   - Use language users understand

2. **Be specific**
   - Include issue/PR numbers
   - Link to relevant docs

3. **Be honest**
   - Don't hide breaking changes
   - List all fixes, even for embarrassing bugs

4. **Keep it chronological**
   - Newest versions at top
   - Don't reorder old versions

5. **Use semantic versioning**
   - MAJOR: Breaking changes in "Removed"
   - MINOR: New features in "Added"
   - PATCH: Fixes in "Fixed"

---

## See Also

- [Versioning Policy](./versioning.md) - Semantic versioning
- [Building Binaries](./building-binaries.md) - Release build process
- [Docker Images](./docker-images.md) - Container releases
- [Keep a Changelog](https://keepachangelog.com/) - Format specification
