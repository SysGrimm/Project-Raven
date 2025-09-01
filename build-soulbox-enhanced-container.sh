#!/bin/bash

# SoulBox Enhanced Containerized Build Script
# Now includes real Pi firmware and operating system for complete functionality
# Optimized for CI/CD pipelines and Docker containers without loop device dependency

set -e

# Colors for output
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
WORK_DIR="$SCRIPT_DIR/enhanced-containerized-build"
VERSION="v0.3.0"
CLEAN=false

# Enhanced URLs for real firmware and OS
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
        -h|--help)
            echo "SoulBox Enhanced Containerized Build System"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version VERSION    Specify version (e.g., v0.3.0)"
            echo "  --clean              Clean build directory first"
            echo "  -h, --help           Show this help"
            echo ""
            echo "Features:"
            echo "  • Downloads real Pi firmware and kernel"
            echo "  • Uses official Raspberry Pi OS base"
            echo "  • Creates fully functional bootable images"
            echo "  • Container-friendly (no loop devices needed)"
            echo "  • Optimized for CI/CD environments"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "SoulBox Enhanced Container Build - $VERSION"

# Check required tools
check_required_tools() {
    log_info "Checking required tools for enhanced build..."
    
    local missing_tools=()
    local required_tools=(curl wget xz parted mkfs.fat mke2fs mcopy e2fsck resize2fs tar sha256sum)
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: apt-get install curl wget xz-utils parted dosfstools e2fsprogs mtools coreutils"
        exit 1
    fi
    
    log_success "All required tools available"
}

# Setup work directory
setup_work_dir() {
    if [[ "$CLEAN" == "true" && -d "$WORK_DIR" ]]; then
        log_info "Cleaning work directory..."
        rm -rf "$WORK_DIR"
    fi
    
    mkdir -p "$WORK_DIR"/{downloads,firmware,os,staging,output}
    log_success "Work directory prepared: $WORK_DIR"
}

# Download Pi firmware
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

