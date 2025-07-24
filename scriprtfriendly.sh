#!/bin/bash

# --- Script Configuration and Safety ---
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Global Variables ---
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTRO=""
PACKAGE_MANAGER=""
INSTALL_CMD=""
UPDATE_CMD=""
UPGRADE_CMD=""
AUTOREMOVE_CMD=""
AUTOCLEAN_CMD=""

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

# Prints an error message and exits.
error_exit() {
    printf "%b%s%b\n" "${C_RED}${C_BOLD}" "ERROR: $1" "${C_DEFAULT}" >&2
    exit 1
}

# Prints a warning message.
print_warning() {
    printf "%b%s%b\n" "${C_YELLOW}" "WARNING: $1" "${C_DEFAULT}"
}

# Prints a success message.
print_success() {
    printf "%b%s%b\n" "${C_GREEN}" "SUCCESS: $1" "${C_DEFAULT}"
}

# Check if running with sudo privileges
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. This is not recommended for security reasons."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        printf "%bThis script requires sudo privileges. Please enter your password.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        sudo -v || error_exit "Failed to obtain sudo privileges"
    fi
}

# Detect the Linux distribution and package manager
detect_package_manager() {
    print_header "Detecting Package Manager"
    
    # Try to detect distribution
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO="$ID"
    elif command -v lsb_release >/dev/null 2>&1; then
        DISTRO="$(lsb_release -si | tr '[:upper:]' '[:lower:]')"
    else
        error_exit "Cannot detect Linux distribution"
    fi
    
    printf "Detected distribution: %b%s%b\n" "${C_GREEN}" "$DISTRO" "${C_DEFAULT}"
    
    # Set package manager commands based on distribution
    case "$DISTRO" in
        ubuntu|debian|linuxmint|elementary)
            PACKAGE_MANAGER="apt"
            INSTALL_CMD="sudo apt install -y"
            UPDATE_CMD="sudo apt update -y"
            UPGRADE_CMD="sudo apt full-upgrade -y"
            AUTOREMOVE_CMD="sudo apt autoremove -y"
            AUTOCLEAN_CMD="sudo apt autoclean -y"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            PACKAGE_MANAGER="dnf"
            INSTALL_CMD="sudo dnf install -y"
            UPDATE_CMD="sudo dnf check-update || true"
            UPGRADE_CMD="sudo dnf upgrade -y"
            AUTOREMOVE_CMD="sudo dnf autoremove -y"
            AUTOCLEAN_CMD="sudo dnf clean all"
            ;;
        opensuse*|sles)
            PACKAGE_MANAGER="zypper"
            INSTALL_CMD="sudo zypper install -y"
            UPDATE_CMD="sudo zypper refresh"
            UPGRADE_CMD="sudo zypper update -y"
            AUTOREMOVE_CMD="sudo zypper rm -u"
            AUTOCLEAN_CMD="sudo zypper clean"
            ;;
        arch|manjaro|endeavouros)
            PACKAGE_MANAGER="pacman"
            INSTALL_CMD="sudo pacman -S --noconfirm"
            UPDATE_CMD="sudo pacman -Sy"
            UPGRADE_CMD="sudo pacman -Syu --noconfirm"
            AUTOREMOVE_CMD="sudo pacman -Rns \$(pacman -Qtdq) 2>/dev/null || true"
            AUTOCLEAN_CMD="sudo pacman -Sc --noconfirm"
            ;;
        *)
            error_exit "Unsupported distribution: $DISTRO"
            ;;
    esac
    
    printf "Package manager: %b%s%b\n" "${C_GREEN}" "$PACKAGE_MANAGER" "${C_DEFAULT}"
}

# Check for essential dependencies
check_dependencies() {
    print_header "Checking Dependencies"
    
    local missing_deps=()
    local essential_commands=("curl" "git" "sudo")
    
    for cmd in "${essential_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error_exit "Missing essential commands: ${missing_deps[*]}. Please install them first."
    fi
    
    print_success "All essential dependencies are available"
}

# Check if a file is newer than another
is_file_newer() {
    local source="$1"
    local dest="$2"
    
    [[ -f "$source" ]] || return 1
    [[ ! -f "$dest" ]] || [[ "$source" -nt "$dest" ]]
}

# Create backup with timestamp
create_backup() {
    local file="$1"
    local backup_suffix="${2:-$(date +%s)}"
    
    if [[ -e "$file" ]]; then
        local backup_name="${file}.bak.${backup_suffix}"
        cp -r "$file" "$backup_name"
        printf "%bCreated backup: %s%b\n" "${C_YELLOW}" "$backup_name" "${C_DEFAULT}"
    fi
}

