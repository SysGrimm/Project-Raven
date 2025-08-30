#!/bin/bash

# SoulBox Image Modification Build System
# Downloads and modifies existing Raspberry Pi OS images instead of building from scratch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
PI_OS_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz"
PI_OS_IMAGE_NAME="2024-07-04-raspios-bookworm-arm64-lite.img"
WORK_DIR="$SCRIPT_DIR/image-work"
MOUNT_DIR="$WORK_DIR/mnt"

# Function to show usage
show_usage() {
    echo "SoulBox Image Modification Build System"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Specify output version (e.g., v1.2.3)"
    echo "  --clean                  Clean up work directory before starting"
    echo "  --keep-base              Keep downloaded base image for reuse"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "This approach:"
    echo "  1. Downloads official Raspberry Pi OS ARM64 image"
    echo "  2. Modifies it by mounting and copying our configs"
    echo "  3. No ARM64 emulation or chroot required"
    echo "  4. Works perfectly in CI/CD containers"
}

# Parse arguments
VERSION=""
CLEAN=false
KEEP_BASE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --keep-base)
            KEEP_BASE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set default version if not provided
if [[ -z "$VERSION" ]]; then
    if [[ -f "scripts/version-manager.sh" ]]; then
        VERSION=$("$SCRIPT_DIR/scripts/version-manager.sh" auto 2>/dev/null || echo "v0.1.0")
    else
        VERSION="v0.1.0"
    fi
fi

log_info "Building SoulBox $VERSION using image modification approach"

# Function to setup work directory
setup_work_dir() {
    if [[ "$CLEAN" == "true" && -d "$WORK_DIR" ]]; then
        log_info "Cleaning work directory..."
        rm -rf "$WORK_DIR"
    fi
    
    mkdir -p "$WORK_DIR"
    mkdir -p "$MOUNT_DIR"/{boot,root}
}

# Function to download Pi OS image
download_pi_os_image() {
    local image_path="$WORK_DIR/$PI_OS_IMAGE_NAME"
    
    if [[ -f "$image_path" ]]; then
        log_info "Pi OS image already exists: $PI_OS_IMAGE_NAME"
        return 0
    fi
    
    log_info "Downloading Raspberry Pi OS image..."
    log_info "URL: $PI_OS_IMAGE_URL"
    
    cd "$WORK_DIR"
    
    # Download compressed image
    curl -L -o "${PI_OS_IMAGE_NAME}.xz" "$PI_OS_IMAGE_URL"
    
    # Extract image
    log_info "Extracting image..."
    xz -d "${PI_OS_IMAGE_NAME}.xz"
    
    if [[ -f "$image_path" ]]; then
        log_success "Downloaded and extracted: $PI_OS_IMAGE_NAME"
        log_info "Size: $(ls -lh "$image_path" | awk '{print $5}')"
    else
        log_error "Failed to extract Pi OS image"
        exit 1
    fi
}

# Function to mount Pi OS image
mount_pi_os_image() {
    local image_path="$WORK_DIR/$PI_OS_IMAGE_NAME"
    
    log_info "Setting up loop device for Pi OS image..."
    
    # Find available loop device
    LOOP_DEV=$(sudo losetup --find --show "$image_path")
    log_info "Using loop device: $LOOP_DEV"
    
    # Wait for device to be ready and probe partitions
    sleep 2
    sudo partprobe "$LOOP_DEV"
    sleep 2
    
    # Mount boot and root partitions
    log_info "Mounting partitions..."
    sudo mount "${LOOP_DEV}p1" "$MOUNT_DIR/boot"
    sudo mount "${LOOP_DEV}p2" "$MOUNT_DIR/root"
    
    log_success "Mounted Pi OS image partitions"
    log_info "Boot: $MOUNT_DIR/boot"
    log_info "Root: $MOUNT_DIR/root"
}

# Function to unmount and cleanup
unmount_pi_os_image() {
    if [[ -n "$LOOP_DEV" ]]; then
        log_info "Unmounting and cleaning up..."
        
        # Unmount partitions
        sudo umount "$MOUNT_DIR/boot" 2>/dev/null || true
        sudo umount "$MOUNT_DIR/root" 2>/dev/null || true
        
        # Detach loop device
        sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
        
        log_success "Cleanup complete"
    fi
}

