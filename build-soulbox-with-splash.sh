#!/bin/bash

set -e
echo "Building SoulBox with Boot Splash, Logo, OpenELEC-style Kodi and Tailscale"
echo "========================================================================="

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SOULBOX_IMAGE="soulbox-splash-${TIMESTAMP}.img"
WORK_DIR="/tmp/soulbox-splash-${TIMESTAMP}"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo ""
echo "Downloading official Raspberry Pi OS Lite ARM64..."
wget -q https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-11/2023-12-11-raspios-bookworm-arm64-lite.img.xz

echo "Extracting image..."
xz -d 2023-12-11-raspios-bookworm-arm64-lite.img.xz
BASE_IMAGE="2023-12-11-raspios-bookworm-arm64-lite.img"

echo "Setting up loop device..."
LOOP_DEV=$(losetup --find --show "$BASE_IMAGE")

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

echo ""
echo "Setting up SoulBox with boot splash..."

# Enable SSH
touch boot/ssh

# Copy logo to multiple locations for boot splash
mkdir -p root/usr/share/pixmaps/soulbox
mkdir -p root/opt/soulbox/assets
if [[ -f "$SCRIPT_DIR/soulbox-logo.png" ]]; then
    cp "$SCRIPT_DIR/soulbox-logo.png" root/usr/share/pixmaps/soulbox/logo.png
    cp "$SCRIPT_DIR/soulbox-logo.png" root/opt/soulbox/assets/logo.png
    echo "  ✓ Copied SoulBox logo for splash screen"
else
    echo "  ⚠ Warning: soulbox-logo.png not found, splash screen will show ASCII art only"
fi

# Install software and configure system
chroot root /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https

# Add Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

apt-get update -qq
apt-get install -y tailscale kodi mesa-utils xinit xorg openbox htop nano git python3-pip rsync screen tmux unzip zip alsa-utils fbi

systemctl enable tailscaled

# Users setup
echo 'pi:soulbox' | chpasswd
useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi,render soulbox
echo 'soulbox:soulbox' | chpasswd
echo 'root:soulbox' | chpasswd

# SSH config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Hostname
echo 'soulbox' > /etc/hostname
sed -i 's/raspberrypi/soulbox/g' /etc/hosts

# Create boot splash service that shows logo
cat > /etc/systemd/system/soulbox-splash.service << 'SPLASH_EOF'
[Unit]
Description=SoulBox Boot Splash
DefaultDependencies=false
After=local-fs.target
Before=graphical-session.target

[Service]
Type=forking
User=root
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
ExecStart=/opt/soulbox/show-splash.sh
TimeoutStartSec=infinity
KillMode=process
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
SPLASH_EOF

# Create splash display script
cat > /opt/soulbox/show-splash.sh << 'SPLASH_SCRIPT_EOF'
#!/bin/bash

# Clear the screen
clear > /dev/tty1

# Show ASCII art and logo
cat << 'ASCII_ART' > /dev/tty1

     ____              _ ____            
    / ___|  ___  _   _| | __ )  _____  __
    \___ \ / _ \| | | | |  _ \ / _ \ \/ /
     ___) | (_) | |_| | | |_) | (_) >  < 
    |____/ \___/ \__,_|_|____/ \___/_/\_\
    
           Will-o'-Wisp Media Center
    
               🔥 Loading... 🔥
    
    The blue flame guides your media journey
    
ASCII_ART

# If fbi is available, try to show the image
if command -v fbi >/dev/null 2>&1; then
    # Show logo image for 3 seconds if possible
    timeout 3 fbi -T 1 -d /dev/fb0 -noverbose -a /opt/soulbox/assets/logo.png >/dev/null 2>&1 &
    sleep 3
fi

# Keep splash visible for a moment
sleep 2
SPLASH_SCRIPT_EOF

chmod +x /opt/soulbox/show-splash.sh

# Enable splash service
systemctl enable soulbox-splash.service

# Autologin config
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTOLOGIN_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin soulbox --noclear %I $TERM
AUTOLOGIN_EOF

# Kodi service
cat > /etc/systemd/system/kodi-standalone.service << 'KODI_SERVICE_EOF'
[Unit]
Description=SoulBox Kodi Media Center
After=systemd-user-sessions.service network.target sound.target soulbox-splash.service
Wants=network-online.target
Conflicts=getty@tty1.service

[Service]
User=soulbox
Group=soulbox
Type=simple
ExecStart=/usr/bin/kodi-standalone
Restart=always
RestartSec=5
StandardInput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
KillMode=mixed
TimeoutStopSec=10

Environment="HOME=/home/soulbox"
Environment="USER=soulbox"
Environment="DISPLAY=:0.0"
Environment="KODI_HOME=/home/soulbox/.kodi"
Environment="MESA_LOADER_DRIVER_OVERRIDE=v3d"

[Install]
WantedBy=multi-user.target
KODI_SERVICE_EOF

systemctl enable kodi-standalone.service
systemctl mask getty@tty1.service

apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
CHROOTEOF

# Boot config with splash optimizations
cat > boot/config.txt << 'BOOTCONFIG'
# SoulBox Will-o'-Wisp Configuration

# Basic settings
gpu_mem=320
arm_64bit=1
disable_overscan=1

# Boot splash settings
disable_splash=0
splash=/opt/soulbox/assets/logo.png

# GPU optimizations 
dtoverlay=vc4-kms-v3d
max_framebuffers=2
gpu_freq=800
over_voltage=2
arm_freq=2200

