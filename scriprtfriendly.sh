
#!/usr/bin/env bash

# --- Script Configuration and Safety ---
# Exit immediately if a command exits with a non-zero status.
# Exit on error, undefined variable, and error in pipeline
set -euo pipefail

# --- Color Definitions for UI ---
C_DEFAULT='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

# --- Helper Functions ---
# Prints a formatted header message.
print_header() {
    printf "\n%b%s%b\n" "${C_BLUE}${C_BOLD}" "--- $1 ---" "${C_DEFAULT}"
}

# Prints an error message and exits
die() {
    printf "\n%b[ERROR]%b %s\n" "${C_RED}${C_BOLD}" "${C_DEFAULT}" "$1" >&2
    exit 1
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        die "This script should not be run as root. Please run as a regular user."
    fi
}

# Check if system is Debian/Ubuntu based
check_debian_ubuntu() {
    if [[ ! -f /etc/debian_version ]]; then
        die "This script is designed for Debian/Ubuntu systems only."
    fi
}

# Prompt user for confirmation
confirm() {
    local prompt="${1:-Continue?}"
    printf "%b%s [y/N]: %b" "${C_YELLOW}" "$prompt" "${C_DEFAULT}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# --- Installation and Setup Functions ---

update_system() {
    print_header "Updating and Upgrading System Packages"
    if ! command -v apt >/dev/null 2>&1; then
        die "This script requires apt (Debian/Ubuntu)."
    fi
    sudo apt update -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
}

install_core_tools() {
    print_header "Installing Core Packages & Tools"
    # Note: apt-transport-https is no longer needed for modern Ubuntu/Debian versions
    sudo apt install -y \
        curl git wget gpg ca-certificates \
        virtualbox tmux zsh flameshot \
        snapd bat btop freerdp2-x11 lsb-release \
        build-essential software-properties-common \
        unzip tree htop neofetch
}

purge_old_editors() {
    print_header "Purging Old Vim/Neovim to prevent conflicts"
    sudo apt purge -y vim || true
    sudo apt purge -y neovim || true
}

setup_rust() {
    print_header "Installing Rust and Cargo Packages"
    if ! command -v rustup >/dev/null 2>&1; then
        printf "%bInstalling Rust via rustup...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        printf "%bRust installation completed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    else
        printf "%bRust is already installed, updating...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        rustup update
    fi
    
    # Source the cargo env to use it immediately in this script session.
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    
    if ! command -v cargo >/dev/null 2>&1; then
        die "Cargo not found after rustup install."
    fi
    
    # Install eza if not already installed
    if ! cargo install --list | grep -q '^eza '; then
        printf "%bInstalling eza (modern ls replacement)...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        cargo install eza
    else
        printf "%beza is already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Make Cargo persistent for new shells - check both .zshrc and .bashrc
    for rc_file in ~/.zshrc ~/.bashrc; do
        if [[ -f "$rc_file" ]] && ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$rc_file" 2>/dev/null; then
            echo -e "\n# Add Cargo to PATH" >> "$rc_file"
            echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$rc_file"
            printf "%bRust/Cargo PATH added to %s%b\n" "${C_GREEN}" "$(basename "$rc_file")" "${C_DEFAULT}"
        fi
    done
}

setup_openvpn() {
    print_header "Installing OpenVPN3"
    # Detect codename for Ubuntu/Debian
    codename=$(lsb_release -cs 2>/dev/null || echo "bookworm")
    sudo mkdir -p /etc/apt/keyrings
    curl -sSfL https://packages.openvpn.net/packages-repo.gpg | sudo tee /etc/apt/keyrings/openvpn.asc > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian $codename main" | sudo tee /etc/apt/sources.list.d/openvpn3.list > /dev/null
    sudo apt update
    sudo apt install -y openvpn3 || sudo apt install -y openvpn
}

install_snap_packages() {
    print_header "Installing Snap Packages"
    if ! command -v snap >/dev/null 2>&1; then
        printf "%bSnapd not found. Installing snapd...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        sudo apt update && sudo apt install -y snapd
        # Wait for snapd to be ready
        sleep 5
    fi
    
    # Array of snap packages to install
    declare -a snap_packages=(
        "waveterm --classic"
        "obsidian --classic" 
        "code --classic"
        "discord"
    )
    
    for package in "${snap_packages[@]}"; do
        package_name=$(echo "$package" | awk '{print $1}')
        if ! snap list | grep -q "^$package_name "; then
            printf "%bInstalling snap package: %s%b\n" "${C_YELLOW}" "$package_name" "${C_DEFAULT}"
            # shellcheck disable=SC2086
            sudo snap install $package || printf "%bFailed to install %s%b\n" "${C_RED}" "$package_name" "${C_DEFAULT}"
        else
            printf "%b%s is already installed%b\n" "${C_GREEN}" "$package_name" "${C_DEFAULT}"
        fi
    done
}
install_neovim() {
    print_header "Installing latest Neovim"
    
    # Check if neovim is already installed and get version
    if command -v nvim >/dev/null 2>&1; then
        current_version=$(nvim --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
        printf "%bCurrent Neovim version: %s%b\n" "${C_YELLOW}" "$current_version" "${C_DEFAULT}"
    fi
    
    mkdir -p "$HOME/Downloads"
    printf "%bDownloading latest Neovim...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    
    if ! curl -L "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" -o "$HOME/Downloads/nvim-linux-x86_64.tar.gz"; then
        die "Failed to download Neovim"
    fi
    
    printf "%bInstalling Neovim to /opt/nvim-linux64...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    sudo rm -rf /opt/nvim-linux64
    sudo tar -C /opt -xzf "$HOME/Downloads/nvim-linux-x86_64.tar.gz"
    
    # Make Neovim available system-wide for all users.
    sudo tee /etc/profile.d/nvim.sh > /dev/null << 'EOF'
# Add Neovim to PATH
export PATH="$PATH:/opt/nvim-linux64/bin"
EOF
    
    # Also add to current user's shell configs
    for rc_file in ~/.zshrc ~/.bashrc; do
        if [[ -f "$rc_file" ]] && ! grep -q '/opt/nvim-linux64/bin' "$rc_file" 2>/dev/null; then
            echo 'export PATH="$PATH:/opt/nvim-linux64/bin"' >> "$rc_file"
        fi
    done
    
    printf "%bNeovim installed successfully. You may need to restart your terminal.%b\n" "${C_GREEN}" "${C_DEFAULT}"
}

clone_git_repos() {
    print_header "Cloning Git Repositories for Tools"
    
    # TPM (Tmux Plugin Manager)
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        printf "%bCloning TPM (Tmux Plugin Manager)...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        mkdir -p "$HOME/.tmux/plugins"
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    else
        printf "%bTPM directory already exists, skipping clone.%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # PEAS (Privilege Escalation Awesome Scripts) - Optional
    printf "%bDo you want to install PEAS (Privilege Escalation Scripts)? [y/N]: %b" "${C_YELLOW}" "${C_DEFAULT}"
    read -r install_peas
    if [[ "$install_peas" =~ ^[Yy]$ ]]; then
        if [ ! -d "$HOME/PEAS" ]; then
            printf "%bCloning PEAS...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
            git clone https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite.git "$HOME/PEAS"
        else
            printf "%bPEAS directory already exists, skipping clone.%b\n" "${C_GREEN}" "${C_DEFAULT}"
        fi
    fi
}

setup_zsh() {
    print_header "Setting up Zsh, Oh My Zsh, and Powerlevel10k"
    
    # Make zsh the default shell
    if [[ "$SHELL" != */zsh ]]; then
        printf "%bSetting zsh as default shell...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        chsh -s "$(which zsh)" || printf "%bCouldn't change default shell. You may need to do this manually.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fi
    
    # Install Oh My Zsh non-interactively.
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        printf "%bInstalling Oh My Zsh...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        printf "%bOh My Zsh already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Install Zsh plugins.
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    declare -A zsh_plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
    )
    
    for plugin in "${!zsh_plugins[@]}"; do
        if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
            printf "%bInstalling zsh plugin: %s%b\n" "${C_YELLOW}" "$plugin" "${C_DEFAULT}"
            git clone "${zsh_plugins[$plugin]}" "$ZSH_CUSTOM/plugins/$plugin"
        else
            printf "%b%s already installed%b\n" "${C_GREEN}" "$plugin" "${C_DEFAULT}"
        fi
    done
    
    # Install Powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        printf "%bInstalling Powerlevel10k theme...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    else
        printf "%bPowerlevel10k already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
}

setup_nvchad() {
    print_header "Installing NvChad Neovim Configuration"
    if [ -d "$HOME/.config/nvim" ]; then
        printf "%bExisting NvChad config found. Backing it up to ~/.config/nvim.bak%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%s)"
    fi
    git clone https://github.com/NvChad/starter "$HOME/.config/nvim"
}

copy_dotfiles() {
    print_header "Copying Local Configuration Files"
    
    # Get the script directory
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Array of dotfiles to copy
    declare -A dotfiles=(
        [".zshrc"]="$HOME/.zshrc"
        [".tmux.conf"]="$HOME/.tmux.conf"
        [".p10k.zsh"]="$HOME/.p10k.zsh"
        ["config"]="$HOME/.config/ghostty/config"
    )
    
    for source_file in "${!dotfiles[@]}"; do
        target_file="${dotfiles[$source_file]}"
        source_path="$script_dir/$source_file"
        
        if [[ -f "$source_path" ]]; then
            # Create target directory if needed
            target_dir="$(dirname "$target_file")"
            mkdir -p "$target_dir"
            
            # Backup existing file if it exists
            if [[ -f "$target_file" ]]; then
                cp "$target_file" "$target_file.bak.$(date +%s)"
                printf "%bBacked up existing %s%b\n" "${C_YELLOW}" "$source_file" "${C_DEFAULT}"
            fi
            
            cp "$source_path" "$target_file"
            printf "%bCopied %s to %s%b\n" "${C_GREEN}" "$source_file" "$target_file" "${C_DEFAULT}"
        else
            printf "%bWarning: %s not found in script directory%b\n" "${C_YELLOW}" "$source_file" "${C_DEFAULT}"
        fi
    done
}

install_nerd_fonts() {
    print_header "Installing Nerd Fonts"
    
    # Check if fonts are already installed
    if fc-list | grep -i "meslo" | grep -i "nerd" >/dev/null 2>&1; then
        printf "%bNerd Fonts (MesloLGS) appear to be already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
        printf "%bDo you want to reinstall? [y/N]: %b" "${C_YELLOW}" "${C_DEFAULT}"
        read -r reinstall
        [[ ! "$reinstall" =~ ^[Yy]$ ]] && return
    fi
    
    mkdir -p "$HOME/.local/share/fonts"
    
    # Download specific Nerd Font files directly instead of building
    font_files=(
        "MesloLGS%20NF%20Regular.ttf"
        "MesloLGS%20NF%20Bold.ttf"
        "MesloLGS%20NF%20Italic.ttf"
        "MesloLGS%20NF%20Bold%20Italic.ttf"
    )
    
    base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    
    for font in "${font_files[@]}"; do
        font_name=$(echo "$font" | sed 's/%20/ /g')
        printf "%bDownloading %s...%b\n" "${C_YELLOW}" "$font_name" "${C_DEFAULT}"
        curl -fLo "$HOME/.local/share/fonts/$font_name" "$base_url/$font" || {
            printf "%bFailed to download %s%b\n" "${C_RED}" "$font_name" "${C_DEFAULT}"
        }
    done
    
    # Rebuild the system font cache to register the new fonts.
    printf "%bRebuilding font cache...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fc-cache -f -v >/dev/null 2>&1
    printf "%bNerd Fonts installed successfully%b\n" "${C_GREEN}" "${C_DEFAULT}"
}

cleanup() {
    print_header "Cleaning Up Downloaded Files"
    files_to_clean=(
        "$HOME/Downloads/nerd-fonts"
        "$HOME/Downloads/nvim-linux-x86_64.tar.gz"
    )
    
    for file in "${files_to_clean[@]}"; do
        if [[ -e "$file" ]]; then
            rm -rf "$file"
            printf "%bRemoved %s%b\n" "${C_GREEN}" "$file" "${C_DEFAULT}"
        fi
    done
}

# --- Main Menu Function ---
main_menu() {
    # Perform initial system checks
    check_not_root
    check_debian_ubuntu
    
    printf "%b%s%b\n" "${C_BLUE}${C_BOLD}" "Welcome to the Linux Development Environment Setup Script" "${C_DEFAULT}"
    printf "%bDetected OS: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Debian/Ubuntu')"
    
    while true; do
        printf "\n%b--- Setup Menu ---%b\n" "${C_GREEN}${C_BOLD}" "${C_DEFAULT}"
        echo "1. Run Full Installation (All Steps)"
        echo "2. Update System Packages Only"
        echo "3. Install Core Tools Only"
        echo "4. Setup Zsh & Oh My Zsh"
        echo "5. Install Neovim & NvChad"
        echo "6. Install Nerd Fonts Only"
        echo "7. Copy Dotfiles Only"
        echo "8. Setup Rust Environment"
        echo "9. Install OpenVPN3"
        echo "s. Show System Information"
        echo "q. Quit"
        printf "%bChoose an option: %b" "${C_YELLOW}" "${C_DEFAULT}"
        read -r choice
        
        case "$choice" in
            1)
                if confirm "This will install all components. Continue?"; then
                    update_system
                    install_core_tools
                    purge_old_editors
                    setup_rust
                    setup_openvpn
                    install_snap_packages
                    install_neovim
                    clone_git_repos
                    setup_zsh
                    setup_nvchad
                    copy_dotfiles
                    install_nerd_fonts
                    cleanup
                    printf "\n%b%sFull installation complete!%b\n" "${C_GREEN}${C_BOLD}" "" "${C_DEFAULT}"
                    printf "%bPlease restart your terminal or run 'source ~/.zshrc' to apply changes.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
                fi
                ;;
            2) update_system ;;
            3) install_core_tools ;;
            4) setup_zsh ;;
            5) purge_old_editors && install_neovim && setup_nvchad ;;
            6) install_nerd_fonts ;;
            7) copy_dotfiles ;;
            8) setup_rust ;;
            9) setup_openvpn ;;
            s|S)
                printf "\n%b--- System Information ---%b\n" "${C_BLUE}${C_BOLD}" "${C_DEFAULT}"
                printf "%bOS: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
                printf "%bKernel: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(uname -r)"
                printf "%bShell: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$SHELL"
                printf "%bUser: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$USER"
                continue
                ;;
            q|Q)
                printf "%bExiting. Have a great day!%b\n" "${C_GREEN}" "${C_DEFAULT}"
                exit 0
                ;;
            *)
                printf "\n%bInvalid option. Please try again.%b\n" "${C_RED}" "${C_DEFAULT}"
                continue
                ;;
        esac
        printf "%b\nOperation complete. Returning to menu...%b\n" "${C_GREEN}" "${C_DEFAULT}"
        sleep 2
    done
}

# --- Script Execution Starts Here ---
main_menu
