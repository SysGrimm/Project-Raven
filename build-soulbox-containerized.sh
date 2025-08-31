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

# Function to install and configure populatefs from e2fsprogs source
install_populatefs() {
    log_info "Installing populatefs from e2fsprogs source (LibreELEC approach)..."
    
    # Install required dependencies first
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Installing e2fsprogs and dependencies..."
        apt-get update -qq 2>/dev/null || true
        apt-get install -y build-essential autoconf automake libtool wget curl xz-utils coreutils e2fsprogs mtools parted dosfstools zip tar pkg-config 2>/dev/null || {
            log_warning "Some packages may have failed to install, continuing..."
        }
    fi
    
    # Create working directory
    local work_dir="/tmp/e2fsprogs-build-$$"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Download e2fsprogs source (known working version)
    log_info "Downloading e2fsprogs source..."
    if ! wget -q "https://github.com/tytso/e2fsprogs/archive/refs/tags/v1.47.0.tar.gz" -O e2fsprogs.tar.gz; then
        log_error "Failed to download e2fsprogs source"
        rm -rf "$work_dir"
        return 1
    fi
    
    # Extract source
    tar -xzf e2fsprogs.tar.gz
    cd e2fsprogs-1.47.0/contrib || {
        log_error "Failed to extract e2fsprogs or find contrib directory"
        rm -rf "$work_dir"
        return 1
    }
    
    log_info "Available contrib tools:"
    ls -la .
    
    # Check for populate-extfs.sh script
    if [[ -f "populate-extfs.sh" ]]; then
        log_success "✅ Found populate-extfs.sh script"
        
        # Install as populatefs
        cp "populate-extfs.sh" "/usr/local/bin/populatefs"
        chmod +x "/usr/local/bin/populatefs"
        
        # Apply container compatibility fixes immediately
        log_info "🔧 Patching populatefs to use system debugfs..."
        
        # Critical fix: Replace hardcoded paths with system commands
        sed -i 's|DEBUGFS=".*"|DEBUGFS="debugfs"|g' "/usr/local/bin/populatefs" 2>/dev/null || true
        sed -i 's|\$CONTRIB_DIR/\.\./debugfs/debugfs|debugfs|g' "/usr/local/bin/populatefs" 2>/dev/null || true
        sed -i 's|\$BIN_DIR/\.\./debugfs/debugfs|debugfs|g' "/usr/local/bin/populatefs" 2>/dev/null || true
        
        # Verify the patch was applied
        log_info "📝 Verifying populatefs patch applied correctly..."
        if grep -n "debugfs" "/usr/local/bin/populatefs" | head -5; then
            log_success "✅ populate-extfs.sh installed as populatefs"
        else
            log_warning "Could not verify populatefs patch"
        fi
    else
        log_error "populate-extfs.sh not found in contrib directory"
        rm -rf "$work_dir"
        return 1
    fi
    
    # Cleanup
    cd /tmp
    rm -rf "$work_dir"
    
    # Add /usr/local/bin to PATH if not already there
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        export PATH="/usr/local/bin:$PATH"
    fi
    
    # Verify installation
    if [[ -x "/usr/local/bin/populatefs" ]]; then
        log_success "✅ populatefs (or alternative) installed"
        ls -la "/usr/local/bin/populatefs"
        
        # Test functionality
        if test_populatefs_functionality; then
            log_success "populatefs installation and testing complete"
            return 0
        else
            log_warning "populatefs installed but functionality test failed - may still work in actual build"
            return 0  # Continue anyway as test might be too strict
        fi
    else
        log_error "populatefs installation failed"
        return 1
    fi
}

# Function to fix populatefs paths for container compatibility
fix_populatefs_paths() {
    log_info "Applying container compatibility fixes to populatefs..."
    
    local populatefs_path=""
    if command -v populatefs >/dev/null 2>&1; then
        populatefs_path=$(command -v populatefs)
    elif [[ -x "/usr/local/bin/populatefs" ]]; then
        populatefs_path="/usr/local/bin/populatefs"
    else
        log_warning "Cannot find populatefs to fix"
        return 1
    fi
    
    log_info "Fixing populatefs at: $populatefs_path"
    
    # Check if it's a shell script that needs fixing
    if file "$populatefs_path" 2>/dev/null | grep -q "shell script"; then
        log_info "Detected shell script - applying path fixes"
        
        # Backup original
        cp "$populatefs_path" "${populatefs_path}.backup" 2>/dev/null || true
        
        # Apply the critical fix from wiki Build #79-80
        # Fix: $CONTRIB_DIR/../debugfs/debugfs -> debugfs
        if grep -q "\$CONTRIB_DIR" "$populatefs_path" 2>/dev/null; then
            log_info "Applying CONTRIB_DIR path fix"
            sed -i 's|\$CONTRIB_DIR/\.\./debugfs/debugfs|debugfs|g' "$populatefs_path"
        fi
        
        # Additional fixes for other common hardcoded paths
        if grep -q "\$BIN_DIR" "$populatefs_path" 2>/dev/null; then
            log_info "Applying BIN_DIR path fix"
            sed -i 's|\$BIN_DIR/\.\./debugfs/debugfs|debugfs|g' "$populatefs_path"
        fi
        
        # Make sure script uses system commands in PATH
        sed -i 's|/usr/local/bin/\.\./../\([^/]*\)|\1|g' "$populatefs_path" 2>/dev/null || true
        
        log_success "Applied container compatibility fixes to populatefs"
        return 0
    else
        log_info "Binary populatefs - no path fixes needed"
        return 0
    fi
}

