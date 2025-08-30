#!/bin/bash

set -e
echo "Building SoulBox with Logo, OpenELEC-style Kodi and Tailscale"
echo "============================================================="

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SOULBOX_IMAGE="soulbox-branded-${TIMESTAMP}.img"
WORK_DIR="/tmp/soulbox-branded-${TIMESTAMP}"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo ""
echo "Downloading official Raspberry Pi OS Lite ARM64..."
wget -q https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-11/2023-12-11-raspios-bookworm-arm64-lite.img.xz

echo "Extracting image..."
xz -d 2023-12-11-raspios-bookworm-arm64-lite.img.xz
BASE_IMAGE="2023-12-11-raspios-bookworm-arm64-lite.img"

echo "Base Pi OS image ready: $(ls -lh $BASE_IMAGE | awk '{print $5}')"

echo ""
echo "Setting up loop device for customization..."
LOOP_DEV=$(losetup --find --show "$BASE_IMAGE")
echo "Loop device: $LOOP_DEV"

# Cleanup function
cleanup() {
    cd /
    umount "$WORK_DIR/boot" "$WORK_DIR/root" 2>/dev/null || true
    [ ! -z "$LOOP_DEV" ] && losetup -d "$LOOP_DEV" 2>/dev/null || true
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Wait for partitions to be recognized
sleep 2
partprobe $LOOP_DEV
sleep 2

echo "Mounting Pi OS partitions..."
mkdir -p boot root
mount ${LOOP_DEV}p1 boot
mount ${LOOP_DEV}p2 root

echo ""
echo "Customizing for SoulBox with branding..."

# Enable SSH by default
touch boot/ssh
echo "SSH enabled"

# Copy logo to the image
mkdir -p root/usr/share/pixmaps/soulbox
cp /root/soulbox/soulbox-logo.png root/usr/share/pixmaps/soulbox/logo.png

# Create SoulBox user and install software
echo "Setting up branded OpenELEC-style Kodi media center..."
chroot root /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

# Update and install packages
apt-get update -qq
apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https

# Add Tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale and Kodi
apt-get update -qq
apt-get install -y tailscale kodi mesa-utils xinit xorg openbox htop nano git python3-pip rsync screen tmux unzip zip alsa-utils

systemctl enable tailscaled

# Set up users
echo 'pi:soulbox' | chpasswd
useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi,render soulbox
echo 'soulbox:soulbox' | chpasswd
echo 'root:soulbox' | chpasswd

# Configure SSH
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set hostname
echo 'soulbox' > /etc/hostname
sed -i 's/raspberrypi/soulbox/g' /etc/hosts

# Configure autologin
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTOLOGIN_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin soulbox --noclear %I $TERM
AUTOLOGIN_EOF

# Create Kodi service
cat > /etc/systemd/system/kodi-standalone.service << 'KODI_SERVICE_EOF'
[Unit]
Description=SoulBox Kodi (OpenELEC-style)
After=systemd-user-sessions.service network.target sound.target
Wants=network-online.target
Conflicts=getty@tty1.service

[Service]
User=soulbox
Group=soulbox
Type=simple
ExecStart=/usr/bin/kodi-standalone
ExecStop=/bin/kill -TERM $MAINPID
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

# Clean up
apt-get clean
apt-get autoremove -y
rm -rf /var/lib/apt/lists/*
CHROOTEOF

echo "System configured with SoulBox branding"

# OpenELEC-style boot optimizations
echo ""
echo "Applying OpenELEC-style boot optimizations..."
cat > boot/config.txt << 'BOOTCONFIG'
# SoulBox Will-o'-Wisp Configuration for Raspberry Pi 5

# Basic settings
gpu_mem=320
arm_64bit=1
disable_overscan=1

# GPU optimizations 
dtoverlay=vc4-kms-v3d
max_framebuffers=2
gpu_freq=800
over_voltage=2
arm_freq=2200

# HDMI settings
hdmi_drive=2
hdmi_force_hotplug=1
hdmi_boost=7

# Video codec optimization
h264_freq=700
hevc_freq=700
isp_freq=700
v3d_freq=800

# Audio
dtparam=audio=on
audio_pwm_mode=2

# Hardware interfaces
dtparam=spi=on
dtparam=i2c_arm=on

# Boot optimizations
boot_delay=0
disable_splash=1

# Performance
force_turbo=1
temp_limit=75
BOOTCONFIG

# Add branded MOTD
echo ""
echo "Adding SoulBox branding..."
cp /root/soulbox/assets/soulbox-motd.txt root/etc/motd

# Create directory structure
mkdir -p root/home/soulbox/{Videos,Music,Pictures,Downloads}
mkdir -p root/home/soulbox/.kodi/{userdata,addons,media}

# Create optimized Kodi settings
cat > root/home/soulbox/.kodi/userdata/advancedsettings.xml << 'KODI_ADVANCED'
<advancedsettings>
    <video>
        <playcountminimumpercent>90</playcountminimumpercent>
        <ignoreseasonzero>true</ignoreseasonzero>
        <allowtranscoding>false</allowtranscoding>
    </video>
    <videoplayer>
        <usedisplayasclock>true</usedisplayasclock>
        <adjustrefreshrate>true</adjustrefreshrate>
        <resamplequality>1</resamplequality>
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
    <audiooutput>
        <audiodevice>ALSA:@</audiodevice>
        <channels>2</channels>
        <samplerate>44100</samplerate>
        <stereoupmix>false</stereoupmix>
        <maintainoriginalvolume>true</maintainoriginalvolume>
    </audiooutput>
    <gui>
        <algorithmdirtyregions>3</algorithmdirtyregions>
        <nofliptimeout>0</nofliptimeout>
    </gui>
</advancedsettings>
KODI_ADVANCED

chown -R 1001:1001 root/home/soulbox/

# Create branded Tailscale setup script
cat > root/home/soulbox/setup-tailscale.sh << 'TAILSCALE_SCRIPT'
#!/bin/bash

echo "SoulBox Will-o'-Wisp Tailscale Setup"
echo "===================================="
echo ""
echo "Let the blue flame guide your connection..."
echo "This script will connect your SoulBox to Tailscale."
echo ""

if tailscale status | grep -q "not logged in"; then
    echo "Starting Tailscale connection..."
    echo ""
    
    sudo tailscale up \
        --accept-routes \
        --accept-dns=false \
        --hostname=soulbox-$(hostname -s) \
        --advertise-tags=tag:soulbox,tag:mediaserver
        
    echo ""
    echo "Tailscale setup complete!"
    echo "Your SoulBox Tailscale IP: $(tailscale ip -4)"
    echo "SSH via Tailscale: ssh soulbox@$(tailscale ip -4)"
    
else
    echo "Tailscale is already connected!"
    echo "Your SoulBox IP: $(tailscale ip -4)"
fi

echo ""
echo "The blue flame now burns across networks..."
echo "Manage at: https://login.tailscale.com/admin/machines"
TAILSCALE_SCRIPT

chmod +x root/home/soulbox/setup-tailscale.sh
chown 1001:1001 root/home/soulbox/setup-tailscale.sh

echo ""
echo "Finalizing SoulBox branded image..."
sync
umount boot root
losetup -d $LOOP_DEV
LOOP_DEV=""

mv "$BASE_IMAGE" "$SOULBOX_IMAGE"
sha256sum "$SOULBOX_IMAGE" > "${SOULBOX_IMAGE}.sha256"

FINAL_PATH="/root/soulbox/${SOULBOX_IMAGE}"
mv "$SOULBOX_IMAGE" "$FINAL_PATH"
mv "${SOULBOX_IMAGE}.sha256" "${FINAL_PATH}.sha256"

trap - EXIT
cleanup

echo ""
echo "SUCCESS! SoulBox Will-o'-Wisp Media Center Complete!"
echo "=================================================="
echo ""
echo "Image: $FINAL_PATH"
echo "Size: $(ls -lh $FINAL_PATH | awk '{print $5}')"
echo ""
echo "Features:"
echo "- Blue will-o'-wisp branding integrated"
echo "- OpenELEC-style Kodi auto-start"
echo "- Tailscale VPN with themed setup"
echo "- Pi 5 optimized performance"
echo "- Logo included in /usr/share/pixmaps/soulbox/"
echo ""
echo "The blue flame awaits your media journey..."

