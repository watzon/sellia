# Homebrew and Scoop Packages

Package manager distribution for Sellia (planned feature).

## Status

**Current Status:** 🚧 **Not Yet Implemented**

This is a placeholder documentation for future Homebrew and Scoop package support.

---

## Overview

Package managers provide convenient installation and updates for Sellia:

- **Homebrew** - macOS and Linux
- **Scoop** - Windows

---

## Homebrew (macOS/Linux)

### Installation (Planned)

```bash
# Add tap
brew tap sellia/tap

# Install Sellia
brew install sellia

# Start tunnel
sellia http 3000
```

---

### Homebrew Formula

**File:** `Formula/sellia.rb`

```ruby
class Sellia < Formula
  desc "Secure tunnels to localhost"
  homepage "https://github.com/watzon/sellia"
  url "https://github.com/watzon/sellia/archive/refs/tags/v1.2.3.tar.gz"
  sha256 "abc123..."
  license "MIT"

  depends_on "crystal"
  depends_on "node" => :build

  def install
    # Build React UI
    cd "web" do
      system "npm", "install"
      system "npm", "run", "build"
    end

    # Build Crystal binary
    system "shards", "build", "--release"
    bin.install "bin/sellia"
  end

  test do
    assert_match "Sellia v#{version}", shell_output("#{bin}/sellia version")
  end
end
```

---

### Auto-Update Strategy

```bash
# Livecheck version
brew livecheck sellia --tap sellia/tap
```

**Configuration (in Formula):**

```ruby
livecheck do
  url :stable
  regex(/^v?(\d+(?:\.\d+)+)$/i)
end
```

---

## Scoop (Windows)

### Installation (Planned)

```powershell
# Add bucket
scoop bucket add sellia https://github.com/watzon/sellia

# Install Sellia
scoop install sellia

# Start tunnel
sellia http 3000
```

---

### Scoop Manifest

**File:** `bucket/sellia.json`

```json
{
  "version": "1.2.3",
  "description": "Secure tunnels to localhost",
  "homepage": "https://github.com/watzon/sellia",
  "license": "MIT",
  "url": [
    "https://github.com/watzon/sellia/releases/download/v1.2.3/sellia-1.2.3-windows-x86_64.exe#/sellia.exe"
  ],
  "hash": [
    "abc123..."
  ],
  "bin": [
    ["sellia.exe", "sellia"]
  ],
  "checkver": "github",
  "autoupdate": {
    "url": "https://github.com/watzon/sellia/releases/download/v$version/sellia-$version-windows-x86_64.exe#/sellia.exe"
  }
}
```

---

## Implementation Checklist

### Homebrew

- [ ] Create Homebrew tap repository
- [ ] Write Formula file
- [ ] Test installation on macOS
- [ ] Test installation on Linux
- [ ] Set up CI/CD to publish formula
- [ ] Add livecheck support
- [ ] Document in README

### Scoop

- [ ] Create Scoop bucket
- [ ] Write manifest file
- [ ] Test installation on Windows 10/11
- [ ] Set up CI/CD to publish manifest
- [ ] Add auto-update support
- [ ] Document in README

---

## CI/CD Integration

### Publish Formula on Release

**Location:** `.github/workflows/release.yml`

```yaml
- name: Update Homebrew formula
  if: startsWith(github.ref, 'refs/tags/')
  run: |
    # Update version in Formula
    sed -i "s/url \".*\"/url \"https://github.com/watzon/sellia/archive/refs/tags/${{ github.ref_name }}.tar.gz\"/" Formula/sellia.rb
    sed -i "s/sha256 \".*\"/sha256 \"${SHASUM}\"/" Formula/sellia.rb

    # Commit to tap repository
    git clone https://${{ secrets.HOMEBREW_TOKEN }}@github.com/sellia/homebrew-tap.git
    cp Formula/sellia.rb homebrew-tap/Formula/sellia.rb
    cd homebrew-tap
    git config user.name "Sellia Bot"
    git config user.email "bot@sellia.me"
    git commit -am "Release ${{ github.ref_name }}"
    git push
```