# --- Installation and Setup Functions ---

update_system() {
    print_header "Updating and Upgrading System Packages"
    $UPDATE_CMD && $UPGRADE_CMD && $AUTOREMOVE_CMD && $AUTOCLEAN_CMD
}

install_core_tools() {
    print_header "Installing Core Packages & Tools"
    
    case "$PACKAGE_MANAGER" in
        apt)
            $INSTALL_CMD \
                apt-transport-https curl git \
                virtualbox tmux zsh flameshot \
                snapd bat btop freerdp2-x11
            ;;
        dnf)
            $INSTALL_CMD \
                curl git \
                VirtualBox tmux zsh flameshot \
                snapd bat btop freerdp
            ;;
        zypper)
            $INSTALL_CMD \
                curl git \
                virtualbox tmux zsh \
                snapd bat btop freerdp
            ;;
        pacman)
            $INSTALL_CMD \
                curl git \
                virtualbox tmux zsh flameshot \
                snapd bat btop freerdp
            ;;
    esac
}

purge_old_editors() {
    print_header "Purging Old Vim/Neovim to prevent conflicts"
    
    case "$PACKAGE_MANAGER" in
        apt)
            sudo apt purge vim neovim -y 2>/dev/null || true
            ;;
        dnf)
            sudo dnf remove vim-enhanced neovim -y 2>/dev/null || true
            ;;
        zypper)
            sudo zypper remove vim neovim -y 2>/dev/null || true
            ;;
        pacman)
            sudo pacman -Rns vim neovim --noconfirm 2>/dev/null || true
            ;;
    esac
}

setup_rust() {
    print_header "Installing Rust and Cargo Packages"
    # Install rustup non-interactively.
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    # Source the cargo env to use it immediately in this script session.
    . "$HOME/.cargo/env"
    cargo install eza

    # Make Cargo persistent for new shells.
    # Add to .zshrc only if it's not already there.
    if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' ~/.zshrc; then
        echo -e "\n# Add Cargo to PATH" >> ~/.zshrc
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc
        printf "%bRust/Cargo PATH added to .zshrc%b\n" "${C_GREEN}" "${C_DEFAULT}"
    fi
}

setup_openvpn() {
    print_header "Installing OpenVPN3"
    
    case "$PACKAGE_MANAGER" in
        apt)
            local codename
            if command -v lsb_release >/dev/null 2>&1; then
                codename="$(lsb_release -cs)"
            else
                # Fallback for common distributions
                case "$DISTRO" in
                    ubuntu)
                        if [[ -f /etc/os-release ]]; then
                            . /etc/os-release
                            codename="$VERSION_CODENAME"
                        fi
                        ;;
                    debian)
                        codename="bookworm"  # Default to latest stable
                        ;;
                    *)
                        codename="bookworm"
                        ;;
                esac
            fi
            
            sudo mkdir -p /etc/apt/keyrings
            curl -sSfL https://packages.openvpn.net/packages-repo.gpg | sudo tee /etc/apt/keyrings/openvpn.asc > /dev/null
            echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian $codename main" | sudo tee /etc/apt/sources.list.d/openvpn3.list > /dev/null
            $UPDATE_CMD
            $INSTALL_CMD openvpn3
            ;;
        dnf)
            $INSTALL_CMD openvpn
            ;;
        zypper)
            $INSTALL_CMD openvpn
            ;;
        pacman)
            $INSTALL_CMD openvpn
            ;;
    esac
}

install_snap_packages() {
    print_header "Installing Snap Packages"
    
    # Ensure snapd is installed and running
    case "$PACKAGE_MANAGER" in
        apt)
            $INSTALL_CMD snapd
            ;;
        dnf)
            $INSTALL_CMD snapd
            sudo systemctl enable --now snapd.socket
            ;;
        zypper)
            $INSTALL_CMD snapd
            sudo systemctl enable --now snapd
            ;;
        pacman)
            # Arch needs snapd from AUR, skip if not available
            if ! command -v snap >/dev/null 2>&1; then
                print_warning "Snapd not available on Arch. Skipping snap packages."
                return 0
            fi
            ;;
    esac
    
    # Wait for snap to be ready
    sudo snap wait system seed.loaded
    
    sudo snap install --classic waveterm
    sudo snap install obsidian --classic
    sudo snap install ghostty --classic
}
install_neovim() {
    print_header "Installing latest Neovim AppImage"
    mkdir -p "$HOME/Downloads"
    curl -L "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" -o "$HOME/Downloads/nvim-linux-x86_64.tar.gz"
    sudo rm -rf /opt/nvim-linux64
    sudo tar -C /opt -xzf "$HOME/Downloads/nvim-linux-x86_64.tar.gz"

    # Make Neovim available system-wide for all users.
    echo 'export PATH="$PATH:/opt/nvim-linux64/bin"' | sudo tee /etc/profile.d/nvim.sh > /dev/null
    printf "%bNeovim PATH configured. You may need to log out and back in.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
}