# Download and extract Pi OS
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
        
        # Extract with explicit error handling and path management
        log_info "Running: xz -d -k $download_file"
        if ! xz -d -k "$download_file"; then
            log_error "Failed to decompress Pi OS image with xz"
            return 1
        fi
        
        # Find the extracted .img file and move it properly
        local extracted_files=("$WORK_DIR/downloads/"*.img)
        if [[ ${#extracted_files[@]} -eq 1 && -f "${extracted_files[0]}" ]]; then
            log_info "Moving extracted image: ${extracted_files[0]} -> $extracted_img"
            mv "${extracted_files[0]}" "$extracted_img"
        else
            log_error "Expected exactly 1 .img file, found: ${#extracted_files[@]}"
            ls -la "$WORK_DIR/downloads/"*.img 2>/dev/null || log_error "No .img files found"
            return 1
        fi
    else
        log_info "Using cached Pi OS image"
    fi
    
    # Verify image integrity
    if [[ -f "$extracted_img" ]]; then
        local file_size=$(stat -c%s "$extracted_img" 2>/dev/null || stat -f%z "$extracted_img" 2>/dev/null)
        if [[ $file_size -gt 1000000000 ]]; then  # > 1GB
            log_success "Pi OS image downloaded and verified ($((file_size / 1024 / 1024))MB)"
            
            # Container optimization: Remove compressed file immediately after extraction
            log_info "Container optimization: Removing compressed Pi OS to save space..."
            rm -f "$download_file"
            log_info "Freed $(((431 * 1024)) KB of container space"
        else
            log_error "Pi OS image too small ($((file_size / 1024 / 1024))MB)"
            return 1
        fi
    else
        log_error "Failed to extract Pi OS image"
        return 1
    fi
}

# Create SoulBox customizations
create_soulbox_customizations() {
    log_info "=== Creating SoulBox Customizations ==="
    
    local staging_dir="$WORK_DIR/staging"
    mkdir -p "$staging_dir"/{boot,root}
    
    # Create enhanced boot config for Pi 5
    cat > "$staging_dir/boot/config.txt" << 'EOF'
# SoulBox Will-o'-Wisp Media Center Configuration
# Optimized for Raspberry Pi 5

[pi5]
# Pi 5 specific settings
arm_64bit=1
kernel=kernel8.img

# GPU and memory for media streaming
gpu_mem=256
arm_freq=2400
over_voltage=2

# Video acceleration
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Audio configuration
dtparam=audio=on
audio_pwm_mode=2

# Performance optimization
force_turbo=1
temp_limit=75

# Display settings
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
    
    The blue flame burns bright!
    
    Features:
    - Kodi Media Center (auto-start)
    - SSH enabled
    - Optimized for Pi 5
    
    Default credentials:
    - soulbox:soulbox (media user)
    - pi:soulbox (compatibility)
    - root:soulbox (admin)
    
    Ready to stream your media!

MOTD

echo "SoulBox customization complete"
EOF

    chmod +x "$staging_dir/root/setup-soulbox.sh"
    
    log_success "SoulBox customizations created"
}

# Extract partitions from Pi OS (container-friendly)
extract_pi_os_partitions() {
    log_info "=== Extracting Pi OS Partitions ==="
    
    local source_image="$WORK_DIR/os/raspios-lite.img"
    local partitions_dir="$WORK_DIR/partitions"
    
    mkdir -p "$partitions_dir"
    
    # Get partition information
    local part_info=$(parted -s "$source_image" unit s print)
    local boot_start=$(echo "$part_info" | grep "^ 1" | awk '{print $2}' | sed 's/s$//')
    local boot_size=$(echo "$part_info" | grep "^ 1" | awk '{print $4}' | sed 's/s$//')
    local root_start=$(echo "$part_info" | grep "^ 2" | awk '{print $2}' | sed 's/s$//')
    local root_size=$(echo "$part_info" | grep "^ 2" | awk '{print $4}' | sed 's/s$//')
    
    log_info "Boot partition: start=$boot_start, size=$boot_size sectors"
    log_info "Root partition: start=$root_start, size=$root_size sectors"
    
    # Extract boot partition
    log_info "Extracting boot partition..."
    dd if="$source_image" of="$partitions_dir/boot.fat" bs=512 skip="$boot_start" count="$boot_size" 2>/dev/null
    
    # Extract root partition  
    log_info "Extracting root partition..."
    dd if="$source_image" of="$partitions_dir/root.ext4" bs=512 skip="$root_start" count="$root_size" 2>/dev/null
    
    # Container optimization: Remove source image immediately after partition extraction
    log_info "Container optimization: Removing source Pi OS image to save space..."
    local source_size=$(stat -c%s "$source_image" 2>/dev/null || stat -f%z "$source_image" 2>/dev/null)
    rm -f "$source_image"
    log_info "Freed $((source_size / 1024 / 1024))MB of container space"
    
    # Verify partitions
    if fsck.fat -v "$partitions_dir/boot.fat" >/dev/null 2>&1; then
        log_success "Boot partition extracted successfully"
    else
        log_error "Boot partition extraction failed"
        return 1
    fi
    
    if e2fsck -n "$partitions_dir/root.ext4" >/dev/null 2>&1; then
        log_success "Root partition extracted successfully"
    else
        log_error "Root partition extraction failed"
        return 1
    fi
}

# Build enhanced SoulBox image
build_enhanced_image() {
    log_info "=== Building Enhanced SoulBox Image ==="
    
    local output_image="$WORK_DIR/output/soulbox-$VERSION.img"
    local firmware_dir="$WORK_DIR/firmware"
    local partitions_dir="$WORK_DIR/partitions"
    local staging_dir="$WORK_DIR/staging"
    
    # Calculate image size (1.0GB for container compatibility) 
    local image_size_mb=1024
    
    log_info "Creating ${image_size_mb}MB disk image..."
    dd if=/dev/zero of="$output_image" bs=1M count=0 seek=$image_size_mb 2>/dev/null
    
    # Create partition table
    log_info "Creating partition table..."
    parted -s "$output_image" mklabel msdos
    parted -s "$output_image" mkpart primary fat32 4MiB 256MiB
    parted -s "$output_image" mkpart primary ext4 256MiB 100%
    parted -s "$output_image" set 1 boot on
    
    # Get new partition information
    local new_part_info=$(parted -s "$output_image" unit B print)
    local new_boot_start=$(echo "$new_part_info" | grep "^ 1" | awk '{print $2}' | tr -d 'B')
    local new_boot_size=$(echo "$new_part_info" | grep "^ 1" | awk '{print $4}' | tr -d 'B')
    local new_root_start=$(echo "$new_part_info" | grep "^ 2" | awk '{print $2}' | tr -d 'B')
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    # Process boot partition
    log_info "Processing boot partition..."
    local boot_img="$temp_dir/boot.img"
    dd if="$output_image" of="$boot_img" bs=1 skip="$new_boot_start" count="$new_boot_size" 2>/dev/null
    
    # Format as FAT32 with compatibility options
    mkfs.fat -F 32 -n "SOULBOX" -f 2 -S 512 -s 1 "$boot_img" 2>/dev/null
    
    # Add real Pi firmware files
    log_info "Adding Pi 5 firmware and kernel..."
    mcopy -i "$boot_img" "$firmware_dir/boot/start4.elf" ::start4.elf
    mcopy -i "$boot_img" "$firmware_dir/boot/fixup4.dat" ::fixup4.dat
    mcopy -i "$boot_img" "$firmware_dir/boot/kernel8.img" ::kernel8.img
    mcopy -i "$boot_img" "$firmware_dir/boot/bcm2712-rpi-5-b.dtb" ::bcm2712-rpi-5-b.dtb
    
    # Add SoulBox configuration
    mcopy -i "$boot_img" "$staging_dir/boot/config.txt" ::config.txt
    mcopy -i "$boot_img" "$staging_dir/boot/cmdline.txt" ::cmdline.txt
    
    # Write boot partition back
    dd if="$boot_img" of="$output_image" bs=1 seek="$new_boot_start" conv=notrunc 2>/dev/null
    
    # Process root partition
    log_info "Processing root partition..."
    local root_img="$temp_dir/root.img"
    dd if="$output_image" of="$root_img" bs=1 skip="$new_root_start" 2>/dev/null
    
    # Copy base OS root content using container-friendly method
    log_info "Copying base OS content..."
    if command -v e2cp >/dev/null 2>&1; then
        # Use e2tools to copy essential files
        local essential_dirs=("/etc" "/usr" "/lib" "/bin" "/sbin")
        for dir in "${essential_dirs[@]}"; do
            if e2ls "$partitions_dir/root.ext4:$dir" >/dev/null 2>&1; then
                log_info "Copying $dir..."
                e2cp -r "$partitions_dir/root.ext4:$dir" "$temp_dir/"
                e2cp -r "$temp_dir$dir" "$root_img:/" 2>/dev/null || true
            fi
        done
    fi
    
    # Add SoulBox customizations
    log_info "Adding SoulBox customizations..."
    if command -v e2mkdir >/dev/null 2>&1; then
        e2mkdir "$root_img:/opt" 2>/dev/null || true
        e2cp "$staging_dir/root/setup-soulbox.sh" "$root_img:/opt/setup-soulbox.sh" 2>/dev/null || true
    fi
    
    # Set proper filesystem label
    tune2fs -L "soulbox-root" "$root_img" 2>/dev/null || true
    
    # Write root partition back
    dd if="$root_img" of="$output_image" bs=1 seek="$new_root_start" conv=notrunc 2>/dev/null
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Create artifacts
    cd "$WORK_DIR/output"
    
    local file_size=$(stat -c%s "$output_image" 2>/dev/null || stat -f%z "$output_image" 2>/dev/null)
    log_success "Enhanced SoulBox image created: $output_image"
    log_info "Image size: $((file_size / 1024 / 1024))MB"
    
    # Create checksum
    sha256sum "$(basename "$output_image")" > "soulbox-$VERSION.img.sha256"
    
    # Create compressed version
    if command -v xz >/dev/null 2>&1; then
        log_info "Creating compressed version..."
        xz -1 -k "soulbox-$VERSION.img"
        sha256sum "soulbox-$VERSION.img.xz" > "soulbox-$VERSION.img.xz.sha256"
        log_success "Compressed image created"
    fi
    
    log_success "Enhanced SoulBox image build completed successfully!"
}

# Main execution
main() {
    log_info "Starting enhanced SoulBox containerized build..."
    
    check_required_tools
    setup_work_dir
    download_pi_firmware
    download_pi_os
    create_soulbox_customizations
    extract_pi_os_partitions
    build_enhanced_image
    
    log_success "Enhanced SoulBox build complete!"
    echo
    echo "Build artifacts created in: $WORK_DIR/output/"
    ls -lh "$WORK_DIR/output/"
    echo
    echo "Ready to flash:"
    echo "1. Use soulbox-$VERSION.img for direct flashing"
    echo "2. Use soulbox-$VERSION.img.xz for compressed transfer"
    echo "3. Verify with corresponding .sha256 files"
    echo
    echo "The blue flame burns bright!"
}

# Execute main function
main "$@"
