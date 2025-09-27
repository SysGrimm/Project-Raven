#!/bin/bash

# Project Raven - OS Stripping Script
# Removes unnecessary packages from Raspberry Pi OS to create minimal media center

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING]  $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo $0)"
    fi
}

# Function to remove desktop environments and GUI components
remove_desktop_components() {
    log "Removing desktop environments and GUI components..."
    
    # Desktop environments
    local desktop_packages=(
        "lxde*"
        "lxde-common"
        "lxsession*"
        "lxpanel*"
        "lxmenu-data"
        "lightdm*"
        "gdm3*"
        "sddm*"
        "x11-common"
        "xserver-xorg*"
        "xinit"
        "xdg-*"
        "desktop-*"
        "gnome-*"
        "gtk2-engines*"
        "gtk3-*"
        "gvfs*"
    )
    
    for package in "${desktop_packages[@]}"; do
        apt-get remove --purge -y $package 2>/dev/null || true
    done
    
    success "Desktop components removed"
}

# Function to remove unnecessary applications
remove_applications() {
    log "Removing unnecessary applications..."
    
    local app_packages=(
        "libreoffice*"
        "wolfram-engine"
        "scratch*"
        "sonic-pi"
        "minecraft-pi"
        "python3-pygame"
        "chromium-browser*"
        "firefox-esr*"
        "thunderbird*"
        "geany*"
        "thonny*"
        "mu-editor*"
        "sense-hat*"
        "python-sense-hat*"
        "realvnc-*"
        "rpi-chromium-mods"
        "rpd-wallpaper"
        "rpd-icons"
        "fonts-droid-fallback"
        "fonts-liberation2"
        "fonts-noto*"
        "fonts-opensymbol"
        "bluej"
        "greenfoot"
        "nodered"
        "claws-mail*"
        "epiphany-browser*"
    )
    
    for package in "${app_packages[@]}"; do
        apt-get remove --purge -y $package 2>/dev/null || true
    done
    
    success "Unnecessary applications removed"
}

# Function to remove development tools (keep essential ones)
remove_dev_tools() {
    log "Removing non-essential development tools..."
    
    local dev_packages=(
        "gcc-*-base"
        "build-essential"
        "manpages-dev"
        "libc6-dev"
        "linux-libc-dev"
        "pkg-config"
        "make"
        "automake"
        "autoconf"
        "cmake"
        "git-man"
        "git-gui"
        "gitk"
    )
    
    # Keep essential packages: git, curl, wget, nano, vim
    for package in "${dev_packages[@]}"; do
        apt-get remove --purge -y $package 2>/dev/null || true
    done
    
    success "Non-essential development tools removed"
}

# Function to remove games and entertainment (except Kodi)
remove_games() {
    log "Removing games and entertainment packages..."
    
    local game_packages=(
        "penguinspuzzle"
        "four-in-a-row"
        "gnome-mines"
        "gnome-sudoku"
        "aisleriot"
        "gnome-mahjongg"
    )
    
    for package in "${game_packages[@]}"; do
        apt-get remove --purge -y $package 2>/dev/null || true
    done
    
    success "Games removed"
}

# Function to remove printer and scanner support
remove_printing() {
    log "Removing printer and scanner support..."
    
    local print_packages=(
        "cups*"
        "hplip*"
        "printer-driver-*"
        "sane-utils"
        "libsane*"
        "simple-scan"
        "system-config-printer*"
    )
    
    for package in "${print_packages[@]}"; do
        apt-get remove --purge -y $package 2>/dev/null || true
    done
    
    success "Printing support removed"
}

# Function to remove accessibility features
remove_accessibility() {
    log "Removing accessibility features..."
    
    local accessibility_packages=(
        "orca"
        "speech-dispatcher*"
        "espeak*"
        "brltty*"
        "at-spi2-*"
    )
    
    for package in "${accessibility_packages[@]}"; do
        apt-get remove --purge -y $package 2>/dev/null || true
    done
    
    success "Accessibility features removed"
}

