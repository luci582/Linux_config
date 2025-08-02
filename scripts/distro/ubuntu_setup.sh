#!/bin/bash

# Ubuntu Development Environment Setup Script
# Optimized for Ubuntu systems

set -eu

# Enable pipefail if supported (bash 3.0+)
if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_VERSINFO[0]}" -ge 3 ]; then
    set -o pipefail
fi

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common/functions.sh"

# --- Ubuntu-specific Functions ---

update_system() {
    print_header "Updating Ubuntu System Packages"
    if ! command -v apt >/dev/null 2>&1; then
        die "This script requires apt (Ubuntu)."
    fi
    sudo apt update -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
}

install_core_tools() {
    print_header "Installing Core Packages & Tools for Ubuntu"
    
    # Install essential development tools
    printf "%bInstalling essential development tools...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    sudo apt install -y \
        curl git wget gpg ca-certificates \
        build-essential cmake pkg-config \
        software-properties-common unzip tree \
        lsb-release apt-transport-https
    
    # Install terminal and productivity tools
    printf "%bInstalling terminal and productivity tools...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    sudo apt install -y \
        tmux zsh flameshot snapd bat btop \
        htop neofetch autojump thefuck fzf \
        cpufrequtils \
        freerdp2-x11
    
    # Install Neovim build dependencies
    printf "%bInstalling Neovim build dependencies...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    sudo apt install -y \
        ninja-build gettext cmake unzip curl \
        build-essential libtool libtool-bin autoconf automake g++ pkg-config
}

purge_old_editors() {
    print_header "Purging Old Vim/Neovim to prevent conflicts"
    sudo apt purge -y vim vim-runtime || true
    sudo apt purge -y neovim || true
    sudo apt autoremove -y
}

setup_openvpn() {
    print_header "Installing OpenVPN3 for Ubuntu"
    
    # Get Ubuntu codename
    codename=$(lsb_release -cs 2>/dev/null || echo "jammy")
    
    # Add OpenVPN repository
    sudo mkdir -p /etc/apt/keyrings
    curl -sSfL https://packages.openvpn.net/packages-repo.gpg | sudo tee /etc/apt/keyrings/openvpn.asc > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/ubuntu $codename main" | sudo tee /etc/apt/sources.list.d/openvpn3.list > /dev/null
    
    sudo apt update
    sudo apt install -y openvpn3 || {
        printf "%bFallback to standard OpenVPN...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        sudo apt install -y openvpn
    }
}

install_ssh_server() {
    print_header "Installing SSH Server for Ubuntu"
    if confirm "Do you want to install SSH server?"; then
        printf "%bInstalling OpenSSH Server...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        sudo apt update
        sudo apt install -y openssh-server
        
        # Enable and start SSH service
        sudo systemctl enable ssh
        sudo systemctl start ssh
        
        printf "%bSSH server installed and started successfully%b\n" "${C_GREEN}" "${C_DEFAULT}"
        printf "%bSSH service status:%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        sudo systemctl status ssh --no-pager
    fi
}

# --- Menu System ---
show_menu() {
    printf "\n%b--- Ubuntu Setup Menu ---%b\n" "${C_GREEN}${C_BOLD}" "${C_DEFAULT}"
    echo "1.  Run Full Installation (All Steps)"
    echo "2.  Update System Packages Only"
    echo "3.  Install Core Tools Only"
    echo "4.  Setup Zsh & Oh My Zsh"
    echo "5.  Install Neovim & NvChad"
    echo "6.  Install Nerd Fonts Only"
    echo "7.  Copy Dotfiles Only"
    echo "8.  Setup Rust Environment"
    echo "9.  Install OpenVPN3"
    echo "10. Install Docker"
    echo "11. Install SSH Server"
    echo "12. Install Virt-Manager"
    echo "13. Install Snap Packages"
    echo "c.  Check Installation Status"
    echo "s.  Show System Information"
    echo "q.  Quit"
    printf "%bChoose an option: %b" "${C_YELLOW}" "${C_DEFAULT}"
}

main_menu() {
    # Initial system checks
    if [ "$(id -u)" -eq 0 ]; then
        die "This script should not be run as root. Please run as a regular user."
    fi
    
    if ! grep -q "Ubuntu" /etc/os-release; then
        die "This script is designed for Ubuntu systems only."
    fi
    
    check_dependencies || die "Please install missing dependencies first."
    
    printf "%b%s%b\n" "${C_BLUE}${C_BOLD}" "Welcome to the Ubuntu Development Environment Setup Script" "${C_DEFAULT}"
    printf "%bDetected OS: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Ubuntu')"
    
    while true; do
        show_menu
        read -r choice
        
        case "$choice" in
            1)
                if confirm "This will install all components. Continue?"; then
                    update_system
                    install_core_tools
                    purge_old_editors
                    setup_rust
                    setup_openvpn
                    install_docker
                    install_virt_manager
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
            10) install_docker ;;
            11) install_ssh_server ;;
            12) install_virt_manager ;;
            13) install_snap_packages ;;
            c|C) check_installation_status ;;
            s|S)
                printf "\n%b--- System Information ---%b\n" "${C_BLUE}${C_BOLD}" "${C_DEFAULT}"
                printf "%bOS: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
                printf "%bKernel: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(uname -r)"
                printf "%bShell: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$SHELL"
                printf "%bUser: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$USER"
                printf "%bArchitecture: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(uname -m)"
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

# Run main menu
main_menu
