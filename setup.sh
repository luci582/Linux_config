#!/bin/bash

# Cross-platform Development Environment Setup - Main Launcher
# Detects OS (Linux/macOS) and runs the appropriate setup script.
# Supports two install modes: desktop (default) and server (no GUI apps).

set -euo pipefail

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

usage() {
    cat <<EOF
Usage: $0 [--server | --desktop] [--help]

Options:
  --server     Headless / server install. Skips all GUI apps
               (virt-manager, snap GUI packages, ghostty, GNOME extensions,
                Docker Desktop cask on macOS, optional Nerd Fonts).
  --desktop    Full workstation install (default).
  -h, --help   Show this help.

Environment overrides:
  INSTALL_MODE=server|desktop    Same as the matching flag.
  FORCE_DISTRO=ubuntu|debian|macos   Skip auto-detection (useful in CI).
EOF
}

# --- OS Detection ---
detect_os() {
    local uname_s
    uname_s="$(uname -s 2>/dev/null || echo unknown)"

    case "$uname_s" in
        Darwin)
            OS_KIND="macos"
            DISTRO="macos"
            OS="macOS"
            VER="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
            return
            ;;
        Linux) ;;
        *)
            die "Unsupported OS: $uname_s. Supported: Linux (Ubuntu/Debian), macOS."
            ;;
    esac

    OS_KIND="linux"

    if [ ! -f /etc/os-release ]; then
        die "Cannot detect Linux distribution. /etc/os-release not found."
    fi

    # shellcheck disable=SC1091
    . /etc/os-release
    OS=${NAME:-}
    VER=${VERSION_ID:-}

    if [ -z "${OS:-}" ]; then
        die "Cannot detect OS. NAME missing from /etc/os-release."
    fi

    case "$OS" in
        *Ubuntu*) DISTRO="ubuntu" ;;
        *Debian*) DISTRO="debian" ;;
        *)
            # Fall back to ID_LIKE for derivatives
            if echo "${ID_LIKE:-}" | grep -qi debian; then
                DISTRO="debian"
            else
                die "Unsupported Linux distribution: $OS. Supports Ubuntu, Debian (and derivatives)."
            fi
            ;;
    esac
}

# --- CLI Parsing ---
parse_args() {
    INSTALL_MODE="${INSTALL_MODE:-desktop}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --server)  INSTALL_MODE="server" ;;
            --desktop) INSTALL_MODE="desktop" ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown argument: $1 (see --help)" ;;
        esac
        shift
    done

    case "$INSTALL_MODE" in
        server|desktop) ;;
        *) die "Invalid INSTALL_MODE: $INSTALL_MODE (expected server|desktop)" ;;
    esac

    export INSTALL_MODE
}

main() {
    print_header "Development Environment Setup"

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    parse_args "$@"

    if [ -n "${FORCE_DISTRO:-}" ]; then
        DISTRO="$FORCE_DISTRO"
        case "$DISTRO" in
            macos) OS_KIND="macos"; OS="macOS" ;;
            ubuntu|debian) OS_KIND="linux"; OS="$DISTRO" ;;
            *) die "FORCE_DISTRO=$FORCE_DISTRO not supported" ;;
        esac
        VER="${VER:-forced}"
    else
        detect_os
    fi

    export OS_KIND DISTRO

    printf "%bDetected OS:%b    %s %s\n" "${C_GREEN}" "${C_DEFAULT}" "$OS" "${VER:-unknown}"
    printf "%bInstall mode:%b  %s\n" "${C_GREEN}" "${C_DEFAULT}" "$INSTALL_MODE"
    printf "%bRunning:%b       scripts/distro/${DISTRO}_setup.sh\n" "${C_YELLOW}" "${C_DEFAULT}"

    DISTRO_SCRIPT="$SCRIPT_DIR/scripts/distro/${DISTRO}_setup.sh"
    if [ ! -f "$DISTRO_SCRIPT" ]; then
        die "Distro script not found: $DISTRO_SCRIPT"
    fi

    chmod +x "$DISTRO_SCRIPT"
    exec "$DISTRO_SCRIPT"
}

# Refuse to run as root (macOS: also reject root); Homebrew/snap/apt each need sudo for specific steps only.
if [ "$(id -u)" -eq 0 ]; then
    die "Do not run as root. Run as a regular user; scripts will call sudo where needed."
fi

main "$@"