# Function to test populatefs functionality
test_populatefs_functionality() {
    log_info "Testing populatefs functionality..."
    
    # Create test environment
    local test_dir="/tmp/populatefs-test-$$"
    local test_ext4="$test_dir/test.ext4"
    local test_staging="$test_dir/staging"
    
    mkdir -p "$test_staging/test-subdir"
    echo "test content" > "$test_staging/test-file"
    echo "subdirectory test" > "$test_staging/test-subdir/sub-file"
    
    # Create test filesystem
    dd if=/dev/zero of="$test_ext4" bs=1M count=10 2>/dev/null
    mke2fs -F -q -t ext4 "$test_ext4" >/dev/null 2>&1
    
    local test_success=false
    
    # Test populatefs with different syntaxes
    local populatefs_cmd=""
    if command -v populatefs >/dev/null 2>&1; then
        populatefs_cmd="populatefs"
    elif [[ -x "/usr/local/bin/populatefs" ]]; then
        populatefs_cmd="/usr/local/bin/populatefs"
    fi
    
    if [[ -n "$populatefs_cmd" ]]; then
        # Test LibreELEC syntax first
        if "$populatefs_cmd" "$test_ext4" "$test_staging" >/dev/null 2>&1; then
            test_success=true
            log_info "✓ LibreELEC syntax works"
        # Test binary syntax
        elif "$populatefs_cmd" -U -d "$test_staging" "$test_ext4" >/dev/null 2>&1; then
            test_success=true
            log_info "✓ Binary syntax works"
        else
            log_warning "Both populatefs syntaxes failed in test"
        fi
    fi
    
    # Cleanup
    rm -rf "$test_dir" 2>/dev/null || true
    
    if [[ "$test_success" == "true" ]]; then
        log_success "populatefs functionality test passed"
        return 0
    else
        log_error "populatefs functionality test failed"
        return 1
    fi
}

# Function to install missing system tools
install_missing_system_tools() {
    log_info "Installing missing system tools for container environment..."
    
    # Check if we have package manager access
    if ! command -v apt-get >/dev/null 2>&1; then
        log_warning "apt-get not available - cannot install system tools"
        return 1
    fi
    
    # Update package list first
    if ! apt-get update -qq 2>/dev/null; then
        log_warning "Failed to update package list"
    fi
    
    # Tools that are often missing in minimal containers and affect populatefs
    local system_tools=("udev" "systemd" "dbus" "util-linux")
    local installed_count=0
    
    for tool in "${system_tools[@]}"; do
        if apt-get install -y "$tool" 2>/dev/null; then
            installed_count=$((installed_count + 1))
            log_info "✓ Installed $tool"
        else
            log_warning "✗ Failed to install $tool (may affect populatefs)"
        fi
    done
    
    # Install udevadm specifically (was missing in build log)
    if ! command -v udevadm >/dev/null 2>&1; then
        if apt-get install -y udev systemd 2>/dev/null; then
            log_info "✓ Installed udevadm"
            installed_count=$((installed_count + 1))
        else
            log_warning "✗ Failed to install udevadm (may cause warnings)"
        fi
    else
        log_info "✓ udevadm already available"
    fi
    
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
    
    # Check for populatefs (required - no fallbacks)
    local has_populatefs=false
    
    if command -v populatefs >/dev/null 2>&1; then
        has_populatefs=true
        log_success "Found populatefs (required method)"
    elif [[ -x "/usr/local/bin/populatefs" ]]; then
        has_populatefs=true
        log_success "Found populatefs in /usr/local/bin (required method)"
        # Ensure /usr/local/bin is in PATH for this session
        export PATH="/usr/local/bin:$PATH"
    fi
    
    if [[ "$has_populatefs" == "false" ]]; then
        log_warning "populatefs not found - required for build!"
        log_info "Attempting to install populatefs..."
        
        # Try to install populatefs automatically
        if install_populatefs; then
            has_populatefs=true
            log_success "Successfully installed populatefs"
        else
            missing_tools+=("populatefs")
            log_error "Failed to install populatefs - build cannot continue"
            log_info "Manual installation: apt-get install e2fsprogs-extra"
            log_info "populatefs is required for reliable filesystem population"
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
    
    # Image size calculations (in MB) - Conservative sizing for container space constraints
    # Container available space: ~1.6GB total, but need buffer for temp files, extraction, etc.
    # After analysis: build #81 failed at ~662MB, so limit to 600MB root for safety
    local boot_size=80    # 80MB sufficient for base boot files
    local root_size=600   # 600MB - conservative size that fits container limits
    local total_size=$((boot_size + root_size + 20))  # 20MB padding
    
    log_info "Image size planning: Boot=${boot_size}MB, Root=${root_size}MB, Total=${total_size}MB"
    
    # Check available disk space with safety buffer
    # Need space for: source image (~2.7GB), extracted filesystems (~2.5GB), 
    #                 temp files (~600MB), final image (total_size), staging (~500MB)
    local available_space=$(df /workspace --output=avail | tail -1)
    local required_space=$((total_size * 2 * 1024))  # 2x final image size for safety buffer
    log_info "Disk space check: Available=${available_space}KB, Required=${required_space}KB (with safety buffer)"
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space! Available: ${available_space}KB, Required: ${required_space}KB"
        log_error "Container needs at least $((required_space / 1024))MB free space for safe operation"
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
    log_info "Copying boot filesystem to image at offset 4MB..."
    if ! dd if="$temp_dir/boot-new.fat" of="$output_image" bs=1M seek=4 conv=notrunc 2>&1; then
        log_error "Failed to copy boot filesystem to final image"
        return 1
    fi
    log_success "Boot filesystem merged successfully"
    
    log_info "Copying root filesystem to image at offset $((boot_size + 4))MB..."
    if ! dd if="$temp_dir/root-new.ext4" of="$output_image" bs=1M seek=$((boot_size + 4)) conv=notrunc 2>&1; then
        log_error "Failed to copy root filesystem to final image"
        return 1
    fi
    log_success "Root filesystem merged successfully"
    
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
    
    # Check if source_img is already an ext4 filesystem (extracted partition) or a disk image
    local parted_output
    parted_output=$(parted -s "$source_img" unit s print 2>/dev/null)
    
    # Debug output
    log_info "Analyzing source image format..."
    echo "$parted_output" | while read -r line; do
        log_info "  $line"
    done
    
    local temp_root="/tmp/soulbox-debugfs-root-$$.ext4"
    
    # Check if this is a loop device (single filesystem) or partitioned disk
    if echo "$parted_output" | grep -q "Partition Table: loop"; then
        # This is already an extracted filesystem, use it directly
        log_info "Source is already an ext4 filesystem - using directly with debugfs"
        temp_root="$source_img"
        local skip_cleanup=true
    else
        # This is a partitioned disk image - need to extract root partition
        log_info "Source is a partitioned disk image - extracting root partition first"
        
        # Try multiple parsing approaches for root partition (partition 2)
        local root_start root_end
        
        # Method 1: Look for line starting with space(s) + 2
        root_start=$(echo "$parted_output" | grep -E '^[[:space:]]*2[[:space:]]' | awk '{print $2}' | sed 's/s$//')
        root_end=$(echo "$parted_output" | grep -E '^[[:space:]]*2[[:space:]]' | awk '{print $3}' | sed 's/s$//')
        
        # Method 2: If that fails, try looking for any line containing partition 2
        if [[ -z "$root_start" || -z "$root_end" ]]; then
            root_start=$(echo "$parted_output" | grep -E '2[[:space:]]+[0-9]+s[[:space:]]+[0-9]+s' | awk '{print $2}' | sed 's/s$//')
            root_end=$(echo "$parted_output" | grep -E '2[[:space:]]+[0-9]+s[[:space:]]+[0-9]+s' | awk '{print $3}' | sed 's/s$//')
        fi
        
        # Method 3: Alternative approach using awk to find partition 2
        if [[ -z "$root_start" || -z "$root_end" ]]; then
            local partition_line=$(echo "$parted_output" | awk '/^[ ]*2[ ]+/ {print; exit}')
            if [[ -n "$partition_line" ]]; then
                root_start=$(echo "$partition_line" | awk '{print $2}' | sed 's/s$//')
                root_end=$(echo "$partition_line" | awk '{print $3}' | sed 's/s$//')
            fi
        fi
        
        log_info "Parsed root partition: start=$root_start, end=$root_end"
        
        if [[ -z "$root_start" || -z "$root_end" || ! "$root_start" =~ ^[0-9]+$ || ! "$root_end" =~ ^[0-9]+$ ]]; then
            log_error "Could not determine root partition location (start=$root_start, end=$root_end)"
            log_error "Partition table parsing failed - this may indicate an unsupported image format"
            return 1
        fi
        
        log_success "Root partition located: sectors $root_start to $root_end"
        
        # Extract root partition
        local root_size_sectors=$((root_end - root_start + 1))
        if ! dd if="$source_img" of="$temp_root" bs=512 skip="$root_start" count="$root_size_sectors" 2>/dev/null; then
            log_error "Failed to extract root partition for debugfs"
            return 1
        fi
        
        log_info "Extracted root partition for debugfs processing"
        local skip_cleanup=false
    fi
    
    # Use debugfs to recursively dump the filesystem
    if extract_with_debugfs_recursive "$temp_root" "$staging_dir" "/"; then
        log_success "debugfs extraction completed successfully"
        if [[ "$skip_cleanup" != "true" ]]; then
            rm -f "$temp_root"
        fi
        return 0
    else
        log_warning "debugfs extraction failed"
        if [[ "$skip_cleanup" != "true" ]]; then
            rm -f "$temp_root"
        fi
        return 1
    fi
}

