#!/bin/bash

# SoulBox Will-o'-Wisp Media Center - Complete Build System
# Creates fully functional bootable images with real Pi firmware and OS

set -e

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/soulbox-build"
IMAGE_SIZE_GB=2  # 2GB for full system
VERSION="v0.3.0"
CLEAN=false

# Pi firmware and OS URLs
PI_FIRMWARE_URL="https://github.com/raspberrypi/firmware/archive/refs/heads/master.tar.gz"
PI_OS_LITE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --clean)
      CLEAN=true
      log_info 'Clean build requested'
      shift
      ;;
    --size)
      IMAGE_SIZE_GB="$2"
      log_info "Custom image size: ${IMAGE_SIZE_GB}GB"
      shift 2
      ;;
    *)
      log_warning "Unknown option: $1"
      shift
      ;;
  esac
done

log_info "Building SoulBox $VERSION - Complete Media Center System"
log_info "Image size: ${IMAGE_SIZE_GB}GB"

# Clean up previous builds if requested
if [[ "$CLEAN" == "true" && -d "$WORK_DIR" ]]; then
    log_info "Cleaning previous build directory..."
    rm -rf "$WORK_DIR"
fi

# Create work directory structure
mkdir -p "$WORK_DIR"/{downloads,firmware,os,staging,output}

# Function to download Pi firmware
download_pi_firmware() {
    log_info "=== Downloading Raspberry Pi Firmware ==="
    
    local firmware_dir="$WORK_DIR/firmware"
    local download_file="$WORK_DIR/downloads/pi-firmware.tar.gz"
    
    if [[ ! -f "$download_file" ]]; then
        log_info "Downloading Pi firmware from GitHub..."
        curl -L -o "$download_file" "$PI_FIRMWARE_URL"
    else
        log_info "Using cached Pi firmware"
    fi
    
    log_info "Extracting Pi firmware..."
    cd "$firmware_dir"
    tar -xzf "$download_file" --strip-components=1
    
    # Verify essential firmware files
    local essential_files=("boot/start4.elf" "boot/fixup4.dat" "boot/kernel8.img" "boot/bcm2712-rpi-5-b.dtb")
    for file in "${essential_files[@]}"; do
        if [[ -f "$firmware_dir/$file" ]]; then
            log_success "✅ Found: $file"
        else
            log_error "❌ Missing: $file"
            return 1
        fi
    done
    
    log_success "Pi firmware downloaded and verified"
}

# Function to download and extract Pi OS
download_pi_os() {
    log_info "=== Downloading Raspberry Pi OS ==="
    
    local os_dir="$WORK_DIR/os"
    local download_file="$WORK_DIR/downloads/raspios-lite.img.xz"
    local extracted_img="$os_dir/raspios-lite.img"
    
    if [[ ! -f "$download_file" ]]; then
        log_info "Downloading Raspberry Pi OS Lite..."
        curl -L -o "$download_file" "$PI_OS_LITE_URL"
    else
        log_info "Using cached Pi OS"
    fi
    
    if [[ ! -f "$extracted_img" ]]; then
        log_info "Extracting Pi OS image..."
        cd "$os_dir"
        xz -d -k "$download_file"
        mv *.img raspios-lite.img 2>/dev/null || true
    else
        log_info "Using cached Pi OS image"
    fi
    
    # Verify image integrity
    if [[ -f "$extracted_img" ]]; then
        local file_size=$(stat -c%s "$extracted_img" 2>/dev/null || stat -f%z "$extracted_img" 2>/dev/null)
        if [[ $file_size -gt 1000000000 ]]; then  # > 1GB
            log_success "Pi OS image downloaded and verified ($((file_size / 1024 / 1024))MB)"
        else
            log_error "Pi OS image too small ($((file_size / 1024 / 1024))MB)"
            return 1
        fi
    else
        log_error "Failed to extract Pi OS image"
        return 1
    fi
}

