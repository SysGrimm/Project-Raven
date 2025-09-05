#!/bin/bash

# Project Raven - CEC Troubleshooting Script
# Diagnoses and fixes common CEC issues on Raspberry Pi

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Check CEC devices
check_cec_devices() {
    log "Checking CEC devices..."
    
    if [[ -c /dev/cec0 ]]; then
        success "CEC device /dev/cec0 found"
        ls -la /dev/cec*
    else
        error "CEC device /dev/cec0 not found"
        return 1
    fi
}

# Check CEC kernel module
check_cec_module() {
    log "Checking CEC kernel module..."
    
    if lsmod | grep -q cec; then
        success "CEC kernel module loaded"
        lsmod | grep cec
    else
        error "CEC kernel module not loaded"
        return 1
    fi
}

# Check boot configuration
check_boot_config() {
    log "Checking boot configuration..."
    
    if grep -q "hdmi_cec_enable=1" /boot/firmware/config.txt; then
        success "CEC enabled in boot config"
    else
        warning "CEC not enabled in boot config"
        echo "Adding CEC configuration to /boot/firmware/config.txt"
        sudo tee -a /boot/firmware/config.txt << 'EOF'

# CEC Configuration for Kodi
hdmi_cec_enable=1
cec_osd_name=RavenBox
EOF
        warning "Reboot required for changes to take effect"
    fi
    
    if grep -q "hdmi_ignore_cec_init=1" /boot/firmware/config.txt; then
        error "CEC init is being ignored - this prevents CEC from working"
        echo "Removing hdmi_ignore_cec_init=1 from config.txt..."
        sudo sed -i '/hdmi_ignore_cec_init=1/d' /boot/firmware/config.txt
        warning "Reboot required for changes to take effect"
    fi
    
    # Show current CEC-related config
    echo "Current CEC configuration:"
    grep -i cec /boot/firmware/config.txt || echo "No CEC configuration found"
}

# Check user permissions
check_permissions() {
    log "Checking user permissions..."
    
    if groups | grep -q video; then
        success "User $(whoami) is in video group"
    else
        warning "User $(whoami) not in video group"
        echo "Adding user to video group..."
        sudo usermod -a -G video $(whoami)
        warning "Please log out and log back in for group changes to take effect"
    fi
}

# Check for processes using CEC
check_cec_usage() {
    log "Checking for processes using CEC devices..."
    
    if command -v lsof >/dev/null 2>&1; then
        local cec_users
        cec_users=$(lsof /dev/cec* 2>/dev/null || true)
        if [[ -n "$cec_users" ]]; then
            warning "Processes using CEC devices:"
            echo "$cec_users"
        else
            success "No processes currently using CEC devices"
        fi
    else
        warning "lsof not available, cannot check CEC device usage"
    fi
}

# Test CEC client
test_cec_client() {
    log "Testing CEC client..."
    
    if ! command -v cec-client >/dev/null 2>&1; then
        error "cec-client not installed"
        echo "Installing CEC utilities..."
        sudo apt update && sudo apt install -y cec-utils
    fi
    
    # Stop Kodi temporarily for testing
    if pgrep -f kodi >/dev/null; then
        warning "Stopping Kodi temporarily for CEC testing..."
        sudo pkill -f kodi
        sleep 2
    fi
    
    echo "Testing CEC connection (timeout 10 seconds)..."
    if timeout 10 bash -c 'echo "scan" | cec-client -s -d 1' 2>&1 | grep -q "opening a connection"; then
        if timeout 10 bash -c 'echo "scan" | cec-client -s -d 1' 2>&1 | grep -q "ERROR"; then
            error "CEC client connection failed"
            echo "Common causes:"
            echo "1. CEC not enabled in boot config"
            echo "2. Device permissions (user not in video group)"
            echo "3. Another process using CEC device"
            echo "4. Hardware/cable issue"
            return 1
        else
            success "CEC client connection successful"
        fi
    else
        error "CEC client failed to start"
        return 1
    fi
}

