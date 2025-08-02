#!/bin/bash

# Linux Development Environment Setup - Main Launcher
# This script detects the OS and runs the appropriate setup script

set -eu

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

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        die "Cannot detect OS. /etc/os-release not found."
    fi
    
    case "$OS" in
        *Ubuntu*)
            DISTRO="ubuntu"
            ;;
        *Debian*)
            DISTRO="debian"
            ;;
        *)
            die "Unsupported OS: $OS. This script supports Ubuntu and Debian only."
            ;;
    esac
}

main() {
    print_header "Linux Development Environment Setup"
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    
    # Detect OS
    detect_os
    
    printf "%bDetected OS: %b%s %s\n" "${C_GREEN}" "${C_DEFAULT}" "$OS" "${VER:-unknown}"
    printf "%bUsing script for: %b%s\n" "${C_YELLOW}" "${C_DEFAULT}" "$DISTRO"
    
    # Check if distro-specific script exists
    DISTRO_SCRIPT="$SCRIPT_DIR/scripts/distro/${DISTRO}_setup.sh"
    
    if [ ! -f "$DISTRO_SCRIPT" ]; then
        die "Script for $DISTRO not found: $DISTRO_SCRIPT"
    fi
    
    # Make script executable
    chmod +x "$DISTRO_SCRIPT"
    
    # Run the appropriate script
    printf "%bLaunching %s setup script...%b\n" "${C_GREEN}" "$DISTRO" "${C_DEFAULT}"
    exec "$DISTRO_SCRIPT"
}

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    die "This script should not be run as root. Please run as a regular user."
fi

main "$@"