# Function to create SoulBox customizations
create_soulbox_customizations() {
    log_info "=== Creating SoulBox Customizations ==="
    
    local staging_dir="$WORK_DIR/staging"
    mkdir -p "$staging_dir"/{boot,root}
    
    # Create enhanced boot config
    cat > "$staging_dir/boot/config.txt" << 'EOF'
# SoulBox Will-o'-Wisp Media Center Configuration
# Optimized for Raspberry Pi 5

[pi5]
# Pi 5 specific settings
arm_64bit=1
kernel=kernel8.img

# GPU and memory
gpu_mem=256
arm_freq=2400
over_voltage=2

# Video acceleration
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Audio
dtparam=audio=on
audio_pwm_mode=2

# Performance
force_turbo=1
temp_limit=75

# Display
hdmi_force_hotplug=1
hdmi_drive=2
hdmi_boost=7
disable_overscan=1

# Boot optimization
disable_splash=0
boot_delay=0

# Hardware interfaces
dtparam=spi=on
dtparam=i2c_arm=on

# USB power
max_usb_current=1

# SoulBox branding
start_file=start4.elf
fixup_file=fixup4.dat

[all]
EOF

    # Create enhanced cmdline
    echo "console=serial0,115200 console=tty1 root=LABEL=soulbox-root rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet splash plymouth.ignore-serial-consoles" > "$staging_dir/boot/cmdline.txt"
    
    # Create SoulBox user setup script
    cat > "$staging_dir/root/setup-soulbox.sh" << 'EOF'
#!/bin/bash
# SoulBox user and service setup script

set -e

# Create soulbox user
useradd -m -s /bin/bash -G sudo,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi,render soulbox || true

# Set passwords (all use 'soulbox')
echo 'soulbox:soulbox' | chpasswd
echo 'pi:soulbox' | chpasswd
echo 'root:soulbox' | chpasswd

# Create SoulBox directories
mkdir -p /home/soulbox/{Videos,Music,Pictures,Downloads,.kodi/userdata}
mkdir -p /opt/soulbox/{logs,scripts,assets}

# Set ownership
chown -R soulbox:soulbox /home/soulbox
chown -R soulbox:soulbox /opt/soulbox

# Enable SSH
systemctl enable ssh

# Create Kodi service
cat > /etc/systemd/system/kodi-soulbox.service << 'SERVICE'
[Unit]
Description=SoulBox Kodi Media Center
After=graphical-session.target network.target sound.target
Wants=graphical-session.target

[Service]
User=soulbox
Group=soulbox
Type=simple
ExecStart=/usr/bin/kodi-standalone
Restart=always
RestartSec=5
Environment=HOME=/home/soulbox
Environment=USER=soulbox
Environment=DISPLAY=:0
Environment=KODI_HOME=/home/soulbox/.kodi

[Install]
WantedBy=multi-user.target
SERVICE

# Enable Kodi service
systemctl enable kodi-soulbox

# Set hostname
echo 'soulbox' > /etc/hostname

# Update hosts
cat > /etc/hosts << 'HOSTS'
127.0.0.1    localhost
127.0.1.1    soulbox
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
HOSTS

# Create SoulBox MOTD
cat > /etc/motd << 'MOTD'

     ____              _ ____            
    / ___|  ___  _   _| | __ )  _____  __
    \___ \ / _ \| | | | |  _ \ / _ \ \/ /
     ___) | (_) | |_| | | |_) | (_) >  < 
    |____/ \___/ \__,_|_|____/ \___/_/\_\

    Will-o'-Wisp Media Center
    
    🔥 The blue flame burns bright! 🔥
    
    Features:
    • Kodi Media Center (auto-start)
    • SSH enabled
    • Optimized for Pi 5
    
    Default credentials:
    • soulbox:soulbox (media user)
    • pi:soulbox (compatibility)
    • root:soulbox (admin)
    
    Ready to stream your media!

MOTD

echo "SoulBox customization complete"
EOF

    chmod +x "$staging_dir/root/setup-soulbox.sh"
    
    log_success "SoulBox customizations created"
}

