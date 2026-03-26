#!/usr/bin/env bash
#
# setup-dev-environment.sh
# Cedar and Sage Studios - Development Environment Setup
#
# Installs: Homebrew, LG webOS TV CLI, VS Code, Claude Code
# Tested on: Ubuntu 24.04 LTS (x86_64)
#
# Usage:
#   ./setup-dev-environment.sh              # Run full setup
#   ./setup-dev-environment.sh --dry-run    # Preview commands without executing
#   ./setup-dev-environment.sh --step N     # Run only step N (1-4)

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DRY_RUN=false
STEP_ONLY=""

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()    { echo -e "${RED}[ERROR]${NC} $*"; }

run() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    else
        eval "$@"
    fi
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --step)    STEP_ONLY="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--step N] [-h|--help]"
            echo ""
            echo "Steps:"
            echo "  1  Install Homebrew (Linuxbrew)"
            echo "  2  Install LG webOS TV CLI (@webos-tools/cli)"
            echo "  3  Install VS Code"
            echo "  4  Install Claude Code (@anthropic-ai/claude-code)"
            exit 0
            ;;
        *) fail "Unknown option: $1"; exit 1 ;;
    esac
done

should_run() {
    [[ -z "$STEP_ONLY" ]] || [[ "$STEP_ONLY" == "$1" ]]
}

# ---------------------------------------------------------------------------
# Pre-flight checks
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

if $DRY_RUN; then
    warn "DRY-RUN mode enabled - no changes will be made"
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 1: Homebrew (Linuxbrew)
# ---------------------------------------------------------------------------
install_homebrew() {
    echo "----------------------------------------------"
    info "Step 1/4: Installing Homebrew (Linuxbrew)"
    echo "----------------------------------------------"

    if command -v brew &>/dev/null; then
        success "Homebrew is already installed: $(brew --version | head -1)"
        info "Updating Homebrew..."
        run "brew update"
        return
    fi

    info "Installing prerequisites..."
    run "apt-get update -qq && apt-get install -y -qq build-essential procps curl file git"

    info "Running Homebrew installer (non-interactive)..."
    run "NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

    # Add to PATH
    if [[ -d /home/linuxbrew/.linuxbrew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

        # Persist to shell profiles
        SHELLENV_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
        for rc_file in "$HOME/.bashrc" "$HOME/.profile"; do
            if ! grep -qF "linuxbrew" "$rc_file" 2>/dev/null; then
                run "echo '$SHELLENV_LINE' >> $rc_file"
            fi
        done
    fi

    if command -v brew &>/dev/null; then
        success "Homebrew installed: $(brew --version | head -1)"
    else
        fail "Homebrew installation could not be verified"
    fi
}

# ---------------------------------------------------------------------------
# Step 2: LG webOS TV CLI
# ---------------------------------------------------------------------------
install_webos_cli() {
    echo ""
    echo "----------------------------------------------"
    info "Step 2/4: Installing LG webOS TV CLI"
    echo "----------------------------------------------"

    if ! command -v node &>/dev/null; then
        fail "Node.js is required but not found. Please install Node.js first."
        return 1
    fi

    if command -v ares &>/dev/null; then
        success "webOS CLI is already installed: $(ares --version 2>/dev/null || echo 'version unknown')"
        info "Updating to latest version..."
    fi

    info "Installing @webos-tools/cli via npm..."
    run "npm install -g @webos-tools/cli@latest"

    info "Setting profile to TV mode..."
    run "ares-config --profile tv 2>/dev/null || true"

    if command -v ares &>/dev/null; then
        success "webOS TV CLI installed"
    else
        fail "webOS CLI installation could not be verified"
    fi

    echo ""
    warn "=== LG TV Setup (manual steps required) ==="
    echo "  1. Register at: https://webostv.developer.lge.com"
    echo "  2. On your LG TV: Install 'Developer Mode' app from LG Content Store"
    echo "  3. Enable Dev Mode on TV, note the IP address and passphrase"
    echo "  4. Pair with TV:  ares-setup-device"
    echo "  5. Install key:   ares-novacom --device <name> --getkey"
    echo "  6. Test:          ares-install --device <name> --list"
    echo ""
    warn "Dev mode sessions expire every ~50 hours and must be renewed!"
}

# ---------------------------------------------------------------------------
# Step 3: VS Code
# ---------------------------------------------------------------------------
install_vscode() {
    echo ""
    echo "----------------------------------------------"
    info "Step 3/4: Installing Visual Studio Code"
    echo "----------------------------------------------"

    if command -v code &>/dev/null; then
        success "VS Code is already installed: $(code --version 2>/dev/null | head -1)"
        return
    fi

    info "Adding Microsoft apt repository..."
    run "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg"
    run "install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg"
    run "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main' | tee /etc/apt/sources.list.d/vscode.list > /dev/null"

    info "Installing VS Code..."
    run "apt-get update -qq && apt-get install -y -qq code"
    run "rm -f /tmp/packages.microsoft.gpg"

    if command -v code &>/dev/null; then
        success "VS Code installed: $(code --version 2>/dev/null | head -1)"
    else
        fail "VS Code installation could not be verified"
    fi
}

# ---------------------------------------------------------------------------
# Step 4: Claude Code
# ---------------------------------------------------------------------------
install_claude_code() {
    echo ""
    echo "----------------------------------------------"
    info "Step 4/4: Installing Claude Code (latest from npm)"
    echo "----------------------------------------------"

    if command -v claude &>/dev/null; then
        success "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'version unknown')"
        info "Updating to latest version..."
    fi

    info "Installing @anthropic-ai/claude-code@latest via npm..."
    run "npm install -g @anthropic-ai/claude-code@latest"

    if command -v claude &>/dev/null; then
        success "Claude Code installed: $(claude --version 2>/dev/null || echo 'installed')"
    else
        fail "Claude Code installation could not be verified"
    fi
}

# ---------------------------------------------------------------------------
# Run steps
# ---------------------------------------------------------------------------
should_run 1 && install_homebrew
should_run 2 && install_webos_cli
should_run 3 && install_vscode
should_run 4 && install_claude_code

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

check_tool "Homebrew"        "brew"
check_tool "webOS TV CLI"    "ares"
check_tool "VS Code"         "code"
check_tool "Claude Code"     "claude"

echo ""
if $DRY_RUN; then
    warn "This was a dry run. Re-run without --dry-run to install."
else
    success "Setup complete! You may need to restart your shell or run:"
    echo "  source ~/.bashrc"
fi
echo ""
