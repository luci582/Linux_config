# Cross-Platform Development Environment Setup

A modular setup script for Ubuntu, Debian, and macOS. Supports **desktop** (full workstation) and **server** (headless, no GUI apps) install modes.

## Features

- **Multi-OS**: Auto-detects Ubuntu, Debian (and derivatives via `ID_LIKE`), and macOS
- **Two install modes**:
  - `--desktop` (default): full workstation — editors, terminals, GUI apps, virtualization
  - `--server`: headless — no GUI apps, no snap/cask GUI packages, no ghostty, no GNOME extensions, no virt-manager, Nerd Fonts skipped, Docker runs via Colima on macOS
- **Homebrew on macOS** (installs Homebrew automatically if missing)
- **apt on Debian/Ubuntu**
- **Interactive menu** with full install or granular steps
- **Installation status check** built-in
- **Non-root enforced**

## Quick Start

```bash
git clone https://github.com/luci582/Linux_config.git ~/linux_config
cd ~/linux_config
chmod +x setup.sh

# Full desktop install (default)
./setup.sh

# Server / headless install
./setup.sh --server
```

Equivalent env-var invocation:

```bash
INSTALL_MODE=server ./setup.sh
```

## What Gets Installed

| Component | Desktop | Server | Linux | macOS |
|---|---|---|---|---|
| Core CLI (git, curl, tmux, zsh, htop, fzf, bat, btop, neofetch, thefuck) | ✅ | ✅ | ✅ | ✅ |
| Build tools (cmake, gcc, pkg-config) | ✅ | ✅ | ✅ | ✅ |
| Zsh + Oh My Zsh + Powerlevel10k + plugins | ✅ | ✅ | ✅ | ✅ |
| Tmux + TPM | ✅ | ✅ | ✅ | ✅ |
| Neovim + NvChad | ✅ | ✅ | ✅ (source build) | ✅ (brew) |
| Rust + eza | ✅ | ✅ | ✅ | ✅ |
| Docker | ✅ (engine / Desktop cask) | ✅ (engine / Colima) | ✅ | ✅ |
| SSH server | optional | optional | ✅ (`openssh-server`) | ✅ (`systemsetup`) |
| Nerd Fonts (MesloLGS) | ✅ | ❌ | ✅ | ✅ (cask) |
| Ghostty config | ✅ | ❌ | ✅ | ✅ |
| Snap GUI apps (VS Code, Obsidian, Discord, Wave) | ✅ | ❌ | ✅ | ❌ |
| Homebrew Cask apps (VS Code, Obsidian, Ghostty) | ✅ | ❌ | ❌ | ✅ |
| Virt-Manager + KVM/QEMU | ✅ | ❌ | ✅ | ❌ |
| GNOME Shell extensions | ✅ | ❌ | ✅ (GNOME only) | ❌ |

## Directory Structure

```
linux_config/
├── setup.sh                       # Main launcher (OS detection + mode flag)
├── scripts/
│   ├── common/
│   │   └── functions.sh           # Shared functions (Linux + macOS)
│   └── distro/
│       ├── ubuntu_setup.sh
│       ├── debian_setup.sh
│       └── macos_setup.sh         # NEW
├── dotfiles/
│   ├── .zshrc
│   ├── .bashrc
│   ├── .tmux.conf
│   ├── .p10k.zsh
│   └── config                     # Ghostty (desktop only)
└── README.md
```

## CLI Options

```
Usage: ./setup.sh [--server | --desktop] [--help]

Options:
  --server     Headless / server install (no GUI apps).
  --desktop    Full workstation install (default).
  -h, --help   Show help.

Environment overrides:
  INSTALL_MODE=server|desktop       Same as the matching flag.
  FORCE_DISTRO=ubuntu|debian|macos  Skip auto-detection (CI use).
```

## Menu Options

Same across all three OS scripts (macOS omits Linux-only items):

1. **Run Full Installation** — all steps for the current mode
2. **Update System** — `apt full-upgrade` on Linux / `brew update && upgrade` on macOS
3. **Install Core Tools**
4. **Setup Zsh & Oh My Zsh**
5. **Install Neovim & NvChad**
6. **Install Nerd Fonts** (skipped in server mode)
7. **Copy Dotfiles**
8. **Setup Rust Environment**
9. **Install Docker**
10. **Install SSH Server** (Linux: `openssh-server`; macOS: `systemsetup -setremotelogin on`)
11. **Install Virt-Manager** *(Linux only, desktop only)*
12. **Install Snap Packages** *(Linux only, desktop only)*
13. **Install GNOME Extensions** *(Linux GNOME only, desktop only)*
14. **Update GNOME Extensions** *(Linux GNOME only, desktop only)*
- `c` Check Installation Status
- `s` Show System Information
- `q` Quit

## Customization

### Dotfiles

Edit files in `dotfiles/` before running `./setup.sh` option 7.

### Package Lists

- Ubuntu: `scripts/distro/ubuntu_setup.sh` → `install_core_tools()`
- Debian: `scripts/distro/debian_setup.sh` → `install_core_tools()`
- macOS:  `scripts/distro/macos_setup.sh`  → `install_core_tools()` (edit `core_formulae` / `casks` arrays)
- Shared: `scripts/common/functions.sh`

## Requirements

- **Linux**: Ubuntu 18.04+ or Debian 10+ (or `ID_LIKE=debian` derivative), `sudo`, internet
- **macOS**: 12+, Xcode Command Line Tools (`xcode-select --install`), internet
- Regular user account (scripts refuse to run as root)
- ~2 GB free disk space

## Troubleshooting

### macOS: Homebrew install fails
Install manually from https://brew.sh, then re-run `./setup.sh`.

### macOS: nerd font cask fails
```bash
brew tap homebrew/cask-fonts
brew install --cask font-meslo-lg-nerd-font
```

### Linux: SSH package conflicts on Debian
Scripts attempt auto-resolution. Manual fallback:
```bash
sudo apt remove --purge openssh-client openssh-server
sudo apt autoremove
sudo apt install openssh-server openssh-client
```

### Permissions
```bash
chmod +x setup.sh
chmod +x scripts/distro/*.sh scripts/common/*.sh
```

### Docker without sudo (Linux)
Log out and back in after install to pick up the `docker` group.

## Security

- Never runs as root
- Backs up existing dotfiles with `.bak.<timestamp>` before overwriting
- Confirmation prompts before destructive changes
- Explicit error handling throughout

## License

MIT