# Function to build the complete image
build_complete_image() {
    log_info "=== Building Complete SoulBox Image ==="
    
    local output_image="$WORK_DIR/output/soulbox-$VERSION.img"
    local pi_os_image="$WORK_DIR/os/raspios-lite.img"
    local staging_dir="$WORK_DIR/staging"
    local firmware_dir="$WORK_DIR/firmware"
    
    # Calculate size in MB
    local image_size_mb=$((IMAGE_SIZE_GB * 1024))
    
    log_info "Creating ${IMAGE_SIZE_GB}GB disk image..."
    
    # Create base image from Pi OS
    cp "$pi_os_image" "$output_image"
    
    # Extend the image to desired size
    dd if=/dev/zero bs=1M count=0 seek=$image_size_mb of="$output_image" 2>/dev/null
    
    # Resize the root partition (partition 2) to fill the space
    log_info "Resizing partitions..."
    parted "$output_image" --script resizepart 2 100%
    
    # Create temporary directory for mounting
    local temp_dir=$(mktemp -d)
    local boot_mnt="$temp_dir/boot"
    local root_mnt="$temp_dir/root"
    
    mkdir -p "$boot_mnt" "$root_mnt"
    
    # Get partition information
    local part_info=$(parted -s "$output_image" unit B print)
    local boot_start=$(echo "$part_info" | grep "^ 1" | awk '{print $2}' | tr -d 'B')
    local boot_size=$(echo "$part_info" | grep "^ 1" | awk '{print $4}' | tr -d 'B')
    local root_start=$(echo "$part_info" | grep "^ 2" | awk '{print $2}' | tr -d 'B')
    
    log_info "Extracting and customizing filesystems..."
    
    # Extract boot partition
    local boot_img="$temp_dir/boot.img"
    dd if="$output_image" of="$boot_img" bs=1 skip="$boot_start" count="$boot_size" 2>/dev/null
    
    # Add real Pi firmware to boot partition
    log_info "Adding Pi 5 firmware and kernel..."
    
    # Copy essential Pi firmware files
    mcopy -i "$boot_img" "$firmware_dir/boot/start4.elf" ::start4.elf
    mcopy -i "$boot_img" "$firmware_dir/boot/fixup4.dat" ::fixup4.dat
    mcopy -i "$boot_img" "$firmware_dir/boot/kernel8.img" ::kernel8.img
    mcopy -i "$boot_img" "$firmware_dir/boot/bcm2712-rpi-5-b.dtb" ::bcm2712-rpi-5-b.dtb
    
    # Add SoulBox boot configuration
    mcopy -i "$boot_img" "$staging_dir/boot/config.txt" ::config.txt
    mcopy -i "$boot_img" "$staging_dir/boot/cmdline.txt" ::cmdline.txt
    
    # Write modified boot partition back
    dd if="$boot_img" of="$output_image" bs=1 seek="$boot_start" conv=notrunc 2>/dev/null
    
    # Handle root filesystem with loop device if available, otherwise use e2tools
    if command -v losetup >/dev/null 2>&1 && [[ -w /dev ]]; then
        log_info "Using loop device for root filesystem customization..."
        
        # Setup loop device for root partition
        local loop_device=$(losetup --find --show -o "$root_start" "$output_image")
        
        # Resize ext4 filesystem to fill partition
        e2fsck -f "$loop_device" || true
        resize2fs "$loop_device"
        
        # Mount and customize
        mount "$loop_device" "$root_mnt"
        
        # Copy SoulBox setup script
        cp "$staging_dir/root/setup-soulbox.sh" "$root_mnt/opt/"
        chmod +x "$root_mnt/opt/setup-soulbox.sh"
        
        # Create first-boot service to run SoulBox setup
        cat > "$root_mnt/etc/systemd/system/soulbox-firstboot.service" << 'EOF'
[Unit]
Description=SoulBox First Boot Setup
After=multi-user.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/opt/setup-soulbox.sh
ExecStartPost=/bin/systemctl disable soulbox-firstboot.service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable first-boot service
        chroot "$root_mnt" systemctl enable soulbox-firstboot.service || true
        
        # Unmount and cleanup
        umount "$root_mnt"
        losetup -d "$loop_device"
    else
        log_info "Using e2tools for root filesystem customization..."
        
        # Extract root partition
        local root_img="$temp_dir/root.img"
        dd if="$output_image" of="$root_img" bs=1 skip="$root_start" 2>/dev/null
        
        # Resize ext4 filesystem
        e2fsck -f "$root_img" || true
        resize2fs "$root_img"
        
        # Add SoulBox setup using e2tools
        if command -v e2cp >/dev/null 2>&1; then
            e2mkdir "$root_img:/opt" || true
            e2cp "$staging_dir/root/setup-soulbox.sh" "$root_img:/opt/setup-soulbox.sh" || true
        fi
        
        # Write root partition back
        dd if="$root_img" of="$output_image" bs=1 seek="$root_start" conv=notrunc 2>/dev/null
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify final image
    local final_size=$(stat -c%s "$output_image" 2>/dev/null || stat -f%z "$output_image" 2>/dev/null)
    log_success "✅ Complete SoulBox image created: $output_image"
    log_info "Final image size: $((final_size / 1024 / 1024 / 1024))GB"
    
    # Create checksum
    cd "$WORK_DIR/output"
    sha256sum "$(basename "$output_image")" > "soulbox-$VERSION.img.sha256"
    
    # Create compressed version
    if command -v xz >/dev/null 2>&1; then
        log_info "Creating compressed version..."
        xz -1 -k "soulbox-$VERSION.img"
        log_success "Created compressed: soulbox-$VERSION.img.xz"
    fi
    
    log_success "🎉 SoulBox $VERSION build completed successfully!"
    echo
    echo "Build artifacts:"
    ls -lh "$WORK_DIR/output/"
}

# Main build process
main() {
    log_info "🔥 Starting SoulBox Will-o'-Wisp build process..."
    
    # Check dependencies
    local missing_tools=()
    for tool in curl wget xz parted mkfs.fat mke2fs mcopy e2fsck resize2fs; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: apt-get install curl wget xz-utils parted dosfstools e2fsprogs mtools"
        exit 1
    fi
    
    # Execute build steps
    download_pi_firmware
    download_pi_os
    create_soulbox_customizations
    build_complete_image
    
    log_success "🎯 SoulBox Will-o'-Wisp Media Center build complete!"
    echo
    echo "Ready to deploy:"
    echo "1. Flash soulbox-$VERSION.img to SD card (8GB+ recommended)"
    echo "2. Boot on Raspberry Pi 5"
    echo "3. First boot will configure SoulBox automatically"
    echo "4. Access via SSH or connect HDMI for Kodi interface"
    echo
    echo "The blue flame burns bright! 🔥"
}

# Execute main function
main "$@"
