#!/bin/bash

# Ubuntu Development Environment Setup Script
# Optimized for Ubuntu systems

set -euo pipefail

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

install_gnome_extensions() {
    skip_if_server "GNOME extensions (GUI)" && return 0

    # Check if GNOME is running
    if [ "${XDG_CURRENT_DESKTOP:-}" != "GNOME" ] && [ "${GDMSESSION:-}" != "gnome" ] && ! pgrep -x gnome-shell >/dev/null 2>&1; then
        printf "%bGNOME not detected. Skipping GNOME extensions installation.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        return 0
    fi

    print_header "Installing GNOME Extensions"
    printf "%bGNOME detected. Installing extensions...%b\n" "${C_GREEN}" "${C_DEFAULT}"
    
    # Install required packages
    printf "%bInstalling GNOME extension tools...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    sudo apt install -y gnome-shell-extensions gnome-shell-extension-manager chrome-gnome-shell pipx || true
    
    # Install gext using pipx for extension management
    if command -v pipx >/dev/null 2>&1; then
        printf "%bInstalling gext extension manager...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        pipx install gnome-extensions-cli --force 2>/dev/null || true
        pipx ensurepath 2>/dev/null || true
    fi
    
    # List of extensions to install
    declare -a extensions=(
        "blur-my-shell@aunetx"
        "clipboard-indicator@tudmotu.com"
        "caffeine@patapon.info"
        "dash-to-dock@micxgx.gmail.com"
        "system-monitor@gnome-shell-extensions.gcampax.github.com"
    )
    
    printf "\n%bInstalling GNOME Shell Extensions:%b\n" "${C_BLUE}${C_BOLD}" "${C_DEFAULT}"
    
    for ext in "${extensions[@]}"; do
        printf "  - %s\n" "$ext"
    done
    
    printf "\n%bNote: You may need to enable extensions manually using GNOME Extensions app%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    printf "%bor by visiting: https://extensions.gnome.org%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    printf "\n%bAfter installation, press Alt+F2, type 'r', and press Enter to reload GNOME Shell%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    
    # Try to install using gext if available
    if command -v gext >/dev/null 2>&1; then
        printf "\n%bInstalling extensions using gext...%b\n" "${C_GREEN}" "${C_DEFAULT}"
        for ext in "${extensions[@]}"; do
            printf "%bInstalling %s...%b\n" "${C_YELLOW}" "$ext" "${C_DEFAULT}"
            gext install "$ext" 2>/dev/null || printf "%bFailed to install %s (manual installation may be required)%b\n" "${C_RED}" "$ext" "${C_DEFAULT}"
        done
    else
        printf "\n%bAutomatic installation tool not available.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        printf "%bPlease install extensions manually from: https://extensions.gnome.org%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    fi
    
    printf "\n%bGNOME extensions setup complete!%b\n" "${C_GREEN}" "${C_DEFAULT}"
}

update_gnome_extensions() {
    skip_if_server "GNOME extensions update (GUI)" && return 0

    # Check if GNOME is running
    if [ "${XDG_CURRENT_DESKTOP:-}" != "GNOME" ] && [ "${GDMSESSION:-}" != "gnome" ] && ! pgrep -x gnome-shell >/dev/null 2>&1; then
        printf "%bGNOME not detected. Skipping GNOME extensions update.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        return 0
    fi

    print_header "Updating GNOME Extensions"
    printf "%bGNOME detected. Updating extensions...%b\n" "${C_GREEN}" "${C_DEFAULT}"
    
    # Check if gext is available
    if ! command -v gext >/dev/null 2>&1; then
        printf "%bgext not found. Installing gnome-extensions-cli...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        
        if command -v pipx >/dev/null 2>&1; then
            pipx install gnome-extensions-cli --force 2>/dev/null || true
            pipx ensurepath 2>/dev/null || true
        else
            printf "%bpipx not found. Installing pipx...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
            sudo apt install -y pipx
            pipx install gnome-extensions-cli --force 2>/dev/null || true
            pipx ensurepath 2>/dev/null || true
        fi
    fi
    
    # Update extensions using gext
    if command -v gext >/dev/null 2>&1; then
        printf "\n%bUpdating all GNOME extensions...%b\n" "${C_GREEN}" "${C_DEFAULT}"
        
        # Get list of installed extensions
        printf "%bFetching installed extensions...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        
        # Update all extensions
        if gext update 2>/dev/null; then
            printf "%bAll extensions updated successfully!%b\n" "${C_GREEN}" "${C_DEFAULT}"
        else
            printf "%bUpdate command not fully successful. Trying individual updates...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
            
            # Try updating specific extensions
            declare -a extensions=(
                "blur-my-shell@aunetx"
                "clipboard-indicator@tudmotu.com"
                "caffeine@patapon.info"
                "dash-to-dock@micxgx.gmail.com"
                "system-monitor@gnome-shell-extensions.gcampax.github.com"
            )
            
            for ext in "${extensions[@]}"; do
                printf "%bUpdating %s...%b\n" "${C_YELLOW}" "$ext" "${C_DEFAULT}"
                gext install "$ext" --force 2>/dev/null || printf "%bFailed to update %s%b\n" "${C_RED}" "$ext" "${C_DEFAULT}"
            done
        fi
        
        printf "\n%bRecommendation: Restart GNOME Shell (Alt+F2, type 'r', Enter) to apply updates%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    else
        printf "%bCould not install gext tool. Please update extensions manually.%b\n" "${C_RED}" "${C_DEFAULT}"
        printf "%bYou can update extensions via the GNOME Extensions app or website.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        return 1
    fi
    
    printf "\n%bGNOME extensions update complete!%b\n" "${C_GREEN}" "${C_DEFAULT}"
}

# --- Menu System ---
show_menu() {
    printf "\n%b--- Ubuntu Setup Menu (%s mode) ---%b\n" "${C_GREEN}${C_BOLD}" "$INSTALL_MODE" "${C_DEFAULT}"
    echo "1.  Run Full Installation (All Steps)"
    echo "2.  Update System Packages Only"
    echo "3.  Install Core Tools Only"
    echo "4.  Setup Zsh & Oh My Zsh"
    echo "5.  Install Neovim & NvChad"
    echo "6.  Install Nerd Fonts Only"
    echo "7.  Copy Dotfiles Only"
    echo "8.  Setup Rust Environment"
    echo "9.  Install Docker"
    echo "10. Install SSH Server"
    echo "11. Install Virt-Manager"
    echo "12. Install Snap Packages"
    echo "13. Install GNOME Extensions (if GNOME detected)"
    echo "14. Update GNOME Extensions (if GNOME detected)"
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
                    install_docker
                    install_virt_manager
                    install_snap_packages
                    install_gnome_extensions
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
            9) install_docker ;;
            10) install_ssh_server ;;
            11) install_virt_manager ;;
            12) install_snap_packages ;;
            13) install_gnome_extensions ;;
            14) update_gnome_extensions ;;
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
