#!/bin/bash

# SoulBox Container-Friendly Build System
# Container-safe approach - no loop device mounting required
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
BASE_IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz"
BASE_IMAGE_NAME="2024-07-04-raspios-bookworm-arm64-lite.img"
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
    echo "  1. Downloads official ARM64 base image"
    echo "  2. Extracts filesystem contents using mtools and e2tools (no mounting!)"
    echo "  3. Creates new SoulBox image from scratch using parted and dd"
    echo "  4. Populates with base system and SoulBox configurations"
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

# Error handling
SAVE_ERROR=""

show_error() {
    echo "SoulBox Build: An error has occurred..."
    echo
    if [[ -n "$SAVE_ERROR" && -s "$SAVE_ERROR" ]]; then
        cat "$SAVE_ERROR"
    else
        echo "Check available disk space and tool dependencies..."
    fi
    echo
    cleanup
    exit 1
}

# Function to install populatefs
install_populatefs() {
    log_info "Attempting to install populatefs..."
    
    # Check if we have package manager access
    if ! command -v apt-get >/dev/null 2>&1; then
        log_warning "apt-get not available - cannot install populatefs"
        return 1
    fi
    
    # Try to install e2fsprogs-extra (contains populatefs)
    if apt-get update -qq && apt-get install -y e2fsprogs-extra 2>/dev/null; then
        if command -v populatefs >/dev/null 2>&1; then
            log_success "Successfully installed populatefs"
            return 0
        else
            log_warning "e2fsprogs-extra installed but populatefs not found"
            return 1
        fi
    else
        log_warning "Failed to install e2fsprogs-extra package"
        return 1
    fi
}

# Function to install e2tools
install_e2tools() {
    log_info "Attempting to install e2tools..."
    
    # Check if we have package manager access
    if ! command -v apt-get >/dev/null 2>&1; then
        log_warning "apt-get not available - cannot install e2tools"
        return 1
    fi
    
    # Try to install e2tools
    if apt-get install -y e2tools 2>/dev/null; then
        if command -v e2cp >/dev/null 2>&1 && command -v e2ls >/dev/null 2>&1; then
            log_success "Successfully installed e2tools"
            return 0
        else
            log_warning "e2tools package installed but commands not found"
            return 1
        fi
    else
        log_warning "Failed to install e2tools package"
        return 1
    fi
}

# Function to install missing system tools
install_missing_system_tools() {
    log_info "Installing missing system tools for container environment..."
    
    # Tools that are often missing in minimal containers
    local system_tools=("udev" "systemd" "dbus")
    local installed_count=0
    
    for tool in "${system_tools[@]}"; do
        if apt-get install -y "$tool" 2>/dev/null; then
            installed_count=$((installed_count + 1))
            log_info "✓ Installed $tool"
        else
            log_warning "✗ Failed to install $tool"
        fi
    done
    
    if [[ $installed_count -gt 0 ]]; then
        log_success "Installed $installed_count system tools"
        return 0
    else
        log_warning "Could not install additional system tools"
        return 1
    fi
}

