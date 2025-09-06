#!/bin/bash

# Project Raven - Raspberry Pi Kodi Configuration Script
# Configures a fresh Raspberry Pi OS installation for auto-boot Kodi with CEC support

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Run as the pi user instead."
        exit 1
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    success "System packages updated"
}

# Install Kodi and dependencies
install_kodi() {
    log "Installing Kodi and CEC utilities..."
    sudo apt install -y kodi python3-cec cec-utils
    success "Kodi and CEC utilities installed"
}

# Configure boot configuration for optimal Kodi performance and CEC
configure_boot() {
    log "Configuring boot settings for Kodi..."
    
    # Backup original config
    sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup
    
    # Remove any existing Kodi/CEC configurations
    sudo sed -i '/# GPU memory split for Kodi/,+10d' /boot/firmware/config.txt
    sudo sed -i '/# Enable hardware acceleration/,+5d' /boot/firmware/config.txt
    sudo sed -i '/# CEC Configuration/,+5d' /boot/firmware/config.txt
    
    # Add optimized configuration
    sudo tee -a /boot/firmware/config.txt << 'EOF'

# GPU memory split for Kodi
gpu_mem=128

# Enable hardware acceleration
dtoverlay=vc4-kms-v3d

# CEC Configuration for Kodi
# Enable CEC but control wake behavior
hdmi_cec_enable=1
cec_osd_name=RavenBox
EOF

    success "Boot configuration updated"
}

# Configure auto-login for user
configure_autologin() {
    local username=${1:-$(whoami)}
    log "Configuring auto-login for user: $username"
    
    # Create systemd override directory
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    
    # Configure auto-login
    sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $username --noclear %I \$TERM
EOF

    success "Auto-login configured for $username"
}

# Configure Kodi auto-start in user's bashrc
configure_kodi_autostart() {
    log "Configuring Kodi auto-start..."
    
    # Backup bashrc
    cp ~/.bashrc ~/.bashrc.backup
    
    # Remove any existing Kodi auto-start configuration
    sed -i '/# Auto-start Kodi on TTY1/,+5d' ~/.bashrc
    
    # Add Kodi auto-start configuration
    cat >> ~/.bashrc << 'EOF'

# Auto-start Kodi on TTY1
if [ "$(tty)" = "/dev/tty1" ]; then
    # Start Kodi in fullscreen
    exec kodi --standalone
fi
EOF

    success "Kodi auto-start configured"
}

# Create systemd service for Kodi (backup method)
create_kodi_service() {
    local username=${1:-$(whoami)}
    log "Creating Kodi systemd service..."
    
    sudo tee /etc/systemd/system/kodi.service << EOF
[Unit]
Description=Kodi Media Center
After=multi-user.target network.target graphical.target
Wants=network.target

[Service]
Type=simple
User=$username
Group=$username
ExecStart=/usr/bin/kodi --standalone
ExecStop=/usr/bin/killall kodi
Restart=always
RestartSec=3
Environment=DISPLAY=:0

[Install]
WantedBy=multi-user.target
EOF

    # Enable but don't start the service (bashrc method is primary)
    sudo systemctl daemon-reload
    sudo systemctl enable kodi.service
    
    success "Kodi systemd service created and enabled"
}

# Configure Kodi settings for optimal CEC support
configure_kodi_settings() {
    log "Configuring Kodi settings..."
    
    # Create Kodi directories
    mkdir -p ~/.kodi/userdata
    
    # If guisettings.xml doesn't exist, create minimal one
    if [[ ! -f ~/.kodi/userdata/guisettings.xml ]]; then
        cat > ~/.kodi/userdata/guisettings.xml << 'EOF'
<settings version="2">
    <setting id="input.enablemouse" default="true">true</setting>
    <setting id="input.enablejoystick" default="true">true</setting>
    <setting id="input.peripherals" default="true">true</setting>
</settings>
EOF
    else
        # Add peripheral support if not present
        if ! grep -q "input.peripherals" ~/.kodi/userdata/guisettings.xml; then
            sed -i '/input\.enablejoystick/a\    <setting id="input.peripherals" default="true">true</setting>' ~/.kodi/userdata/guisettings.xml
        fi
    fi
    
    success "Kodi settings configured"
}

# Test CEC functionality (run after reboot)
test_cec() {
    log "Testing CEC functionality..."
    
    # Check if CEC devices exist
    if [[ ! -c /dev/cec0 ]]; then
        error "CEC device /dev/cec0 not found"
        return 1
    fi
    
    # Check permissions
    if ! groups | grep -q video; then
        warning "User not in video group. Adding to video group..."
        sudo usermod -a -G video $(whoami)
        warning "Please log out and log back in for group changes to take effect"
    fi
    
    success "CEC devices found and permissions look correct"
}

# Main installation function
main() {
    log "Starting Project Raven Kodi Configuration..."
    
    check_root
    update_system
    install_kodi
    configure_boot
    configure_autologin
    configure_kodi_autostart
    create_kodi_service
    configure_kodi_settings
    test_cec
    
    success "Configuration complete!"
    echo
    log "Next steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. Connect your TV via HDMI"
    echo "3. Kodi should auto-start and CEC should be functional"
    echo "4. Test CEC with your TV remote"
    echo
    warning "Note: If this is your first run, please reboot before testing CEC functionality"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
