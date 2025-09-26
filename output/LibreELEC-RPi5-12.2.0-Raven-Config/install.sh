#!/bin/bash
# LibreELEC Raven Configuration Installer

echo "🚀 LibreELEC Raven Configuration Installer"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Detect boot partition
BOOT_PART=""
if [ -d "/flash" ]; then
    BOOT_PART="/flash"
elif [ -d "/boot" ]; then
    BOOT_PART="/boot"
else
    echo "❌ Could not find boot partition"
    exit 1
fi

echo "📁 Boot partition detected: $BOOT_PART"

# Copy boot files
echo "📋 Installing boot configuration..."
cp boot/config.txt "$BOOT_PART/" 2>/dev/null && echo "✅ config.txt installed"
cp boot/cmdline.txt "$BOOT_PART/" 2>/dev/null && echo "✅ cmdline.txt installed"
cp boot/first-boot.sh "$BOOT_PART/" 2>/dev/null && echo "✅ first-boot.sh installed"

# Copy Kodi settings
echo "📋 Installing Kodi settings..."
if [ -d "storage" ]; then
    cp -r storage/* /storage/ 2>/dev/null && echo "✅ Kodi settings installed"
fi

echo "🎉 Installation complete! Reboot to apply changes."