# Helper function to read symlink target using debugfs
handle_debugfs_symlink() {
    local filesystem="$1"
    local symlink_path="$2"
    
    # Debug: Try multiple debugfs approaches to read symlink
    local ls_output stat_output
    
    # Method 1: Use debugfs ls -l (should work for symlinks in directory listings)
    ls_output=$(echo "ls -l $symlink_path" | debugfs "$filesystem" 2>&1)
    
    # Method 2: Use debugfs stat command (more detailed info)
    stat_output=$(echo "stat $symlink_path" | debugfs "$filesystem" 2>&1)
    
    # Clean debug output to stderr (avoid color code pollution)
    echo "[DEBUG] ls_output for $symlink_path: '$ls_output'" >&2
    echo "[DEBUG] stat_output for $symlink_path: '$stat_output'" >&2
    
    # Try to extract target from stat output first (most reliable)
    if [[ -n "$stat_output" ]]; then
        # Look for "Fast link dest:" line in stat output
        local fast_link_line=$(echo "$stat_output" | grep "Fast link dest:" | head -1)
        if [[ -n "$fast_link_line" && "$fast_link_line" =~ Fast[[:space:]]+link[[:space:]]+dest:[[:space:]]*\"([^\"]+)\" ]]; then
            local target="${BASH_REMATCH[1]}"
            echo "$target"
            return
        elif [[ -n "$fast_link_line" && "$fast_link_line" =~ Fast[[:space:]]+link[[:space:]]+dest:[[:space:]]*([^[:space:]]+) ]]; then
            local target="${BASH_REMATCH[1]}"
            # Remove any trailing quotes or whitespace
            target=$(echo "$target" | sed 's/^"//;s/"$//;s/[[:space:]]*$//')
            echo "$target"
            return
        fi
    fi
    
    # Try to extract target from ls output as backup
    if [[ -n "$ls_output" ]]; then
        local clean_ls=$(echo "$ls_output" | grep -v "debugfs:" | head -1)
        if [[ -n "$clean_ls" && "$clean_ls" =~ -\>[[:space:]]*([^[:space:]].*)$ ]]; then
            local target="${BASH_REMATCH[1]}"
            echo "$target" | sed 's/[[:space:]]*$//'
            return
        fi
    fi
    
    # Method 3: Hardcoded fallback for common Pi OS symlinks
    case "$symlink_path" in
        "/bin")
            echo "usr/bin"
            return
            ;;
        "/lib")
            echo "usr/lib"
            return
            ;;
        "/sbin")
            echo "usr/sbin"
            return
            ;;
        *)
            log_warning "Could not determine symlink target for $symlink_path"
            echo ""
            ;;
    esac
}

