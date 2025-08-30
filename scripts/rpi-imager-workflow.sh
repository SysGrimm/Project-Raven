#!/bin/bash
# SoulBox Raspberry Pi Imager Complete Workflow
# End-to-end process for creating and using SoulBox images with rpi-imager
#
# Usage: ./rpi-imager-workflow.sh [command]

set -euo pipefail

SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_cmd() { echo -e "${CYAN}[CMD]${NC} $1"; }

show_usage() {
    cat << EOF
SoulBox Raspberry Pi Imager Workflow

USAGE:
    $0 [command]

COMMANDS:
    build       Build SoulBox image for rpi-imager (requires Linux)
    configure   Generate Tailscale configuration files
    setup       Setup rpi-imager with SoulBox repository
    flash       Interactive flashing guide with rpi-imager
    deploy      Complete deployment workflow
    help        Show this help

EXAMPLES:
    $0 deploy           # Complete workflow from config to flash
    $0 configure        # Just generate Tailscale config
    $0 setup            # Setup rpi-imager repository

REQUIREMENTS:
    - Raspberry Pi Imager installed
    - For building: Linux system with build tools

EOF
}

# Check if running on macOS
check_macos() {
    if [[ "$(uname)" == "Darwin" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if Raspberry Pi Imager is installed
check_rpi_imager() {
    if check_macos; then
        if [[ -d "/Applications/Raspberry Pi Imager.app" ]]; then
            log_info "Raspberry Pi Imager found"
            return 0
        else
            log_warn "Raspberry Pi Imager not found"
            log_info "Download from: https://www.raspberrypi.com/software/"
            return 1
        fi
    else
        if command -v rpi-imager >/dev/null 2>&1; then
            log_info "Raspberry Pi Imager found"
            return 0
        else
            log_warn "Raspberry Pi Imager not found"
            log_info "Install with: sudo apt install rpi-imager"
            return 1
        fi
    fi
}

# Build SoulBox image (requires Linux)
build_image() {
    log_step "Building SoulBox Image for rpi-imager"
    echo ""
    
    if check_macos; then
        log_error "Image building requires Linux system"
        echo ""
        echo "OPTIONS FOR macOS USERS:"
        echo ""
        echo "1. USE DOCKER (Recommended):"
        log_cmd "docker run -it --privileged -v \"\$(pwd)\":/workspace ubuntu:22.04"
        log_cmd "# Inside container:"
        log_cmd "cd /workspace"
        log_cmd "apt-get update && apt-get install -y git sudo"
        log_cmd "sudo ./scripts/build-rpi-imager-image.sh --compress --metadata"
        echo ""
        echo "2. USE VIRTUAL MACHINE:"
        echo "   - Run Ubuntu/Debian VM"
        echo "   - Clone SoulBox repository"
        echo "   - Run build script"
        echo ""
        echo "3. USE CLOUD INSTANCE:"
        echo "   - Launch Ubuntu instance (AWS/GCP/etc.)"
        echo "   - Install dependencies and build"
        echo ""
        return 1
    fi
    
    # Linux build process
    log_info "Checking build requirements..."
    
    if [[ $EUID -ne 0 ]]; then
        log_error "Building requires root privileges"
        log_cmd "sudo $0 build"
        return 1
    fi
    
    # Run the rpi-imager build script
    log_info "Starting image build process..."
    "${PROJECT_DIR}/scripts/build-rpi-imager-image.sh" --compress --metadata
    
    log_info "Image build completed!"
    echo ""
}

# Generate Tailscale configuration
configure_tailscale() {
    log_step "Generating Tailscale Configuration"
    echo ""
    
    cd "$PROJECT_DIR"
    
    if [[ ! -x "scripts/create-tailscale-config.sh" ]]; then
        log_error "Tailscale config script not found"
        return 1
    fi
    
    log_info "Starting interactive Tailscale configuration..."
    echo ""
    
    ./scripts/create-tailscale-config.sh --interactive
    
    echo ""
    log_info "Tailscale configuration completed!"
    
    # Show generated files
    echo "Generated files:"
    for file in tailscale-authkey.txt soulbox-config.txt; do
        if [[ -f "$file" ]]; then
            echo "  ✓ $file"
        fi
    done
    echo ""
}

# Setup rpi-imager with SoulBox repository  
setup_rpi_imager() {
    log_step "Setting up Raspberry Pi Imager"
    echo ""
    
    if ! check_rpi_imager; then
        return 1
    fi
    
    local dist_dir="${PROJECT_DIR}/dist"
    local metadata_file="${dist_dir}/local-images.json"
    
    # Check if we have built images
    if [[ ! -f "$metadata_file" ]]; then
        log_warn "No SoulBox images found"
        echo ""
        echo "BUILD SOULBOX IMAGE FIRST:"
        echo "1. On Linux system, run:"
        log_cmd "$0 build"
        echo ""
        echo "2. Or download pre-built image"
        echo ""
        return 1
    fi
    
    log_info "SoulBox images found at: $dist_dir"
    
    echo ""
    echo "=== Raspberry Pi Imager Setup ==="
    echo ""
    echo "1. OPEN RASPBERRY PI IMAGER"
    if check_macos; then
        echo "   - Open /Applications/Raspberry Pi Imager.app"
    else
        echo "   - Run: rpi-imager"
    fi
    echo ""
    echo "2. ADD CUSTOM REPOSITORY (Option A):"
    echo "   - Click gear icon (⚙️) in top-right"
    echo "   - Go to 'Options' tab"
    echo "   - Enable 'Set custom repository'"
    echo "   - Enter URL: file://$metadata_file"
    echo "   - Click 'Save'"
    echo "   - SoulBox should appear in OS list"
    echo ""
    echo "3. OR USE CUSTOM IMAGE (Option B):"
    echo "   - Click 'Use custom image'"
    echo "   - Select: $(find "$dist_dir" -name "soulbox-*.img" -o -name "soulbox-*.img.xz" | head -1)"
    echo ""
    
    log_info "Raspberry Pi Imager setup instructions displayed"
}

# Interactive flashing guide
flash_guide() {
    log_step "SoulBox Flashing Guide"
    echo ""
    
    if ! check_rpi_imager; then
        return 1
    fi
    
    echo "=== PREPARATION ==="
    echo ""
    echo "1. INSERT SD CARD (32GB+ recommended)"
    echo "2. BACKUP any important data on SD card"
    echo "3. Have Tailscale configuration ready (optional)"
    echo ""
    
    echo "=== FLASHING PROCESS ==="
    echo ""
    echo "1. OPEN RASPBERRY PI IMAGER"
    if check_macos; then
        log_cmd "open '/Applications/Raspberry Pi Imager.app'"
    else
        log_cmd "rpi-imager"
    fi
    echo ""
    
    echo "2. SELECT SOULBOX IMAGE:"
    echo "   - If you set up custom repository: Select 'SoulBox Media Center'"
    echo "   - Otherwise: Click 'Use custom image' and browse to .img file"
    echo ""
    
    echo "3. SELECT SD CARD:"
    echo "   - Click 'Choose storage'"
    echo "   - Select your SD card (be careful!)"
    echo ""
    
    echo "4. CONFIGURE ADVANCED OPTIONS (⚙️):"
    echo "   - Enable SSH (with password or key)"
    echo "   - Set username: pi"  
    echo "   - Configure WiFi credentials"
    echo "   - Set locale/timezone"
    echo ""
    
    echo "5. WRITE IMAGE:"
    echo "   - Click 'Write'"
    echo "   - Confirm and wait for completion"
    echo ""
    
    echo "=== POST-FLASH CONFIGURATION ==="
    echo ""
    echo "6. ADD TAILSCALE CONFIG (Optional):"
    echo "   - SD card will be remounted as 'bootfs'"
    if check_macos; then
        echo "   - Copy files to /Volumes/bootfs/"
    else
        echo "   - Copy files to mounted boot partition"
    fi
    echo "   - Files to copy:"
    for file in tailscale-authkey.txt soulbox-config.txt; do
        if [[ -f "${PROJECT_DIR}/$file" ]]; then
            echo "     ✓ $file"
        else
            echo "     - $file (not generated)"
        fi
    done
    echo ""
    
    echo "7. SAFELY EJECT SD CARD:"
    if check_macos; then
        log_cmd "diskutil eject /Volumes/bootfs"
    else
        echo "   - Use system eject function"
    fi
    echo ""
    
    echo "=== FIRST BOOT ==="
    echo ""
    echo "8. INSERT SD CARD in Raspberry Pi 5"
    echo "9. CONNECT HDMI, power on"
    echo "10. WAIT for boot and Kodi startup (2-3 minutes)"
    echo "11. TAILSCALE will configure automatically if auth key provided"
    echo ""
    
    echo "=== ACCESS YOUR SOULBOX ==="
    echo ""
    echo "SSH Access:"
    echo "  - Find Pi IP: nmap -sn 192.168.1.0/24"
    echo "  - SSH: ssh reaper@<IP-ADDRESS>"
    echo "  - Or via Tailscale: ssh reaper@<HOSTNAME>.ts.net"
    echo ""
    echo "Kodi Access:"
    echo "  - Direct HDMI output"
    echo "  - Web interface: http://<IP>:8080 (if enabled in Kodi)"
    echo ""
}

# Complete deployment workflow
deploy_workflow() {
    log_step "Complete SoulBox Deployment Workflow"
    echo ""
    
    local steps=(
        "configure:Generate Tailscale configuration"
        "setup:Setup Raspberry Pi Imager"
        "flash:Flash SD card with SoulBox"
    )
    
    for step_info in "${steps[@]}"; do
        local step_cmd=${step_info%%:*}
        local step_desc=${step_info#*:}
        
        echo "===================================================="
        log_step "$step_desc"
        echo "===================================================="
        echo ""
        
        case $step_cmd in
            configure)
                configure_tailscale
                ;;
            setup)
                setup_rpi_imager
                ;;
            flash)
                flash_guide
                ;;
        esac
        
        if [[ "$step_cmd" != "flash" ]]; then
            echo ""
            read -p "Press Enter to continue to next step..."
            echo ""
        fi
    done
    
    echo "===================================================="
    log_step "Deployment Workflow Complete!"
    echo "===================================================="
    echo ""
    echo "Your SoulBox SD card is ready!"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Insert SD card into Raspberry Pi 5"
    echo "2. Power on and wait for Kodi to start"
    echo "3. Configure your media sources"
    echo "4. Enjoy your SoulBox media center!"
    echo ""
}

# Main execution
main() {
    case "${1:-help}" in
        build)
            build_image
            ;;
        configure)
            configure_tailscale
            ;;
        setup)
            setup_rpi_imager
            ;;
        flash)
            flash_guide
            ;;
        deploy)
            deploy_workflow
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