clone_git_repos() {
    print_header "Cloning Git Repositories for Tools"
    # TPM (Tmux Plugin Manager)
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    else
        printf "%bTPM directory already exists, skipping clone.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fi

    # PEAS (Privilege Escalation Awesome Scripts)
    if [ ! -d "$HOME/PEAS" ]; then
        git clone https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite.git ~/PEAS
    else
        printf "%bPEAS directory already exists, skipping clone.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fi
}

setup_zsh() {
    print_header "Setting up Zsh, Oh My Zsh, and Powerlevel10k"
    # Install Oh My Zsh non-interactively.
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    # Install Zsh plugins.
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
}

setup_nvchad() {
    print_header "Installing NvChad Neovim Configuration"
    
    local nvim_config="$HOME/.config/nvim"
    
    if [[ -d "$nvim_config" ]]; then
        local backup_name="nvim.bak.$(date +%s)"
        printf "%bExisting NvChad config found. Backing it up to ~/.config/%s%b\n" "${C_YELLOW}" "$backup_name" "${C_DEFAULT}"
        mv "$nvim_config" "$HOME/.config/$backup_name"
    fi
    
    git clone https://github.com/NvChad/starter "$nvim_config"
}

copy_dotfiles() {
    print_header "Copying Local Configuration Files (.zshrc, .tmux.conf, .p10k.zsh)"
    
    local dotfiles=(".zshrc" ".tmux.conf" ".p10k.zsh")
    local config_files=("config")
    local updated_files=()
    
    # Copy dotfiles to home directory
    for file in "${dotfiles[@]}"; do
        local source="$SCRIPT_DIR/$file"
        local dest="$HOME/$file"
        
        if [[ -f "$source" ]]; then
            if is_file_newer "$source" "$dest"; then
                [[ -f "$dest" ]] && create_backup "$dest"
                cp -f "$source" "$dest"
                updated_files+=("$file")
            else
                printf "%b%s is up to date, skipping.%b\n" "${C_YELLOW}" "$file" "${C_DEFAULT}"
            fi
        else
            print_warning "Source file $source not found, skipping."
        fi
    done
    
    # Copy config files to .config directory
    mkdir -p "$HOME/.config/ghostty"
    for file in "${config_files[@]}"; do
        local source="$SCRIPT_DIR/$file"
        local dest="$HOME/.config/ghostty/$file"
        
        if [[ -f "$source" ]]; then
            if is_file_newer "$source" "$dest"; then
                [[ -f "$dest" ]] && create_backup "$dest"
                cp -f "$source" "$dest"
                updated_files+=("ghostty/$file")
            else
                printf "%b%s is up to date, skipping.%b\n" "${C_YELLOW}" "ghostty/$file" "${C_DEFAULT}"
            fi
        else
            print_warning "Source file $source not found, skipping."
        fi
    done
    
    if [[ ${#updated_files[@]} -gt 0 ]]; then
        print_success "Updated files: ${updated_files[*]}"
    else
        printf "%bNo files needed updating.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fi
}

install_nerd_fonts() {
    print_header "Building and Installing Nerd Fonts"
    mkdir -p ~/.local/share/fonts
    git clone --depth=1 https://github.com/romkatv/nerd-fonts.git ~/Downloads/nerd-fonts
    # Ensure the build script is executable before running it.
    chmod +x ~/Downloads/nerd-fonts/build
    ~/Downloads/nerd-fonts/build 'Meslo/S/*'
    cp -f ~/Downloads/nerd-fonts/out/* ~/.local/share/fonts/
    # Rebuild the system font cache to register the new fonts.
    fc-cache -f -v
}

cleanup() {
    print_header "Cleaning Up Downloaded Files"
    rm -rf ~/Downloads/nerd-fonts
    rm -f ~/Downloads/nvim-linux-x86_64.tar.gz
}

# --- Command Line Argument Handling ---

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

This script sets up a development environment with various tools and configurations.

OPTIONS:
    -h, --help              Show this help message
    -a, --all               Run full installation (all steps)
    -u, --update            Update system packages only
    -c, --core              Install core tools only
    -z, --zsh               Setup Zsh & Oh My Zsh
    -n, --neovim            Install Neovim & NvChad
    -f, --fonts             Install Nerd Fonts only
    -d, --dotfiles          Copy dotfiles only
    -r, --rust              Setup Rust and Cargo packages
    -o, --openvpn           Install OpenVPN
    -s, --snap              Install Snap packages
    -g, --git-repos         Clone Git repositories
    --non-interactive       Run without interactive prompts

EXAMPLES:
    $SCRIPT_NAME --core --zsh           # Install core tools and setup Zsh
    $SCRIPT_NAME --all --non-interactive # Run full installation without prompts
    $SCRIPT_NAME                        # Show interactive menu

EOF
}

parse_arguments() {
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                args+=("all")
                shift
                ;;
            -u|--update)
                args+=("update")
                shift
                ;;
            -c|--core)
                args+=("core")
                shift
                ;;
            -z|--zsh)
                args+=("zsh")
                shift
                ;;
            -n|--neovim)
                args+=("neovim")
                shift
                ;;
            -f|--fonts)
                args+=("fonts")
                shift
                ;;
            -d|--dotfiles)
                args+=("dotfiles")
                shift
                ;;
            -r|--rust)
                args+=("rust")
                shift
                ;;
            -o|--openvpn)
                args+=("openvpn")
                shift
                ;;
            -s|--snap)
                args+=("snap")
                shift
                ;;
            -g|--git-repos)
                args+=("git-repos")
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            *)
                error_exit "Unknown option: $1. Use -h or --help for usage information."
                ;;
        esac
    done
    
    printf '%s\n' "${args[@]}"
}

execute_functions() {
    local functions=("$@")
    
    for func in "${functions[@]}"; do
        case "$func" in
            all)
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
                print_success "Full installation complete!"
                ;;
            update)
                update_system
                ;;
            core)
                install_core_tools
                ;;
            zsh)
                setup_zsh
                ;;
            neovim)
                purge_old_editors
                install_neovim
                setup_nvchad
                ;;
            fonts)
                install_nerd_fonts
                ;;
            dotfiles)
                copy_dotfiles
                ;;
            rust)
                setup_rust
                ;;
            openvpn)
                setup_openvpn
                ;;
            snap)
                install_snap_packages
                ;;
            git-repos)
                clone_git_repos
                ;;
            *)
                error_exit "Unknown function: $func"
                ;;
        esac
    done
}

# --- Main Menu Function ---

main_menu() {
    while true; do
        printf "\n%b--- Setup Menu ---%b\n" "${C_GREEN}${C_BOLD}" "${C_DEFAULT}"
        echo "1. Run Full Installation (All Steps)"
        echo "2. Update System Packages Only"
        echo "3. Install Core Tools Only"
        echo "4. Setup Zsh & Oh My Zsh"
        echo "5. Install Neovim & NvChad"
        echo "6. Install Nerd Fonts Only"
        echo "7. Copy Dotfiles Only"
        echo "8. Setup Rust & Cargo"
        echo "9. Install OpenVPN"
        echo "10. Install Snap Packages"
        echo "11. Clone Git Repositories"
        echo "q. Quit"
        printf "%bChoose an option: %b" "${C_YELLOW}" "${C_DEFAULT}"
        read -r choice

        case "$choice" in
            1)
                execute_functions "all"
                ;;
            2)
                execute_functions "update"
                ;;
            3)
                execute_functions "core"
                ;;
            4)
                execute_functions "zsh"
                ;;
            5)
                execute_functions "neovim"
                ;;
            6)
                execute_functions "fonts"
                ;;
            7)
                execute_functions "dotfiles"
                ;;
            8)
                execute_functions "rust"
                ;;
            9)
                execute_functions "openvpn"
                ;;
            10)
                execute_functions "snap"
                ;;
            11)
                execute_functions "git-repos"
                ;;
            q|Q)
                echo "Exiting."
                exit 0
                ;;
            *)
                printf "\n%bInvalid option. Please try again.%b\n" "${C_RED}" "${C_DEFAULT}"
                ;;
        esac
        printf "%b\nOperation complete. Returning to menu...%b\n" "${C_GREEN}" "${C_DEFAULT}"
    done
}

# --- Script Execution Starts Here ---

main() {
    # Initialize variables
    NON_INTERACTIVE=false
    
    # Parse command line arguments
    local requested_functions
    mapfile -t requested_functions < <(parse_arguments "$@")
    
    # Pre-flight checks
    check_dependencies
    check_sudo
    detect_package_manager
    
    # Execute based on arguments or show menu
    if [[ ${#requested_functions[@]} -gt 0 ]]; then
        execute_functions "${requested_functions[@]}"
        print_success "All requested operations completed successfully!"
    else
        main_menu
    fi
}

# Call main function with all arguments
main "$@"