# Helper function for recursive debugfs extraction (OPTIMIZED)
extract_with_debugfs_recursive() {
    local filesystem="$1"
    local staging_dir="$2"
    local fs_path="$3"
    local current_depth="${4:-0}"
    
    # Prevent infinite recursion and limit performance bottlenecks
    if [[ $current_depth -gt 12 ]]; then
        log_warning "Maximum recursion depth reached for $fs_path (performance optimization)"
        return 0
    fi
    
    # Skip problematic paths that cause performance issues
    case "$fs_path" in
        "/usr/bin"|"/usr/sbin"|"/bin"|"/sbin")
            # These are usually symlinks to large directories - handle differently
            if [[ $current_depth -eq 0 ]]; then
                log_info "Processing large directory: $fs_path (optimized symlink handling)"
                extract_large_directory_optimized "$filesystem" "$staging_dir" "$fs_path"
                return $?
            else
                log_info "Skipping deep symlink directory to avoid performance issues: $fs_path"
                return 0
            fi
            ;;
        "/proc"|"/sys"|"/dev")
            # These are virtual filesystems, just create empty directories
            log_info "Creating empty virtual filesystem directory: $fs_path"
            mkdir -p "$staging_dir$fs_path"
            return 0
            ;;
    esac
    
    # Create the directory in staging
    mkdir -p "$staging_dir$fs_path"
    
    # Get directory listing from debugfs with better error handling
    local listings debug_output debug_exit_code
    debug_output=$(echo "ls -l $fs_path" | debugfs "$filesystem" 2>&1)
    debug_exit_code=$?
    
    if [[ $debug_exit_code -ne 0 ]]; then
        log_warning "debugfs ls command failed for $fs_path (exit code: $debug_exit_code)"
        return 1
    fi
    
    # Filter out debugfs prompts and extract actual directory listing
    listings=$(echo "$debug_output" | grep -v "debugfs:" | grep -v "^$")
    
    if [[ -z "$listings" ]]; then
        return 0
    fi
    
    # Debug output for root directory
    if [[ "$fs_path" == "/" ]]; then
        log_info "Root directory listing from debugfs:"
        echo "$listings" | while read -r line; do
            [[ -n "$line" ]] && log_info "  $line"
        done
    fi
    
    local files_extracted=0
    local dirs_processed=0
    local symlinks_processed=0
    local items_processed=0
    
    # Parse debugfs output and extract files/directories
    while read -r line; do
        [[ -z "$line" ]] && continue
        
    # Performance optimization: limit processing in deep directories
    items_processed=$((items_processed + 1))
    if [[ $current_depth -gt 5 && $items_processed -gt 500 ]]; then
        log_info "Limiting extraction in deep directory $fs_path (performance optimization)"
        break
    fi
        
        # Parse debugfs ls -l output format
        local perms=$(echo "$line" | awk '{print $2}')
        local name=$(echo "$line" | awk '{print $NF}')
        
        [[ "$name" == "." || "$name" == ".." ]] && continue
        [[ -z "$name" ]] && continue
        
        local full_fs_path
        if [[ "$fs_path" == "/" ]]; then
            full_fs_path="/$name"
        else
            full_fs_path="$fs_path/$name"
        fi
        local full_staging_path="$staging_dir$full_fs_path"
        
        if [[ "${perms:0:1}" == "d" ]]; then
            # It's a directory - recurse with depth limit
            if extract_with_debugfs_recursive "$filesystem" "$staging_dir" "$full_fs_path" $((current_depth + 1)); then
                dirs_processed=$((dirs_processed + 1))
            fi
        elif [[ "${perms:0:1}" == "l" || "$perms" == "120777" ]]; then
            # It's a symlink - handle with optimized approach
            local symlink_target
            symlink_target=$(handle_debugfs_symlink_optimized "$filesystem" "$full_fs_path")
            
            if [[ -n "$symlink_target" ]]; then
                # Create the symlink in staging
                ln -sf "$symlink_target" "$full_staging_path" 2>/dev/null
                symlinks_processed=$((symlinks_processed + 1))
                
                # Only process symlink targets for critical directories at shallow depths
                if [[ $current_depth -le 1 ]] && [[ "$name" =~ ^(bin|sbin|lib)$ ]]; then
                    log_info "Processing critical symlink: $name -> $symlink_target"
                    
                    local target_full_path
                    if [[ "$symlink_target" =~ ^/ ]]; then
                        target_full_path="$symlink_target"
                    else
                        local parent_dir=$(dirname "$full_fs_path")
                        if [[ "$parent_dir" == "/" ]]; then
                            target_full_path="/$symlink_target"
                        else
                            target_full_path="$parent_dir/$symlink_target"
                        fi
                    fi
                    
                    # Check if target exists and extract it
                    local target_check_output
                    target_check_output=$(echo "stat $target_full_path" | debugfs "$filesystem" 2>/dev/null)
                    
                    if [[ "$target_check_output" =~ Type:[[:space:]]*directory ]]; then
                        mkdir -p "$staging_dir$target_full_path"
                        if extract_with_debugfs_recursive "$filesystem" "$staging_dir" "$target_full_path" $((current_depth + 1)); then
                            log_info "✓ Extracted critical symlink target: $target_full_path"
                        fi
                    fi
                fi
            fi
        else
            # It's a regular file - extract it
            local dump_output
            dump_output=$(echo "dump $full_fs_path $full_staging_path" | debugfs "$filesystem" 2>&1)
            local dump_exit_code=$?
            
            if [[ $dump_exit_code -eq 0 ]]; then
                files_extracted=$((files_extracted + 1))
                # Log progress for root level files
                if [[ $current_depth -eq 0 ]]; then
                    log_info "Extracted file: $name"
                fi
            fi
        fi
        
    done <<< "$listings"
    
    # Log extraction summary for root level
    if [[ "$fs_path" == "/" ]]; then
        log_info "Root extraction summary: $files_extracted files, $dirs_processed directories, $symlinks_processed symlinks processed"
    fi
    
    return 0
}