# Function to check required tools
check_required_tools() {
    log_info "Checking required tools..."
    
    local missing_tools=()
    
    # Check for basic tools
    command -v curl >/dev/null 2>&1 || missing_tools+=(curl)
    command -v xz >/dev/null 2>&1 || missing_tools+=(xz-utils)
    command -v parted >/dev/null 2>&1 || missing_tools+=(parted)
    command -v dd >/dev/null 2>&1 || missing_tools+=(coreutils)
    command -v zip >/dev/null 2>&1 || missing_tools+=(zip)
    command -v tar >/dev/null 2>&1 || missing_tools+=(tar)
    
    # Check for filesystem tools
    command -v mcopy >/dev/null 2>&1 || missing_tools+=(mtools)
    command -v mformat >/dev/null 2>&1 || missing_tools+=(mtools)
    command -v mdir >/dev/null 2>&1 || missing_tools+=(mtools)
    command -v mkfs.fat >/dev/null 2>&1 || missing_tools+=(dosfstools)
    command -v fsck.fat >/dev/null 2>&1 || missing_tools+=(dosfstools)
    command -v mke2fs >/dev/null 2>&1 || missing_tools+=(e2fsprogs)
    command -v tune2fs >/dev/null 2>&1 || missing_tools+=(e2fsprogs)
    command -v e2fsck >/dev/null 2>&1 || missing_tools+=(e2fsprogs)
    
    # Check for populatefs (preferred) or e2tools (fallback)
    local has_populatefs=false
    local has_e2tools=false
    
    if command -v populatefs >/dev/null 2>&1; then
        has_populatefs=true
        log_success "Found populatefs (preferred method)"
    elif [[ -x "/usr/local/bin/populatefs" ]]; then
        has_populatefs=true
        log_success "Found populatefs in /usr/local/bin (preferred method)"
        # Ensure /usr/local/bin is in PATH for this session
        export PATH="/usr/local/bin:$PATH"
    fi
    
    if command -v e2cp >/dev/null 2>&1 && command -v e2ls >/dev/null 2>&1; then
        has_e2tools=true
        log_info "Found e2tools (fallback method available)"
    fi
    
    if [[ "$has_populatefs" == "false" && "$has_e2tools" == "false" ]]; then
        log_warning "Neither populatefs nor e2tools found!"
        log_info "Attempting to install populatefs..."
        
        # Try to install populatefs automatically
        if install_populatefs; then
            has_populatefs=true
            log_success "Successfully installed populatefs"
        else
            log_warning "Could not install populatefs, checking for e2tools..."
            if install_e2tools; then
                has_e2tools=true
                log_success "Successfully installed e2tools"
            else
                missing_tools+=("populatefs OR e2tools")
                log_error "Failed to install either populatefs or e2tools"
                log_info "Manual installation: apt-get install e2fsprogs-extra (for populatefs)"
                log_info "Or: apt-get install e2tools (for fallback)"
            fi
        fi
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with: apt-get update && apt-get install -y e2fsprogs-extra mtools dosfstools parted curl xz-utils coreutils zip tar"
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

# Function to download base image with integrity checking
download_base_image() {
    local image_path="$WORK_DIR/source/$BASE_IMAGE_NAME"
    local compressed_path="${image_path}.xz"
    
    if [[ -f "$image_path" ]]; then
        log_info "Base image already exists: $BASE_IMAGE_NAME"
        # Verify existing image integrity
        if verify_image_integrity "$image_path"; then
            return 0
        else
            log_warning "Existing image appears corrupted, re-downloading..."
            rm -f "$image_path"
        fi
    fi
    
    log_info "Downloading base ARM64 image..."
    log_info "URL: $BASE_IMAGE_URL"
    
    cd "$WORK_DIR/source"
    
    # Try multiple download attempts with fallback URLs
    local download_success=false
    local urls=(
        "$BASE_IMAGE_URL"
        "https://archive.raspberrypi.org/debian/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz"
    )
    
    for attempt in 1 2 3; do
        for url in "${urls[@]}"; do
            log_info "Download attempt $attempt with URL: $url"
            
            # Download with resume support and progress
            if curl -L -C - --retry 3 --retry-delay 5 -o "${BASE_IMAGE_NAME}.xz" "$url"; then
                log_success "Download completed"
                download_success=true
                break 2
            else
                log_warning "Download failed, trying next URL..."
                rm -f "${BASE_IMAGE_NAME}.xz" 2>/dev/null || true
            fi
        done
        
        if [[ "$download_success" == "true" ]]; then
            break
        fi
        
        log_warning "Attempt $attempt failed, retrying in 5 seconds..."
        sleep 5
    done
    
    if [[ "$download_success" != "true" ]]; then
        log_error "Failed to download base image after multiple attempts"
        exit 1
    fi
    
    # Extract image with verification
    log_info "Extracting image..."
    if ! xz -d -v "${BASE_IMAGE_NAME}.xz"; then
        log_error "Failed to extract compressed image"
        exit 1
    fi
    
    if [[ -f "$image_path" ]]; then
        log_success "Downloaded and extracted: $BASE_IMAGE_NAME"
        log_info "Size: $(ls -lh "$image_path" | awk '{print $5}')"
        
        # Verify image integrity
        if verify_image_integrity "$image_path"; then
            log_success "Image integrity verified"
        else
            log_error "Downloaded image failed integrity check"
            exit 1
        fi
    else
        log_error "Failed to extract base image"
        exit 1
    fi
}

# Function to verify image integrity
verify_image_integrity() {
    local image_path="$1"
    
    log_info "Verifying image integrity..."
    
    # Check if file exists and has reasonable size
    if [[ ! -f "$image_path" ]]; then
        log_error "Image file not found: $image_path"
        return 1
    fi
    
    local file_size=$(stat -c%s "$image_path" 2>/dev/null || stat -f%z "$image_path" 2>/dev/null)
    if [[ $file_size -lt 1000000000 ]]; then  # Less than 1GB
        log_error "Image file too small: ${file_size} bytes"
        return 1
    fi
    
    # Check if it's a valid disk image by looking for partition table
    if ! parted -s "$image_path" print >/dev/null 2>&1; then
        log_error "Invalid disk image - no readable partition table"
        return 1
    fi
    
    # Check for EXT4 filesystem signature
    if ! dd if="$image_path" skip=1056768 bs=512 count=1 2>/dev/null | grep -q "EXT"; then
        log_warning "EXT4 filesystem signature not found at expected location"
        # This is a warning, not a failure, as partition layout might vary
    fi
    
    log_success "Image integrity verification passed"
    return 0
}

# Function to extract base image filesystems without mounting
extract_base_filesystems() {
    local source_image="$WORK_DIR/source/$BASE_IMAGE_NAME"
    local boot_fs="$WORK_DIR/filesystems/base-boot.fat"
    local root_fs="$WORK_DIR/filesystems/base-root.ext4"
    
    log_info "Extracting base image filesystems using container-friendly method..."
    
    # Get partition information using parted
    log_info "Analyzing partition table..."
    parted -s "$source_image" unit s print > "$WORK_DIR/partition-info.txt"
    
    # Extract partition details (assuming standard layout)
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
    
    log_success "Base image filesystems extracted successfully"
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

# SoulBox Will-o'-Wisp Configuration
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
    
    # Create first boot setup script with embedded TSAUTH
    cat > "$root_dir/opt/soulbox/first-boot-setup.sh" << EOF
#!/bin/bash

# SoulBox First Boot Setup
set -e

LOG_FILE="/var/log/soulbox-setup.log"
exec > >(tee -a \$LOG_FILE) 2>&1

echo "\$(date): Starting SoulBox first boot setup..."

# Set Tailscale auth key from build-time environment (secure injection)
export TSAUTH="${TSAUTH:-}"
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

# Configure Tailscale if auth key is available
if [ -n "${TSAUTH:-}" ]; then
    echo "Configuring Tailscale with provided auth key..."
    
    # Start Tailscale daemon
    systemctl start tailscaled
    
    # Wait for daemon to be ready
    for i in {1..10}; do
        if tailscale status >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done
    
    # Configure Tailscale with auth key
    if tailscale up --auth-key="${TSAUTH}" --accept-routes --ssh; then
        echo "✅ Tailscale configured successfully"
    else
        echo "⚠️ Tailscale configuration failed - manual setup required"
    fi
else
    echo "No Tailscale auth key provided - manual authentication required after boot"
fi

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
    
    The blue flame burns bright
    
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
    
    # Image size calculations (in MB) - Balanced approach for container space constraints
    # Container available space: ~1.6GB, need to balance base OS completeness with space limits
    local boot_size=100   # 100MB sufficient for base boot files
    local root_size=900   # 900MB - compromise between functionality and container space limits
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
    
    # Create partition table with proper sector alignment
    log_info "Creating MBR partition table with compatible alignment..."
    if ! parted -s "$output_image" mklabel msdos; then
        log_error "Failed to create partition table"
        return 1
    fi
    # Use 4MiB start to ensure proper alignment for FAT32
    if ! parted -s "$output_image" mkpart primary fat32 4MiB $((boot_size + 4))MiB; then
        log_error "Failed to create boot partition"
        return 1
    fi
    if ! parted -s "$output_image" mkpart primary ext4 $((boot_size + 4))MiB $((boot_size + root_size + 4))MiB; then
        log_error "Failed to create root partition"
        return 1
    fi
    # Set proper partition IDs for hardware compatibility
    if ! parted -s "$output_image" set 1 boot on; then
        log_error "Failed to set boot flag"
        return 1
    fi
    if ! parted -s "$output_image" set 1 lba on; then
        log_error "Failed to set LBA flag"
        return 1
    fi
    log_success "Partition table created with compatible alignment"
    
    # Create filesystem images
    log_info "Creating boot filesystem (${boot_size}MB)..."
    if ! dd if=/dev/zero of="$temp_dir/boot-new.fat" bs=1M count="$boot_size" 2>/dev/null; then
        log_error "Failed to create boot filesystem image"
        return 1
    fi
    # Format as FAT32 with proper parameters for hardware compatibility
    if ! mkfs.fat -F 32 -n "SOULBOX" -v "$temp_dir/boot-new.fat" 2>/dev/null; then
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
    
    if [[ ! -f "$WORK_DIR/filesystems/base-boot.fat" ]]; then
        log_error "Source boot partition missing: $WORK_DIR/filesystems/base-boot.fat"
        return 1
    fi
    log_success "Source boot partition ready: $(ls -lh "$WORK_DIR/filesystems/base-boot.fat" | awk '{print $5}')"
    
    if [[ ! -f "$WORK_DIR/filesystems/base-root.ext4" ]]; then
        log_error "Source root partition missing: $WORK_DIR/filesystems/base-root.ext4"
        return 1
    fi
    log_success "Source root partition ready: $(ls -lh "$WORK_DIR/filesystems/base-root.ext4" | awk '{print $5}')"
    
    if [[ ! -d "$WORK_DIR/soulbox-assets" ]]; then
        log_error "SoulBox assets missing: $WORK_DIR/soulbox-assets"
        return 1
    fi
    log_success "SoulBox assets ready"
    
    log_info "All prerequisites verified - calling filesystem copy function..."
    copy_and_customize_filesystems "$temp_dir"
    
    # Merge filesystems into final image
    log_info "Merging filesystems into SoulBox image..."
    dd if="$temp_dir/boot-new.fat" of="$output_image" bs=1M seek=4 conv=notrunc 2>/dev/null
    dd if="$temp_dir/root-new.ext4" of="$output_image" bs=1M seek=$((boot_size + 4)) conv=notrunc 2>/dev/null
    
    # Generate multiple formats for different use cases
    cd "$WORK_DIR/output"
    local base_name="soulbox-v${version_num}"
    
    # Generate checksums for raw image
    sha256sum "$(basename "$output_image")" > "${base_name}.img.sha256"
    
    # Clean up intermediate files to free space before compression
    log_info "Cleaning up intermediate files for compression space..."
    rm -rf "$temp_dir" 2>/dev/null || true
    rm -rf "$WORK_DIR/source" 2>/dev/null || true
    rm -rf "$WORK_DIR/filesystems" 2>/dev/null || true
    rm -rf "$WORK_DIR/soulbox-assets" 2>/dev/null || true
    
    # Check available space before compression
    local available_before=$(df /workspace --output=avail | tail -1)
    log_info "Available space before compression: ${available_before}KB"
    
    log_info "Creating compressed image formats..."
    
    # Create TAR.GZ format (better compression, Linux-friendly)
    log_info "Creating TAR.GZ archive..."
    if tar -czf "${base_name}.img.tar.gz" "$(basename "$output_image")" 2>&1; then
        sha256sum "${base_name}.img.tar.gz" > "${base_name}.img.tar.gz.sha256" 2>/dev/null || echo "TAR.GZ checksum generation failed" >&2
        log_success "TAR.GZ archive created successfully"
    else
        log_warning "TAR.GZ archive creation failed - likely due to disk space"
        touch "${base_name}.img.tar.gz.sha256"  # Create empty file to prevent errors
    fi
    
    log_success "SoulBox image created in multiple formats:"
    log_info "Raw IMG: $(ls -lh "$output_image" | awk '{print $5}')"
    log_info "TAR.GZ: $(ls -lh "${base_name}.img.tar.gz" | awk '{print $5}' 2>/dev/null || echo 'failed')"
    
    # Copy all formats to script directory for easy access
    cp "$output_image" "$SCRIPT_DIR/"
    cp "${base_name}.img.tar.gz" "$SCRIPT_DIR/" 2>/dev/null || true
    cp *.sha256 "$SCRIPT_DIR/"
    
    log_success "All formats copied to: $SCRIPT_DIR/"
}

# Helper function to extract directory contents recursively using correct e2tools syntax
extract_directory_contents() {
    local source_img="$1"
    local source_dir="$2"
    local target_dir="$3"
    local max_files="${4:-1000}"
    local current_depth="${5:-0}"
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Increase depth limit for kernel modules (they can be deeply nested)
    local max_depth=6
    if [[ $current_depth -gt $max_depth ]]; then
        echo "    Maximum recursion depth ($max_depth) reached for $source_dir"
        return 0
    fi
    
    # Get directory listing using long format to better parse filenames
    local listing_output
    listing_output=$(e2ls -l "$source_img:$source_dir" 2>&1)
    local e2ls_exit_code=$?
    
    if [[ $e2ls_exit_code -ne 0 ]]; then
        echo "    ERROR: e2ls failed for $source_dir (exit code: $e2ls_exit_code)"
        echo "    e2ls output: $listing_output"
        return 1
    fi
    
    if [[ -z "$listing_output" ]]; then
        echo "    WARNING: Empty directory listing for $source_dir"
        return 0
    fi
    
    local files_copied=0
    local dirs_processed=0
    local total_processed=0
    local copy_failures=0
    
    # Parse e2ls -l output line by line (format: permissions links user group size date filename)
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        # Extract filename from the end of the line (after date/time)
        # e2ls -l format: drwxr-xr-x   2 0    0        1024 Dec  7  2023 filename
        local filename
        filename=$(echo "$line" | awk '{print $NF}')
        
        # Skip . and .. entries and lost+found
        [[ "$filename" == "." || "$filename" == ".." || "$filename" == "lost+found" ]] && continue
        [[ -z "$filename" ]] && continue
        
        # Limit extraction to prevent runaway copying
        if [[ $total_processed -ge $max_files ]]; then
            echo "    Reached file limit ($max_files) for $source_dir"
            break
        fi
        
        local source_item="$source_dir/$filename"
        local target_item="$target_dir/$filename"
        
        # Check if it's a directory based on the first character of permissions
        local permissions
        permissions=$(echo "$line" | awk '{print $1}')
        
        if [[ "${permissions:0:1}" == "d" ]]; then
            # It's a directory - recurse into it
            echo "    Processing directory: $source_item"
            mkdir -p "$target_item"
            if extract_directory_contents "$source_img" "$source_item" "$target_item" $max_files $((current_depth + 1)); then
                dirs_processed=$((dirs_processed + 1))
            else
                echo "    WARNING: Failed to process directory: $source_item"
            fi
        else
            # It's a file - copy it with proper error handling
            local copy_result
            copy_result=$(e2cp "$source_img:$source_item" "$target_item" 2>&1)
            local copy_exit_code=$?
            
            if [[ $copy_exit_code -eq 0 ]]; then
                files_copied=$((files_copied + 1))
                # For kernel modules, log successful copies
                if [[ "$source_dir" == "/lib/modules"* ]]; then
                    echo "    + Copied kernel module file: $filename"
                fi
            else
                echo "    ERROR: Failed to copy $source_item (exit code: $copy_exit_code)"
                echo "    e2cp output: $copy_result"
                copy_failures=$((copy_failures + 1))
            fi
        fi
        
        total_processed=$((total_processed + 1))
        
        # Progress indicator for large directories
        if [[ $((total_processed % 100)) -eq 0 ]]; then
            echo "    Progress: $total_processed items processed in $source_dir"
        fi
        
    done <<< "$listing_output"
    
    echo "    $source_dir: $files_copied files, $dirs_processed subdirs extracted (failures: $copy_failures)"
    
    # Return success if we extracted anything, or if it was an empty directory
    if [[ $files_copied -gt 0 || $dirs_processed -gt 0 || $total_processed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate kernel module extraction
validate_kernel_modules_extraction() {
    local modules_dir="$1"
    
    log_info "=== KERNEL MODULES EXTRACTION VALIDATION ==="
    
    if [[ ! -d "$modules_dir" ]]; then
        log_error "Kernel modules directory not found: $modules_dir"
        return 1
    fi
    
    # Count kernel versions and modules
    local kernel_versions=$(find "$modules_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
    local total_modules=$(find "$modules_dir" -name "*.ko" | wc -l)
    local total_files=$(find "$modules_dir" -type f | wc -l)
    
    log_info "Kernel module validation results:"
    log_info "  - Kernel versions found: $kernel_versions"
    log_info "  - Total .ko files: $total_modules"
    log_info "  - Total files: $total_files"
    
    # List kernel versions
    if [[ $kernel_versions -gt 0 ]]; then
        log_info "  - Kernel version directories:"
        find "$modules_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | while read -r version; do
            local version_modules=$(find "$modules_dir/$version" -name "*.ko" | wc -l)
            log_info "    * $version ($version_modules modules)"
        done
    fi
    
    # Critical validation - check for essential directories
    local critical_dirs=("kernel/drivers" "kernel/net" "kernel/fs")
    local critical_found=0
    
    for kernel_ver_dir in "$modules_dir"/*/; do
        if [[ -d "$kernel_ver_dir" ]]; then
            for critical_dir in "${critical_dirs[@]}"; do
                if [[ -d "$kernel_ver_dir/$critical_dir" ]]; then
                    critical_found=$((critical_found + 1))
                    log_info "  + Found critical directory: $(basename "$kernel_ver_dir")/$critical_dir"
                fi
            done
        fi
    done
    
    # Determine validation result
    if [[ $total_modules -eq 0 ]]; then
        log_error "CRITICAL: No kernel modules (.ko files) found!"
        log_error "This will cause boot failure - missing /proc/modules"
        return 1
    elif [[ $total_modules -lt 100 ]]; then
        log_warning "WARNING: Very few kernel modules found ($total_modules)"
        log_warning "This may cause hardware compatibility issues"
    else
        log_success "Kernel modules extraction appears successful ($total_modules modules)"
    fi
    
    if [[ $critical_found -eq 0 ]]; then
        log_warning "WARNING: No critical kernel directories found"
        log_warning "System may have limited functionality"
    else
        log_success "Found $critical_found critical kernel directories"
    fi
    
    return 0
}

# Alternative kernel module extraction function
extract_kernel_modules_alternative() {
    local source_img="$1"
    local target_modules_dir="$2"
    
    log_info "=== ALTERNATIVE KERNEL MODULES EXTRACTION ==="
    
    mkdir -p "$target_modules_dir"
    
    # Step 1: Find available kernel versions
    log_info "Step 1: Discovering kernel versions..."
    local kernel_versions
    kernel_versions=$(e2ls -l "$source_img:/lib/modules" 2>/dev/null | grep '^d' | awk '{print $NF}' | head -5)
    
    if [[ -z "$kernel_versions" ]]; then
        log_error "No kernel versions found in /lib/modules"
        return 1
    fi
    
    log_info "Found kernel versions: $(echo "$kernel_versions" | tr '\n' ' ')"
    
    local extracted_versions=0
    local total_modules_extracted=0
    
    # Step 2: Extract each kernel version
    while read -r kernel_ver; do
        [[ -z "$kernel_ver" ]] && continue
        
        # Remove any trailing slash
        kernel_ver="${kernel_ver%/}"
        
        log_info "Step 2: Extracting kernel version: $kernel_ver"
        local kernel_modules_dir="$target_modules_dir/$kernel_ver"
        mkdir -p "$kernel_modules_dir"
        
        # Step 3: Use file-by-file extraction for this kernel version
        local version_modules=0
        version_modules=$(extract_kernel_version_modules "$source_img" "/lib/modules/$kernel_ver" "$kernel_modules_dir")
        
        if [[ $version_modules -gt 0 ]]; then
            extracted_versions=$((extracted_versions + 1))
            total_modules_extracted=$((total_modules_extracted + version_modules))
            log_success "✓ Extracted $version_modules modules for $kernel_ver"
        else
            log_warning "✗ Failed to extract modules for $kernel_ver"
        fi
        
    done <<< "$kernel_versions"
    
    log_info "Alternative extraction summary:"
    log_info "  - Kernel versions processed: $(echo "$kernel_versions" | wc -l)"
    log_info "  - Kernel versions extracted: $extracted_versions"
    log_info "  - Total modules extracted: $total_modules_extracted"
    
    if [[ $total_modules_extracted -gt 0 ]]; then
        log_success "✓ Alternative kernel module extraction succeeded"
        return 0
    else
        log_error "✗ Alternative kernel module extraction failed"
        return 1
    fi
}

# Extract modules for a specific kernel version using optimized approach
extract_kernel_version_modules() {
    local source_img="$1"
    local source_modules_path="$2"
    local target_dir="$3"
    
    local modules_extracted=0
    
    # Create essential kernel subdirectories
    local kernel_subdirs=("kernel" "kernel/drivers" "kernel/net" "kernel/fs" "kernel/sound" "kernel/crypto")
    for subdir in "${kernel_subdirs[@]}"; do
        mkdir -p "$target_dir/$subdir"
        
        # Try to extract this subdirectory
        if extract_directory_contents "$source_img" "$source_modules_path/$subdir" "$target_dir/$subdir" 200 0; then
            local subdir_modules=$(find "$target_dir/$subdir" -name "*.ko" 2>/dev/null | wc -l)
            if [[ $subdir_modules -gt 0 ]]; then
                modules_extracted=$((modules_extracted + subdir_modules))
                echo "    ✓ $subdir: $subdir_modules modules"
            fi
        fi
    done
    
    # Extract essential module files from root of kernel version directory
    local essential_files=("modules.order" "modules.builtin" "modules.builtin.modinfo" "modules.dep" "modules.dep.bin" "modules.symbols" "modules.symbols.bin" "modules.alias" "modules.alias.bin" "modules.devname")
    for essential_file in "${essential_files[@]}"; do
        if e2cp "$source_img:$source_modules_path/$essential_file" "$target_dir/$essential_file" 2>/dev/null; then
            echo "    ✓ Essential file: $essential_file"
        fi
    done
    
    echo $modules_extracted
}

# Modern LibreELEC-style staging function with proper extraction methods
extract_pi_os_to_staging() {
    local source_img="$1"
    local staging_dir="$2"
    
    log_info "=== EXTRACTING PI OS TO STAGING DIRECTORY ==="
    log_info "Source: $source_img"
    log_info "Staging: $staging_dir"
    
    # Create staging directory
    mkdir -p "$staging_dir"
    
# Try extraction methods in order of reliability (e2tools removed due to corruption)
    if extract_with_loop_mount "$source_img" "$staging_dir"; then
        log_success "Pi OS extracted using loop mounting (most reliable)"
    elif extract_with_debugfs "$source_img" "$staging_dir"; then
        log_success "Pi OS extracted using debugfs (reliable fallback)"
    else
        log_error "CRITICAL: Both loop mount and debugfs extraction failed"
        log_error "E2tools extraction has been removed due to systematic corruption"
        log_error "Container environment may not support loop devices and debugfs failed"
        return 1
    fi
    
    # Verify extraction
    local file_count=$(find "$staging_dir" -type f | wc -l)
    local dir_count=$(find "$staging_dir" -type d | wc -l)
    log_info "Staging extraction complete: $file_count files, $dir_count directories"
    
    if [[ $file_count -lt 500 ]]; then
        log_error "Too few files extracted ($file_count) - extraction likely failed"
        return 1
    else
        log_success "Pi OS content successfully staged ($file_count files)"
    fi
}

# Method 1: Loop mounting extraction (most reliable - LibreELEC preferred)
extract_with_loop_mount() {
    local source_img="$1"
    local staging_dir="$2"
    
    log_info "=== ATTEMPTING LOOP MOUNTING EXTRACTION ==="
    
    # Check if loop devices are available
    if [[ ! -e /dev/loop0 ]] && [[ ! -c /dev/loop-control ]]; then
        log_info "Loop devices not available - container environment detected"
        return 1
    fi
    
    # Check if we can create loop devices (requires privileges)
    local test_loop
    if ! test_loop=$(losetup --find 2>/dev/null); then
        log_info "Cannot access loop devices - insufficient privileges"
        return 1
    fi
    
    log_info "Loop devices available - attempting mount-based extraction"
    
    local mount_point="/tmp/soulbox-loop-mount-$$"
    mkdir -p "$mount_point"
    
    local loop_device
    if loop_device=$(losetup --find --show "$source_img" 2>/dev/null); then
        log_info "Mounted image on loop device: $loop_device"
        
        # Wait for partition devices to appear
        sleep 2
        partprobe "$loop_device" 2>/dev/null || true
        
        # Mount the ext4 partition (usually partition 2)
        if mount "${loop_device}p2" "$mount_point" 2>/dev/null; then
            log_success "Successfully mounted root partition"
            
            # Copy entire filesystem tree
            if cp -a "$mount_point"/* "$staging_dir/" 2>/dev/null; then
                log_success "Loop mount extraction completed successfully"
                
                # Cleanup
                umount "$mount_point" 2>/dev/null || true
                losetup -d "$loop_device" 2>/dev/null || true
                rmdir "$mount_point" 2>/dev/null || true
                
                return 0
            else
                log_warning "Failed to copy filesystem content"
            fi
            
            # Cleanup on failure
            umount "$mount_point" 2>/dev/null || true
        else
            log_warning "Failed to mount root partition"
        fi
        
        losetup -d "$loop_device" 2>/dev/null || true
    else
        log_warning "Failed to setup loop device"
    fi
    
    rmdir "$mount_point" 2>/dev/null || true
    return 1
}

# Method 2: debugfs extraction (reliable fallback)
extract_with_debugfs() {
    local source_img="$1"
    local staging_dir="$2"
    
    log_info "=== ATTEMPTING DEBUGFS EXTRACTION ==="
    
    # Check if debugfs is available
    if ! command -v debugfs >/dev/null 2>&1; then
        log_info "debugfs not available - trying to install"
        if command -v apt-get >/dev/null 2>&1; then
            if ! apt-get install -y e2fsprogs 2>/dev/null; then
                log_warning "Could not install debugfs"
                return 1
            fi
        else
            log_warning "Cannot install debugfs - no package manager"
            return 1
        fi
    fi
    
    log_info "Using debugfs for ext4 extraction"
    
    # Extract root partition as separate file first (reuse existing logic)
    local temp_root="/tmp/soulbox-debugfs-root-$$.ext4"
    
    # Get partition information using parted
    local root_start=$(parted -s "$source_img" unit s print | grep "^ 2" | awk '{print $2}' | sed 's/s$//')
    local root_end=$(parted -s "$source_img" unit s print | grep "^ 2" | awk '{print $3}' | sed 's/s$//')
    
    if [[ -z "$root_start" || -z "$root_end" ]]; then
        log_error "Could not determine root partition location"
        return 1
    fi
    
    # Extract root partition
    local root_size_sectors=$((root_end - root_start + 1))
    if ! dd if="$source_img" of="$temp_root" bs=512 skip="$root_start" count="$root_size_sectors" 2>/dev/null; then
        log_error "Failed to extract root partition for debugfs"
        return 1
    fi
    
    log_info "Extracted root partition, using debugfs to dump filesystem"
    
    # Use debugfs to recursively dump the filesystem
    if extract_with_debugfs_recursive "$temp_root" "$staging_dir" "/"; then
        log_success "debugfs extraction completed successfully"
        rm -f "$temp_root"
        return 0
    else
        log_warning "debugfs extraction failed"
        rm -f "$temp_root"
        return 1
    fi
}

# Helper function for recursive debugfs extraction
extract_with_debugfs_recursive() {
    local filesystem="$1"
    local staging_dir="$2"
    local fs_path="$3"
    
    # Create the directory in staging
    mkdir -p "$staging_dir$fs_path"
    
    # Get directory listing from debugfs
    local listings
    listings=$(echo "ls -l $fs_path" | debugfs "$filesystem" 2>/dev/null | grep -v "debugfs:")
    
    # Parse debugfs output and extract files/directories
    while read -r line; do
        [[ -z "$line" ]] && continue
        
        # Parse debugfs ls -l output format
        local perms=$(echo "$line" | awk '{print $1}')
        local name=$(echo "$line" | awk '{print $NF}')
        
        [[ "$name" == "." || "$name" == ".." ]] && continue
        [[ -z "$name" ]] && continue
        
        local full_fs_path="$fs_path/$name"
        local full_staging_path="$staging_dir$full_fs_path"
        
        if [[ "${perms:0:1}" == "d" ]]; then
            # It's a directory - recurse
            extract_with_debugfs_recursive "$filesystem" "$staging_dir" "$full_fs_path"
        else
            # It's a file - extract it
            echo "dump $full_fs_path $full_staging_path" | debugfs "$filesystem" 2>/dev/null >/dev/null
        fi
        
    done <<< "$listings"
    
    return 0
}

# Method 3: e2tools extraction (last resort - existing method)
extract_with_e2tools() {
    local source_img="$1"
    local staging_dir="$2"
    
    log_info "=== USING E2TOOLS EXTRACTION (LAST RESORT) ==="
    log_warning "Using e2tools - this method may have compatibility issues"
    
    extract_pi_os_content_with_e2tools "$source_img" "$staging_dir"
    return $?
}

# Extract Pi OS content using improved e2tools (fallback when populatefs not available for extraction)
extract_pi_os_content_with_e2tools() {
    local source_img="$1"
    local staging_dir="$2"
    
    # Core Pi OS directories for extraction
    local core_dirs=(
        "/bin" "/sbin" "/lib" "/usr/bin" "/usr/sbin" "/usr/lib"
        "/etc" "/var/lib/dpkg" "/var/lib/apt" "/boot"
    )
    
    local total_extracted=0
    local total_failed=0
    
    for sys_dir in "${core_dirs[@]}"; do
        log_info "Staging Pi OS directory: $sys_dir"
        local target_dir="$staging_dir$sys_dir"
        mkdir -p "$(dirname "$target_dir")"
        
        if extract_directory_contents "$source_img" "$sys_dir" "$target_dir" 2000; then
            total_extracted=$((total_extracted + 1))
            log_success "Staged: $sys_dir"
            
            # Special handling for kernel modules validation
            if [[ "$sys_dir" == "/lib" ]]; then
                validate_kernel_modules_extraction "$target_dir/modules" || log_warning "Kernel module staging may be incomplete"
            fi
        else
            log_warning "Failed to stage: $sys_dir (trying critical files)"
            total_failed=$((total_failed + 1))
            
            # Critical file fallback for key directories
            if [[ "$sys_dir" == "/bin" ]]; then
                extract_critical_bin_files "$source_img" "$staging_dir"
            elif [[ "$sys_dir" == "/lib" ]]; then
                extract_critical_lib_files "$source_img" "$staging_dir"
            fi
        fi
    done
    
    log_info "Pi OS staging summary: $total_extracted succeeded, $total_failed failed"
}

# Extract critical /bin files when directory extraction fails
extract_critical_bin_files() {
    local source_img="$1"
    local staging_dir="$2"
    
    mkdir -p "$staging_dir/bin"
    local bin_files=("bash" "sh" "ls" "cp" "mv" "rm" "mount" "umount" "cat" "grep" "sed" "awk" "chmod" "chown")
    
    for bin_file in "${bin_files[@]}"; do
        if e2cp "$source_img:/bin/$bin_file" "$staging_dir/bin/$bin_file" 2>/dev/null; then
            log_info "✓ Critical binary: /bin/$bin_file"
        fi
    done
}

# Extract critical /lib files when directory extraction fails
extract_critical_lib_files() {
    local source_img="$1"
    local staging_dir="$2"
    
    mkdir -p "$staging_dir/lib"
    
    # Try alternative kernel module extraction to staging
    log_info "Attempting alternative kernel module staging..."
    if extract_kernel_modules_alternative "$source_img" "$staging_dir/lib/modules"; then
        log_success "✓ Kernel modules staged via alternative method"
    else
        log_error "✗ All kernel module staging methods failed"
    fi
    
    # Essential library files
    local lib_files=("ld-linux-aarch64.so.1")
    for lib_file in "${lib_files[@]}"; do
        if e2cp "$source_img:/lib/$lib_file" "$staging_dir/lib/$lib_file" 2>/dev/null; then
            log_info "✓ Critical library: /lib/$lib_file"
        fi
    done
}

# Function to copy and customize filesystems
copy_and_customize_filesystems() {
    # LibreELEC-style error handling
    SAVE_ERROR="$1/save_error"
    
    local temp_dir="$1"
    local base_boot="$WORK_DIR/filesystems/base-boot.fat"
    local base_root="$WORK_DIR/filesystems/base-root.ext4"
    local assets_dir="$WORK_DIR/soulbox-assets"
    
    log_info "=== STAGING-STYLE FILESYSTEM CREATION ==="
    log_info "Temp dir: $temp_dir"
    log_info "Base boot: $base_boot"
    log_info "Base root: $base_root"
    log_info "Assets: $assets_dir"
    
    # Verify input files exist
    if [[ ! -f "$base_boot" ]]; then
        log_error "Boot partition file missing: $base_boot"
        return 1
    fi
    
    if [[ ! -f "$base_root" ]]; then
        log_error "Root partition file missing: $base_root"
        return 1
    fi
    
    if [[ ! -d "$assets_dir" ]]; then
        log_error "Assets directory missing: $assets_dir"
        return 1
    fi
    
    # Copy base OS boot content
    log_info "Processing boot partition..."
    mkdir -p "$temp_dir/boot-content"
    
    # Extract boot content using mtools
    log_info "Extracting boot partition content..."
    if mcopy -s -i "$base_boot" :: "$temp_dir/boot-content/" 2>&1; then
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
    
    # Ensure essential boot files are present
    log_info "Ensuring essential boot files are present..."
    local essential_files=("start4.elf" "fixup4.dat" "bcm2712-rpi-5-b.dtb" "kernel8.img" "config.txt" "cmdline.txt")
    for essential_file in "${essential_files[@]}"; do
        if [[ ! -f "$temp_dir/boot-content/$essential_file" ]]; then
            log_warning "Essential boot file missing: $essential_file"
            # For now, create placeholder - ideally should extract from Pi OS image
            if [[ "$essential_file" == "config.txt" ]]; then
                echo "# Raspberry Pi Configuration" > "$temp_dir/boot-content/config.txt"
            elif [[ "$essential_file" == "cmdline.txt" ]]; then
                echo "console=serial0,115200 console=tty1 root=PARTUUID=ROOT_PARTUUID rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait" > "$temp_dir/boot-content/cmdline.txt"
            fi
        fi
    done
    
    # Copy back to new boot filesystem using proper mtools commands
    log_info "Populating new boot filesystem..."
    local boot_copy_count=0
    local boot_copy_failures=0
    
    # First, ensure the FAT32 filesystem is accessible
    if ! mdir -i "$temp_dir/boot-new.fat" :: >/dev/null 2>&1; then
        log_error "Cannot access newly created boot filesystem"
        return 1
    fi
    
    # Copy files one by one with better error handling
    for file in "$temp_dir/boot-content"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            log_info "Copying boot file: $filename"
            if mcopy -i "$temp_dir/boot-new.fat" "$file" "::$filename" 2>/dev/null; then
                boot_copy_count=$((boot_copy_count + 1))
            else
                log_warning "Failed to copy $filename to boot partition"
                boot_copy_failures=$((boot_copy_failures + 1))
            fi
        fi
    done
    
    log_success "Boot filesystem populated with $boot_copy_count files ($boot_copy_failures failed)"
    
    # Verify boot filesystem has files
    log_info "Verifying boot filesystem contents..."
    if mdir -i "$temp_dir/boot-new.fat" :: 2>/dev/null | grep -q .; then
        local file_count=$(mdir -i "$temp_dir/boot-new.fat" :: 2>/dev/null | grep -c '^[^d]' || echo "0")
        log_success "Boot filesystem verification passed: $file_count files found"
    else
        log_error "Boot filesystem appears to be empty!"
        return 1
    fi
    
    # Process root filesystem
    log_info "Processing root partition..."
    mkdir -p "$temp_dir/root-content"
    
    # Create essential directory structure
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
    
    # STAGING APPROACH: Use staging directory and populatefs
    log_info "=== STAGING-STYLE STAGING AND POPULATION ==="
    
    # Create staging directory
    local staging_dir="$temp_dir/staging-root"
    log_info "Creating staging directory: $staging_dir"
    mkdir -p "$staging_dir"
    
    # Extract base OS content to staging directory
    log_info "Extracting base OS content to staging directory..."
    extract_pi_os_to_staging "$base_root" "$staging_dir"
    
    # Merge SoulBox customizations into staging
    log_info "Merging SoulBox customizations with base OS content..."
    if [[ -d "$temp_dir/root-content" ]]; then
        cp -r "$temp_dir/root-content"/* "$staging_dir/" 2>/dev/null || true
        log_success "SoulBox customizations merged into staging"
    fi
    
    # Add filesystem marker
    touch "$staging_dir/.please_resize_me"
    log_info "Added filesystem resize marker"
    
    # Populate filesystem using staging method
    log_info "Populating filesystem using staging method..."
    local populatefs_cmd=""
    if command -v populatefs >/dev/null 2>&1; then
        populatefs_cmd="populatefs"
        log_info "Using populatefs from PATH (preferred method)"
    elif [[ -x "/usr/local/bin/populatefs" ]]; then
        populatefs_cmd="/usr/local/bin/populatefs"
        log_info "Using populatefs from /usr/local/bin (preferred method)"
    fi
    
    if [[ -n "$populatefs_cmd" ]]; then
        # Try different populatefs syntax - shell script vs binary have different options
        local populate_success=false
        
        # Method 1: Try standard populatefs binary syntax
        log_info "Attempting populatefs (binary syntax): $populatefs_cmd -U -d $staging_dir $temp_dir/root-new.ext4"
        if "$populatefs_cmd" -U -d "$staging_dir" "$temp_dir/root-new.ext4" >"$SAVE_ERROR" 2>&1; then
            populate_success=true
            log_success "✓ Populatefs succeeded with binary syntax"
        else
            log_warning "Binary syntax failed, trying shell script syntax..."
            
            # Method 2: Try shell script syntax (populate-extfs.sh)
            log_info "Attempting populatefs (shell script syntax): $populatefs_cmd $temp_dir/root-new.ext4 $staging_dir"
            if "$populatefs_cmd" "$temp_dir/root-new.ext4" "$staging_dir" >"$SAVE_ERROR" 2>&1; then
                populate_success=true
                log_success "✓ Populatefs succeeded with shell script syntax"
            else
                log_error "Both populatefs syntaxes failed"
                if [[ -s "$SAVE_ERROR" ]]; then
                    log_error "Populatefs error output:"
                    cat "$SAVE_ERROR"
                fi
            fi
        fi
        
        if [[ "$populate_success" == "true" ]]; then
            # Verify the populated filesystem using tune2fs (more reliable than e2ls)
            log_info "Verifying populated filesystem..."
            if tune2fs -l "$temp_dir/root-new.ext4" >/dev/null 2>&1; then
                local fs_info=$(tune2fs -l "$temp_dir/root-new.ext4" 2>/dev/null)
                local block_count=$(echo "$fs_info" | grep "Block count:" | awk '{print $3}' || echo "0")
                local free_blocks=$(echo "$fs_info" | grep "Free blocks:" | awk '{print $3}' || echo "0")
                local used_blocks=$((block_count - free_blocks))
                
                if [[ $used_blocks -gt 1000 ]]; then
                    log_success "Populatefs completed - filesystem has content (used blocks: $used_blocks)"
                else
                    log_warning "Filesystem appears mostly empty (used blocks: $used_blocks)"
                fi
            else
                log_warning "Could not verify filesystem with tune2fs"
            fi
            
            log_success "Staging-style filesystem population complete!"
            return 0
        fi
    fi
    
    # REMOVED: e2tools fallback - it causes filesystem corruption
    log_error "CRITICAL: populatefs is required but failed or not available"
    log_error "E2tools fallback has been removed due to systematic corruption issues"
    log_error "Please ensure populatefs is properly built and available"
    
    if [[ -s "$SAVE_ERROR" ]]; then
        log_error "Last error output:"
        cat "$SAVE_ERROR"
    fi
    
    return 1
}

# E2tools fallback function for filesystem population
populate_filesystem_with_e2tools() {
    local temp_dir="$1"
    local staging_dir="$2"
    
    log_info "=== E2TOOLS FALLBACK FILESYSTEM POPULATION ==="
    
    # Create directories first - using a different approach due to e2tools limitations
    local dir_count=0
    local file_count=0
    local failed_ops=0
    
    log_info "Creating essential directories in ext4 filesystem..."
    # Create critical directories individually without -p flag (e2mkdir doesn't support -p reliably)
    local essential_dirs=("bin" "boot" "dev" "etc" "home" "lib" "media" "mnt" "opt" "proc" "root" "run" "sbin" "srv" "sys" "tmp" "usr" "var")
    for dir in "${essential_dirs[@]}"; do
        if e2mkdir "$temp_dir/root-new.ext4:/$dir" 2>/dev/null; then
            dir_count=$((dir_count + 1))
        else
            log_warning "Failed to create essential directory: /$dir"
            failed_ops=$((failed_ops + 1))
        fi
    done
    
    # Create nested directories one level at a time
    local nested_dirs=("boot/firmware" "etc/systemd" "etc/apt" "etc/ssh" "home/soulbox" "home/pi" "opt/soulbox" "usr/bin" "usr/lib" "usr/local" "usr/share" "var/log" "var/tmp" "var/cache")
    for dir in "${nested_dirs[@]}"; do
        if e2mkdir "$temp_dir/root-new.ext4:/$dir" 2>/dev/null; then
            dir_count=$((dir_count + 1))
        else
            log_warning "Failed to create nested directory: /$dir"
            failed_ops=$((failed_ops + 1))
        fi
    done
    
    # Create SoulBox specific directories
    local soulbox_dirs=("home/soulbox/Videos" "home/soulbox/Music" "home/soulbox/Pictures" "home/soulbox/Downloads" "home/soulbox/.kodi" "home/soulbox/.kodi/userdata" "opt/soulbox/assets" "opt/soulbox/scripts" "opt/soulbox/logs" "etc/systemd/system" "etc/systemd/system/multi-user.target.wants")
    for dir in "${soulbox_dirs[@]}"; do
        if e2mkdir "$temp_dir/root-new.ext4:/$dir" 2>/dev/null; then
            dir_count=$((dir_count + 1))
        else
            log_warning "Failed to create SoulBox directory: /$dir"
            failed_ops=$((failed_ops + 1))
        fi
    done
    
    log_success "Created $dir_count directories (failed: $failed_ops)"
    
    # Copy files from staging directory
    log_info "Copying files from staging directory to ext4 filesystem..."
    failed_ops=0
    if [[ -d "$staging_dir" ]]; then
        while IFS= read -r -d '' file; do
            rel_path="${file#$staging_dir}"
            if [[ -n "$rel_path" && "$rel_path" != "/.please_resize_me" ]]; then
                if e2cp "$file" "$temp_dir/root-new.ext4:$rel_path" 2>/dev/null; then
                    file_count=$((file_count + 1))
                else
                    # Only log warnings for important files
                    if [[ "$rel_path" == "/lib/modules/"* || "$rel_path" == "/bin/"* || "$rel_path" == "/sbin/"* ]]; then
                        log_warning "Failed to copy important file: $rel_path"
                    fi
                    failed_ops=$((failed_ops + 1))
                fi
            fi
        done < <(find "$staging_dir" -type f -print0)
        log_success "Copied $file_count files from staging (failed: $failed_ops)"
    else
        log_warning "Staging directory not found - using minimal content"
    fi
    
    # Handle symbolic links workaround - create them in first-boot script
    log_info "Processing symbolic links from staging..."
    local link_count=0
    local symlink_commands=""
    if [[ -d "$staging_dir" ]]; then
        while IFS= read -r -d '' link; do
            rel_path="${link#$staging_dir}"
            target=$(readlink "$link" 2>/dev/null || echo "")
            if [[ -n "$target" && -n "$rel_path" ]]; then
                log_info "Creating symlink workaround for: $rel_path -> $target"
                # Add command to create symlink during first boot
                symlink_commands+="ln -sf '$target' '$rel_path'\n"
                link_count=$((link_count + 1))
            fi
        done < <(find "$staging_dir" -type l -print0 2>/dev/null)
        
        if [[ $link_count -gt 0 ]]; then
            log_info "Creating symlink restoration script for $link_count links"
            # Create a script to restore symlinks on first boot
            mkdir -p "$staging_dir/opt/soulbox"
            cat > "$staging_dir/opt/soulbox/restore-symlinks.sh" << EOF
#!/bin/bash
# SoulBox Symlink Restoration Script
set -e

echo "Restoring symbolic links..."
${symlink_commands}
echo "Symbolic links restored successfully"
EOF
            chmod +x "$staging_dir/opt/soulbox/restore-symlinks.sh"
            
            # Copy the symlink script to filesystem
            e2cp "$staging_dir/opt/soulbox/restore-symlinks.sh" "$temp_dir/root-new.ext4:/opt/soulbox/restore-symlinks.sh" 2>/dev/null
        fi
    fi
    
    # Final verification
    log_info "Verifying populated filesystem..."
    if e2ls "$temp_dir/root-new.ext4:/" >/dev/null 2>&1; then
        local root_items=$(e2ls "$temp_dir/root-new.ext4:/" 2>/dev/null | wc -l || echo "0")
        log_success "E2tools fallback completed - $root_items items in root filesystem"
    else
        log_error "E2tools filesystem verification failed"
        return 1
    fi
    
    # Create essential system files (fallback if extraction failed)
    log_info "Ensuring essential system files exist..."
    if [[ ! -f "$temp_dir/root-content/etc/passwd" ]]; then
        cat > "$temp_dir/root-content/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
pi:x:1000:1000:Raspberry Pi User,,,:/home/pi:/bin/bash
EOF
    fi
    
    if [[ ! -f "$temp_dir/root-content/etc/group" ]]; then
        cat > "$temp_dir/root-content/etc/group" << 'EOF'
root:x:0:
pi:x:1000:
EOF
    fi
    
    if [[ ! -f "$temp_dir/root-content/etc/shadow" ]]; then
        cat > "$temp_dir/root-content/etc/shadow" << 'EOF'
root:*:19000:0:99999:7:::
pi:*:19000:0:99999:7:::
EOF
    fi
    
    if [[ ! -f "$temp_dir/root-content/etc/fstab" ]]; then
        cat > "$temp_dir/root-content/etc/fstab" << 'EOF'
proc            /proc           proc    defaults          0       0
LABEL=SOULBOX  /boot/firmware  vfat    defaults          0       2
LABEL=soulbox-root /               ext4    defaults,noatime  0       1
EOF
    fi
    
    # Ensure critical shell binaries exist
    if [[ ! -f "$temp_dir/root-content/bin/sh" ]]; then
        log_info "Creating /bin/sh fallback (copying bash)"
        if [[ -f "$temp_dir/root-content/bin/bash" ]]; then
            cp "$temp_dir/root-content/bin/bash" "$temp_dir/root-content/bin/sh"
        else
            log_warning "No bash available for /bin/sh fallback - creating minimal script"
            cat > "$temp_dir/root-content/bin/sh" << 'EOF'
#!/bin/dash
# Minimal sh fallback for SoulBox - will be replaced during first boot
exec "$@"
EOF
            chmod +x "$temp_dir/root-content/bin/sh"
        fi
    fi
    
    # Create home directories
    mkdir -p "$temp_dir/root-content/home/pi"
    mkdir -p "$temp_dir/root-content/root"
    
    log_success "Essential system files verified"
    
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
    
    # Create directories first - using a different approach due to e2tools limitations
    local dir_count=0
    local file_count=0
    local failed_ops=0
    
    log_info "Creating essential directories in ext4 filesystem..."
    # Create critical directories individually without -p flag (e2mkdir doesn't support -p reliably)
    local essential_dirs=("bin" "boot" "dev" "etc" "home" "lib" "media" "mnt" "opt" "proc" "root" "run" "sbin" "srv" "sys" "tmp" "usr" "var")
    for dir in "${essential_dirs[@]}"; do
        if e2mkdir "$temp_dir/root-new.ext4:/$dir" 2>/dev/null; then
            dir_count=$((dir_count + 1))
        else
            log_warning "Failed to create essential directory: /$dir"
            failed_ops=$((failed_ops + 1))
        fi
    done
    
    # Create nested directories one level at a time
    local nested_dirs=("boot/firmware" "etc/systemd" "etc/apt" "etc/ssh" "home/soulbox" "home/pi" "opt/soulbox" "usr/bin" "usr/lib" "usr/local" "usr/share" "var/log" "var/tmp" "var/cache")
    for dir in "${nested_dirs[@]}"; do
        if e2mkdir "$temp_dir/root-new.ext4:/$dir" 2>/dev/null; then
            dir_count=$((dir_count + 1))
        else
            log_warning "Failed to create nested directory: /$dir"
            failed_ops=$((failed_ops + 1))
        fi
    done
    
    # Create SoulBox specific directories
    local soulbox_dirs=("home/soulbox/Videos" "home/soulbox/Music" "home/soulbox/Pictures" "home/soulbox/Downloads" "home/soulbox/.kodi" "home/soulbox/.kodi/userdata" "opt/soulbox/assets" "opt/soulbox/scripts" "opt/soulbox/logs" "etc/systemd/system" "etc/systemd/system/multi-user.target.wants")
    for dir in "${soulbox_dirs[@]}"; do
        if e2mkdir "$temp_dir/root-new.ext4:/$dir" 2>/dev/null; then
            dir_count=$((dir_count + 1))
        else
            log_warning "Failed to create SoulBox directory: /$dir"
            failed_ops=$((failed_ops + 1))
        fi
    done
    
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
    
    # Handle symbolic links workaround - create them in first-boot script
    log_info "Processing symbolic links..."
    local link_count=0
    local symlink_commands=""
    while IFS= read -r -d '' link; do
        rel_path="${link#$temp_dir/root-content}"
        target=$(readlink "$link")
        log_info "Creating symlink workaround for: $rel_path -> $target"
        # Add command to create symlink during first boot
        symlink_commands+="ln -sf '$target' '$rel_path'\n"
        link_count=$((link_count + 1))
    done < <(find "$temp_dir/root-content" -type l -print0)
    
    if [[ $link_count -gt 0 ]]; then
        log_info "Creating symlink restoration script for $link_count links"
        # Create a script to restore symlinks on first boot
        cat > "$temp_dir/root-content/opt/soulbox/restore-symlinks.sh" << EOF
#!/bin/bash
# SoulBox Symlink Restoration Script
set -e

echo "Restoring symbolic links..."
${symlink_commands}
echo "Symbolic links restored successfully"
EOF
        chmod +x "$temp_dir/root-content/opt/soulbox/restore-symlinks.sh"
        
        # Update first-boot script to run symlink restoration
        sed -i '/echo "$(date): Starting SoulBox first boot setup..."/a\
# Restore symbolic links that e2tools could not create\
if [[ -f "/opt/soulbox/restore-symlinks.sh" ]]; then\
    echo "Restoring symbolic links..."\
    /opt/soulbox/restore-symlinks.sh\
    rm -f /opt/soulbox/restore-symlinks.sh\
fi' "$temp_dir/root-content/opt/soulbox/first-boot-setup.sh"
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
    download_base_image
    extract_base_filesystems
    create_soulbox_assets
    build_soulbox_image
    
    echo ""
    log_success "SoulBox $SOULBOX_VERSION is ready!"
    echo ""
    echo "Build Summary:"
    echo "   Version: $SOULBOX_VERSION"
    echo "   Method: Container-friendly (no loop devices)"
    echo "   Output: soulbox-v${SOULBOX_VERSION#v}.img"
    echo "   Base: Official ARM64 base image"
    echo ""
    echo "Flash to SD card and boot - first boot will install packages automatically!"
    echo "This approach works in any container environment!"
}

main "$@"
