# cedar-and-sage-apothecary
Cedar and Sage Studios: Apothecary Line. Premium, nature-inspired loungewear.

## Development Environment Setup

### Prerequisites
- Chromebook (Crostini/Debian 12) or Ubuntu 24.04 LTS
- Sudo password set (`sudo passwd $(whoami)` if you haven't)
- LG TV with **Developer Mode** app enabled, Dev Mode ON, Key Server ON

### Quick Start

```bash
./setup-dev-environment.sh              # Full setup (TV + VS Code + Claude Code)
./setup-dev-environment.sh --step 1     # LG TV Homebrew Channel only
./setup-dev-environment.sh --step 2     # VS Code only
./setup-dev-environment.sh --step 3     # Claude Code only
```

### What Gets Installed

| Step | Tool | Where | Purpose |
|---|---|---|---|
| 1 | [webOS CLI](https://webostv.developer.lge.com) + [Homebrew Channel](https://www.webosbrew.org/) | LG TV | Unofficial app store for your LG TV |
| 2 | [VS Code](https://code.visualstudio.com/) | Chromebook | Code editor |
| 3 | [Claude Code](https://github.com/anthropics/claude-code) | Chromebook | AI-powered CLI assistant (v2.1.76+) |

### LG TV Homebrew Channel

The script will walk you through connecting to your TV. Before running, make sure:

1. **Developer Mode** app is open on the TV
2. **Dev Mode** is toggled ON
3. **Key Server** is toggled ON
4. Note the **IP address** and **passphrase** shown on screen

The script installs the webOS CLI tools, connects to your TV, downloads the Homebrew Channel `.ipk`, and installs it.

> **Note:** Developer Mode expires every ~1000 hours. Open the Developer Mode app on your TV and click "Extend" before it expires, or your sideloaded apps will be removed.