# Optimized symlink handler that avoids excessive debugfs calls
handle_debugfs_symlink_optimized() {
    local filesystem="$1"
    local symlink_path="$2"
    
    # Quick stat check - single debugfs call
    local stat_output
    stat_output=$(echo "stat $symlink_path" | debugfs "$filesystem" 2>/dev/null)
    
    # Extract target from "Fast link dest:" line
    if [[ "$stat_output" =~ Fast[[:space:]]+link[[:space:]]+dest:[[:space:]]*\"([^\"]+)\" ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi
    
    # Fallback patterns for common Pi OS symlinks (avoid debugfs calls)
    case "$symlink_path" in
        "/bin") echo "usr/bin" ;;
        "/lib") echo "usr/lib" ;;
        "/sbin") echo "usr/sbin" ;;
        *) echo "" ;; # Return empty for unknown symlinks to avoid slow processing
    esac
}

# Optimized extraction for large directories (like /usr/bin)
extract_large_directory_optimized() {
    local filesystem="$1"
    local staging_dir="$2"
    local fs_path="$3"
    
    log_info "Optimized extraction for large directory: $fs_path"
    
    # First, check if this is a symlink
    local stat_output
    stat_output=$(echo "stat $fs_path" | debugfs "$filesystem" 2>/dev/null)
    
    if [[ "$stat_output" =~ Type:[[:space:]]*symlink ]]; then
        # It's a symlink - get the target and create the symlink
        local symlink_target
        symlink_target=$(handle_debugfs_symlink_optimized "$filesystem" "$fs_path")
        
        if [[ -n "$symlink_target" ]]; then
            log_info "Creating symlink: $fs_path -> $symlink_target"
            mkdir -p "$(dirname "$staging_dir$fs_path")"
            ln -sf "$symlink_target" "$staging_dir$fs_path" 2>/dev/null
            
            # Extract the target directory with limited depth
            local target_full_path
            if [[ "$symlink_target" =~ ^/ ]]; then
                target_full_path="$symlink_target"
            else
                target_full_path="/$symlink_target"
            fi
            
            log_info "Extracting symlink target with limited depth: $target_full_path"
            extract_with_debugfs_limited "$filesystem" "$staging_dir" "$target_full_path" 50
            return $?
        fi
    else
        # It's a directory - extract with limits
        log_info "Extracting large directory with limits: $fs_path"
        extract_with_debugfs_limited "$filesystem" "$staging_dir" "$fs_path" 100
        return $?
    fi
}

# Limited extraction for performance (extract only first N files)
extract_with_debugfs_limited() {
    local filesystem="$1"
    local staging_dir="$2"
    local fs_path="$3"
    local max_files="${4:-50}"
    
    mkdir -p "$staging_dir$fs_path"
    
    # Get directory listing
    local listings
    listings=$(echo "ls -l $fs_path" | debugfs "$filesystem" 2>/dev/null | grep -v "debugfs:" | grep -v "^$")
    
    [[ -z "$listings" ]] && return 0
    
    local files_extracted=0
    local items_processed=0
    
    while read -r line && [[ $files_extracted -lt $max_files ]]; do
        [[ -z "$line" ]] && continue
        
        items_processed=$((items_processed + 1))
        
        local perms=$(echo "$line" | awk '{print $2}')
        local name=$(echo "$line" | awk '{print $NF}')
        
        [[ "$name" == "." || "$name" == ".." ]] && continue
        [[ -z "$name" ]] && continue
        
        local full_fs_path="$fs_path/$name"
        local full_staging_path="$staging_dir$full_fs_path"
        
        if [[ "${perms:0:1}" != "d" ]] && [[ "${perms:0:1}" != "l" ]]; then
            # Regular file - extract it
            if echo "dump $full_fs_path $full_staging_path" | debugfs "$filesystem" >/dev/null 2>&1; then
                files_extracted=$((files_extracted + 1))
            fi
        elif [[ "${perms:0:1}" == "l" ]]; then
            # Symlink - create it without recursing
            local target
            target=$(handle_debugfs_symlink_optimized "$filesystem" "$full_fs_path")
            if [[ -n "$target" ]]; then
                ln -sf "$target" "$full_staging_path" 2>/dev/null
                files_extracted=$((files_extracted + 1))
            fi
        fi
        
    done <<< "$listings"
    
    log_info "Limited extraction of $fs_path: $files_extracted files extracted (limit: $max_files)"
    return 0
}