# Check Kodi CEC settings
check_kodi_settings() {
    log "Checking Kodi CEC settings..."
    
    local settings_file="$HOME/.kodi/userdata/guisettings.xml"
    if [[ -f "$settings_file" ]]; then
        if grep -q "input.peripherals" "$settings_file"; then
            success "Kodi peripheral support enabled"
        else
            warning "Kodi peripheral support not configured"
            echo "Adding peripheral support to Kodi settings..."
            
            # Create backup
            cp "$settings_file" "${settings_file}.backup"
            
            # Add peripheral support
            if grep -q "input\.enablejoystick" "$settings_file"; then
                sed -i '/input\.enablejoystick/a\    <setting id="input.peripherals" default="true">true</setting>' "$settings_file"
            else
                # Add to end of settings
                sed -i 's|</settings>|    <setting id="input.peripherals" default="true">true</setting>\n</settings>|' "$settings_file"
            fi
            success "Peripheral support added to Kodi settings"
        fi
    else
        warning "Kodi settings file not found - Kodi may not have been run yet"
    fi
}

# Check system logs for CEC errors
check_logs() {
    log "Checking system logs for CEC-related messages..."
    
    echo "Kernel messages:"
    dmesg | grep -i cec || echo "No CEC messages in kernel log"
    
    echo
    echo "Recent journal entries:"
    journalctl --no-pager -n 20 | grep -i cec || echo "No recent CEC messages in journal"
}

# Provide recommendations
provide_recommendations() {
    log "CEC Troubleshooting Recommendations:"
    
    echo
    echo "1. Ensure HDMI cable supports CEC (most modern cables do)"
    echo "2. Enable CEC on your TV (usually in TV settings under HDMI-CEC, Anynet+, Bravia Sync, etc.)"
    echo "3. Connect Pi directly to TV, not through AVR/switch when testing"
    echo "4. Reboot after any configuration changes"
    echo "5. Try different HDMI ports on your TV"
    echo
    echo "TV Brand-specific CEC names:"
    echo "- Samsung: Anynet+"
    echo "- Sony: Bravia Sync"
    echo "- LG: SimpLink"
    echo "- Panasonic: VIERA Link"
    echo "- Sharp: Aquos Link"
    echo
}

# Fix common issues
fix_common_issues() {
    log "Attempting to fix common CEC issues..."
    
    # Ensure user is in video group
    if ! groups | grep -q video; then
        sudo usermod -a -G video $(whoami)
        warning "Added user to video group - logout/login required"
    fi
    
    # Ensure CEC utilities are installed
    if ! command -v cec-client >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y cec-utils python3-cec
        success "Installed CEC utilities"
    fi
    
    # Check and fix boot configuration
    if ! grep -q "hdmi_cec_enable=1" /boot/firmware/config.txt; then
        sudo tee -a /boot/firmware/config.txt << 'EOF'

# CEC Configuration for Kodi
hdmi_cec_enable=1
cec_osd_name=RavenBox
EOF
        warning "Added CEC configuration - reboot required"
    fi
    
    # Remove conflicting settings
    if grep -q "hdmi_ignore_cec_init=1" /boot/firmware/config.txt; then
        sudo sed -i '/hdmi_ignore_cec_init=1/d' /boot/firmware/config.txt
        warning "Removed conflicting CEC setting - reboot required"
    fi
}

# Main diagnostic function
main() {
    echo "Project Raven CEC Troubleshooting Tool"
    echo "======================================"
    
    case "${1:-}" in
        "test")
            test_cec_client
            ;;
        "fix")
            fix_common_issues
            ;;
        "logs")
            check_logs
            ;;
        *)
            check_cec_devices
            check_cec_module
            check_boot_config
            check_permissions
            check_cec_usage
            check_kodi_settings
            test_cec_client
            provide_recommendations
            ;;
    esac
}

# Show usage if no arguments
if [[ $# -eq 0 ]]; then
    echo
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  (no args)  - Run full diagnostic"
    echo "  test       - Test CEC client only"
    echo "  fix        - Attempt to fix common issues"
    echo "  logs       - Show CEC-related log messages"
    echo
fi

# Run main function
main "$@"
