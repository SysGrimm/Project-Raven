#!/bin/bash
set -e

# Raspberry Pi OS Image Customization Script
# This script customizes a Pi OS image with Kodi and Tailscale

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_FILE="$1"
VERSION_DATE="$2"

if [ -z "$IMAGE_FILE" ] || [ -z "$VERSION_DATE" ]; then
    echo "Usage: $0 <image_file> <version_date>"
    exit 1
fi

echo "Customizing $IMAGE_FILE with version date $VERSION_DATE"

# Create working directory
WORK_DIR="/tmp/raven-customize-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Copy image to working directory
cp "$IMAGE_FILE" ./image.img

# Create loop device
sudo losetup -P /dev/loop0 ./image.img

# Wait for partitions
sleep 2
sudo partprobe /dev/loop0

# Mount partitions
mkdir -p boot rootfs
sudo mount /dev/loop0p1 boot
sudo mount /dev/loop0p2 rootfs

echo "Customizing boot partition..."

# Enable SSH
sudo touch boot/ssh

# Configure boot settings for Kodi
sudo tee -a boot/config.txt << 'EOF'

# Raven Pi customizations for Kodi
dtparam=audio=on
gpu_mem=128
dtoverlay=vc4-kms-v3d

# Disable rainbow splash
disable_splash=1

# Overclock for better performance (optional)
#arm_freq=2000
#over_voltage=2
EOF

echo "Creating installation scripts..."

# Create the main installation script
sudo tee boot/raven-install.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting Raven Pi installation..."

# Update package lists
apt-get update

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable tailscaled

# Install Kodi and dependencies
echo "Installing Kodi..."
apt-get install -y \
    kodi \
    kodi-standalone \
    xserver-xorg \
    xinit \
    alsa-utils \
    pulseaudio \
    avahi-daemon

# Create kodi user
echo "Setting up Kodi user..."
useradd -m -G audio,video,input,dialout,plugdev,tty,users kodi || true
usermod -a -G audio,video,input,dialout,plugdev,tty,users kodi

# Set up Kodi directories
mkdir -p /home/kodi/.kodi
chown -R kodi:kodi /home/kodi

# Configure automatic login for kodi user
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTO_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin kodi --noclear %I $TERM
AUTO_EOF

# Create Kodi systemd service
cat > /etc/systemd/system/kodi.service << 'KODI_EOF'
[Unit]
Description=Kodi Media Center
After=graphical-session.target network-online.target
Wants=graphical-session.target network-online.target

[Service]
Type=simple
User=kodi
Group=kodi
Environment=HOME=/home/kodi
Environment=XDG_RUNTIME_DIR=/run/user/1001
ExecStartPre=/bin/mkdir -p /run/user/1001
ExecStartPre=/bin/chown kodi:kodi /run/user/1001
ExecStart=/usr/bin/kodi-standalone
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
KODI_EOF

# Disable display manager (we want Kodi to run directly)
systemctl disable lightdm 2>/dev/null || true
systemctl disable gdm3 2>/dev/null || true

# Enable Kodi service
systemctl enable kodi

# Create helpful scripts for the user
cat > /home/kodi/setup-tailscale.sh << 'TS_EOF'
#!/bin/bash
echo "=========================================="
echo "Setting up Tailscale on your Raven Pi"
echo "=========================================="
echo ""
echo "Run the following command:"
echo "  sudo tailscale up"
echo ""
echo "Then follow the authentication URL that appears."
echo "After authentication, you can access this Pi"
echo "securely from anywhere on your Tailscale network!"
echo ""
TS_EOF

chmod +x /home/kodi/setup-tailscale.sh
chown kodi:kodi /home/kodi/setup-tailscale.sh

# Create network info script
cat > /home/kodi/network-info.sh << 'NET_EOF'
#!/bin/bash
echo "=========================================="
echo "Raven Pi Network Information"
echo "=========================================="
echo ""
echo "Local IP addresses:"
hostname -I
echo ""
echo "Tailscale status:"
sudo tailscale status 2>/dev/null || echo "Tailscale not configured yet. Run: sudo tailscale up"
echo ""
echo "To access Kodi remotely:"
echo "- Web interface: http://$(hostname -I | cut -d' ' -f1):8080"
echo "- SSH: ssh kodi@$(hostname -I | cut -d' ' -f1)"
echo ""
NET_EOF

chmod +x /home/kodi/network-info.sh
chown kodi:kodi /home/kodi/network-info.sh

# Update system message
cat > /etc/motd << 'MOTD_EOF'

██████╗  █████╗ ██╗   ██╗███████╗███╗   ██╗    ██████╗ ██╗
██╔══██╗██╔══██╗██║   ██║██╔════╝████╗  ██║    ██╔══██╗██║
██████╔╝███████║██║   ██║█████╗  ██╔██╗ ██║    ██████╔╝██║
██╔══██╗██╔══██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║    ██╔═══╝ ██║
██║  ██║██║  ██║ ╚████╔╝ ███████╗██║ ╚████║    ██║     ██║
╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝    ╚═╝     ╚═╝

Raspberry Pi OS with Kodi & Tailscale
Ready-to-use media center with secure remote access

Quick Commands:
  ~/setup-tailscale.sh    - Set up Tailscale VPN
  ~/network-info.sh       - Show network information
  sudo systemctl status kodi - Check Kodi status

Default user: kodi
Kodi web interface: http://your-ip:8080

MOTD_EOF

# Enable useful services
systemctl enable avahi-daemon
systemctl enable ssh

# Clean up package cache
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Raven Pi installation completed successfully!"

# Remove installation files
rm -f /boot/raven-install.sh
rm -f /etc/systemd/system/raven-firstboot.service

# Schedule reboot to start services
shutdown -r +1 "Raven Pi setup complete. Rebooting in 1 minute..."
EOF

chmod +x boot/raven-install.sh

# Create systemd service to run installation on first boot
sudo tee rootfs/etc/systemd/system/raven-firstboot.service << 'EOF'
[Unit]
Description=Raven Pi First Boot Setup
After=network-online.target
Wants=network-online.target
ConditionPathExists=/boot/raven-install.sh

[Service]
Type=oneshot
ExecStart=/boot/raven-install.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the firstboot service
sudo chroot rootfs systemctl enable raven-firstboot.service

echo "Image customization complete!"

# Unmount and cleanup
sudo umount boot rootfs || true
sudo losetup -d /dev/loop0 || true

# Move customized image back
mv ./image.img "$IMAGE_FILE"

# Cleanup
rm -rf "$WORK_DIR"

echo "Customized image ready: $IMAGE_FILE"
