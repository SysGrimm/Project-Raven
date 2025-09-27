#!/bin/bash

# Project Raven - Boot Splash Configuration
# Sets up custom Project Raven splash screen during boot

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
PLYMOUTH_THEME_DIR="/usr/share/plymouth/themes/project-raven"

# Function to install Plymouth
install_plymouth() {
    log "Installing Plymouth boot splash system"
    
    apt-get update
    apt-get install -y plymouth plymouth-themes imagemagick
    
    success "Plymouth installed"
}

# Function to create Project Raven Plymouth theme
create_plymouth_theme() {
    log "Creating Project Raven Plymouth theme"
    
    # Create theme directory
    mkdir -p "$PLYMOUTH_THEME_DIR"
    
    # Mandatory logo check for Project Raven
    if [[ ! -f "$LOGO_FILE" ]]; then
        error "CRITICAL: Project Raven logo not found at $LOGO_FILE"
        error "Boot splash logo is mandatory for Project Raven systems"
        exit 1
    fi
    
    log "[SUCCESS] Project Raven logo found: $LOGO_FILE"
    
    # Copy and optimize logo for boot splash
    cp "$LOGO_FILE" "$PLYMOUTH_THEME_DIR/logo.png"
    
    # Create different sizes for better display
    convert "$LOGO_FILE" -resize 200x200 "$PLYMOUTH_THEME_DIR/logo-200.png" 2>/dev/null || true
    convert "$LOGO_FILE" -resize 128x128 "$PLYMOUTH_THEME_DIR/logo-128.png" 2>/dev/null || true
    convert "$LOGO_FILE" -resize 64x64 "$PLYMOUTH_THEME_DIR/logo-64.png" 2>/dev/null || true
    
    # Create Plymouth theme configuration
    cat > "$PLYMOUTH_THEME_DIR/project-raven.plymouth" << 'EOF'
[Plymouth Theme]
Name=Project Raven
Description=Project Raven Boot Splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/project-raven
ScriptFile=/usr/share/plymouth/themes/project-raven/project-raven.script
EOF

    # Create the Plymouth script for animation and display
    cat > "$PLYMOUTH_THEME_DIR/project-raven.script" << 'EOF'
# Project Raven Plymouth Boot Splash Script

# Set up the background
Window.SetBackgroundTopColor(0.0, 0.0, 0.0);     # Black
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);   # Black

# Try to load logo images (fallback if not available)
if (Plymouth.GetMode() == "boot") {
    # Try different logo sizes
    logo_200 = Image("logo-200.png");
    logo_128 = Image("logo-128.png");
    logo_64 = Image("logo-64.png");
    logo_original = Image("logo.png");
    
    # Use the best available logo
    if (logo_200) {
        logo = logo_200;
    } else if (logo_128) {
        logo = logo_128;
    } else if (logo_64) {
        logo = logo_64;
    } else if (logo_original) {
        logo = logo_original;
    } else {
        # Fallback: create text-based logo
        logo = Image.Text("PROJECT RAVEN", 1.0, 1.0, 1.0, 1.0, "Ubuntu 24");
    }
    
    # Position logo in center
    logo_sprite = Sprite(logo);
    logo_sprite.SetX(Window.GetWidth() / 2 - logo.GetWidth() / 2);
    logo_sprite.SetY(Window.GetHeight() / 2 - logo.GetHeight() / 2 - 50);
}

# Add loading text
status_text = Image.Text("Starting Project Raven...", 0.8, 0.8, 0.8, 1.0, "Ubuntu 16");
status_sprite = Sprite(status_text);
status_sprite.SetPosition(Window.GetWidth() / 2 - status_text.GetWidth() / 2, 
                         Window.GetHeight() / 2 + 100, 1);

# Add progress indicator (spinning dots)
progress_text = Image.Text("", 0.6, 0.6, 0.6, 1.0, "Ubuntu 14");
progress_sprite = Sprite(progress_text);
progress_sprite.SetPosition(Window.GetWidth() / 2 - 50, Window.GetHeight() / 2 + 130, 1);

# Animation counter
frame = 0;

# Progress animation function
fun refresh_callback() {
    frame++;
    
    # Animate progress dots
    if (frame % 60 < 15) {
        progress_text = Image.Text("●○○", 0.6, 0.6, 0.6, 1.0, "Ubuntu 14");
    } else if (frame % 60 < 30) {
        progress_text = Image.Text("○●○", 0.6, 0.6, 0.6, 1.0, "Ubuntu 14");
    } else if (frame % 60 < 45) {
        progress_text = Image.Text("○○●", 0.6, 0.6, 0.6, 1.0, "Ubuntu 14");
    } else {
        progress_text = Image.Text("○○○", 0.3, 0.3, 0.3, 1.0, "Ubuntu 14");
    }
    
    progress_sprite.SetImage(progress_text);
    progress_sprite.SetX(Window.GetWidth() / 2 - progress_text.GetWidth() / 2);
}

Plymouth.SetRefreshFunction(refresh_callback);

# Update status messages
fun display_message_callback(text) {
    status_text = Image.Text(text, 0.8, 0.8, 0.8, 1.0, "Ubuntu 16");
    status_sprite.SetImage(status_text);
    status_sprite.SetX(Window.GetWidth() / 2 - status_text.GetWidth() / 2);
}

Plymouth.SetDisplayMessageFunction(display_message_callback);