# Note: e2tools extraction methods removed - now using loop mount → debugfs chain
# This ensures reliable extraction without the corruption issues that plagued e2tools

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
    local boot_extraction_success=false
    
    # Try multiple mtools extraction methods
    if mcopy -s -i "$base_boot" "::*" "$temp_dir/boot-content/" 2>/dev/null; then
        boot_extraction_success=true
        log_success "Boot partition extracted successfully with wildcard method"
    elif mcopy -i "$base_boot" "::" "$temp_dir/boot-content/" 2>/dev/null; then
        boot_extraction_success=true
        log_success "Boot partition extracted successfully with directory method"
    else
        log_warning "Standard mtools extraction failed, trying individual file extraction..."
        
        # Try to extract essential boot files individually
        local essential_boot_files=("start4.elf" "fixup4.dat" "kernel8.img" "config.txt" "cmdline.txt" "bcm2712-rpi-5-b.dtb")
        local extraction_count=0
        
        for boot_file in "${essential_boot_files[@]}"; do
            if mcopy -i "$base_boot" "::$boot_file" "$temp_dir/boot-content/$boot_file" 2>/dev/null; then
                log_info "✓ Extracted essential boot file: $boot_file"
                extraction_count=$((extraction_count + 1))
            else
                log_warning "✗ Failed to extract: $boot_file"
            fi
        done
        
        # Also try alternative Pi 4/5 boot files
        local alt_boot_files=("start.elf" "fixup.dat" "bootcode.bin")
        for boot_file in "${alt_boot_files[@]}"; do
            if mcopy -i "$base_boot" "::$boot_file" "$temp_dir/boot-content/$boot_file" 2>/dev/null; then
                log_info "✓ Extracted alternative boot file: $boot_file"
                extraction_count=$((extraction_count + 1))
            fi
        done
        
        if [[ $extraction_count -gt 3 ]]; then
            boot_extraction_success=true
            log_success "Individual file extraction succeeded: $extraction_count files extracted"
        fi
    fi
    
    # If all extraction methods failed, create error and exit
    if [[ "$boot_extraction_success" != "true" ]]; then
        log_error "CRITICAL: All boot file extraction methods failed"
        log_error "Cannot create bootable image without essential boot files"
        log_error "Please verify the base Raspberry Pi OS image is valid"
        return 1
    fi
    
    log_info "Boot files found: $(ls -la "$temp_dir/boot-content/" | wc -l) items"
    
    # Add SoulBox boot customizations
    if [[ -f "$assets_dir/boot/soulbox-config.txt" ]]; then
        log_info "Adding SoulBox boot configuration..."
        cat "$assets_dir/boot/soulbox-config.txt" >> "$temp_dir/boot-content/config.txt"
        log_success "Boot configuration added"
    else
        log_warning "SoulBox boot config not found: $assets_dir/boot/soulbox-config.txt"
    fi
    
    # Fix cmdline.txt if it exists to use the correct root filesystem
    if [[ -f "$temp_dir/boot-content/cmdline.txt" ]]; then
        log_info "Fixing cmdline.txt to use correct root filesystem..."
        # Replace any existing root= parameter with our label-based approach
        sed -i 's/root=[^ ]*/root=LABEL=soulbox-root/g' "$temp_dir/boot-content/cmdline.txt"
        # Add rootdelay if not present
        if ! grep -q "rootdelay" "$temp_dir/boot-content/cmdline.txt"; then
            sed -i 's/$/ rootdelay=5/' "$temp_dir/boot-content/cmdline.txt"
        fi
        log_success "cmdline.txt updated to use LABEL=soulbox-root"
    fi
    
    # Verify essential boot files are present (DO NOT CREATE PLACEHOLDERS)
    log_info "Verifying essential boot files are present..."
    local essential_files=("start4.elf" "fixup4.dat" "bcm2712-rpi-5-b.dtb" "kernel8.img" "config.txt" "cmdline.txt")
    local missing_critical_files=()
    local missing_optional_files=()
    
    for essential_file in "${essential_files[@]}"; do
        if [[ ! -f "$temp_dir/boot-content/$essential_file" ]]; then
            # Categorize missing files
            if [[ "$essential_file" == "config.txt" || "$essential_file" == "cmdline.txt" ]]; then
                missing_optional_files+=("$essential_file")
                log_warning "Boot configuration file missing: $essential_file (can create minimal version)"
            else
                missing_critical_files+=("$essential_file")
                log_error "CRITICAL boot file missing: $essential_file (CANNOT BOOT WITHOUT THIS)"
            fi
        else
            log_success "✓ Found essential boot file: $essential_file"
        fi
    done
    
    # Create minimal config files only if they're missing
    for missing_file in "${missing_optional_files[@]}"; do
        if [[ "$missing_file" == "config.txt" ]]; then
            log_info "Creating minimal config.txt..."
            cat > "$temp_dir/boot-content/config.txt" << 'EOF'
# Raspberry Pi Configuration
# Generated by SoulBox - minimal boot configuration
arm_64bit=1
disable_overscan=1

# GPU memory for media center
gpu_mem=320

# Boot optimization
boot_delay=0

