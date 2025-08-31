#!/bin/bash
# macOS SoulBox Deployment Helper
# Simplifies deployment process for macOS users

set -euo pipefail

SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

show_usage() {
    cat << EOF
SoulBox macOS Deployment Helper

USAGE:
    $0 [command]

COMMANDS:
    prepare     Generate Tailscale configuration files
    flash       Instructions for flashing SD card
    setup       Generate setup commands for Pi
    all         Complete deployment guide

EXAMPLES:
    $0 prepare          # Generate config files
    $0 all              # Show complete deployment process

EOF
}

# Generate Tailscale configuration
prepare_config() {
    log_step "Generating Tailscale Configuration"
    
    cd "$PROJECT_DIR"
    
    if [[ ! -x "scripts/create-tailscale-config.sh" ]]; then
        log_error "Tailscale config script not found or not executable"
        exit 1
    fi
    
    log_info "Starting interactive configuration..."
    ./scripts/create-tailscale-config.sh --interactive
    
    echo ""
    log_info "Configuration files generated!"
    echo "Files created:"
    ls -la tailscale-authkey.txt soulbox-config.txt 2>/dev/null || echo "  (files will be created after configuration)"
    echo ""
}

# Show SD card flashing instructions
flash_instructions() {
    log_step "SD Card Flashing Instructions"
    
    cat << EOF

1. DOWNLOAD RASPBERRY PI IMAGER
   https://www.raspberrypi.com/software/

2. FLASH RASPBERRY PI OS
   - Choose: "Raspberry Pi OS Lite (64-bit)"
   - Click gear icon for advanced options:
     ✓ Enable SSH (with password or key)
     ✓ Set username: pi
     ✓ Configure WiFi credentials
     ✓ Set locale/timezone

3. FLASH TO SD CARD
   - Insert SD card
   - Select SD card in imager
   - Write image

4. ADD SOULBOX CONFIG FILES
   After flashing, SD card will be mounted as 'bootfs'
   
   Copy generated files:
   cp tailscale-authkey.txt /Volumes/bootfs/  (if exists)
   cp soulbox-config.txt /Volumes/bootfs/     (if exists)
   
   Safely eject:
   diskutil eject /Volumes/bootfs

EOF
}

# Generate Pi setup commands
setup_commands() {
    log_step "Raspberry Pi Setup Commands"
    
    local gitea_url="https://gitea.osiris-adelie.ts.net/reaper/soulbox.git"
    
    cat << EOF

AFTER FIRST BOOT:

1. FIND PI IP ADDRESS
   # Scan your network
   nmap -sn 192.168.1.0/24
   
   # Or check your router's admin page

2. SSH INTO PI
   ssh pi@192.168.1.XXX

3. CLONE AND SETUP SOULBOX
   git clone ${gitea_url}
   cd soulbox
   sudo ./scripts/setup-system.sh

4. REBOOT
   sudo reboot

5. ACCESS SOULBOX
   # Wait 2-3 minutes for services to start
   
   # SSH as reaper user:
   ssh reaper@192.168.1.XXX
   
   # Or via Tailscale (if configured):
   ssh reaper@your-hostname.your-tailnet.ts.net
   
   # Kodi web interface (if enabled):
   http://192.168.1.XXX:8080

EOF
}

# Check macOS requirements
check_requirements() {
    log_info "Checking macOS requirements..."
    
    # Check if nmap is available
    if ! command -v nmap >/dev/null 2>&1; then
        log_warn "nmap not found - install with: brew install nmap"
    fi
    
    # Check if Raspberry Pi Imager is installed
    if [[ ! -d "/Applications/Raspberry Pi Imager.app" ]]; then
        log_warn "Raspberry Pi Imager not found"
        log_info "Download from: https://www.raspberrypi.com/software/"
    fi
    
    echo ""
}

# Show complete deployment process
show_complete_guide() {
    log_step "Complete SoulBox Deployment Guide for macOS"
    echo ""
    
    check_requirements
    prepare_config
    flash_instructions
    setup_commands
    
    cat << EOF

TROUBLESHOOTING:
- If Pi doesn't boot: Check SD card, power supply, HDMI connection
- If SSH fails: Check IP address, ensure SSH was enabled in imager
- If setup script fails: Check internet connection on Pi
- For Tailscale issues: See TFM.md documentation

WHAT HAPPENS AFTER SETUP:
✓ Kodi starts automatically on boot
✓ Tailscale VPN configured (if auth key provided)
✓ SSH access via local network and Tailscale
✓ GPU hardware acceleration enabled
✓ Optimized for Pi 5 performance

NEXT STEPS:
1. Configure Kodi media sources
2. Set up remote access via Tailscale
3. Enable Kodi web interface if needed
4. Set up media library and sources

EOF
}

# Main execution
main() {
    case "${1:-all}" in
        prepare)
            prepare_config
            ;;
        flash)
            flash_instructions
            ;;
        setup)
            setup_commands
            ;;
        all)
            show_complete_guide
            ;;
        *)
            show_usage
            ;;
    esac
}

main "$@"