# Handle boot progress
fun boot_progress_callback(duration, progress) {
    if (progress < 0.5) {
        display_message_callback("Loading system components...");
    } else if (progress < 0.8) {
        display_message_callback("Configuring media center...");
    } else {
        display_message_callback("Almost ready...");
    }
}

Plymouth.SetBootProgressFunction(boot_progress_callback);

# Handle shutdown
if (Plymouth.GetMode() == "shutdown") {
    status_text = Image.Text("Shutting down Project Raven...", 0.8, 0.8, 0.8, 1.0, "Ubuntu 16");
    status_sprite.SetImage(status_text);
    status_sprite.SetX(Window.GetWidth() / 2 - status_text.GetWidth() / 2);
}
EOF

    success "Plymouth theme created"
}

# Function to configure boot parameters
configure_boot_splash() {
    log "Configuring boot parameters for splash screen"
    
    local config_file="/boot/firmware/config.txt"
    local cmdline_file="/boot/firmware/cmdline.txt"
    
    # Update config.txt for better splash screen support
    if [[ -f "$config_file" ]]; then
        # Remove existing splash configurations
        sed -i '/^disable_splash=/d' "$config_file"
        sed -i '/^boot_delay=/d' "$config_file"
        
        # Add splash screen configuration
        cat >> "$config_file" << 'EOF'

# Project Raven Boot Splash Configuration
disable_splash=0
boot_delay=0
EOF
        success "Updated $config_file"
    else
        warn "$config_file not found, splash screen may not work optimally"
    fi
    
    # Update cmdline.txt for silent boot with splash
    if [[ -f "$cmdline_file" ]]; then
        # Backup original cmdline.txt
        cp "$cmdline_file" "${cmdline_file}.backup"
        
        # Remove verbose boot messages and add splash
        sed -i 's/console=tty1/console=tty3/g' "$cmdline_file"
        
        # Add quiet boot parameters if not present
        if ! grep -q "quiet" "$cmdline_file"; then
            sed -i 's/$/ quiet/' "$cmdline_file"
        fi
        if ! grep -q "splash" "$cmdline_file"; then
            sed -i 's/$/ splash/' "$cmdline_file"
        fi
        if ! grep -q "plymouth.ignore-serial-consoles" "$cmdline_file"; then
            sed -i 's/$/ plymouth.ignore-serial-consoles/' "$cmdline_file"
        fi
        
        success "Updated $cmdline_file"
    else
        warn "$cmdline_file not found"
    fi
}

# Function to enable Plymouth theme
enable_plymouth_theme() {
    log "Enabling Project Raven Plymouth theme"
    
    # Set the theme
    plymouth-set-default-theme project-raven
    
    # Update initramfs
    update-initramfs -u
    
    success "Plymouth theme enabled"
}

# Function to create systemd service for post-boot cleanup
create_cleanup_service() {
    log "Creating boot splash cleanup service"
    
    cat > /etc/systemd/system/project-raven-splash-cleanup.service << 'EOF'
[Unit]
Description=Project Raven Boot Splash Cleanup
After=multi-user.target
Before=kodi.service

[Service]
Type=oneshot
ExecStart=/usr/bin/plymouth quit --retain-splash
ExecStartPost=/bin/sleep 2
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable project-raven-splash-cleanup.service
    
    success "Cleanup service created"
}

# Function to test Plymouth theme
test_plymouth_theme() {
    log "Testing Plymouth theme (5 second preview)"
    
    if command -v plymouth >/dev/null 2>&1; then
        plymouth --show-splash &
        sleep 5
        plymouth --quit
        success "Plymouth theme test completed"
    else
        warn "Plymouth not available for testing"
    fi
}

# Main function
main() {
    log "[THEME] Setting up Project Raven boot splash screen"
    echo "============================================="
    
    # Mandatory logo check for Project Raven
    if [[ ! -f "$LOGO_FILE" ]]; then
        error "CRITICAL: Project Raven logo not found at $LOGO_FILE"
        error "Boot splash logo is mandatory for Project Raven systems"
        exit 1
    fi
    
    log "[SUCCESS] Project Raven logo found at: $LOGO_FILE"
    
    install_plymouth
    create_plymouth_theme
    configure_boot_splash
    enable_plymouth_theme
    create_cleanup_service
    
    success "[THEME] Boot splash configured with MANDATORY Project Raven logo!"
    echo "============================================="
    echo "[INFO]  Configuration complete:"
    echo "   [LOGO]  Plymouth theme: project-raven (MANDATORY logo)"
    echo "   [FOLDER] Theme location: $PLYMOUTH_THEME_DIR"
    echo "   [LAUNCH] Boot will show Project Raven splash"
    echo "   [UPDATE] Reboot to see the new splash screen"
    echo ""
    echo "[INFO] To test the splash screen now:"
    echo "   sudo plymouth --show-splash"
    echo "   (wait 5 seconds)"
    echo "   sudo plymouth --quit"
}

# Show help
show_help() {
    cat << EOF
Project Raven Boot Splash Configuration

Usage: $0 [OPTION]

Options:
    --test          Test the Plymouth theme without full installation
    --help          Show this help message

Examples:
    sudo $0                 # Full installation and configuration
    sudo $0 --test          # Test theme only
    $0 --help              # Show help

This script configures a custom Plymouth boot splash screen for Project Raven.
It will display the Project Raven logo during boot with animated loading text.

Requirements:
    - Must be run as root
    - Logo file should be at: $CONFIG_DIR/logo.png
    - Raspberry Pi OS with systemd boot

EOF
}

# Parse command line arguments
case "${1:-}" in
    --test)
        test_plymouth_theme
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
