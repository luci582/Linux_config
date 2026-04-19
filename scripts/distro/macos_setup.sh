#!/bin/bash

# macOS Development Environment Setup Script
# Uses Homebrew as the package manager. Supports desktop and server modes.

set -euo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../common/functions.sh
. "$SCRIPT_DIR/../common/functions.sh"

# --- macOS-specific Functions ---

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        return 0
    fi

    print_header "Installing Homebrew"
    printf "%bHomebrew not found. Installing...%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to current PATH for the rest of the session (Apple Silicon + Intel paths)
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if ! command -v brew >/dev/null 2>&1; then
        die "Homebrew install failed. See https://brew.sh"
    fi
}

update_system() {
    print_header "Updating Homebrew"
    ensure_homebrew
    brew update
    brew upgrade
    brew cleanup
}

install_core_tools() {
    print_header "Installing Core Packages & Tools for macOS"
    ensure_homebrew

    # Essentials (CLI, works in server mode too)
    local core_formulae=(
        git curl wget gnupg
        cmake pkg-config
        tree unzip
        tmux zsh
        htop btop neofetch
        bat fzf thefuck
        eza
    )

    printf "%bInstalling CLI formulae: %s%b\n" "${C_YELLOW}" "${core_formulae[*]}" "${C_DEFAULT}"
    brew install "${core_formulae[@]}"

    if is_server_mode; then
        printf "%b[server mode] skipping GUI casks (ghostty, vscode, obsidian, discord)%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        return 0
    fi

    # Desktop-only GUI apps
    print_header "Installing GUI applications via Homebrew Cask"
    local casks=(
        ghostty
        visual-studio-code
        obsidian
    )
    for cask in "${casks[@]}"; do
        printf "%bInstalling cask: %s%b\n" "${C_YELLOW}" "$cask" "${C_DEFAULT}"
        brew install --cask "$cask" 2>&1 | tail -5 || \
            printf "%bFailed/skipped cask: %s%b\n" "${C_RED}" "$cask" "${C_DEFAULT}"
    done
}

purge_old_editors() {
    # Nothing to purge on macOS — brew installs are isolated.
    printf "%b[macOS] no legacy editors to purge; skipping.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
}

install_ssh_server() {
    print_header "Enabling Remote Login (SSH) on macOS"
    if ! confirm "Enable Remote Login (SSH server) via systemsetup?"; then
        return 0
    fi
    # Needs admin; will prompt for password.
    sudo systemsetup -setremotelogin on || \
        printf "%bFailed to enable Remote Login. Enable via System Settings → General → Sharing%b\n" "${C_RED}" "${C_DEFAULT}"
    printf "%bRemote Login status:%b\n" "${C_YELLOW}" "${C_DEFAULT}"
    sudo systemsetup -getremotelogin || true
}

# Stubs for menu parity with Linux scripts — macOS has no snap/GNOME/virt-manager.
install_virt_manager() {
    printf "%b[macOS] virt-manager/KVM not available. Try UTM or VMware Fusion via brew cask.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
}

install_snap_packages() {
    printf "%b[macOS] snap is Linux-only. GUI apps install via brew casks (see 'Install Core Tools').%b\n" "${C_YELLOW}" "${C_DEFAULT}"
}

install_gnome_extensions() {
    printf "%b[macOS] GNOME extensions are Linux-only. Skipping.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
}

update_gnome_extensions() {
    printf "%b[macOS] GNOME extensions are Linux-only. Skipping.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
}

# --- Menu System ---
show_menu() {
    printf "\n%b--- macOS Setup Menu (%s mode) ---%b\n" "${C_GREEN}${C_BOLD}" "$INSTALL_MODE" "${C_DEFAULT}"
    echo "1.  Run Full Installation (All Steps)"
    echo "2.  Update Homebrew & upgrade all"
    echo "3.  Install Core Tools Only"
    echo "4.  Setup Zsh & Oh My Zsh"
    echo "5.  Install Neovim & NvChad"
    echo "6.  Install Nerd Fonts Only"
    echo "7.  Copy Dotfiles Only"
    echo "8.  Setup Rust Environment"
    echo "9.  Install Docker"
    echo "10. Enable Remote Login (SSH)"
    echo "c.  Check Installation Status"
    echo "s.  Show System Information"
    echo "q.  Quit"
    printf "%bChoose an option: %b" "${C_YELLOW}" "${C_DEFAULT}"
}

main_menu() {
    if [ "$(id -u)" -eq 0 ]; then
        die "Do not run as root."
    fi

    if [ "$(uname -s)" != "Darwin" ]; then
        die "This script is for macOS only."
    fi

    check_dependencies || die "Install Xcode Command Line Tools first: xcode-select --install"
    ensure_homebrew

    printf "%b%s%b\n" "${C_BLUE}${C_BOLD}" "Welcome to the macOS Development Environment Setup Script" "${C_DEFAULT}"
    printf "%bmacOS: %b%s   %bmode: %b%s\n" "${C_GREEN}" "${C_DEFAULT}" "$(sw_vers -productVersion 2>/dev/null || echo unknown)" "${C_GREEN}" "${C_DEFAULT}" "$INSTALL_MODE"

    while true; do
        show_menu
        read -r choice

        case "$choice" in
            1)
                if confirm "This will install all components ($INSTALL_MODE mode). Continue?"; then
                    update_system
                    install_core_tools
                    setup_rust
                    install_docker
                    install_neovim
                    clone_git_repos
                    setup_zsh
                    setup_nvchad
                    copy_dotfiles
                    install_nerd_fonts
                    printf "\n%bFull installation complete!%b\n" "${C_GREEN}${C_BOLD}" "${C_DEFAULT}"
                    printf "%bRestart your terminal or run 'source ~/.zshrc' to apply changes.%b\n" "${C_YELLOW}" "${C_DEFAULT}"
                fi
                ;;
            2) update_system ;;
            3) install_core_tools ;;
            4) setup_zsh ;;
            5) install_neovim && setup_nvchad ;;
            6) install_nerd_fonts ;;
            7) copy_dotfiles ;;
            8) setup_rust ;;
            9) install_docker ;;
            10) install_ssh_server ;;
            c|C) check_installation_status ;;
            s|S)
                printf "\n%b--- System Information ---%b\n" "${C_BLUE}${C_BOLD}" "${C_DEFAULT}"
                printf "%bOS:%b            macOS %s\n" "${C_GREEN}" "${C_DEFAULT}" "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
                printf "%bBuild:%b         %s\n" "${C_GREEN}" "${C_DEFAULT}" "$(sw_vers -buildVersion 2>/dev/null || echo unknown)"
                printf "%bKernel:%b        %s\n" "${C_GREEN}" "${C_DEFAULT}" "$(uname -r)"
                printf "%bShell:%b         %s\n" "${C_GREEN}" "${C_DEFAULT}" "$SHELL"
                printf "%bUser:%b          %s\n" "${C_GREEN}" "${C_DEFAULT}" "$USER"
                printf "%bArchitecture:%b  %s\n" "${C_GREEN}" "${C_DEFAULT}" "$(uname -m)"
                printf "%bMode:%b          %s\n" "${C_GREEN}" "${C_DEFAULT}" "$INSTALL_MODE"
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

main_menu