# Function to modify the mounted image
modify_pi_os_image() {
    log_info "Modifying Raspberry Pi OS image with SoulBox configuration..."
    
    # 1. Update hostname and network configuration
    configure_system_identity
    
    # 2. Configure SSH and security
    configure_ssh_security
    
    # 3. Create SoulBox directory structure
    create_soulbox_directories
    
    # 4. Copy SoulBox assets and branding
    copy_soulbox_assets
    
    # 5. Configure boot settings with Pi 5 optimizations
    configure_boot_settings
    
    # 6. Create Kodi configuration and service
    create_kodi_configuration
    
    # 7. Setup Tailscale integration
    setup_tailscale_integration
    
    # 8. Create splash service
    create_splash_service
    
    # 9. Create first boot setup service
    create_first_boot_setup
    
    # 10. Create setup scripts for user
    create_setup_scripts
    
    # 11. Configure system services and users
    configure_system_services
    
    log_success "Image modification complete - SoulBox is ready!"
}

# Function to create splash service
create_splash_service() {
    log_info "Creating splash screen service..."
    
    # Create splash script
    sudo tee "$MOUNT_DIR/root/opt/soulbox/show-splash.sh" > /dev/null << 'EOF'
#!/bin/bash
clear > /dev/tty1 2>&1
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

if command -v fbi >/dev/null 2>&1 && [ -f "/opt/soulbox/assets/logo.png" ]; then
    timeout 4 fbi -T 1 -d /dev/fb0 -noverbose -a /opt/soulbox/assets/logo.png >/dev/null 2>&1 || true
fi
sleep 3
EOF

    sudo chmod +x "$MOUNT_DIR/root/opt/soulbox/show-splash.sh"
    
    # Create splash service
    sudo tee "$MOUNT_DIR/root/etc/systemd/system/soulbox-splash.service" > /dev/null << 'EOF'
[Unit]
Description=SoulBox Boot Splash Screen
DefaultDependencies=false
After=local-fs.target
Before=soulbox-setup.service

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
EOF

    # Enable splash service
    sudo ln -sf /etc/systemd/system/soulbox-splash.service \
        "$MOUNT_DIR/root/etc/systemd/system/multi-user.target.wants/soulbox-splash.service"
}

# Function to create first boot setup
create_first_boot_setup() {
    log_info "Creating first boot setup script..."
    
    sudo tee "$MOUNT_DIR/root/opt/soulbox/first-boot-setup.sh" > /dev/null << 'EOF'
#!/bin/bash

# SoulBox First Boot Setup
# Installs packages and configures system on first boot

set -e

LOG_FILE="/var/log/soulbox-setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "$(date): Starting SoulBox first boot setup..."

# Update package lists
echo "Updating package lists..."
apt-get update -qq

# Install required packages
echo "Installing SoulBox packages..."
apt-get install -y \
    kodi mesa-utils xinit xorg openbox \
    python3-pip screen tmux unzip zip alsa-utils \
    tailscale fbi

# Create soulbox user
if ! id "soulbox" &>/dev/null; then
    echo "Creating soulbox user..."
    useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi,render soulbox
    echo 'soulbox:soulbox' | chpasswd
fi

# Set passwords
echo 'pi:soulbox' | chpasswd
echo 'root:soulbox' | chpasswd

# Configure autologin
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin soulbox --noclear %I $TERM
AUTOLOGIN

# Create Kodi service
cat > /etc/systemd/system/kodi-standalone.service << 'KODI_SERVICE'
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
KODI_SERVICE

# Enable services
systemctl enable soulbox-splash.service
systemctl enable kodi-standalone.service
systemctl mask getty@tty1.service
systemctl enable tailscaled
systemctl enable ssh

# Set proper ownership
chown -R soulbox:soulbox /home/soulbox/

# Create completion marker
touch /opt/soulbox/setup-complete

echo "$(date): SoulBox first boot setup complete!"

# Disable this service now that setup is complete
systemctl disable soulbox-setup.service

echo "$(date): Rebooting in 10 seconds..."
sleep 10
reboot
EOF

    sudo chmod +x "$MOUNT_DIR/root/opt/soulbox/first-boot-setup.sh"
    
    # Create service for first boot setup
    sudo tee "$MOUNT_DIR/root/etc/systemd/system/soulbox-setup.service" > /dev/null << 'EOF'
[Unit]
Description=SoulBox First Boot Setup
After=network.target
ConditionPathExists=!/opt/soulbox/setup-complete

[Service]
Type=oneshot
ExecStart=/opt/soulbox/first-boot-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable first boot setup
    sudo ln -sf /etc/systemd/system/soulbox-setup.service \
        "$MOUNT_DIR/root/etc/systemd/system/multi-user.target.wants/soulbox-setup.service"
}

