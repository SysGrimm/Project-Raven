#!/bin/bash

# Project Raven - EEPROM Fix Script
# Fixes common Raspberry Pi EEPROM service issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
}

# Function to fix EEPROM service issues
fix_eeprom_service() {
    log "Fixing Raspberry Pi EEPROM service issues..."
    
    # Disable the problematic EEPROM service if it's causing boot issues
    if systemctl is-enabled rpi-eeprom-update >/dev/null 2>&1; then
        warning "Disabling problematic EEPROM update service"
        systemctl disable rpi-eeprom-update || true
        systemctl stop rpi-eeprom-update || true
    fi
    
    # Check if we're on a real Raspberry Pi or virtualized environment
    if [[ -f /proc/cpuinfo ]] && grep -q "Raspberry Pi" /proc/cpuinfo; then
        log "Detected Raspberry Pi hardware, keeping EEPROM functionality"
        
        # Re-enable with proper configuration
        apt-get update -y
        apt-get install -y rpi-eeprom || true
        
        # Configure EEPROM updates to be less aggressive
        if [[ -f /etc/default/rpi-eeprom-update ]]; then
            sed -i 's/FIRMWARE_RELEASE_STATUS="default"/FIRMWARE_RELEASE_STATUS="stable"/' /etc/default/rpi-eeprom-update
        fi
        
        success "EEPROM service configured for stable updates"
    else
        log "Not running on Raspberry Pi hardware, EEPROM service not needed"
        
        # Completely remove EEPROM services in virtual environments
        systemctl mask rpi-eeprom-update || true
        apt-get remove -y rpi-eeprom || true
        
        success "EEPROM services removed for virtual environment"
    fi
}

# Function to fix other common boot service issues
fix_boot_services() {
    log "Fixing common boot service issues..."
    
    # List of services that commonly fail in virtual environments
    local problematic_services=(
        "rpi-eeprom-update"
        "hciuart"
        "bluetooth"
        "ModemManager"
        "wpa_supplicant"
    )
    
    for service in "${problematic_services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            log "Checking service: $service"
            if ! systemctl is-active --quiet "$service"; then
                warning "Service $service is failing, disabling..."
                systemctl disable "$service" || true
                systemctl mask "$service" || true
            fi
        fi
    done
    
    success "Boot services cleaned up"
}

# Function to optimize systemd boot
optimize_systemd() {
    log "Optimizing systemd boot process..."
    
    # Reduce systemd timeout for failed services
    if [[ -f /etc/systemd/system.conf ]]; then
        sed -i 's/#DefaultTimeoutStartSec=90s/DefaultTimeoutStartSec=30s/' /etc/systemd/system.conf
        sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=15s/' /etc/systemd/system.conf
    fi
    
    # Reload systemd configuration
    systemctl daemon-reload
    
    success "Systemd optimized for faster boot"
}

# Function to create a systemd override for problematic services
create_service_overrides() {
    log "Creating service overrides to prevent boot failures..."
    
    # Create override for EEPROM service
    mkdir -p /etc/systemd/system/rpi-eeprom-update.service.d/
    cat > /etc/systemd/system/rpi-eeprom-update.service.d/override.conf << 'EOF'
[Unit]
# Project Raven override - prevent boot failures
Requisite=
After=
ConditionPathExists=/sys/firmware/devicetree/base/model

[Service]
# Fail silently if not on real Pi hardware
ExecStart=
ExecStart=/bin/bash -c 'if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then /usr/bin/rpi-eeprom-update -a; else exit 0; fi'
EOF
    
    success "Service overrides created"
}

# Main function
main() {
    log "[CONFIG] Project Raven - EEPROM and Boot Service Fix"
    echo "=============================================="
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo $0)"
        exit 1
    fi
    
    fix_eeprom_service
    fix_boot_services
    optimize_systemd
    create_service_overrides
    
    log "[COMPLETE] EEPROM and boot service fixes completed!"
    warning "Reboot recommended to apply all changes"
}

# Run main function
main "$@"