# Display
hdmi_drive=2
hdmi_force_hotplug=1
hdmi_boost=7
hdmi_group=1
hdmi_mode=16

# Video codecs
h264_freq=700
hevc_freq=700
isp_freq=700
v3d_freq=800

# Audio
dtparam=audio=on
audio_pwm_mode=2

# Hardware
dtparam=spi=on
dtparam=i2c_arm=on

# Boot speed
boot_delay=0

# Performance
force_turbo=1
temp_limit=75
BOOTCONFIG

# Custom cmdline for faster boot
echo 'console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles' > boot/cmdline.txt

# Add themed MOTD
cat > root/etc/motd << 'MOTD_EOF'

     ____              _ ____            
    / ___|  ___  _   _| | __ )  _____  __
    \___ \ / _ \| | | | |  _ \ / _ \ \/ /
     ___) | (_) | |_| | | |_) | (_) >  < 
    |____/ \___/ \__,_|_|____/ \___/_/\_\
    
    Will-o'-Wisp Media Center ~ Boot Complete
    
    🔥 The blue flame burns bright 🔥
    
    Default credentials:
    - soulbox:soulbox (media center user)
    - pi:soulbox (compatibility)
    - root:soulbox (admin access)
    
    Services:
    - Kodi media center (auto-starts after splash)
    - Tailscale VPN (run './setup-tailscale.sh')
    - Boot splash service active
    
    Hardware Optimizations:
    - GPU: 320MB for media processing
    - Video: H264/HEVC hardware acceleration
    - Display: Optimized HDMI output
    - Audio: Hardware enabled
    
    The blue flame has guided you home...
    
MOTD_EOF

# Create user directories and configs
mkdir -p root/home/soulbox/{Videos,Music,Pictures,Downloads}
mkdir -p root/home/soulbox/.kodi/{userdata,addons,media}

cat > root/home/soulbox/.kodi/userdata/advancedsettings.xml << 'KODI_SETTINGS'
<advancedsettings>
    <video>
        <playcountminimumpercent>90</playcountminimumpercent>
        <ignoreseasonzero>true</ignoreseasonzero>
    </video>
    <videoplayer>
        <usedisplayasclock>true</usedisplayasclock>
        <adjustrefreshrate>true</adjustrefreshrate>
    </videoplayer>
    <videolibrary>
        <importwatchedstate>true</importwatchedstate>
        <importresumepoint>true</importresumepoint>
    </videolibrary>
    <network>
        <curlclienttimeout>30</curlclienttimeout>
        <curllowspeedtime>20</curllowspeedtime>
        <cachemembuffersize>20971520</cachemembuffersize>
    </network>
</advancedsettings>
KODI_SETTINGS

chown -R 1001:1001 root/home/soulbox/

# Themed Tailscale setup
cat > root/home/soulbox/setup-tailscale.sh << 'TAILSCALE_SCRIPT'
#!/bin/bash

clear
echo ""
echo "     🔥 SoulBox Will-o'-Wisp Tailscale Setup 🔥"
echo "     =========================================="
echo ""
echo "     Let the blue flame extend across networks..."
echo ""

if tailscale status | grep -q "not logged in"; then
    echo "     Igniting Tailscale connection..."
    echo ""
    
    sudo tailscale up \
        --accept-routes \
        --accept-dns=false \
        --hostname=soulbox-$(hostname -s) \
        --advertise-tags=tag:soulbox,tag:mediaserver
        
    echo ""
    echo "     🔥 Connection established! 🔥"
    echo "     Your SoulBox Tailscale IP: $(tailscale ip -4)"
    echo "     SSH via Tailscale: ssh soulbox@$(tailscale ip -4)"
else
    echo "     🔥 The flame already burns across networks! 🔥"
    echo "     Your SoulBox IP: $(tailscale ip -4)"
fi

echo ""
echo "     The blue flame now guides you from anywhere..."
echo "     Manage at: https://login.tailscale.com/admin/machines"
echo ""
TAILSCALE_SCRIPT

chmod +x root/home/soulbox/setup-tailscale.sh
chown 1001:1001 root/home/soulbox/setup-tailscale.sh

echo "Finalizing image with boot splash..."
sync
umount boot root
losetup -d $LOOP_DEV
LOOP_DEV=""

mv "$BASE_IMAGE" "$SOULBOX_IMAGE"
sha256sum "$SOULBOX_IMAGE" > "${SOULBOX_IMAGE}.sha256"

FINAL_PATH="$SCRIPT_DIR/${SOULBOX_IMAGE}"
mv "$SOULBOX_IMAGE" "$FINAL_PATH"
mv "${SOULBOX_IMAGE}.sha256" "${FINAL_PATH}.sha256"

trap - EXIT
cleanup

echo ""
echo "SUCCESS! SoulBox Will-o'-Wisp with Boot Splash Complete!"
echo "======================================================"
echo ""
echo "Image: $FINAL_PATH"
echo "Size: $(ls -lh $FINAL_PATH | awk '{print $5}')"
echo ""
echo "Boot Splash Features:"
echo "- Custom ASCII art and logo display at boot"
echo "- Themed loading messages"
echo "- Logo integration in boot config"
echo "- Smooth transition to Kodi"
echo "- 'quiet splash' boot for clean appearance"
echo ""
echo "🔥 The blue flame will guide users from the very first boot 🔥"

