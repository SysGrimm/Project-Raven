#!/bin/bash

# Post-Build Customization Script
# Runs after LibreELEC image is built to add final customizations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$CUSTOM_DIR/LibreELEC.tv"

echo "🎨 Starting post-build customizations..."

# Find the built image
IMAGE_FILE=$(find "$BUILD_DIR/target" -name "*.img.gz" | head -1)
if [ -z "$IMAGE_FILE" ]; then
    echo "❌ No built image found!"
    exit 1
fi

echo "📀 Found image: $IMAGE_FILE"

# Extract image for modification
WORK_DIR="/tmp/libreelec-custom-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "📂 Extracting image..."
gunzip -c "$IMAGE_FILE" > image.img

# Mount the image partitions
LOOP_DEV=$(sudo losetup -f --show image.img)
sudo partprobe "$LOOP_DEV"

# Mount the system partition (usually partition 2)
mkdir -p system
sudo mount "${LOOP_DEV}p2" system

# Mount the boot partition (usually partition 1)  
mkdir -p boot
sudo mount "${LOOP_DEV}p1" boot

# Mount the storage partition (usually partition 2 if it exists)  
mkdir -p storage
if [ -e "${LOOP_DEV}p2" ]; then
    sudo mount "${LOOP_DEV}p2" storage 2>/dev/null || {
        # If p2 doesn't exist or fails, try mounting p1 as storage
        sudo mount "${LOOP_DEV}p1" storage
    }
else
    # Only one partition, use boot as storage
    ln -s boot storage
fi

echo "🔧 Applying customizations..."

# 0. Apply custom boot configuration for Pi 5
if [ -f "$CUSTOM_DIR/customizations/config.txt" ]; then
    echo "⚙️ Applying Pi 5 boot configuration..."
    # Backup original config.txt
    sudo cp boot/config.txt boot/config.txt.backup 2>/dev/null || true
    # Apply our custom config.txt
    sudo cp "$CUSTOM_DIR/customizations/config.txt" boot/config.txt
fi

# Apply custom cmdline.txt for Pi 5
if [ -f "$CUSTOM_DIR/customizations/cmdline.txt" ]; then
    echo "⚙️ Applying Pi 5 kernel command line..."
    # Backup original cmdline.txt
    sudo cp boot/cmdline.txt boot/cmdline.txt.backup 2>/dev/null || true
    # Apply our custom cmdline.txt
    sudo cp "$CUSTOM_DIR/customizations/cmdline.txt" boot/cmdline.txt
fi

# 1. Install custom Kodi skin/theme
if [ -d "$CUSTOM_DIR/customizations/themes" ]; then
    echo "🎨 Installing custom themes..."
    sudo cp -r "$CUSTOM_DIR/customizations/themes"/* system/usr/share/kodi/addons/ 2>/dev/null || true
fi

# 2. Pre-configure Kodi settings
if [ -f "$CUSTOM_DIR/customizations/settings/guisettings.xml" ]; then
    echo "⚙️ Installing Kodi settings..."
    sudo mkdir -p storage/.kodi/userdata
    sudo cp "$CUSTOM_DIR/customizations/settings/guisettings.xml" storage/.kodi/userdata/
fi

# 3. Install additional add-ons
if [ -d "$CUSTOM_DIR/customizations/addons" ]; then
    echo "📦 Installing additional add-ons..."
    sudo mkdir -p storage/.kodi/addons
    sudo cp -r "$CUSTOM_DIR/customizations/addons"/* storage/.kodi/addons/ 2>/dev/null || true
fi

# 4. Configure Tailscale auto-start
echo "🔐 Configuring Tailscale..."
sudo mkdir -p storage/.kodi/userdata/addon_data/service.tailscale
cat << 'EOF' | sudo tee storage/.kodi/userdata/addon_data/service.tailscale/settings.xml > /dev/null
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<settings version="2">
    <setting id="auto_login" value="true" />
    <setting id="hostname" value="LibreELEC-Raven" />
    <setting id="accept_routes" value="true" />
    <setting id="accept_dns" value="true" />
</settings>
EOF

# 5. Enable SSH by default
echo "🔑 Enabling SSH..."
sudo touch storage/.cache/services/sshd.conf

# 6. Set custom hostname
echo "🏷️ Setting custom hostname..."
echo "LibreELEC-Raven" | sudo tee system/etc/hostname > /dev/null

# 7. Create welcome message
cat << 'EOF' | sudo tee storage/.kodi/userdata/addon_data/service.tailscale/welcome.txt > /dev/null
🚀 Welcome to LibreELEC Project Raven!

This custom build includes:
✅ Tailscale VPN (pre-configured)
✅ Optimized Kodi settings
✅ Popular streaming add-ons
✅ Custom theme/skin
✅ CEC support enabled

First time setup:
1. Connect to your network
2. Tailscale will auto-authenticate
3. Access via: http://tailscale-ip:8080
4. SSH via: ssh root@tailscale-ip

Build: Project Raven v1.0
EOF

echo "💾 Finalizing image..."

# Unmount and cleanup
sudo umount boot 2>/dev/null || true
sudo umount storage 2>/dev/null || true
sudo losetup -d "$LOOP_DEV"

# Compress the modified image
gzip image.img
FINAL_IMAGE="$CUSTOM_DIR/LibreELEC-Project-Raven-$(date +%Y%m%d).img.gz"
mv image.img.gz "$FINAL_IMAGE"

# Cleanup
cd /
rm -rf "$WORK_DIR"

echo "✅ Custom image ready!"
echo "📀 Location: $FINAL_IMAGE"
echo ""
echo "🔥 Flash to SD card with:"
echo "   dd if='$FINAL_IMAGE' of=/dev/sdX bs=4M status=progress"
echo "   or use Raspberry Pi Imager"
