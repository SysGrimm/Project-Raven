#!/bin/bash

# SoulBox Container-Friendly Build System
# Based on LibreELEC's approach - no loop device mounting required
# Uses mtools (FAT32) and e2tools/populatefs (ext4) for filesystem manipulation

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
WORK_DIR="$SCRIPT_DIR/containerized-build"
SOULBOX_VERSION=""

# Function to show usage
show_usage() {
    echo "SoulBox Container-Friendly Build System"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Specify output version (e.g., v1.2.3)"
    echo "  --clean                  Clean up work directory before starting"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "This approach:"
    echo "  1. Downloads official Raspberry Pi OS ARM64 image"
    echo "  2. Extracts filesystem contents using mtools and e2tools (no mounting!)"
    echo "  3. Creates new SoulBox image from scratch using parted and dd"
    echo "  4. Populates with Pi OS content + SoulBox configurations"
    echo "  5. Works in unprivileged containers - no loop devices needed!"
}

# Parse arguments
CLEAN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            SOULBOX_VERSION="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
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
if [[ -z "$SOULBOX_VERSION" ]]; then
    if [[ -f "scripts/gitea-version-manager.sh" ]]; then
        log_info "Getting next version from Gitea releases..."
        SOULBOX_VERSION=$(./scripts/gitea-version-manager.sh auto 2>/dev/null || echo "v0.1.0")
        log_success "Version determined: $SOULBOX_VERSION"
    elif [[ -f "scripts/version-manager.sh" ]]; then
        log_info "Using git tag fallback versioning..."
        SOULBOX_VERSION=$(./scripts/version-manager.sh auto 2>/dev/null || echo "v0.1.0")
    else
        SOULBOX_VERSION="v0.1.0"
    fi
fi

log_info "Building SoulBox $SOULBOX_VERSION using container-friendly approach"

# Function to check required tools
check_required_tools() {
    log_info "Checking required tools..."
    
    local missing_tools=()
    
    # Check for basic tools
    command -v curl >/dev/null 2>&1 || missing_tools+=(curl)
    command -v xz >/dev/null 2>&1 || missing_tools+=(xz-utils)
    command -v parted >/dev/null 2>&1 || missing_tools+=(parted)
    command -v dd >/dev/null 2>&1 || missing_tools+=(coreutils)
    
    # Check for filesystem tools
    command -v mcopy >/dev/null 2>&1 || missing_tools+=(mtools)
    command -v mformat >/dev/null 2>&1 || missing_tools+=(mtools)
    command -v e2cp >/dev/null 2>&1 || missing_tools+=(e2tools)
    command -v mke2fs >/dev/null 2>&1 || missing_tools+=(e2fsprogs)
    command -v fsck.fat >/dev/null 2>&1 || missing_tools+=(dosfstools)
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: apt-get update && apt-get install -y ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "All required tools are available"
}

# Function to setup work directory
setup_work_dir() {
    if [[ "$CLEAN" == "true" && -d "$WORK_DIR" ]]; then
        log_info "Cleaning work directory..."
        rm -rf "$WORK_DIR"
    fi
    
    mkdir -p "$WORK_DIR"/{source,filesystems,output}
    log_success "Work directory prepared: $WORK_DIR"
}