# Function to create setup scripts
create_setup_scripts() {
    log_info "Creating setup scripts..."
    
    # Create Tailscale setup script
    sudo tee "$MOUNT_DIR/root/home/soulbox/setup-tailscale.sh" > /dev/null << 'EOF'
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
EOF

    sudo chmod +x "$MOUNT_DIR/root/home/soulbox/setup-tailscale.sh"
    sudo chown 1000:1000 "$MOUNT_DIR/root/home/soulbox/setup-tailscale.sh" 2>/dev/null || true
}

# Function to configure system identity
configure_system_identity() {
    log_info "Configuring system identity..."
    
    # Update hostname
    echo "soulbox" | sudo tee "$MOUNT_DIR/root/etc/hostname" >/dev/null
    
    # Update hosts file
    sudo tee "$MOUNT_DIR/root/etc/hosts" > /dev/null << 'EOF'
127.0.0.1    localhost
127.0.1.1    soulbox
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
EOF
    
    # Configure network interfaces
    sudo tee "$MOUNT_DIR/root/etc/network/interfaces" > /dev/null << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
}

# Function to configure SSH and security
configure_ssh_security() {
    log_info "Configuring SSH and security..."
    
    # Configure SSH
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' "$MOUNT_DIR/root/etc/ssh/sshd_config"
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$MOUNT_DIR/root/etc/ssh/sshd_config"
    
    # Enable SSH service
    sudo ln -sf /lib/systemd/system/ssh.service "$MOUNT_DIR/root/etc/systemd/system/multi-user.target.wants/ssh.service"
}

# Function to create SoulBox directories
create_soulbox_directories() {
    log_info "Creating SoulBox directory structure..."
    
    # Create main SoulBox directories
    sudo mkdir -p "$MOUNT_DIR/root/opt/soulbox"/{assets,scripts,logs}
    sudo mkdir -p "$MOUNT_DIR/root/home/soulbox"/{Videos,Music,Pictures,Downloads}
    sudo mkdir -p "$MOUNT_DIR/root/home/soulbox/.kodi"/{userdata,addons,media}
    
    # Set proper permissions (will be adjusted after user creation)
    sudo chmod 755 "$MOUNT_DIR/root/opt/soulbox"
    sudo chmod 755 "$MOUNT_DIR/root/home/soulbox"
}

# Function to copy SoulBox assets
copy_soulbox_assets() {
    log_info "Copying SoulBox assets and branding..."
    
    # Copy logo if available
    if [[ -f "$SCRIPT_DIR/soulbox-logo.png" ]]; then
        sudo cp "$SCRIPT_DIR/soulbox-logo.png" "$MOUNT_DIR/root/opt/soulbox/assets/logo.png"
        log_success "Copied SoulBox logo"
    fi
    
    # Create branded MOTD
    sudo tee "$MOUNT_DIR/root/etc/motd" > /dev/null << 'EOF'

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
    - Kodi media center (auto-starts after setup)
    - Tailscale VPN (run './setup-tailscale.sh')
    - Boot splash service active
    
    The blue flame has guided you home...

EOF
}

# Function to create Kodi configuration
create_kodi_configuration() {
    log_info "Creating Kodi configuration..."
    
    # Create Kodi advanced settings for Pi 5
    sudo tee "$MOUNT_DIR/root/home/soulbox/.kodi/userdata/advancedsettings.xml" > /dev/null << 'EOF'
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
    <cputempcommand>vcgencmd measure_temp</cputempcommand>
</advancedsettings>
EOF
    
    # Create sources.xml for media directories
    sudo tee "$MOUNT_DIR/root/home/soulbox/.kodi/userdata/sources.xml" > /dev/null << 'EOF'
<sources>
    <video>
        <default pathversion="1"></default>
        <source>
            <name>Videos</name>
            <path pathversion="1">/home/soulbox/Videos/</path>
            <allowsharing>true</allowsharing>
        </source>
    </video>
    <music>
        <default pathversion="1"></default>
        <source>
            <name>Music</name>
            <path pathversion="1">/home/soulbox/Music/</path>
            <allowsharing>true</allowsharing>
        </source>
    </music>
    <pictures>
        <default pathversion="1"></default>
        <source>
            <name>Pictures</name>
            <path pathversion="1">/home/soulbox/Pictures/</path>
            <allowsharing>true</allowsharing>
        </source>
    </pictures>
</sources>
EOF
}

