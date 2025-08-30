#!/bin/bash

set -e
echo "Adding Boot Splash to Existing SoulBox Image"
echo "==========================================="

# Check if image exists
EXISTING_IMAGE="/root/soulbox/soulbox-openelec-20250830_133809.img"
if [ ! -f "$EXISTING_IMAGE" ]; then
    echo "Error: Existing image not found at $EXISTING_IMAGE"
    exit 1
fi

echo "Found existing image: $EXISTING_IMAGE"
echo "Creating splash-enabled version..."

# Create working directory
WORK_DIR="/tmp/add-splash-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Copy existing image
cp "$EXISTING_IMAGE" "soulbox-with-splash.img"

echo "Setting up loop device..."
LOOP_DEV=$(losetup --find --show "soulbox-with-splash.img")

# Cleanup function
cleanup() {
    cd /
    umount "$WORK_DIR/boot" "$WORK_DIR/root" 2>/dev/null || true
    [ ! -z "$LOOP_DEV" ] && losetup -d "$LOOP_DEV" 2>/dev/null || true
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

sleep 2 && partprobe $LOOP_DEV && sleep 2

echo "Mounting partitions..."
mkdir -p boot root
mount ${LOOP_DEV}p1 boot
mount ${LOOP_DEV}p2 root

echo "Adding boot splash components..."

# Copy logo for splash
mkdir -p root/opt/soulbox/assets
cp /root/soulbox/soulbox-logo.png root/opt/soulbox/assets/logo.png

# Install fbi for image display if not present
chroot root /bin/bash << 'INSTALL_FBI'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y fbi
apt-get clean
INSTALL_FBI

# Create splash service
cat > root/etc/systemd/system/soulbox-splash.service << 'SPLASH_SERVICE'
[Unit]
Description=SoulBox Boot Splash Screen
DefaultDependencies=false
After=local-fs.target
Before=kodi-standalone.service

[Service]
Type=forking
User=root
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
ExecStart=/opt/soulbox/show-splash.sh
TimeoutStartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
SPLASH_SERVICE

# Create splash script
cat > root/opt/soulbox/show-splash.sh << 'SPLASH_SCRIPT'
#!/bin/bash

# Clear screen
clear > /dev/tty1 2>&1

# Show themed ASCII art
cat << 'SPLASH_ART' > /dev/tty1 2>&1

     ____              _ ____            
    / ___|  ___  _   _| | __ )  _____  __
    \___ \ / _ \| | | | |  _ \ / _ \ \/ /
     ___) | (_) | |_| | | |_) | (_) >  < 
    |____/ \___/ \__,_|_|____/ \___/_/\_\
    
           🔥 Will-o'-Wisp Media Center 🔥
    
                    Loading...
    
        The blue flame guides your media journey
    
SPLASH_ART

# Try to display logo image
if command -v fbi >/dev/null 2>&1 && [ -f "/opt/soulbox/assets/logo.png" ]; then
    timeout 4 fbi -T 1 -d /dev/fb0 -noverbose -a /opt/soulbox/assets/logo.png >/dev/null 2>&1 || true
fi

# Keep splash visible briefly
sleep 3
SPLASH_SCRIPT

chmod +x root/opt/soulbox/show-splash.sh

# Enable splash service
chroot root systemctl enable soulbox-splash.service

# Update boot config to include splash
if ! grep -q "disable_splash=0" boot/config.txt; then
    echo "" >> boot/config.txt
    echo "# SoulBox Boot Splash" >> boot/config.txt
    echo "disable_splash=0" >> boot/config.txt
fi

# Update cmdline for quiet boot
if ! grep -q "quiet splash" boot/cmdline.txt; then
    sed -i 's/rootwait/rootwait quiet splash/' boot/cmdline.txt
fi

echo "Splash integration complete!"
sync
umount boot root
losetup -d $LOOP_DEV
LOOP_DEV=""

# Create final image with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FINAL_NAME="soulbox-splash-${TIMESTAMP}.img"
FINAL_PATH="/root/soulbox/${FINAL_NAME}"
mv "soulbox-with-splash.img" "$FINAL_PATH"

# Create checksum
sha256sum "$FINAL_PATH" > "${FINAL_PATH}.sha256"

# Copy to downloads
cp "$FINAL_PATH" "/mnt/user/downloads/"
cp "${FINAL_PATH}.sha256" "/mnt/user/downloads/"

trap - EXIT
cleanup

echo ""
echo "SUCCESS! Boot Splash Added to SoulBox Image"
echo "=========================================="
echo ""
echo "New image: $FINAL_PATH"
echo "Size: $(ls -lh $FINAL_PATH | awk '{print $5}')"
echo "Also copied to: /mnt/user/downloads/"
echo ""
echo "Boot Splash Features Added:"
echo "- ASCII art and logo display during boot"
echo "- Themed loading message"
echo "- Quiet boot mode for clean appearance"
echo "- Logo display using framebuffer"
echo ""
echo "🔥 Your SoulBox will now show the blue flame at boot! 🔥"