# Function to clean up package system
cleanup_packages() {
    log "Cleaning up package system..."
    
    # Remove orphaned packages
    apt-get autoremove --purge -y
    
    # Clean package cache
    apt-get autoclean
    apt-get clean
    
    # Remove package lists (will be regenerated when needed)
    rm -rf /var/lib/apt/lists/*
    
    success "Package system cleaned"
}

# Function to remove unnecessary services
disable_services() {
    log "Disabling unnecessary services..."
    
    local services=(
        "bluetooth"
        "ModemManager"
        "wpa_supplicant"
        "avahi-daemon"
        "triggerhappy"
        "dphys-swapfile"
        "keyboard-setup"
        "plymouth*"
    )
    
    for service in "${services[@]}"; do
        systemctl disable $service 2>/dev/null || true
        systemctl stop $service 2>/dev/null || true
    done
    
    success "Unnecessary services disabled"
}

# Function to clean up filesystem
cleanup_filesystem() {
    log "Cleaning up filesystem..."
    
    # Remove documentation
    rm -rf /usr/share/doc/* 2>/dev/null || true
    rm -rf /usr/share/man/* 2>/dev/null || true
    rm -rf /usr/share/info/* 2>/dev/null || true
    
    # Remove locales except English
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} \; 2>/dev/null || true
    
    # Remove sample configs and templates
    rm -rf /usr/share/pixmaps/* 2>/dev/null || true
    rm -rf /usr/share/applications/* 2>/dev/null || true
    
    # Clean temporary files
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    
    # Clean logs
    find /var/log -type f -name "*.log" -delete 2>/dev/null || true
    find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
    
    success "Filesystem cleaned"
}

# Function to show disk usage before and after
show_disk_usage() {
    local phase="$1"
    log "Disk usage $phase stripping:"
    df -h / | grep -E '^/dev/'
    echo ""
}

# Function to create minimal package list for future reference
create_minimal_list() {
    log "Creating minimal package list..."
    
    dpkg --get-selections | grep -v deinstall | awk '{print $1}' > /opt/raven/minimal-packages.list
    
    success "Minimal package list saved to /opt/raven/minimal-packages.list"
}

# Main execution
main() {
    log "[LAUNCH] Starting Raspberry Pi OS stripping for Project Raven"
    echo "======================================================"
    
    check_root
    
    show_disk_usage "before"
    
    # Create directory for our files
    mkdir -p /opt/raven
    
    # Update package database first
    log "Updating package database..."
    apt-get update -y
    
    # Remove components
    remove_desktop_components
    remove_applications
    remove_dev_tools
    remove_games
    remove_printing
    remove_accessibility
    disable_services
    cleanup_packages
    cleanup_filesystem
    
    # Create reference
    create_minimal_list
    
    show_disk_usage "after"
    
    log "[COMPLETE] OS stripping completed successfully!"
    echo "========================================"
    warning "Reboot recommended to complete all changes"
}

# Show usage information
show_usage() {
    echo "Project Raven OS Stripping Script"
    echo "================================="
    echo ""
    echo "This script strips down Raspberry Pi OS to minimal components needed"
    echo "for a Kodi-first media center experience."
    echo ""
    echo "Usage: sudo $0"
    echo ""
    echo "What gets removed:"
    echo "  - Desktop environments (LXDE, etc.)"
    echo "  - Office applications (LibreOffice)"
    echo "  - Development tools (compilers, IDEs)"
    echo "  - Games and entertainment"
    echo "  - Printer/scanner support"
    echo "  - Accessibility features"
    echo "  - Documentation and man pages"
    echo ""
    echo "What gets kept:"
    echo "  - Essential system components"
    echo "  - Network management"
    echo "  - SSH server"
    echo "  - Package manager"
    echo "  - Basic command line tools"
    echo ""
}

# Handle command line arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        error "Unknown argument: $1. Use '$0 help' for usage information."
        ;;
esac
