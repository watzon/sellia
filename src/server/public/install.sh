#!/bin/bash
set -euo pipefail

# Sellia installer script
# Usage: curl -fsSL https://sellia.me/install.sh | bash
#        curl -fsSL https://sellia.me/install.sh | bash -s -- --user
#        curl -fsSL https://sellia.me/install.sh | bash -s -- --out ~/bin

REPO="watzon/sellia"
BINARY_NAME="sellia"

# Colors (disabled if not a tty)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  CYAN=''
  BOLD=''
  NC=''
fi

info() { echo -e "${CYAN}${BOLD}==>${NC} $1"; }
success() { echo -e "${GREEN}${BOLD}==>${NC} $1"; }
warn() { echo -e "${YELLOW}${BOLD}Warning:${NC} $1"; }
error() { echo -e "${RED}${BOLD}Error:${NC} $1" >&2; exit 1; }

# Defaults
INSTALL_DIR=""
INSTALL_USER=false
VERSION="latest"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --user)
      INSTALL_USER=true
      shift
      ;;
    --out)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --help|-h)
      echo "Sellia Installer"
      echo ""
      echo "Usage: curl -fsSL https://sellia.me/install.sh | bash [-- OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --user           Install to ~/.local/bin (no sudo required)"
      echo "  --out PATH       Install to custom directory"
      echo "  --version VER    Install specific version (e.g., v0.3.0)"
      echo "  --help, -h       Show this help"
      echo ""
      echo "Examples:"
      echo "  curl -fsSL https://sellia.me/install.sh | bash"
      echo "  curl -fsSL https://sellia.me/install.sh | bash -s -- --user"
      echo "  curl -fsSL https://sellia.me/install.sh | bash -s -- --out ~/bin"
      echo "  curl -fsSL https://sellia.me/install.sh | bash -s -- --version v0.3.0"
      exit 0
      ;;
    *)
      error "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

# Detect OS
detect_os() {
  local os
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    darwin) echo "darwin" ;;
    linux) echo "linux" ;;
    mingw*|msys*|cygwin*) echo "windows" ;;
    *) error "Unsupported operating system: $os" ;;
  esac
}

# Detect architecture
detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) error "Unsupported architecture: $arch" ;;
  esac
}

# Get install directory
get_install_dir() {
  if [ -n "$INSTALL_DIR" ]; then
    echo "$INSTALL_DIR"
  elif [ "$INSTALL_USER" = true ]; then
    echo "$HOME/.local/bin"
  else
    local os
    os=$(detect_os)
    case "$os" in
      darwin|linux) echo "/usr/local/bin" ;;
      windows) echo "$LOCALAPPDATA/Programs/sellia" ;;
    esac
  fi
}

# Check if we need sudo
needs_sudo() {
  local dir="$1"
  if [ -w "$dir" ] 2>/dev/null || [ -w "$(dirname "$dir")" ] 2>/dev/null; then
    return 1
  fi
  return 0
}

# Get latest version from GitHub API
get_latest_version() {
  local url="https://api.github.com/repos/${REPO}/releases/latest"
  local response

  if command -v curl &>/dev/null; then
    response=$(curl -fsSL "$url" 2>/dev/null) || error "Failed to fetch release info from GitHub"
  elif command -v wget &>/dev/null; then
    response=$(wget -qO- "$url" 2>/dev/null) || error "Failed to fetch release info from GitHub"
  else
    error "Neither curl nor wget found. Please install one of them."
  fi

  echo "$response" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4
}

# Download file
download() {
  local url="$1"
  local dest="$2"

  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$dest" || return 1
  elif command -v wget &>/dev/null; then
    wget -q "$url" -O "$dest" || return 1
  else
    error "Neither curl nor wget found"
  fi
}

main() {
  echo -e "${CYAN}${BOLD}"
  echo "   ___      _ _ _       "
  echo "  / __| ___| | (_) __ _ "
  echo "  \__ \/ -_) | | / _\` |"
  echo "  |___/\___|_|_|_\__,_|"
  echo -e "${NC}"
  echo "  Secure tunnels to localhost"
  echo ""

  # Detect platform
  local os arch
  os=$(detect_os)
  arch=$(detect_arch)
  info "Detected platform: ${os}-${arch}"

  # Get version
  local version
  if [ "$VERSION" = "latest" ]; then
    info "Fetching latest version..."
    version=$(get_latest_version)
    [ -z "$version" ] && error "Could not determine latest version"
  else
    version="$VERSION"
    # Ensure version starts with 'v'
    [[ "$version" != v* ]] && version="v$version"
  fi
  info "Version: $version"

  # Determine install directory
  local install_dir
  install_dir=$(get_install_dir)

  # Create directory if needed
  if [ ! -d "$install_dir" ]; then
    info "Creating directory: $install_dir"
    if needs_sudo "$install_dir"; then
      sudo mkdir -p "$install_dir"
    else
      mkdir -p "$install_dir"
    fi
  fi

  # Build download URL
  local binary_name="sellia-${os}-${arch}"
  [ "$os" = "windows" ] && binary_name="${binary_name}.exe"
  local download_url="https://github.com/${REPO}/releases/download/${version}/${binary_name}"

  info "Downloading from: $download_url"

  # Download to temp file
  local tmp_file
  tmp_file=$(mktemp)
  trap "rm -f '$tmp_file'" EXIT

  download "$download_url" "$tmp_file" || error "Failed to download binary. Check if version $version exists."

  # Make executable
  chmod +x "$tmp_file"

  # Install
  local dest_path="${install_dir}/${BINARY_NAME}"
  [ "$os" = "windows" ] && dest_path="${dest_path}.exe"

  info "Installing to: $dest_path"

  if needs_sudo "$install_dir"; then
    sudo mv "$tmp_file" "$dest_path"
    sudo chmod +x "$dest_path"
  else
    mv "$tmp_file" "$dest_path"
    chmod +x "$dest_path"
  fi

  # Verify installation
  if [ -x "$dest_path" ]; then
    success "Sellia $version installed successfully!"
    echo ""

    # Check if in PATH
    if ! command -v sellia &>/dev/null; then
      warn "$install_dir is not in your PATH"
      echo ""
      echo "Add it to your shell profile:"
      echo ""
      echo "  # For bash (~/.bashrc or ~/.bash_profile)"
      echo "  export PATH=\"\$PATH:$install_dir\""
      echo ""
      echo "  # For zsh (~/.zshrc)"
      echo "  export PATH=\"\$PATH:$install_dir\""
      echo ""
      echo "  # For fish (~/.config/fish/config.fish)"
      echo "  fish_add_path $install_dir"
      echo ""
    else
      echo "Run 'sellia help' to get started"
    fi
  else
    error "Installation failed"
  fi
}

main "$@"
