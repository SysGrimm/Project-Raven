#!/bin/bash

# Project Raven Tailscale Installer for Existing LibreELEC
# Quick and easy way to add Tailscale VPN to your LibreELEC installation

set -euo pipefail

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}🚀 Project Raven Tailscale Installer${NC}"
echo "Adding Tailscale VPN to your existing LibreELEC installation..."
echo

# Check if running on LibreELEC
if [ ! -f /etc/libreelec-release ]; then
    error "This script must be run on a LibreELEC system!"
    exit 1
fi

log "Detected LibreELEC system"
cat /etc/libreelec-release
echo

# Detect architecture
ARCH=$(uname -m)
log "Detected architecture: $ARCH"

# Determine Tailscale binary URL
case "$ARCH" in
    "armv7l")
        TAILSCALE_URL="https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_arm.tgz"
        log "Will download 32-bit ARM binary for Pi 2/3"
        ;;
    "aarch64")
        TAILSCALE_URL="https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_arm64.tgz"
        log "Will download 64-bit ARM binary for Pi 4/5"
        ;;
    "x86_64")
        TAILSCALE_URL="https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_amd64.tgz"
        log "Will download x86_64 binary for Intel/AMD"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Create addon directory
ADDON_DIR="/storage/.kodi/addons/service.tailscale"
log "Creating addon directory: $ADDON_DIR"
mkdir -p "$ADDON_DIR"

# Download Project Raven repository
TEMP_DIR="/tmp/project-raven-$$"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

log "Downloading Project Raven source..."
if command -v wget >/dev/null 2>&1; then
    wget -q https://github.com/SysGrimm/Project-Raven/archive/refs/heads/main.zip
elif command -v curl >/dev/null 2>&1; then
    curl -sL https://github.com/SysGrimm/Project-Raven/archive/refs/heads/main.zip -o main.zip
else
    error "Neither wget nor curl is available!"
    exit 1
fi

log "Extracting source files..."
unzip -q main.zip

# Copy addon files
log "Installing Tailscale addon files..."
cp -r Project-Raven-main/libreelec-tailscale-addon/source/* "$ADDON_DIR/"

# Download Tailscale binary
log "Downloading Tailscale binary from: $TAILSCALE_URL"
mkdir -p "$ADDON_DIR/bin"
cd "$ADDON_DIR/bin"

if command -v wget >/dev/null 2>&1; then
    wget -q "$TAILSCALE_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -sL "$TAILSCALE_URL" -o "$(basename "$TAILSCALE_URL")"
fi

log "Extracting Tailscale binary..."
tar -xzf tailscale_*.tgz --strip-components=1
rm tailscale_*.tgz

# Make binaries executable
chmod +x tailscale tailscaled

# Verify installation
if [ -f "$ADDON_DIR/addon.xml" ] && [ -f "$ADDON_DIR/bin/tailscale" ]; then
    success "Tailscale addon installed successfully!"
else
    error "Installation verification failed!"
    exit 1
fi

# Create default settings
SETTINGS_DIR="/storage/.kodi/userdata/addon_data/service.tailscale"
mkdir -p "$SETTINGS_DIR"

if [ ! -f "$SETTINGS_DIR/settings.xml" ]; then
    log "Creating default settings..."
    cat > "$SETTINGS_DIR/settings.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<settings version="2">
    <setting id="auto_login" value="true" />
    <setting id="hostname" value="LibreELEC-Tailscale" />
    <setting id="accept_routes" value="true" />
    <setting id="accept_dns" value="true" />
    <setting id="daemon_port" value="41641" />
    <setting id="enable_ssh_over_tailscale" value="true" />
</settings>
EOF
    success "Default settings created"
fi

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo
success "🎉 Installation complete!"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Restart Kodi: systemctl restart kodi"
echo "2. Go to Kodi → Settings → Add-ons → My add-ons → Services"
echo "3. Find 'Tailscale VPN' and enable it"
echo "4. Follow the authentication prompts"
echo "5. Check your Tailscale admin panel for the new device"
echo
echo -e "${BLUE}Useful commands:${NC}"
echo "• Check status: systemctl status kodi"
echo "• View logs: tail -f /storage/.kodi/temp/kodi.log | grep -i tailscale"
echo "• Manual restart: systemctl restart kodi"
echo
echo -e "${GREEN}Access methods after setup:${NC}"
echo "• SSH via Tailscale: ssh root@100.x.x.x"
echo "• Web interface: http://100.x.x.x:8080"  
echo "• Samba shares: smb://100.x.x.x"
echo
warning "Remember to restart Kodi to activate the addon!"

# Offer to restart Kodi
echo
read -p "Would you like to restart Kodi now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Restarting Kodi..."
    systemctl restart kodi
    success "Kodi restarted! Check Add-ons → Services for Tailscale VPN"
else
    warning "Don't forget to restart Kodi when ready: systemctl restart kodi"
fi
