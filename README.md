# cedar-and-sage-apothecary
Cedar and Sage Studios: Apothecary Line. Premium, nature-inspired loungewear.

## Development Environment Setup

### Prerequisites
- Ubuntu 24.04 LTS (or compatible Debian-based distro, including Chromebook Crostini)
- Node.js v18+ and npm (v22 recommended) -- script will attempt to install if missing
- Git, curl, wget
- **Chromebook users:** You need a sudo password set. If you've never set one, run:
  ```bash
  sudo passwd $(whoami)
  ```

### Quick Start

```bash
# Run the full setup (installs Homebrew, webOS TV CLI, VS Code, Claude Code)
./setup-dev-environment.sh

# Preview what will be installed without making changes
./setup-dev-environment.sh --dry-run

# Install only a specific tool
./setup-dev-environment.sh --step 1   # Homebrew only
./setup-dev-environment.sh --step 2   # LG webOS TV CLI only
./setup-dev-environment.sh --step 3   # VS Code only
./setup-dev-environment.sh --step 4   # Claude Code only
```

### What Gets Installed

| Tool | Version | Purpose |
|---|---|---|
| [Homebrew](https://brew.sh/) | ~5.1.1 | Package manager for Linux |
| [webOS TV CLI](https://webostv.developer.lge.com) | ~3.2.0+ | LG smart TV app development (`ares-*` commands) |
| [VS Code](https://code.visualstudio.com/) | latest | Code editor |
| [Claude Code](https://github.com/anthropics/claude-code) | ~2.1.76 | AI-powered CLI assistant |

### LG TV Development

After running the setup, you'll need to manually configure your LG TV for development:

1. Register at [webOS TV Developer](https://webostv.developer.lge.com)
2. Install the **Developer Mode** app on your LG TV from the LG Content Store
3. Enable Dev Mode and note the TV's IP address and passphrase
4. Pair your machine with the TV: `ares-setup-device`
5. Install the dev key: `ares-novacom --device <name> --getkey`
6. Verify: `ares-install --device <name> --list`

> **Note:** Developer mode sessions expire every ~50 hours and must be renewed via the Developer Mode app on the TV.
