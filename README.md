# Linux Development Environment Setup

A comprehensive, multi-distribution Linux development environment setup script with support for Ubuntu and Debian.

## 🚀 Features

- **Multi-Distribution Support**: Automatically detects Ubuntu or Debian and runs the appropriate script
- **Organized Structure**: Clean directory organization with modular components
- **Comprehensive Tools**: Installs development tools, editors, virtualization, and productivity software
- **Interactive Menu**: User-friendly menu system for selective installation
- **Backup System**: Automatically backs up existing configurations

## 📁 Directory Structure

```
linux_config/
├── setup.sh                    # Main launcher script (run this)
├── scripts/
│   ├── common/
│   │   └── functions.sh        # Shared functions for both distros
│   └── distro/
│       ├── ubuntu_setup.sh     # Ubuntu-specific setup
│       └── debian_setup.sh     # Debian-specific setup
├── dotfiles/                   # Your configuration files
│   ├── .zshrc
│   ├── .tmux.conf
│   ├── .p10k.zsh
│   └── config                  # Ghostty config
└── README.md                   # This file
```

## 🎯 What Gets Installed

### Core Development Tools
- Build essentials (gcc, cmake, pkg-config, etc.)
- Git, curl, wget, tree, unzip
- Development libraries and headers

### Terminal & Productivity
- **Zsh** with Oh My Zsh and Powerlevel10k theme
- **Tmux** with TPM (Tmux Plugin Manager)
- **Neovim** (built from source) with NvChad configuration
- **Nerd Fonts** (MesloLGS for terminal icons)
- Modern CLI tools: bat, btop, htop, neofetch, fzf, thefuck

### Development Environment
- **Rust** (via rustup) with eza (modern ls replacement)
- **Docker** with docker-compose
- **Virt-Manager** with KVM/QEMU for virtualization

### Applications
- **Snap packages**: VS Code, Discord, Obsidian, Wave Terminal
- **OpenVPN3** client
- **SSH Server** (optional)
- **Remote Desktop**: FreeRDP client

## 🚀 Quick Start

1. **Clone or download this repository**:
   ```bash
   git clone <repository-url> ~/linux_config
   cd ~/linux_config
   ```

2. **Make the main script executable**:
   ```bash
   chmod +x setup.sh
   ```

3. **Run the setup**:
   ```bash
   ./setup.sh
   ```

The script will automatically detect your OS (Ubuntu/Debian) and present you with an interactive menu.

## 📋 Menu Options

1. **Run Full Installation**: Installs everything automatically
2. **Update System Packages**: Updates all system packages
3. **Install Core Tools**: Essential development tools and libraries
4. **Setup Zsh & Oh My Zsh**: Terminal shell and theme setup
5. **Install Neovim & NvChad**: Modern text editor with configuration
6. **Install Nerd Fonts**: Fonts with icon support
7. **Copy Dotfiles**: Copies your configuration files
8. **Setup Rust Environment**: Rust programming language and tools
9. **Install OpenVPN3**: VPN client
10. **Install Docker**: Container platform
11. **Install SSH Server**: Remote access server
12. **Install Virt-Manager**: Virtualization management
13. **Install Snap Packages**: Modern applications
**c. Check Installation Status**: Comprehensive status check of all components

## 🔧 Customization

### Adding Your Dotfiles
Place your configuration files in the `dotfiles/` directory:
- `.zshrc` - Zsh configuration
- `.tmux.conf` - Tmux configuration  
- `.p10k.zsh` - Powerlevel10k theme configuration
- `config` - Ghostty terminal configuration

### Modifying Package Lists
Edit the respective distro files:
- `scripts/distro/ubuntu_setup.sh` for Ubuntu-specific packages
- `scripts/distro/debian_setup.sh` for Debian-specific packages
- `scripts/common/functions.sh` for shared functionality

## � Installation Status Checker

The new **Check Installation Status** feature provides a comprehensive overview of your development environment:

- ✅ **Detailed Component Check**: Verifies installation of all major components
- 📊 **Progress Tracking**: Shows completion percentage and summary statistics  
- 🎯 **Version Information**: Displays version numbers for installed tools
- 🚦 **Status Indicators**: 
  - ✓ Fully installed and working
  - ◐ Installed but not running/configured
  - ✗ Missing or not installed
- 📈 **Smart Recommendations**: Suggests next steps based on completion status

Use option `c` in any menu to run the comprehensive status check.

## �🛠️ Distribution Differences

### Ubuntu Features
- Uses Ubuntu-specific repositories for Docker and OpenVPN3
- Optimized package selections for Ubuntu
- Better snap package support

### Debian Features  
- Uses Debian-specific repositories
- Enhanced SSH server conflict resolution
- Debian-optimized package management

## 🔒 Security & Safety

- **Never runs as root**: Script checks and prevents root execution
- **Backup system**: Automatically backs up existing configurations
- **Confirmation prompts**: Asks before making significant changes
- **Error handling**: Comprehensive error checking and reporting

## 🐛 Troubleshooting

### SSH Package Conflicts (Debian)
If you encounter SSH package conflicts on Debian, the script includes automatic resolution. If automatic resolution fails, manually run:
```bash
sudo apt remove --purge openssh-client openssh-server
sudo apt autoremove
sudo apt install openssh-server openssh-client
```

### Permission Issues
If you get permission errors:
```bash
chmod +x setup.sh
chmod +x scripts/distro/*.sh
chmod +x scripts/common/functions.sh
```

### Docker Permission
After Docker installation, you may need to log out and back in to use Docker without sudo.

## 📝 Requirements

- Ubuntu 18.04+ or Debian 10+
- Internet connection for package downloads
- At least 2GB free disk space
- Regular user account with sudo privileges

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is open source and available under the MIT License.
