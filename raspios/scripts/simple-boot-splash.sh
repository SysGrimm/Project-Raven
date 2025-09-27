#!/bin/bash

# Project Raven - Simple Boot Splash (Framebuffer-based)
# Alternative splash screen implementation using framebuffer

set -euo pipefail

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

warn() {
    echo -e "${YELLOW}[WARNING]  $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (sudo)"
   exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configurations"
LOGO_FILE="$CONFIG_DIR/logo.png"

# Function to install framebuffer tools
install_framebuffer_tools() {
    log "Installing framebuffer display tools"
    
    apt-get update
    apt-get install -y fbi imagemagick
    
    success "Framebuffer tools installed"
}

# Function to create boot splash service
create_splash_service() {
    log "Creating framebuffer boot splash service"
    
    # Create the splash display script
    cat > /usr/local/bin/project-raven-splash.sh << 'EOF'
#!/bin/bash

# Project Raven Framebuffer Splash Display

LOGO_FILE="/usr/local/share/project-raven/logo.png"
SPLASH_TEXT="/usr/local/share/project-raven/splash.txt"

# Create splash text if logo not available
if [[ ! -f "$LOGO_FILE" ]]; then
    mkdir -p "$(dirname "$SPLASH_TEXT")"
    cat > "$SPLASH_TEXT" << 'SPLASH_EOF'




                    ██████╗ ██████╗  ██████╗      ██╗███████╗ ██████╗████████╗    
                    ██╔══██╗██╔══██╗██╔═══██╗     ██║██╔════╝██╔════╝╚══██╔══╝    
                    ██████╔╝██████╔╝██║   ██║     ██║█████╗  ██║        ██║       
                    ██╔═══╝ ██╔══██╗██║   ██║██   ██║██╔══╝  ██║        ██║       
                    ██║     ██║  ██║╚██████╔╝╚█████╔╝███████╗╚██████╗   ██║       
                    ╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚════╝ ╚══════╝ ╚═════╝   ╚═╝       
                                                                                  
                    ██████╗  ██████╗ ██╗   ██╗███████╗███╗   ██╗                  
                    ██╔══██╗██╔═══██╗██║   ██║██╔════╝████╗  ██║                  
                    ██████╔╝██║   ██║██║   ██║█████╗  ██╔██╗ ██║                  
                    ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║                  
                    ██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║ ╚████║                  
                    ╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═══╝                  
                                                                                  
                           [VIDEO] Premium Media Center Experience [VIDEO]                  
                                                                                  
                                      Loading...                                  


SPLASH_EOF
fi

# Clear screen and hide cursor
clear
echo -e "\033[?25l"

# Set console to graphics mode
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null || true

# Display logo or text
if [[ -f "$LOGO_FILE" ]] && command -v fbi >/dev/null 2>&1; then
    # Display logo with fbi
    fbi -T 1 -d /dev/fb0 -noverbose -a "$LOGO_FILE" &
    FBI_PID=$!
    
    # Show loading text below logo
    sleep 1
    echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
    echo -e "\033[1;37m                    [VIDEO] PROJECT RAVEN [VIDEO]\033[0m"
    echo -e "\033[0;36m              Premium Media Center Experience\033[0m"
    echo -e "\n\033[0;33m                      Loading...\033[0m"
    
    # Keep splash for 8 seconds or until kodi starts
    for i in {1..40}; do
        if pgrep -x "kodi" >/dev/null 2>&1; then
            break
        fi
        sleep 0.2
    done
    
    # Clean up
    kill $FBI_PID 2>/dev/null || true
    
elif [[ -f "$SPLASH_TEXT" ]]; then
    # Display text splash
    cat "$SPLASH_TEXT"
    
    # Keep splash for 8 seconds or until kodi starts
    for i in {1..40}; do
        if pgrep -x "kodi" >/dev/null 2>&1; then
            break
        fi
        sleep 0.2
    done
fi

# Restore cursor and clear screen
echo -e "\033[?25h"
clear
EOF

    chmod +x /usr/local/bin/project-raven-splash.sh
    
    # Copy logo if available
    if [[ -f "$LOGO_FILE" ]]; then
        mkdir -p /usr/local/share/project-raven
        cp "$LOGO_FILE" /usr/local/share/project-raven/logo.png
        success "Logo copied to system location"
    fi
    
    # Create systemd service
    cat > /etc/systemd/system/project-raven-splash.service << 'EOF'
[Unit]
Description=Project Raven Boot Splash Screen
After=systemd-user-sessions.service
Before=getty@tty1.service
Before=kodi.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/local/bin/project-raven-splash.sh
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
RemainAfterExit=yes
TimeoutStartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable project-raven-splash.service
    
    success "Framebuffer splash service created"
}

# Function to configure quiet boot
configure_quiet_boot() {
    log "Configuring quiet boot for better splash experience"
    
    local config_file="/boot/firmware/config.txt"
    local cmdline_file="/boot/firmware/cmdline.txt"
    
    # Update config.txt
    if [[ -f "$config_file" ]]; then
        sed -i '/^disable_splash=/d' "$config_file"
        cat >> "$config_file" << 'EOF'

# Simple Boot Splash Configuration
disable_splash=0
EOF
    fi
    
    # Update cmdline.txt for quiet boot
    if [[ -f "$cmdline_file" ]]; then
        cp "$cmdline_file" "${cmdline_file}.backup.simple"
        
        # Make boot quieter
        sed -i 's/console=tty1/console=tty3/g' "$cmdline_file"
        
        if ! grep -q "quiet" "$cmdline_file"; then
            sed -i 's/$/ quiet/' "$cmdline_file"
        fi
        if ! grep -q "loglevel=3" "$cmdline_file"; then
            sed -i 's/$/ loglevel=3/' "$cmdline_file"
        fi
    fi
    
    success "Quiet boot configured"
}

# Main function
main() {
    log "[THEME] Setting up simple Project Raven boot splash"
    echo "=============================================="
    
    # Mandatory logo check for Project Raven
    if [[ ! -f "$LOGO_FILE" ]]; then
        error "CRITICAL: Project Raven logo not found at $LOGO_FILE"
        error "Boot splash logo is mandatory for Project Raven systems"
        exit 1
    fi
    
    log "[SUCCESS] Project Raven logo found: $LOGO_FILE"
    
    install_framebuffer_tools
    create_splash_service
    configure_quiet_boot
    
    success "[THEME] Simple boot splash configured with MANDATORY logo!"
    echo "=============================================="
    echo "[INFO]  Configuration:"
    echo "   [MEDIA] Type: Framebuffer-based splash"
    echo "   [LOGO]  Logo: MANDATORY Project Raven logo"
    echo "   [PERFORMANCE] Service: project-raven-splash.service"
    echo "   [UPDATE] Reboot to see splash screen"
    echo ""
    echo "[INFO] To test:"
    echo "   sudo systemctl start project-raven-splash.service"
}

# Parse arguments
case "${1:-}" in
    --help|-h)
        cat << EOF
Simple Project Raven Boot Splash

Usage: $0

This script creates a simple framebuffer-based boot splash screen
as an alternative to Plymouth. It's lighter weight and more reliable
on Raspberry Pi systems.

Features:
    - Framebuffer image display (if logo available)
    - ASCII art text fallback
    - Automatic cleanup when Kodi starts
    - Quiet boot configuration

Requirements:
    - Must be run as root
    - Logo at: $CONFIG_DIR/logo.png (MANDATORY)

EOF
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