# Function to setup Tailscale integration
setup_tailscale_integration() {
    log_info "Setting up Tailscale integration..."
    
    # Add Tailscale repository configuration
    sudo tee "$MOUNT_DIR/root/etc/apt/sources.list.d/tailscale.list" > /dev/null << 'EOF'
deb https://pkgs.tailscale.com/stable/debian bookworm main
EOF
    
    # Add Tailscale GPG key location (will be downloaded during first boot)
    sudo mkdir -p "$MOUNT_DIR/root/usr/share/keyrings"
    
    # Create Tailscale setup service for first boot
    sudo tee "$MOUNT_DIR/root/etc/systemd/system/tailscale-setup.service" > /dev/null << 'EOF'
[Unit]
Description=Setup Tailscale Repository
Before=soulbox-setup.service
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/opt/soulbox/tailscale-setup-complete

[Service]
Type=oneshot
ExecStartPre=/usr/bin/curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
ExecStart=/usr/bin/apt-get update -qq
ExecStartPost=/usr/bin/touch /opt/soulbox/tailscale-setup-complete
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable Tailscale setup service
    sudo ln -sf /etc/systemd/system/tailscale-setup.service \
        "$MOUNT_DIR/root/etc/systemd/system/multi-user.target.wants/tailscale-setup.service"
}

# Function to configure system services
configure_system_services() {
    log_info "Configuring system services..."
    
    # Create fstab for proper mounting
    sudo tee "$MOUNT_DIR/root/etc/fstab" > /dev/null << 'EOF'
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1
/dev/mmcblk0p1  /boot/firmware  vfat    defaults          0       2
tmpfs           /tmp            tmpfs   defaults,noatime  0       0
EOF
    
    # Disable unnecessary services
    sudo rm -f "$MOUNT_DIR/root/etc/systemd/system/multi-user.target.wants/triggerhappy.service" 2>/dev/null || true
    
    log_success "System services configured"
}

# Function to configure boot settings
configure_boot_settings() {
    log_info "Configuring boot settings..."
    
    # Update config.txt with Pi 5 optimizations
    sudo tee -a "$MOUNT_DIR/boot/config.txt" > /dev/null << 'EOF'

# SoulBox Will-o'-Wisp Configuration for Raspberry Pi 5
gpu_mem=320
arm_64bit=1
disable_overscan=1

# Boot splash settings
disable_splash=0

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
EOF

    # Update cmdline.txt for quiet boot
    if [[ -f "$MOUNT_DIR/boot/cmdline.txt" ]]; then
        sudo sed -i 's/$/ quiet splash/' "$MOUNT_DIR/boot/cmdline.txt"
    fi
}

# Function to create final image
create_final_image() {
    local version_num="${VERSION#v}"
    local output_image="soulbox-v${version_num}.img"
    
    log_info "Creating final SoulBox image..."
    
    # Copy the modified image
    cp "$WORK_DIR/$PI_OS_IMAGE_NAME" "$output_image"
    
    # Generate checksum
    shasum -a 256 "$output_image" > "${output_image}.sha256"
    
    log_success "Created SoulBox image: $output_image"
    log_info "Size: $(ls -lh "$output_image" | awk '{print $5}')"
    
    # Create MOTD
    sudo tee "$MOUNT_DIR/root/etc/motd" > /dev/null << 'EOF'

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
    - Kodi media center (auto-starts after setup)
    - Tailscale VPN (run './setup-tailscale.sh')
    - Boot splash service active
    
    The blue flame has guided you home...

EOF
}

# Main execution
main() {
    log_info "SoulBox Image Modification Build System"
    log_info "======================================"
    
    # Setup cleanup trap
    trap unmount_pi_os_image EXIT
    
    # Execute build steps
    setup_work_dir
    download_pi_os_image
    mount_pi_os_image
    modify_pi_os_image
    create_final_image
    unmount_pi_os_image
    
    # Cleanup if requested
    if [[ "$KEEP_BASE" != "true" ]]; then
        log_info "Cleaning up work directory..."
        rm -rf "$WORK_DIR"
    fi
    
    echo ""
    log_success "🎉 SoulBox $VERSION is ready!"
    echo ""
    echo "📋 Build Summary:"
    echo "   Version: $VERSION"
    echo "   Method: Image Modification (no emulation required)"
    echo "   Output: soulbox-v${VERSION#v}.img"
    echo "   Base: Official Raspberry Pi OS ARM64"
    echo ""
    echo "🚀 Flash to SD card and boot - first boot will install packages automatically!"
    echo "💡 This approach works perfectly in CI/CD environments!"
}

main "$@"