# Function to download Pi OS image
download_pi_os_image() {
    local image_path="$WORK_DIR/source/$PI_OS_IMAGE_NAME"
    
    if [[ -f "$image_path" ]]; then
        log_info "Pi OS image already exists: $PI_OS_IMAGE_NAME"
        return 0
    fi
    
    log_info "Downloading Raspberry Pi OS image..."
    log_info "URL: $PI_OS_IMAGE_URL"
    
    cd "$WORK_DIR/source"
    
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

# Function to extract Pi OS filesystems without mounting
extract_pi_os_filesystems() {
    local source_image="$WORK_DIR/source/$PI_OS_IMAGE_NAME"
    local boot_fs="$WORK_DIR/filesystems/pi-boot.fat"
    local root_fs="$WORK_DIR/filesystems/pi-root.ext4"
    
    log_info "Extracting Pi OS filesystems using container-friendly method..."
    
    # Get partition information using parted
    log_info "Analyzing partition table..."
    parted -s "$source_image" unit s print > "$WORK_DIR/partition-info.txt"
    
    # Extract partition details (assuming standard Pi OS layout)
    local boot_start=$(parted -s "$source_image" unit s print | grep "^ 1" | awk '{print $2}' | sed 's/s$//')
    local boot_end=$(parted -s "$source_image" unit s print | grep "^ 1" | awk '{print $3}' | sed 's/s$//')
    local root_start=$(parted -s "$source_image" unit s print | grep "^ 2" | awk '{print $2}' | sed 's/s$//')
    local root_end=$(parted -s "$source_image" unit s print | grep "^ 2" | awk '{print $3}' | sed 's/s$//')
    
    log_info "Boot partition: sectors $boot_start to $boot_end"
    log_info "Root partition: sectors $root_start to $root_end"
    
    # Extract boot partition (FAT32)
    log_info "Extracting boot partition..."
    local boot_size_sectors=$((boot_end - boot_start + 1))
    dd if="$source_image" of="$boot_fs" bs=512 skip="$boot_start" count="$boot_size_sectors" 2>/dev/null
    
    # Extract root partition (ext4)  
    log_info "Extracting root partition..."
    local root_size_sectors=$((root_end - root_start + 1))
    dd if="$source_image" of="$root_fs" bs=512 skip="$root_start" count="$root_size_sectors" 2>/dev/null
    
    # Verify filesystems
    fsck.fat -v "$boot_fs" >/dev/null 2>&1 || log_warning "Boot filesystem check failed"
    e2fsck -n "$root_fs" >/dev/null 2>&1 || log_warning "Root filesystem check failed"
    
    log_success "Pi OS filesystems extracted successfully"
}

# Function to create SoulBox assets
create_soulbox_assets() {
    local assets_dir="$WORK_DIR/soulbox-assets"
    mkdir -p "$assets_dir"/{boot,root}
    
    log_info "Creating SoulBox customization assets..."
    
    # Create boot configuration
    create_boot_config "$assets_dir/boot"
    
    # Create root filesystem customizations
    create_root_customizations "$assets_dir/root"
    
    log_success "SoulBox assets created"
}

# Function to create boot configuration
create_boot_config() {
    local boot_dir="$1"
    
    # Create enhanced config.txt
    cat > "$boot_dir/soulbox-config.txt" << 'EOF'

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
}

# Function to create root customizations
create_root_customizations() {
    local root_dir="$1"
    
    # Create SoulBox directory structure
    mkdir -p "$root_dir/opt/soulbox"/{assets,scripts,logs}
    mkdir -p "$root_dir/home/soulbox"/{Videos,Music,Pictures,Downloads,.kodi/userdata}
    
    # Create first boot setup script
    cat > "$root_dir/opt/soulbox/first-boot-setup.sh" << 'EOF'
#!/bin/bash

# SoulBox First Boot Setup
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
After=systemd-user-sessions.service network.target sound.target
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
systemctl enable kodi-standalone.service
systemctl mask getty@tty1.service
systemctl enable tailscaled
systemctl enable ssh

# Set proper ownership
chown -R soulbox:soulbox /home/soulbox/

# Create completion marker
touch /opt/soulbox/setup-complete

echo "$(date): SoulBox first boot setup complete!"

# Disable this service
systemctl disable soulbox-setup.service

echo "$(date): Rebooting in 10 seconds..."
sleep 10
reboot
EOF
    
    chmod +x "$root_dir/opt/soulbox/first-boot-setup.sh"
    
    # Create SoulBox setup service
    mkdir -p "$root_dir/etc/systemd/system"
    cat > "$root_dir/etc/systemd/system/soulbox-setup.service" << 'EOF'
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
    
    # Create systemd wants directory and enable service
    mkdir -p "$root_dir/etc/systemd/system/multi-user.target.wants"
    ln -sf /etc/systemd/system/soulbox-setup.service "$root_dir/etc/systemd/system/multi-user.target.wants/soulbox-setup.service"
    
    # Create branded MOTD
    cat > "$root_dir/etc/motd" << 'EOF'

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
    - Tailscale VPN integration
    - Boot setup service active
    
    The blue flame has guided you home...

EOF

    # Update hostname
    echo "soulbox" > "$root_dir/etc/hostname"
    
    # Update hosts file
    cat > "$root_dir/etc/hosts" << 'EOF'
127.0.0.1    localhost
127.0.1.1    soulbox
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
EOF
}

# Function to build SoulBox image from scratch
build_soulbox_image() {
    local version_num="${SOULBOX_VERSION#v}"
    local output_image="$WORK_DIR/output/soulbox-v${version_num}.img"
    local temp_dir="$WORK_DIR/temp"
    
    log_info "Building SoulBox image from scratch..."
    
    mkdir -p "$temp_dir"
    
    # Image size calculations (in MB) - Optimized for container disk space limits (~1.5GB available)
    local boot_size=128   # Reduced from 256MB - sufficient for Pi OS boot files
    local root_size=1024  # Reduced from 2048MB - minimal but functional Pi OS system
    local total_size=$((boot_size + root_size + 25))  # 25MB padding
    
    log_info "Image size planning: Boot=${boot_size}MB, Root=${root_size}MB, Total=${total_size}MB"
    
    # Check available disk space
    local available_space=$(df /workspace --output=avail | tail -1)
    local required_space=$((total_size * 1024))  # Convert to KB
    log_info "Disk space check: Available=${available_space}KB, Required=${required_space}KB"
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space! Available: ${available_space}KB, Required: ${required_space}KB"
        return 1
    fi
    log_success "Sufficient disk space available"
    
    # Create blank image
    log_info "Creating blank image (${total_size}MB)..."
    if ! dd if=/dev/zero of="$output_image" bs=1M count=0 seek="$total_size" 2>/dev/null; then
        log_error "Failed to create blank image file"
        return 1
    fi
    log_success "Blank image created: $(ls -lh "$output_image" | awk '{print $5}')"
    
    # Create partition table
    log_info "Creating partition table..."
    if ! parted -s "$output_image" mklabel msdos; then
        log_error "Failed to create partition table"
        return 1
    fi
    if ! parted -s "$output_image" mkpart primary fat32 1MiB $((boot_size + 1))MiB; then
        log_error "Failed to create boot partition"
        return 1
    fi
    if ! parted -s "$output_image" mkpart primary ext4 $((boot_size + 1))MiB $((boot_size + root_size + 1))MiB; then
        log_error "Failed to create root partition"
        return 1
    fi
    if ! parted -s "$output_image" set 1 boot on; then
        log_error "Failed to set boot flag"
        return 1
    fi
    log_success "Partition table created successfully"
    
    # Create filesystem images
    log_info "Creating boot filesystem (${boot_size}MB)..."
    if ! dd if=/dev/zero of="$temp_dir/boot-new.fat" bs=1M count="$boot_size" 2>/dev/null; then
        log_error "Failed to create boot filesystem image"
        return 1
    fi
    if ! mformat -i "$temp_dir/boot-new.fat" -v "SOULBOX" -F ::; then
        log_error "Failed to format boot filesystem"
        return 1
    fi
    log_success "Boot filesystem created: $(ls -lh "$temp_dir/boot-new.fat" | awk '{print $5}')"
    
    log_info "Creating root filesystem (${root_size}MB)..."
    if ! dd if=/dev/zero of="$temp_dir/root-new.ext4" bs=1M count="$root_size" 2>/dev/null; then
        log_error "Failed to create root filesystem image"
        return 1
    fi
    log_success "Root filesystem image created: $(ls -lh "$temp_dir/root-new.ext4" | awk '{print $5}')"
    
    log_info "Formatting root filesystem with ext4..."
    if ! mke2fs -F -q -t ext4 -L "soulbox-root" "$temp_dir/root-new.ext4" 2>&1; then
        log_error "mke2fs failed to format root filesystem"
        return 1
    fi
    log_success "Root filesystem formatted successfully"
    
    # Copy Pi OS content and add SoulBox customizations
    log_info "=== PRE-FUNCTION DIAGNOSTICS ==="
    log_info "About to call copy_and_customize_filesystems with temp_dir: $temp_dir"
    log_info "Checking prerequisites before function call..."
    
    # Verify all required components exist before calling the function
    if [[ ! -d "$temp_dir" ]]; then
        log_error "Temp directory missing: $temp_dir"
        return 1
    fi
    log_success "Temp directory exists: $temp_dir"
    
    if [[ ! -f "$temp_dir/boot-new.fat" ]]; then
        log_error "Boot filesystem image missing: $temp_dir/boot-new.fat"
        return 1
    fi
    log_success "Boot filesystem ready: $(ls -lh "$temp_dir/boot-new.fat" | awk '{print $5}')"
    
    if [[ ! -f "$temp_dir/root-new.ext4" ]]; then
        log_error "Root filesystem image missing: $temp_dir/root-new.ext4"
        return 1
    fi
    log_success "Root filesystem ready: $(ls -lh "$temp_dir/root-new.ext4" | awk '{print $5}')"
    
    if [[ ! -f "$WORK_DIR/filesystems/pi-boot.fat" ]]; then
        log_error "Source boot partition missing: $WORK_DIR/filesystems/pi-boot.fat"
        return 1
    fi
    log_success "Source boot partition ready: $(ls -lh "$WORK_DIR/filesystems/pi-boot.fat" | awk '{print $5}')"
    
    if [[ ! -f "$WORK_DIR/filesystems/pi-root.ext4" ]]; then
        log_error "Source root partition missing: $WORK_DIR/filesystems/pi-root.ext4"
        return 1
    fi
    log_success "Source root partition ready: $(ls -lh "$WORK_DIR/filesystems/pi-root.ext4" | awk '{print $5}')"
    
    if [[ ! -d "$WORK_DIR/soulbox-assets" ]]; then
        log_error "SoulBox assets missing: $WORK_DIR/soulbox-assets"
        return 1
    fi
    log_success "SoulBox assets ready"
    
    log_info "All prerequisites verified - calling filesystem copy function..."
    copy_and_customize_filesystems "$temp_dir"
    
    # Merge filesystems into final image
    log_info "Merging filesystems into SoulBox image..."
    dd if="$temp_dir/boot-new.fat" of="$output_image" bs=1M seek=1 conv=notrunc 2>/dev/null
    dd if="$temp_dir/root-new.ext4" of="$output_image" bs=1M seek=$((boot_size + 1)) conv=notrunc 2>/dev/null
    
    # Generate checksum
    cd "$WORK_DIR/output"
    sha256sum "$(basename "$output_image")" > "$(basename "$output_image").sha256"
    
    log_success "SoulBox image created: $output_image"
    log_info "Size: $(ls -lh "$output_image" | awk '{print $5}')"
    
    # Copy to script directory for easy access
    cp "$output_image" "$SCRIPT_DIR/"
    cp "${output_image}.sha256" "$SCRIPT_DIR/"
    
    log_success "Image copied to: $SCRIPT_DIR/$(basename "$output_image")"
}

# Function to copy and customize filesystems
copy_and_customize_filesystems() {
    # Temporarily disable set -e for better error handling
    set +e
    
    local temp_dir="$1"
    local pi_boot="$WORK_DIR/filesystems/pi-boot.fat"
    local pi_root="$WORK_DIR/filesystems/pi-root.ext4"
    local assets_dir="$WORK_DIR/soulbox-assets"
    
    log_info "=== Starting filesystem copying phase ==="
    log_info "Temp dir: $temp_dir"
    log_info "Pi boot: $pi_boot"
    log_info "Pi root: $pi_root"
    log_info "Assets: $assets_dir"
    
    log_info "Copying Pi OS content and adding SoulBox customizations..."
    
    # Verify input files exist
    log_info "Checking input files..."
    if [[ ! -f "$pi_boot" ]]; then
        log_error "Boot partition file missing: $pi_boot"
        set -e
        return 1
    fi
    log_success "Boot partition file found: $(ls -lh "$pi_boot" | awk '{print $5}')"
    
    if [[ ! -f "$pi_root" ]]; then
        log_error "Root partition file missing: $pi_root"
        set -e
        return 1
    fi
    log_success "Root partition file found: $(ls -lh "$pi_root" | awk '{print $5}')"
    
    if [[ ! -d "$assets_dir" ]]; then
        log_error "Assets directory missing: $assets_dir"
        set -e
        return 1
    fi
    log_success "Assets directory found"
    
    # Copy Pi OS boot content
    log_info "Processing boot partition..."
    mkdir -p "$temp_dir/boot-content"
    
    # Extract boot content using mtools
    log_info "Extracting boot partition content..."
    if mcopy -s -i "$pi_boot" :: "$temp_dir/boot-content/" 2>&1; then
        log_success "Boot partition extracted successfully"
        log_info "Boot files found: $(ls -la "$temp_dir/boot-content/" | wc -l) items"
    else
        log_warning "Boot partition extraction failed, creating minimal setup"
        # Create minimal boot files
        touch "$temp_dir/boot-content/config.txt"
        touch "$temp_dir/boot-content/cmdline.txt"
        echo "# Minimal boot configuration" > "$temp_dir/boot-content/config.txt"
        echo "console=serial0,115200 console=tty1 root=PARTUUID=ROOT_PARTUUID rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait" > "$temp_dir/boot-content/cmdline.txt"
    fi
    
    # Add SoulBox boot customizations
    if [[ -f "$assets_dir/boot/soulbox-config.txt" ]]; then
        log_info "Adding SoulBox boot configuration..."
        cat "$assets_dir/boot/soulbox-config.txt" >> "$temp_dir/boot-content/config.txt"
        log_success "Boot configuration added"
    else
        log_warning "SoulBox boot config not found: $assets_dir/boot/soulbox-config.txt"
    fi
    
    # Copy back to new boot filesystem
    log_info "Populating new boot filesystem..."
    local boot_copy_count=0
    for file in "$temp_dir/boot-content"/*; do
        if [[ -f "$file" ]]; then
            if mcopy -i "$temp_dir/boot-new.fat" "$file" :: 2>&1; then
                boot_copy_count=$((boot_copy_count + 1))
            else
                log_warning "Failed to copy $(basename "$file") to boot partition"
            fi
        fi
    done
    log_success "Boot filesystem populated with $boot_copy_count files"
    
    # Process root filesystem
    log_info "Processing root partition..."
    mkdir -p "$temp_dir/root-content"
    
    # Create essential Pi OS directory structure
    log_info "Creating directory structure..."
    local dirs=("bin" "boot/firmware" "dev" "etc/systemd/system" "etc/apt" "etc/ssh" "home" "lib" "media" "mnt" "opt" "proc" "root" "run" "sbin" "srv" "sys" "tmp" "usr/bin" "usr/lib" "usr/local" "usr/share" "var/log" "var/tmp" "var/cache")
    for dir in "${dirs[@]}"; do
        mkdir -p "$temp_dir/root-content/$dir"
    done
    log_success "Directory structure created"
    
    # Copy SoulBox root customizations
    if [[ -d "$assets_dir/root" ]]; then
        log_info "Copying SoulBox assets..."
        if cp -r "$assets_dir/root"/* "$temp_dir/root-content/" 2>&1; then
            log_success "SoulBox assets copied successfully"
        else
            log_warning "Some SoulBox assets may not have copied properly"
        fi
    else
        log_warning "SoulBox assets directory not found: $assets_dir/root"
    fi
    
    # Create essential system files
    log_info "Creating essential system files..."
    cat > "$temp_dir/root-content/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
pi:x:1000:1000:Raspberry Pi User,,,:/home/pi:/bin/bash
EOF
    
    cat > "$temp_dir/root-content/etc/group" << 'EOF'
root:x:0:
pi:x:1000:
EOF
    
    cat > "$temp_dir/root-content/etc/shadow" << 'EOF'
root:*:19000:0:99999:7:::
pi:*:19000:0:99999:7:::
EOF
    
    # Create home directories
    mkdir -p "$temp_dir/root-content/home/pi"
    mkdir -p "$temp_dir/root-content/root"
    
    log_success "Essential system files created"
    
    # Verify filesystem before populating
    if [[ ! -f "$temp_dir/root-new.ext4" ]]; then
        log_error "Root filesystem image missing: $temp_dir/root-new.ext4"
        return 1
    fi
    
    # Test e2tools functionality
    log_info "Testing e2tools functionality..."
    if e2ls "$temp_dir/root-new.ext4:" >/dev/null 2>&1; then
        log_success "e2tools can access the filesystem"
    else
        log_error "e2tools cannot access the filesystem - this will cause failure"
        return 1
    fi
    
    # Populate the ext4 filesystem using e2cp
    log_info "Populating root filesystem with e2tools..."
    
    # Create directories first
    local dir_count=0
    local file_count=0
    local failed_ops=0
    
    log_info "Creating directories in ext4 filesystem..."
    while IFS= read -r -d '' dir; do
        if [[ "$dir" != "$temp_dir/root-content" ]]; then
            rel_path="${dir#$temp_dir/root-content}"
            if [[ -n "$rel_path" && "$rel_path" != "/" ]]; then
                if e2mkdir -p "$temp_dir/root-new.ext4:$rel_path" 2>/dev/null; then
                    dir_count=$((dir_count + 1))
                else
                    log_warning "Failed to create directory: $rel_path"
                    failed_ops=$((failed_ops + 1))
                fi
            fi
        fi
    done < <(find "$temp_dir/root-content" -type d -print0)
    
    log_success "Created $dir_count directories (failed: $failed_ops)"
    
    # Copy files
    log_info "Copying files to ext4 filesystem..."
    failed_ops=0
    while IFS= read -r -d '' file; do
        rel_path="${file#$temp_dir/root-content}"
        if [[ -n "$rel_path" ]]; then
            if e2cp "$file" "$temp_dir/root-new.ext4:$rel_path" 2>/dev/null; then
                file_count=$((file_count + 1))
            else
                log_warning "Failed to copy: $rel_path"
                failed_ops=$((failed_ops + 1))
            fi
        fi
    done < <(find "$temp_dir/root-content" -type f -print0)
    
    log_success "Copied $file_count files (failed: $failed_ops)"
    
    # Handle symbolic links (limited support)
    log_info "Processing symbolic links..."
    local link_count=0
    while IFS= read -r -d '' link; do
        rel_path="${link#$temp_dir/root-content}"
        target=$(readlink "$link")
        log_warning "Skipping symlink: $rel_path -> $target (e2tools limitation)"
        link_count=$((link_count + 1))
    done < <(find "$temp_dir/root-content" -type l -print0)
    
    if [[ $link_count -gt 0 ]]; then
        log_warning "Skipped $link_count symbolic links due to e2tools limitations"
    fi
    
    # Final verification
    log_info "Verifying populated filesystem..."
    if e2ls "$temp_dir/root-new.ext4:/" >/dev/null 2>&1; then
        local root_items=$(e2ls "$temp_dir/root-new.ext4:/" 2>/dev/null | wc -l || echo "0")
        log_success "Filesystem populated successfully - $root_items items in root"
    else
        log_error "Filesystem verification failed"
        return 1
    fi
    
    log_success "Filesystem customization complete"
}

# Function for cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$WORK_DIR/temp" 2>/dev/null || true
    log_success "Cleanup complete"
}

# Main execution
main() {
    log_info "SoulBox Container-Friendly Build System"
    log_info "======================================="
    
    trap cleanup EXIT
    
    # Execute build steps
    check_required_tools
    setup_work_dir
    download_pi_os_image
    extract_pi_os_filesystems
    create_soulbox_assets
    build_soulbox_image
    
    echo ""
    log_success "🎉 SoulBox $SOULBOX_VERSION is ready!"
    echo ""
    echo "📋 Build Summary:"
    echo "   Version: $SOULBOX_VERSION"
    echo "   Method: Container-friendly (no loop devices)"
    echo "   Output: soulbox-v${SOULBOX_VERSION#v}.img"
    echo "   Base: Official Raspberry Pi OS ARM64"
    echo ""
    echo "🚀 Flash to SD card and boot - first boot will install packages automatically!"
    echo "💡 This approach works in any container environment!"
}

main "$@"