---

### Publish Scoop Manifest

```yaml
- name: Update Scoop manifest
  if: startsWith(github.ref, 'refs/tags/')
  run: |
    # Update version in manifest
    cat > bucket/sellia.json <<EOF
    {
      "version": "${VERSION}",
      "url": ["https://github.com/watzon/sellia/releases/download/v${VERSION}/sellia-${VERSION}-windows-x86_64.exe#/sellia.exe"],
      "hash": "${SHASUM}"
    }
    EOF

    # Commit to bucket
    git clone https://${{ secrets.SCOOP_TOKEN }}@github.com/sellia/scoop-bucket.git
    cp bucket/sellia.json scoop-bucket/bucket/sellia.json
    cd scoop-bucket
    git config user.name "Sellia Bot"
    git config user.email "bot@sellia.me"
    git commit -am "Release ${VERSION}"
    git push
```

---

## Comparison

| Feature | Homebrew | Scoop |
|---------|----------|-------|
| Platforms | macOS, Linux | Windows |
| Package Format | Ruby formula | JSON manifest |
| Build from Source | Yes | No (binary only) |
| Auto-update | Yes (livecheck) | Yes (checkver) |
| Sandbox | Optional | Yes (by default) |

---

## Alternative Package Managers

### Linux

#### AUR (Arch Linux)

```bash
# Install from AUR
yay -S sellia

# Or manually
git clone https://aur.archlinux.org/sellia.git
cd sellia
makepkg -si
```

---

#### Snap (Ubuntu/Debian)

```bash
# Install snap
sudo snap install sellia

# Run tunnel
sellia.http 3000
```

---

#### Flatpak

```bash
# Install flatpak
flatpak install flathub me.sellia.Tunnel

# Run tunnel
flatpak run me.sellia.Tunnel http 3000
```

---

### macOS

#### MacPorts

```bash
# Install from MacPorts
sudo port install sellia

# Run tunnel
sellia http 3000
```

---

## User Documentation (Planned)

### macOS Installation

```markdown
## macOS

### Using Homebrew (recommended)

```bash
brew tap sellia/tap
brew install sellia
```

### Manual Install

Download binary from [releases page](https://github.com/watzon/sellia/releases).
```

---

### Linux Installation

```markdown
## Linux

### Using Homebrew

```bash
brew tap sellia/tap
brew install sellia
```

### Using AUR (Arch Linux)

```bash
yay -S sellia
```

### Manual Install

Download binary from [releases page](https://github.com/watzon/sellia/releases).
```

---

### Windows Installation

```markdown
## Windows

### Using Scoop (recommended)

```powershell
scoop bucket add sellia https://github.com/sellia/scoop-bucket
scoop install sellia
```

### Manual Install

Download `.exe` from [releases page](https://github.com/watzon/sellia/releases).
```

---

## Testing Package Installations

### Homebrew

```bash
# Test local formula
brew install --build-from-source Formula/sellia.rb

# Verify installation
sellia version

# Test tunnel
sellia http 3000
```

---

### Scoop

```powershell
# Test local manifest
scoop install .\bucket\sellia.json

# Verify installation
sellia version

# Test tunnel
sellia http 3000
```

---

## Resources

### Homebrew

- [Homebrew Documentation](https://docs.brew.edu/)
- [Formula Cookbook](https://docs.brew.edu/Formula-Cookbook.html)
- [Creating a Tap](https://docs.brew.edu/How-to-Create-and-Maintain-a-Tap.html)

### Scoop

- [Scoop Documentation](https://scoop.sh/)
- [Creating Apps](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [Creating Buckets](https://github.com/ScoopInstaller/Scoop/wiki/Buckets)

---

## See Also

- [Building Binaries](./building-binaries.md) - Build process
- [Docker Images](./docker-images.md) - Container distribution
- [Versioning Policy](./versioning.md) - Semantic versioning
- [Release Workflow](https://github.com/watzon/sellia/blob/main/.github/workflows/release.yml) - CI/CD
