#!/usr/bin/env bash
#
# setup-dev-environment.sh
# Cedar and Sage Studios - Development Environment Setup
#
# Installs:
#   1. webOS CLI tools + Homebrew Channel on LG TV
#   2. VS Code
#   3. Claude Code
#
# Tested on: Chromebook Crostini (Debian 12), Ubuntu 24.04 LTS
#
# Usage:
#   ./setup-dev-environment.sh              # Run full setup
#   ./setup-dev-environment.sh --step N     # Run only step N (1-3)

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()    { echo -e "${RED}[ERROR]${NC} $*"; }

STEP_ONLY=""
APT_UPDATED=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --step)    STEP_ONLY="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--step N] [-h|--help]"
            echo ""
            echo "Steps:"
            echo "  1  Install webOS CLI + Homebrew Channel on LG TV"
            echo "  2  Install VS Code"
            echo "  3  Install Claude Code"
            exit 0
            ;;
        *) fail "Unknown option: $1"; exit 1 ;;
    esac
done

should_run() {
    [[ -z "$STEP_ONLY" ]] || [[ "$STEP_ONLY" == "$1" ]]
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Cedar & Sage - Dev Environment Setup"
echo "=============================================="
echo ""

info "System: $(uname -srm)"
info "OS: $(. /etc/os-release && echo "$PRETTY_NAME")"
info "Node: $(node --version 2>/dev/null || echo 'not found')"
info "npm: $(npm --version 2>/dev/null || echo 'not found')"
echo ""

# Detect sudo
if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
    info "Running as user '$(whoami)' - will use sudo for system commands"
    if ! $SUDO -v 2>/dev/null; then
        fail "sudo access required. Run: sudo passwd \$(whoami) to set a password first."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

# Run apt-get update at most once per invocation to avoid redundant index fetches.
apt_update_once() {
    if [[ "$APT_UPDATED" -eq 0 ]]; then
        info "Updating apt package index..."
        $SUDO apt-get update -qq
        APT_UPDATED=1
    fi
}

# Ensure Node.js is present; install via apt if missing.
ensure_nodejs() {
    if command -v node &>/dev/null; then
        return 0
    fi
    warn "Node.js not found. Installing via apt..."
    apt_update_once
    $SUDO apt-get install -y -qq nodejs npm
    if ! command -v node &>/dev/null; then
        fail "Node.js installation failed."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Step 1: webOS CLI + Homebrew Channel on LG TV
# ---------------------------------------------------------------------------
install_homebrew_channel() {
    echo "----------------------------------------------"
    info "Step 1/3: LG TV Homebrew Channel Setup"
    echo "----------------------------------------------"

    # 1a: Ensure Node.js is available
    ensure_nodejs || return 1
    success "Node.js $(node --version)"

    # 1b: Install webOS CLI tools
    if command -v ares-install &>/dev/null; then
        success "webOS CLI already installed"
    else
        info "Installing webOS CLI tools (@webos-tools/cli)..."
        $SUDO npm install -g @webos-tools/cli@latest
    fi

    if command -v ares-install &>/dev/null; then
        success "webOS CLI ready"
    else
        fail "webOS CLI install failed"
        return 1
    fi

    # 1c: Set up TV device
    echo ""
    info "Now let's connect to your LG TV."
    echo ""
    echo "  Make sure on your TV:"
    echo "    - Developer Mode app is open"
    echo "    - Dev Mode is ON"
    echo "    - Key Server is ON"
    echo "    - Note the IP address and passphrase shown"
    echo ""

    read -rp "Enter your LG TV's IP address (e.g. 192.168.1.100): " TV_IP
    read -rp "Enter a name for this device [lgtv]: " TV_NAME
    TV_NAME="${TV_NAME:-lgtv}"

    info "Adding TV device '$TV_NAME' at $TV_IP..."
    ares-setup-device --add "$TV_NAME" --info "{\"host\":\"$TV_IP\",\"port\":\"9922\",\"username\":\"prisoner\"}"

    echo ""
    info "Getting device key (enter the passphrase from Developer Mode app)..."
    ares-novacom --device "$TV_NAME" --getkey

    # Verify connection
    echo ""
    info "Verifying connection to TV..."
    if ares-device-info --device "$TV_NAME" 2>/dev/null; then
        success "Connected to LG TV!"
    else
        fail "Could not connect to TV. Check IP and that Dev Mode + Key Server are ON."
        return 1
    fi

    # 1d: Download and install Homebrew Channel
    echo ""
    info "Downloading latest Homebrew Channel .ipk..."
    HBC_IPK="/tmp/homebrew-channel.ipk"
    HBC_FALLBACK_URL="https://github.com/nicoquinterosc/Homebrew-channel-/releases/download/v0.7.2/org.nicoquinterosc.homebrewchannel_0.7.2_all.ipk"

    # Try to get the actual latest release URL from GitHub API.
    # grep/cut is used here instead of jq because jq is not guaranteed to be
    # present on a minimal Debian/Crostini install.
    WEBOSBREW_URL=$(curl -fsL --connect-timeout 15 --max-time 30 \
        "https://api.github.com/repos/nicoquinterosc/Homebrew-channel-/releases/latest" 2>/dev/null \
        | grep -o '"browser_download_url": "[^"]*\.ipk"' | head -1 | cut -d'"' -f4) || true

    DOWNLOAD_URL="${WEBOSBREW_URL:-$HBC_FALLBACK_URL}"
    [[ -z "$WEBOSBREW_URL" ]] && info "API lookup failed; using pinned fallback URL."

    if ! curl -fL --connect-timeout 30 --max-time 120 -o "$HBC_IPK" "$DOWNLOAD_URL"; then
        fail "Could not download Homebrew Channel .ipk automatically."
        echo ""
        echo "  Download it manually from:"
        echo "    https://github.com/nicoquinterosc/Homebrew-channel-/releases"
        echo "  Then install with:"
        echo "    ares-install --device $TV_NAME /path/to/file.ipk"
        return 1
    fi

    info "Installing Homebrew Channel on TV..."
    ares-install --device "$TV_NAME" "$HBC_IPK"

    success "Homebrew Channel installed on your LG TV!"
    echo ""
    echo "  Open Homebrew Channel on your TV to browse and install apps."
    echo ""
    warn "Developer Mode expires every 1000 hours (~41 days)."
    warn "Open the Developer Mode app on your TV and click 'Extend' before it expires."
    rm -f "$HBC_IPK"
}

# ---------------------------------------------------------------------------
# Step 2: VS Code
# ---------------------------------------------------------------------------
install_vscode() {
    echo ""
    echo "----------------------------------------------"
    info "Step 2/3: Installing Visual Studio Code"
    echo "----------------------------------------------"

    if command -v code &>/dev/null; then
        success "VS Code is already installed: $(code --version 2>/dev/null | head -1)"
        return
    fi

    info "Adding Microsoft apt repository..."
    curl -fsSL --connect-timeout 15 --max-time 30 https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor | $SUDO tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null
    $SUDO chmod 644 /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null

    info "Installing VS Code..."
    apt_update_once
    $SUDO apt-get install -y -qq code

    if command -v code &>/dev/null; then
        success "VS Code installed: $(code --version 2>/dev/null | head -1)"
    else
        fail "VS Code installation could not be verified"
    fi
}

# ---------------------------------------------------------------------------
# Step 3: Claude Code
# ---------------------------------------------------------------------------
install_claude_code() {
    echo ""
    echo "----------------------------------------------"
    info "Step 3/3: Installing Claude Code (latest)"
    echo "----------------------------------------------"

    ensure_nodejs || return 1

    info "Installing @anthropic-ai/claude-code@latest via npm..."
    $SUDO npm install -g @anthropic-ai/claude-code@latest

    if command -v claude &>/dev/null; then
        success "Claude Code installed: $(claude --version 2>/dev/null || echo 'installed')"
    else
        fail "Claude Code installation could not be verified"
    fi
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
should_run 1 && install_homebrew_channel
should_run 2 && install_vscode
should_run 3 && install_claude_code

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Installation Summary"
echo "=============================================="

check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}+${NC} $name"
    else
        echo -e "  ${RED}-${NC} $name (not found)"
    fi
}

check_tool "webOS TV CLI"    "ares-install"
check_tool "VS Code"         "code"
check_tool "Claude Code"     "claude"

echo ""
success "Done! Restart your shell or run: source ~/.bashrc"
echo ""
