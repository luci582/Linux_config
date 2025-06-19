#!/bin/bash

# --- Script Configuration and Safety ---
# Exit immediately if a command exits with a non-zero status.
set -e

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

# --- Installation and Setup Functions ---

update_system() {
    print_header "Updating and Upgrading System Packages"
    sudo apt update -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
}

install_core_tools() {
    print_header "Installing Core Packages & Tools"
    sudo apt install -y \
        apt-transport-https curl git \
        virtualbox tmux zsh flameshot \
        snapd bat btop freerdp3-x11
}

purge_old_editors() {
    print_header "Purging Old Vim/Neovim to prevent conflicts"
    sudo apt purge vim -y
    # Use '|| true' so the script doesn't fail if neovim wasn't installed.
    sudo apt purge neovim -y || true
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
    sudo mkdir -p /etc/apt/keyrings
    curl -sSfL https://packages.openvpn.net/packages-repo.gpg | sudo tee /etc/apt/keyrings/openvpn.asc > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] https://packages.openvpn.net/openvpn3/debian bookworm main" | sudo tee /etc/apt/sources.list.d/openvpn3.list > /dev/null
    sudo apt update
    sudo apt install -y openvpn3
}

install_snap_packages() {
    print_header "Installing Snap Packages"
    sudo snap install --classic waveterm
    sudo snap install obsidian --classic
    snap install ghostty --classic
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
    if [ -d "$HOME/.config/nvim" ]; then
        printf "%bExisting NvChad config found. Backing it up to ~/.config/nvim.bak%b\n" "${C_YELLOW}" "${C_DEFAULT}"
        mv ~/.config/nvim ~/.config/nvim.bak
    fi
    git clone https://github.com/NvChad/starter ~/.config/nvim
}

copy_dotfiles() {
    print_header "Copying Local Configuration Files (.zshrc, .tmux.conf, .p10k.zsh)"
    # This assumes dotfiles are in the same directory as this script.
    cp -f .zshrc ~
    cp -f .tmux.conf ~
    cp -f .p10k.zsh ~
    cp -f config ~/.config/ghostty
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
        echo "q. Quit"
        printf "%bChoose an option: %b" "${C_YELLOW}" "${C_DEFAULT}"
        read -r choice

        case "$choice" in
            1)
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
                echo -e "\n${C_GREEN}${C_BOLD}Full installation complete!${C_DEFAULT}"
                ;;
            2)
                update_system
                ;;
            3)
                install_core_tools
                ;;
            4)
                setup_zsh
                ;;
            5)
                purge_old_editors
                install_neovim
                setup_nvchad
                ;;
            6)
                install_nerd_fonts
                ;;
            7)
                copy_dotfiles
                ;;
            8)
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
main_menu