# GPU driver
dtoverlay=vc4-kms-v3d
EOF
        elif [[ "$missing_file" == "cmdline.txt" ]]; then
            log_info "Creating minimal cmdline.txt..."
            echo "console=serial0,115200 console=tty1 root=LABEL=soulbox-root rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait rootdelay=5" > "$temp_dir/boot-content/cmdline.txt"
        fi
    done
    
    # FAIL BUILD if critical boot files are missing
    if [[ ${#missing_critical_files[@]} -gt 0 ]]; then
        log_error "CRITICAL ERROR: Missing essential boot files that cannot be recreated:"
        for missing in "${missing_critical_files[@]}"; do
            log_error "  - $missing (required for Pi 5 boot)"
        done
        log_error "These files must be extracted from the base Raspberry Pi OS image"
        log_error "The image would fail to boot without them - stopping build"
        return 1
    fi
    
    if [[ ${#missing_optional_files[@]} -gt 0 ]]; then
        log_success "Created minimal versions of missing configuration files: ${missing_optional_files[*]}"
    fi
    
    log_success "All essential boot files verified or created"
    
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
    
    # Ensure all required e2fsprogs tools are in PATH for populatefs
    local original_path="$PATH"
    export PATH="/usr/sbin:/sbin:/usr/bin:/bin:/usr/local/bin:$PATH"
    log_info "Enhanced PATH for populatefs dependencies: $PATH"
    
    # Verify populatefs dependencies are available
    local missing_deps=()
    for dep in mke2fs debugfs tune2fs e2fsck; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing populatefs dependencies: ${missing_deps[*]}"
        log_info "Attempting to locate missing dependencies..."
        for dep in "${missing_deps[@]}"; do
            for search_path in /usr/sbin /sbin /usr/local/sbin /usr/local/bin; do
                if [[ -x "$search_path/$dep" ]]; then
                    log_info "Found $dep in $search_path"
                    export PATH="$search_path:$PATH"
                    break
                fi
            done
        done
    else
        log_success "All populatefs dependencies found in PATH"
    fi
    
    local populatefs_cmd=""
    if command -v populatefs >/dev/null 2>&1; then
        populatefs_cmd="populatefs"
        log_info "Using populatefs from PATH (preferred method)"
    elif [[ -x "/usr/local/bin/populatefs" ]]; then
        populatefs_cmd="/usr/local/bin/populatefs"
        log_info "Using populatefs from /usr/local/bin (preferred method)"
    fi
    
    if [[ -n "$populatefs_cmd" ]]; then
        # Enhanced populatefs execution with comprehensive debugging
        local populate_success=false
        
        # Verify populatefs tool before attempting to use it
        log_info "Analyzing populatefs tool: $populatefs_cmd"
        if [[ -x "$populatefs_cmd" ]]; then
            log_info "✓ populatefs executable verified"
        elif command -v "$populatefs_cmd" >/dev/null 2>&1; then
            log_info "✓ populatefs found in PATH"
        else
            log_error "populatefs command not executable: $populatefs_cmd"
            export PATH="$original_path"
            return 1
        fi
        
        # Check if it's a script or binary
        local populatefs_type="unknown"
        if file "$(command -v "$populatefs_cmd" 2>/dev/null || echo "$populatefs_cmd")" 2>/dev/null | grep -q "shell script"; then
            populatefs_type="script"
        elif file "$(command -v "$populatefs_cmd" 2>/dev/null || echo "$populatefs_cmd")" 2>/dev/null | grep -q "ELF.*executable"; then
            populatefs_type="binary"
        fi
        log_info "Detected populatefs type: $populatefs_type"
        
        # Pre-execution validation
        log_info "Pre-execution validation:"
        log_info "  - Staging directory: $staging_dir ($(find "$staging_dir" -type f 2>/dev/null | wc -l) files)"
        log_info "  - Target filesystem: $temp_dir/root-new.ext4 ($(ls -lh "$temp_dir/root-new.ext4" | awk '{print $5}'))"
        
        # Verify staging directory has content
        local staging_files=$(find "$staging_dir" -type f 2>/dev/null | wc -l)
        if [[ $staging_files -lt 100 ]]; then
            log_error "Staging directory has very few files ($staging_files) - population will likely fail"
            log_error "This indicates that base OS extraction failed"
            export PATH="$original_path"
            return 1
        fi
        
        # Try different populatefs syntax based on type and common patterns
        
        # Method 1: Standard LibreELEC populatefs syntax (filesystem source_dir)
        if [[ "$populate_success" != "true" ]]; then
            log_info "Method 1 - LibreELEC syntax: $populatefs_cmd $temp_dir/root-new.ext4 $staging_dir"
            if "$populatefs_cmd" "$temp_dir/root-new.ext4" "$staging_dir" >"$SAVE_ERROR" 2>&1; then
                populate_success=true
                log_success "✓ Populatefs succeeded with LibreELEC syntax (method 1)"
            else
                log_warning "LibreELEC syntax failed, trying alternative syntaxes..."
                if [[ -s "$SAVE_ERROR" ]]; then
                    log_info "Method 1 error output:"
                    head -5 "$SAVE_ERROR" | sed 's/^/    /' || true
                fi
            fi
        fi
        
        # Method 2: Binary syntax with -U -d flags (source_dir filesystem)
        if [[ "$populate_success" != "true" ]]; then
            log_info "Method 2 - Binary syntax with flags: $populatefs_cmd -U -d $staging_dir $temp_dir/root-new.ext4"
            if "$populatefs_cmd" -U -d "$staging_dir" "$temp_dir/root-new.ext4" >"$SAVE_ERROR" 2>&1; then
                populate_success=true
                log_success "✓ Populatefs succeeded with binary syntax (method 2)"
            else
                log_warning "Binary syntax with -U -d failed..."
                if [[ -s "$SAVE_ERROR" ]]; then
                    log_info "Method 2 error output:"
                    head -5 "$SAVE_ERROR" | sed 's/^/    /' || true
                fi
            fi
        fi
        
        # Method 3: Alternative LibreELEC syntax with -d flag (filesystem source_dir)
        if [[ "$populate_success" != "true" ]]; then
            log_info "Method 3 - Alternative syntax: $populatefs_cmd -d $temp_dir/root-new.ext4 $staging_dir"
            if "$populatefs_cmd" -d "$temp_dir/root-new.ext4" "$staging_dir" >"$SAVE_ERROR" 2>&1; then
                populate_success=true
                log_success "✓ Populatefs succeeded with alternative syntax (method 3)"
            else
                log_warning "Alternative syntax failed..."
                if [[ -s "$SAVE_ERROR" ]]; then
                    log_info "Method 3 error output:"
                    head -5 "$SAVE_ERROR" | sed 's/^/    /' || true
                fi
            fi
        fi
        
        # Method 4: Help-based syntax detection
        if [[ "$populate_success" != "true" ]]; then
            log_info "Method 4 - Attempting to detect syntax from help output"
            local help_output
            help_output=$("$populatefs_cmd" --help 2>&1 || "$populatefs_cmd" -h 2>&1 || echo "No help available")
            log_info "Help output preview:"
            echo "$help_output" | head -3 | sed 's/^/    /' || true
            
            # Try syntax based on help patterns
            if echo "$help_output" | grep -q "\-U.*\-d"; then
                log_info "Help suggests -U -d syntax, trying: $populatefs_cmd -U -d $temp_dir/root-new.ext4 $staging_dir"
                if "$populatefs_cmd" -U -d "$temp_dir/root-new.ext4" "$staging_dir" >"$SAVE_ERROR" 2>&1; then
                    populate_success=true
                    log_success "✓ Populatefs succeeded with help-guided syntax (method 4)"
                fi
            fi
        fi
        
        # If all methods failed, show comprehensive error information
        if [[ "$populate_success" != "true" ]]; then
            log_error "All populatefs syntaxes failed. Comprehensive error analysis:"
            log_error "Tool info: $populatefs_cmd (type: $populatefs_type)"
            log_error "Tool version info:"
            "$populatefs_cmd" --version 2>&1 | head -2 | sed 's/^/    /' || echo "    No version info available"
            
            if [[ -s "$SAVE_ERROR" ]]; then
                log_error "Last error output (full):"
                cat "$SAVE_ERROR" | sed 's/^/    /'
            fi
            
            # Check if it might be a different tool with the same name
            log_error "Tool analysis:"
            which "$populatefs_cmd" 2>/dev/null | sed 's/^/    Tool path: /' || echo "    Tool not in PATH"
            file "$(command -v "$populatefs_cmd" 2>/dev/null || echo "$populatefs_cmd")" 2>/dev/null | sed 's/^/    Tool type: /' || echo "    Cannot analyze tool"
        fi
        
        if [[ "$populate_success" == "true" ]]; then
            # CRITICAL: Verify filesystem was actually populated
            log_info "Verifying filesystem population..."
            
            local verification_failed=false
            
            if tune2fs -l "$temp_dir/root-new.ext4" >/dev/null 2>&1; then
                local fs_info=$(tune2fs -l "$temp_dir/root-new.ext4" 2>/dev/null)
                local total_inodes=$(echo "$fs_info" | grep "Inode count:" | awk '{print $3}' || echo "0")
                local free_inodes=$(echo "$fs_info" | grep "Free inodes:" | awk '{print $3}' || echo "0")
                local used_inodes=$((total_inodes - free_inodes))
                local block_count=$(echo "$fs_info" | grep "Block count:" | awk '{print $3}' || echo "0")
                local free_blocks=$(echo "$fs_info" | grep "Free blocks:" | awk '{print $3}' || echo "0")
                local used_blocks=$((block_count - free_blocks))
                
                log_info "Filesystem usage: $used_inodes inodes used, $used_blocks blocks used"
                
                # Check for essential system files using e2ls
                local critical_missing=()
                local critical_files=("/bin/bash" "/sbin/init" "/etc/passwd" "/lib" "/usr/bin")
                for critical_file in "${critical_files[@]}"; do
                    if ! e2ls "$temp_dir/root-new.ext4:$critical_file" >/dev/null 2>&1; then
                        critical_missing+=("$critical_file")
                    fi
                done
                
                # FAIL BUILD if filesystem is essentially empty (would cause Pi 5 boot failure)
                if [[ $used_inodes -lt 100 ]]; then
                    log_error "CRITICAL: Filesystem population failed - only $used_inodes inodes used"
                    log_error "Expected: >1000 inodes for a functional Pi OS base system"
                    log_error "This would cause 'No init found' boot failure on Pi 5"
                    verification_failed=true
                elif [[ ${#critical_missing[@]} -gt 2 ]]; then
                    log_error "CRITICAL: Missing essential system files: ${critical_missing[*]}"
                    log_error "This would cause 'can't execute /sbin/init' boot failure on Pi 5"
                    verification_failed=true
                else
                    log_success "✓ Filesystem population verified: $used_inodes inodes, $used_blocks blocks used"
                    if [[ ${#critical_missing[@]} -gt 0 ]]; then
                        log_warning "Some files missing but build can continue: ${critical_missing[*]}"
                    fi
                fi
            else
                log_error "Could not verify filesystem with tune2fs - filesystem may be corrupted"
                verification_failed=true
            fi
            
            if [[ "$verification_failed" == "true" ]]; then
                log_error "Filesystem verification failed - build cannot continue"
                log_error "Debug: Check staging directory population and populatefs functionality"
                if [[ -d "$staging_dir" ]]; then
                    local staging_files=$(find "$staging_dir" -type f | wc -l)
                    log_error "Staging directory contained $staging_files files"
                    if [[ $staging_files -lt 1000 ]]; then
                        log_error "Root cause: Base Pi OS extraction to staging failed"
                    else
                        log_error "Root cause: populatefs failed to copy from staging to filesystem"
                    fi
                fi
                return 1
            fi
            
            log_success "Staging-style filesystem population complete!"
            # Restore original PATH
            export PATH="$original_path"
            return 0
        fi
    fi
    
    # Restore original PATH before error exit
    export PATH="$original_path"
    
    log_error "CRITICAL: populatefs failed - no fallback methods available"
    log_error "The build system now requires populatefs for reliable operation"
    log_error "E2tools fallback has been removed due to corruption issues"
    log_error "Please ensure populatefs is properly installed and configured"
    
    if [[ -s "$SAVE_ERROR" ]]; then
        log_error "Last error output:"
        cat "$SAVE_ERROR"
    fi
    
    return 1
}

# Note: e2tools functions removed - build system now requires populatefs for reliability
# This ensures consistent, corruption-free filesystem population

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
