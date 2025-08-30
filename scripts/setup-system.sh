#!/bin/bash
# SoulBox System Setup Script
# Creates reaper user and configures system for Kodi media center
# 
# Usage: sudo ./setup-system.sh
# 
# This script should be run on a fresh Debian installation

set -euo pipefail

# Configuration constants
KODI_USER="reaper"
KODI_UID="1000"
KODI_HOME="/home/${KODI_USER}"
SERVICE_NAME="kodi-standalone"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    apt-get update -qq
    apt-get upgrade -y -qq
    log_info "System packages updated"
}

# Install required packages
install_packages() {
    log_info "Installing required packages..."
    
    # Core packages for Kodi and GPU support
    local packages=(
        "kodi"
        "kodi-inputstream-adaptive"
        "kodi-peripheral-joystick"
        "kodi-pvr-iptvsimple"
        "mesa-va-drivers"
        "mesa-vdpau-drivers"
        "va-driver-all"
        "vdpau-driver-all"
        "firmware-misc-nonfree"
        "libraspberrypi0"
        "raspi-config"
        "alsa-utils"
        "pulseaudio"
        "pulseaudio-utils"
    )
    
    apt-get install -y -qq "${packages[@]}"
    log_info "Required packages installed"
}

# Create reaper user with proper groups
create_user() {
    log_info "Creating ${KODI_USER} user..."
    
    # Create user if doesn't exist
    if ! id "${KODI_USER}" &>/dev/null; then
        useradd -m -u ${KODI_UID} -s /bin/bash -c "Kodi Media Center User" ${KODI_USER}
        log_info "User ${KODI_USER} created"
    else
        log_warn "User ${KODI_USER} already exists"
    fi
    
    # Add user to required groups
    local groups=("video" "audio" "render" "input" "gpio" "i2c" "spi")
    for group in "${groups[@]}"; do
        if getent group ${group} >/dev/null 2>&1; then
            usermod -a -G ${group} ${KODI_USER}
            log_info "Added ${KODI_USER} to ${group} group"
        else
            log_warn "Group ${group} does not exist, skipping"
        fi
    done
    
    # Set up home directory permissions
    chown -R ${KODI_USER}:${KODI_USER} ${KODI_HOME}
    chmod 755 ${KODI_HOME}
}

# Configure GPU and hardware access
configure_gpu() {
    log_info "Configuring GPU access..."
    
    # Ensure GPU device permissions
    if [[ -c /dev/dri/card0 ]]; then
        chgrp video /dev/dri/card0
        chmod 660 /dev/dri/card0
        log_info "GPU device permissions configured"
    else
        log_warn "GPU device /dev/dri/card0 not found"
    fi
    
    # Configure udev rules for persistent GPU access
    cat > /etc/udev/rules.d/99-soulbox-gpu.rules << 'EOF'
# SoulBox GPU access rules
SUBSYSTEM=="drm", GROUP="video", MODE="0660"
SUBSYSTEM=="dri", GROUP="video", MODE="0660"
KERNEL=="card*", GROUP="video", MODE="0660"
KERNEL=="render*", GROUP="render", MODE="0660"
EOF
    
    log_info "GPU udev rules created"
}

# Install systemd service
install_service() {
    log_info "Installing ${SERVICE_NAME} systemd service..."
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    local config_dir=$(dirname $(dirname $(realpath $0)))
    
    if [[ -f "${config_dir}/configs/systemd/${SERVICE_NAME}.service" ]]; then
        cp "${config_dir}/configs/systemd/${SERVICE_NAME}.service" "${service_file}"
        
        # Reload systemd and enable service
        systemctl daemon-reload
        systemctl enable ${SERVICE_NAME}
        
        log_info "Service installed and enabled"
    else
        log_error "Service file not found in configs/systemd/"
        exit 1
    fi
}

# Configure boot settings
configure_boot() {
    log_info "Configuring boot settings..."
    
    local config_file="/boot/firmware/config.txt"
    local config_dir=$(dirname $(dirname $(realpath $0)))
    
    # Backup existing config
    if [[ -f "${config_file}" ]]; then
        cp "${config_file}" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Existing config.txt backed up"
    fi
    
    # Install optimized config
    if [[ -f "${config_dir}/configs/boot/config.txt" ]]; then
        cp "${config_dir}/configs/boot/config.txt" "${config_file}"
        log_info "Optimized config.txt installed"
    else
        log_warn "Optimized config.txt not found, keeping existing configuration"
    fi
}

# Configure audio
configure_audio() {
    log_info "Configuring audio for ${KODI_USER}..."
    
    # Create PulseAudio configuration
    sudo -u ${KODI_USER} mkdir -p ${KODI_HOME}/.config/pulse
    
    cat > ${KODI_HOME}/.config/pulse/client.conf << 'EOF'
# SoulBox PulseAudio client configuration
autospawn = yes
daemon-binary = /usr/bin/pulseaudio
extra-arguments = --log-target=syslog
EOF
    
    chown -R ${KODI_USER}:${KODI_USER} ${KODI_HOME}/.config
    log_info "Audio configuration complete"
}

# Set up automatic login (optional)
setup_autologin() {
    log_info "Configuring console autologin for ${KODI_USER}..."
    
    # Configure getty to auto-login reaper on tty7
    mkdir -p /etc/systemd/system/getty@tty7.service.d
    
    cat > /etc/systemd/system/getty@tty7.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KODI_USER} --noclear %I $TERM
Type=simple
EOF
    
    systemctl daemon-reload
    log_info "Console autologin configured"
}

# Final system configuration
finalize_setup() {
    log_info "Finalizing system setup..."
    
    # Disable unnecessary services for headless operation
    local services_to_disable=(
        "bluetooth"
        "wifi-powersave@wlan0"
        "ModemManager"
        "wpa_supplicant"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled ${service} >/dev/null 2>&1; then
            systemctl disable ${service}
            log_info "Disabled ${service} service"
        fi
    done
    
    # Update initramfs
    update-initramfs -u
    
    log_info "System setup complete"
}

# Verification function
verify_setup() {
    log_info "Verifying system setup..."
    
    # Check user exists and has correct groups
    if id ${KODI_USER} >/dev/null 2>&1; then
        log_info "User ${KODI_USER} exists"
        local user_groups=$(groups ${KODI_USER} | cut -d: -f2)
        log_info "User groups: ${user_groups}"
    else
        log_error "User ${KODI_USER} not found"
        return 1
    fi
    
    # Check service is enabled
    if systemctl is-enabled ${SERVICE_NAME} >/dev/null 2>&1; then
        log_info "Service ${SERVICE_NAME} is enabled"
    else
        log_error "Service ${SERVICE_NAME} is not enabled"
        return 1
    fi
    
    # Check GPU devices
    if [[ -c /dev/dri/card0 ]]; then
        log_info "GPU device /dev/dri/card0 is available"
    else
        log_warn "GPU device /dev/dri/card0 not found - may need reboot"
    fi
    
    log_info "Verification complete"
}

# Main execution
main() {
    log_info "Starting SoulBox system setup..."
    
    check_root
    update_system
    install_packages
    create_user
    configure_gpu
    install_service
    configure_boot
    configure_audio
    setup_autologin
    finalize_setup
    verify_setup
    
    log_info "SoulBox setup completed successfully!"
    log_info "Reboot the system to apply all changes."
    log_info "After reboot, Kodi should start automatically."
}

# Execute main function
main "$@"
