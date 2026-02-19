#!/bin/bash

# Common functions shared between Ubuntu and Debian setup scripts

# --- Color Definitions ---
C_DEFAULT='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

# --- Helper Functions ---
print_header() {
    printf "\n%b%s%b\n" "${C_BLUE}${C_BOLD}" "--- $1 ---" "${C_DEFAULT}"
}

die() {
    printf "\n%b[ERROR]%b %s\n" "${C_RED}${C_BOLD}" "${C_DEFAULT}" "$1" >&2
    exit 1
}

confirm() {
    local prompt="${1:-Continue?}"
    printf "%b%s [y/N]: %b" "${C_YELLOW}" "$prompt" "${C_DEFAULT}"
    read -r response
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

check_dependencies() {
    local deps="curl git sudo"
    local missing=""
    
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            if [ -z "$missing" ]; then
                missing="$dep"
            else
                missing="$missing $dep"
            fi
        fi
    done
    
    if [ -n "$missing" ]; then
        printf "%bMissing required dependencies: %s%b\n" "${C_RED}" "$missing" "${C_DEFAULT}"
        printf "%bPlease install them first: sudo apt update && sudo apt install -y %s%b\n" "${C_YELLOW}" "$missing" "${C_DEFAULT}"
        return 1
    fi
    return 0
}

# --- Installation Functions ---

setup_rust() {
    print_header "Installing Rust and Cargo Packages"
    if ! command -v rustup >/dev/null 2>&1; then
        printf "%bInstalling Rust via rustup...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        printf "%bRust installation completed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    else
        printf "%bRust is already installed, updating...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        rustup update stable
    fi
    
    # Source the cargo env to use it immediately in this script session.
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    
    if ! command -v cargo >/dev/null 2>&1; then
        die "Cargo not found after rustup install."
    fi
    
    # Install eza if not already installed
    if ! cargo install --list | grep -q '^eza '; then
        printf "%bInstalling eza (modern ls replacement)...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        cargo install eza --locked
    else
        printf "%beza is already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Make Cargo persistent for new shells
    for rc_file in ~/.zshrc ~/.bashrc; do
        if [ -f "$rc_file" ] && ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$rc_file" 2>/dev/null; then
            {
                echo
                echo "# Add Cargo to PATH"
                echo 'export PATH="$HOME/.cargo/bin:$PATH"'
            } >> "$rc_file"
            printf "%bRust/Cargo PATH added to %s%b\n" "${C_GREEN}" "$(basename "$rc_file")" "${C_DEFAULT}"
        fi
    done
}

install_docker() {
    print_header "Installing Docker"
    
    # Check if Docker is already installed
    if command -v docker >/dev/null 2>&1; then
        printf "%bDocker is already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
        docker --version
        if confirm "Docker is already installed. Do you want to reinstall?"; then
            printf "%bProceeding with Docker reinstallation...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        else
            return 0
        fi
    fi
    
    # Remove any old Docker installations
    sudo apt remove -y docker docker-engine docker.io containerd runc || true
    
    # Update package index and install prerequisites
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key and repository
    sudo mkdir -p /etc/apt/keyrings
    
    # Detect if Ubuntu or Debian for correct repository
    if grep -q "Ubuntu" /etc/os-release; then
        # Ubuntu
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        # Debian
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker "$USER"
    
    # Enable and start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    printf "%bDocker installed successfully. You may need to log out and back in to use Docker without sudo.%b\n" "${C_GREEN}" "${C_DEFAULT}"
}

install_virt_manager() {
    print_header "Installing Virt-Manager and KVM"
    
    # Check if virt-manager is already installed
    if command -v virt-manager >/dev/null 2>&1; then
        printf "%bVirt-Manager is already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
        if ! confirm "Virt-Manager is already installed. Do you want to reinstall?"; then
            return 0
        fi
    fi
    
    # Install virtualization packages
    sudo apt update
    sudo apt install -y \
        qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
        virt-manager virt-viewer spice-vdagent
    
    # Add user to libvirt groups
    sudo usermod -aG libvirt "$USER"
    sudo usermod -aG kvm "$USER"
    
    # Enable and start libvirtd service
    sudo systemctl enable libvirtd
    sudo systemctl start libvirtd
    
    # Check if virtualization is supported
    if grep -Ec '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        printf "%bVirtualization support detected%b\n" "${C_GREEN}" "${C_DEFAULT}"
    else
        printf "%bWarning: Hardware virtualization may not be supported or enabled in BIOS%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fi
    
    printf "%bVirt-Manager installed successfully. You may need to log out and back in to use it.%b\n" "${C_GREEN}" "${C_DEFAULT}"
}

install_snap_packages() {
    print_header "Installing Snap Packages"
    if ! command -v snap >/dev/null 2>&1; then
        printf "%bSnapd not found. Installing snapd...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        sudo apt update && sudo apt install -y snapd
        # Wait for snapd to be ready
        sleep 5
    fi
    
    # List of snap packages to install
    snap_packages="waveterm --classic
obsidian --classic
code --classic
discord"
    
    # Install packages efficiently
    echo "$snap_packages" | while IFS= read -r package; do
        [ -z "$package" ] && continue
        package_name=$(echo "$package" | awk '{print $1}')
        if ! snap list 2>/dev/null | grep -q "^$package_name "; then
            printf "%bInstalling snap package: %s%b\n" "${C_YELLOW}" "$package_name" "${C_DEFAULT}"
            # shellcheck disable=SC2086
            if sudo snap install $package; then
                printf "%b%s installed successfully%b\n" "${C_GREEN}" "$package_name" "${C_DEFAULT}"
            else
                printf "%bFailed to install %s%b\n" "${C_RED}" "$package_name" "${C_DEFAULT}"
            fi
        else
            printf "%b%s is already installed%b\n" "${C_GREEN}" "$package_name" "${C_DEFAULT}"
        fi
    done
}

install_neovim() {
    print_header "Building and Installing Latest Neovim from Source"
    
    # Check if neovim is already installed and at a good version
    if command -v nvim >/dev/null 2>&1; then
        current_version=$(nvim --version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
        printf "%bCurrent Neovim version: %s%b\n" "${C_YELLOW}" "${current_version:-unknown}" "${C_DEFAULT}"
        
        if ! confirm "Neovim is already installed. Do you want to rebuild from source?"; then
            return 0
        fi
        printf "%bProceeding with Neovim build...%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Remove old installation
    sudo rm -rf /opt/neovim
    
    # Clone or update Neovim repository
    if [ -d "$HOME/Downloads/neovim" ]; then
        printf "%bExisting Neovim repository found. Checking status...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        cd "$HOME/Downloads/neovim"
        
        # Check if it's a valid git repository
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            printf "%bInvalid git repository. Removing and cloning fresh...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
            cd "$HOME/Downloads"
            rm -rf neovim
            git clone --depth=1 --branch=stable https://github.com/neovim/neovim.git
            cd neovim
        else
            # Try to update the repository
            printf "%bUpdating existing Neovim repository...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
            
            # Clean any local changes
            git clean -fdx
            git reset --hard HEAD
            
            # Fetch latest changes
            if git fetch --all --tags; then
                # Check if stable branch exists
                if git rev-parse --verify origin/stable >/dev/null 2>&1; then
                    git checkout stable 2>/dev/null || git checkout -b stable origin/stable
                    git reset --hard origin/stable
                    git pull origin stable
                else
                    printf "%bStable branch not found. Removing and cloning fresh...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
                    cd "$HOME/Downloads"
                    rm -rf neovim
                    git clone --depth=1 --branch=stable https://github.com/neovim/neovim.git
                    cd neovim
                fi
            else
                printf "%bFetch failed. Removing and cloning fresh...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
                cd "$HOME/Downloads"
                rm -rf neovim
                git clone --depth=1 --branch=stable https://github.com/neovim/neovim.git
                cd neovim
            fi
        fi
    else
        printf "%bCloning Neovim repository...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        mkdir -p "$HOME/Downloads"
        cd "$HOME/Downloads"
        git clone --depth=1 --branch=stable https://github.com/neovim/neovim.git
        cd neovim
    fi
    
    # Build Neovim
    printf "%bBuilding Neovim (this may take a few minutes)...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=/opt/neovim
    
    # Install Neovim
    printf "%bInstalling Neovim to /opt/neovim...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    sudo make install
    
    # Create symlink for system-wide access
    sudo ln -sf /opt/neovim/bin/nvim /usr/local/bin/nvim
    
    # Add to shell configs
    for rc_file in ~/.zshrc ~/.bashrc; do
        if [ -f "$rc_file" ] && ! grep -q '/opt/neovim/bin' "$rc_file" 2>/dev/null; then
            echo 'export PATH="$PATH:/opt/neovim/bin"' >> "$rc_file"
        fi
    done
    
    printf "%bNeovim built and installed successfully!%b\n" "${C_GREEN}" "${C_DEFAULT}"
    /opt/neovim/bin/nvim --version | head -n1
}

clone_git_repos() {
    print_header "Cloning Git Repositories for Tools"
    
    # TPM (Tmux Plugin Manager)
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        printf "%bCloning TPM (Tmux Plugin Manager)...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        mkdir -p "$HOME/.tmux/plugins"
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        printf "%bTPM installed successfully%b\n" "${C_GREEN}" "${C_DEFAULT}"
    else
        printf "%bTPM directory already exists, skipping clone.%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
}

setup_zsh() {
    print_header "Setting up Zsh, Oh My Zsh, and Powerlevel10k"
    
    # Check if zsh is installed
    if ! command -v zsh >/dev/null 2>&1; then
        printf "%bZsh is not installed. Attempting to install...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y zsh
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y zsh
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y zsh
        else
            printf "%bCannot install zsh automatically. Please install zsh manually and run this function again.%b\n" "${C_RED}" "${C_DEFAULT}"
            return 1
        fi
        
        # Verify installation
        if ! command -v zsh >/dev/null 2>&1; then
            printf "%bFailed to install zsh. Please install it manually: sudo apt install zsh%b\n" "${C_RED}" "${C_DEFAULT}"
            return 1
        fi
        printf "%bZsh installed successfully%b\n" "${C_GREEN}" "${C_DEFAULT}"
    else
        printf "%bZsh is already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Install Oh My Zsh non-interactively
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        printf "%bInstalling Oh My Zsh...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        printf "%bOh My Zsh already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Install Zsh plugins
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        printf "%bInstalling zsh plugin: zsh-autosuggestions%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        git clone --depth=1 "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions" &
    else
        printf "%bzsh-autosuggestions already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        printf "%bInstalling zsh plugin: zsh-syntax-highlighting%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        git clone --depth=1 "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" &
    else
        printf "%bzsh-syntax-highlighting already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
        printf "%bInstalling zsh plugin: zsh-completions%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        git clone --depth=1 "https://github.com/zsh-users/zsh-completions" "$ZSH_CUSTOM/plugins/zsh-completions" &
    else
        printf "%bzsh-completions already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Install Powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        printf "%bInstalling Powerlevel10k theme...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" &
    else
        printf "%bPowerlevel10k already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
    
    # Wait for all background jobs to complete
    wait
    
    # Change default shell to zsh
    if ! echo "$SHELL" | grep -q "zsh"; then
        printf "%bChanging default shell to zsh...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        chsh -s "$(which zsh)" || {
            printf "%bCouldn't change default shell automatically. Please run: chsh -s \$(which zsh)%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        }
    else
        printf "%bZsh is already the default shell%b\n" "${C_GREEN}" "${C_DEFAULT}"
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
    
    # Get the script directory (go up from scripts/common to root)
    script_dir="$(cd "$(dirname "$0")/../.." && pwd)"
    dotfiles_dir="$script_dir/dotfiles"
    
    if [ ! -d "$dotfiles_dir" ]; then
        printf "%bWarning: dotfiles directory not found at %s%b\n" "${C_YELLOW}" "$dotfiles_dir" "${C_DEFAULT}"
        return
    fi
    
    # Copy dotfiles individually
    copy_dotfile() {
        local source_file="$1"
        local target_file="$2"
        local source_path="$dotfiles_dir/$source_file"
        
        if [ -f "$source_path" ]; then
            # Create target directory if needed
            target_dir="$(dirname "$target_file")"
            mkdir -p "$target_dir"
            
            # Backup existing file if it exists
            if [ -f "$target_file" ]; then
                cp "$target_file" "$target_file.bak.$(date +%s)"
                printf "%bBacked up existing %s%b\n" "${C_YELLOW}" "$source_file" "${C_DEFAULT}"
            fi
            
            cp "$source_path" "$target_file"
            printf "%bCopied %s to %s%b\n" "${C_GREEN}" "$source_file" "$target_file" "${C_DEFAULT}"
        else
            printf "%bWarning: %s not found in dotfiles directory%b\n" "${C_YELLOW}" "$source_file" "${C_DEFAULT}"
        fi
    }
    
    # Copy each dotfile
    copy_dotfile ".zshrc" "$HOME/.zshrc"
    copy_dotfile ".tmux.conf" "$HOME/.tmux.conf"
    copy_dotfile ".p10k.zsh" "$HOME/.p10k.zsh"
    copy_dotfile ".bashrc" "$HOME/.bashrc"
    copy_dotfile "config" "$HOME/.config/ghostty/config"
}

install_nerd_fonts() {
    print_header "Installing Nerd Fonts"
    
    # Check if fonts are already installed
    if fc-list | grep -i "meslo" | grep -i "nerd" >/dev/null 2>&1; then
        printf "%bNerd Fonts (MesloLGS) appear to be already installed%b\n" "${C_GREEN}" "${C_DEFAULT}"
        if ! confirm "Do you want to reinstall?"; then
            return
        fi
    fi
    
    mkdir -p "$HOME/.local/share/fonts"
    
    # Download font files
    font_files="MesloLGS%20NF%20Regular.ttf
MesloLGS%20NF%20Bold.ttf
MesloLGS%20NF%20Italic.ttf
MesloLGS%20NF%20Bold%20Italic.ttf"
    
    base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    
    # Download fonts in parallel
    echo "$font_files" | while IFS= read -r font; do
        [ -z "$font" ] && continue
        font_name=$(echo "$font" | sed 's/%20/ /g')
        if [ ! -f "$HOME/.local/share/fonts/$font_name" ]; then
            printf "%bDownloading %s...%b\n" "${C_YELLOW}" "$font_name" "${C_DEFAULT}"
            (curl -fLo "$HOME/.local/share/fonts/$font_name" "$base_url/$font" && \
             printf "%bDownloaded %s successfully%b\n" "${C_GREEN}" "$font_name" "${C_DEFAULT}") || \
            printf "%bFailed to download %s%b\n" "${C_RED}" "$font_name" "${C_DEFAULT}" &
        else
            printf "%b%s already exists%b\n" "${C_GREEN}" "$font_name" "${C_DEFAULT}"
        fi
    done
    
    # Wait for all downloads to complete
    wait
    
    # Rebuild font cache
    printf "%bRebuilding font cache...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fc-cache -fv >/dev/null 2>&1
    printf "%bNerd Fonts installed successfully%b\n" "${C_GREEN}" "${C_DEFAULT}"
}

cleanup() {
    print_header "Cleaning Up Downloaded Files"
    
    for file in "$HOME/Downloads/nerd-fonts" "$HOME/Downloads/nvim-linux-x86_64.tar.gz" "$HOME/Downloads/neovim"; do
        if [ -e "$file" ]; then
            if confirm "Remove $file?"; then
                rm -rf "$file"
                printf "%bRemoved %s%b\n" "${C_GREEN}" "$file" "${C_DEFAULT}"
            fi
        fi
    done
}

check_installation_status() {
    print_header "Checking Installation Status"
    
    local total_checks=0
    local passed_checks=0
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking system packages..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 && command -v tmux >/dev/null 2>&1; then
        printf "%b✓ INSTALLED%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Rust installation..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
        rust_version=$(rustc --version | awk '{print $2}')
        printf "%b✓ INSTALLED (v%s)%b\n" "${C_GREEN}" "$rust_version" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking eza (rust package)..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v eza >/dev/null 2>&1; then
        printf "%b✓ INSTALLED%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Docker installation..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v docker >/dev/null 2>&1; then
        docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        printf "%b✓ INSTALLED (v%s)%b\n" "${C_GREEN}" "$docker_version" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Virt-Manager..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v virt-manager >/dev/null 2>&1; then
        printf "%b✓ INSTALLED%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking KVM support..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if systemctl is-active --quiet libvirtd 2>/dev/null; then
        printf "%b✓ RUNNING%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    elif command -v libvirtd >/dev/null 2>&1; then
        printf "%b◐ INSTALLED (not running)%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Neovim installation..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v nvim >/dev/null 2>&1; then
        nvim_version=$(nvim --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
        printf "%b✓ INSTALLED (%s)%b\n" "${C_GREEN}" "$nvim_version" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking NvChad configuration..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if [ -d "$HOME/.config/nvim" ] && [ -f "$HOME/.config/nvim/init.lua" ]; then
        printf "%b✓ INSTALLED%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Zsh installation..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v zsh >/dev/null 2>&1; then
        zsh_version=$(zsh --version | awk '{print $2}')
        printf "%b✓ INSTALLED (v%s)%b\n" "${C_GREEN}" "$zsh_version" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Oh My Zsh..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if [ -d "$HOME/.oh-my-zsh" ]; then
        printf "%b✓ INSTALLED%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Powerlevel10k theme..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if [ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
        printf "%b✓ INSTALLED%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Zsh plugins..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    plugins_found=0
    plugins_total=3
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ] && plugins_found=$((plugins_found + 1))
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ] && plugins_found=$((plugins_found + 1))
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" ] && plugins_found=$((plugins_found + 1))
    
    if [ "$plugins_found" -eq "$plugins_total" ]; then
        printf "%b✓ INSTALLED (%d/%d)%b\n" "${C_GREEN}" "$plugins_found" "$plugins_total" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ PARTIAL (%d/%d)%b\n" "${C_YELLOW}" "$plugins_found" "$plugins_total" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking TMux Plugin Manager..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        printf "%b✓ INSTALLED%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Nerd Fonts..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if fc-list | grep -i "meslo" | grep -i "nerd" >/dev/null 2>&1; then
        font_count=$(fc-list | grep -i "meslo" | grep -i "nerd" | wc -l)
        printf "%b✓ INSTALLED (%d fonts)%b\n" "${C_GREEN}" "$font_count" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking OpenVPN..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v openvpn3 >/dev/null 2>&1 || command -v openvpn >/dev/null 2>&1; then
        if command -v openvpn3 >/dev/null 2>&1; then
            printf "%b✓ INSTALLED (OpenVPN3)%b\n" "${C_GREEN}" "${C_DEFAULT}"
        else
            printf "%b✓ INSTALLED (OpenVPN)%b\n" "${C_GREEN}" "${C_DEFAULT}"
        fi
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking SSH Server..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        printf "%b✓ INSTALLED & RUNNING%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    elif command -v sshd >/dev/null 2>&1; then
        printf "%b◐ INSTALLED (not running)%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking Snap packages..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if command -v snap >/dev/null 2>&1; then
        snap_count=0
        snap_packages="code discord obsidian waveterm"
        for pkg in $snap_packages; do
            if snap list 2>/dev/null | grep -q "^$pkg "; then
                snap_count=$((snap_count + 1))
            fi
        done
        if [ "$snap_count" -gt 0 ]; then
            printf "%b✓ INSTALLED (%d packages)%b\n" "${C_GREEN}" "$snap_count" "${C_DEFAULT}"
            passed_checks=$((passed_checks + 1))
        else
            printf "%b◐ SNAPD READY (no packages)%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        fi
    else
        printf "%b✗ MISSING%b\n" "${C_RED}" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking default shell..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    if echo "$SHELL" | grep -q "zsh"; then
        printf "%b✓ ZSH (default)%b\n" "${C_GREEN}" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b◐ NOT ZSH (%s)%b\n" "${C_YELLOW}" "$SHELL" "${C_DEFAULT}"
    fi
    
    printf "%b%-40s%b" "${C_YELLOW}" "Checking dotfiles..." "${C_DEFAULT}"
    total_checks=$((total_checks + 1))
    dotfiles_found=0
    dotfiles_total=4
    [ -f "$HOME/.zshrc" ] && dotfiles_found=$((dotfiles_found + 1))
    [ -f "$HOME/.tmux.conf" ] && dotfiles_found=$((dotfiles_found + 1))
    [ -f "$HOME/.p10k.zsh" ] && dotfiles_found=$((dotfiles_found + 1))
    [ -f "$HOME/.config/ghostty/config" ] && dotfiles_found=$((dotfiles_found + 1))
    
    if [ "$dotfiles_found" -eq "$dotfiles_total" ]; then
        printf "%b✓ INSTALLED (%d/%d)%b\n" "${C_GREEN}" "$dotfiles_found" "$dotfiles_total" "${C_DEFAULT}"
        passed_checks=$((passed_checks + 1))
    else
        printf "%b✗ PARTIAL (%d/%d)%b\n" "${C_YELLOW}" "$dotfiles_found" "$dotfiles_total" "${C_DEFAULT}"
    fi
    
    # Summary
    printf "\n%b--- Installation Summary ---%b\n" "${C_BOLD}" "${C_DEFAULT}"
    printf "%bTotal checks: %d%b\n" "${C_BLUE}" "$total_checks" "${C_DEFAULT}"
    printf "%bPassed: %d%b\n" "${C_GREEN}" "$passed_checks" "${C_DEFAULT}"
    printf "%bFailed: %d%b\n" "${C_RED}" "$((total_checks - passed_checks))" "${C_DEFAULT}"
    
    completion_percentage=$((passed_checks * 100 / total_checks))
    printf "%bCompletion: %d%%%b\n" "${C_YELLOW}" "$completion_percentage" "${C_DEFAULT}"
    
    if [ "$completion_percentage" -eq 100 ]; then
        printf "\n%b🎉 All components are installed and configured!%b\n" "${C_GREEN}${C_BOLD}" "${C_DEFAULT}"
    elif [ "$completion_percentage" -ge 80 ]; then
        printf "\n%b👍 Most components are installed. Consider installing missing items.%b\n" "${C_YELLOW}${C_BOLD}" "${C_DEFAULT}"
    else
        printf "\n%b⚠️  Many components are missing. Consider running the full installation.%b\n" "${C_RED}${C_BOLD}" "${C_DEFAULT}"
    fi
}
