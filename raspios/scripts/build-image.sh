#!/bin/bash

# Project Raven - Raspberry Pi OS Image Builder
# Creates customized Raspberry Pi OS images with Project Raven configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RASPIOS_DIR="${PROJECT_ROOT}/raspios"
BUILD_DIR="${PROJECT_ROOT}/build"
IMAGES_DIR="${PROJECT_ROOT}/images"

# Configuration
RASPIOS_VERSION="2024-07-04"
RASPIOS_LITE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-${RASPIOS_VERSION}/2024-07-04-raspios-bookworm-arm64-lite.img.xz"
RASPIOS_DESKTOP_URL="https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-${RASPIOS_VERSION}/2024-07-04-raspios-bookworm-arm64.img.xz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${PURPLE}[INFO] $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking build prerequisites..."
    
    # Check for required tools
    local required_tools=("wget" "xz" "parted" "losetup" "mount" "umount")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool '$tool' is not installed"
        fi
    done
    
    # Check if running on macOS (need different approach)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        warning "Building on macOS detected. This script requires Linux for image mounting."
        info "Consider using Pi-CI with Docker for cross-platform building"
        return 1
    fi
    
    # Check if running as root (needed for mounting)
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (needed for image mounting)"
    fi
    
    success "Prerequisites check passed"
}

# Function to download base Raspberry Pi OS image
download_base_image() {
    local variant="$1"  # "lite" or "desktop"
    local url
    local filename
    
    case "$variant" in
        "lite")
            url="$RASPIOS_LITE_URL"
            filename="raspios-lite.img.xz"
            ;;
        "desktop")
            url="$RASPIOS_DESKTOP_URL"
            filename="raspios-desktop.img.xz"
            ;;
        *)
            error "Invalid variant: $variant. Use 'lite' or 'desktop'"
            ;;
    esac
    
    log "Downloading Raspberry Pi OS $variant image..."
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    if [ ! -f "$filename" ]; then
        wget -O "$filename" "$url"
        success "Downloaded $filename"
    else
        info "$filename already exists, skipping download"
    fi
    
    # Extract image
    local img_name="${filename%.xz}"
    if [ ! -f "$img_name" ]; then
        log "Extracting image..."
        xz -d -k "$filename"
        success "Extracted to $img_name"
    else
        info "$img_name already extracted"
    fi
    
    echo "$BUILD_DIR/$img_name"
}

# Function to customize image
customize_image() {
    local image_path="$1"
    local output_name="$2"
    
    log "Customizing Raspberry Pi OS image..."
    
    # Create loop device
    local loop_device
    loop_device=$(losetup -f --show "$image_path")
    
    # Create partitions
    partprobe "$loop_device"
    
    # Mount boot and root partitions
    local boot_mount="/mnt/raven-boot"
    local root_mount="/mnt/raven-root"
    
    mkdir -p "$boot_mount" "$root_mount"
    
    mount "${loop_device}p1" "$boot_mount"
    mount "${loop_device}p2" "$root_mount"
    
    # Customize boot partition
    log "Customizing boot partition..."
    
    # Copy our custom config files
    cp "$RASPIOS_DIR/configurations/config.txt" "$boot_mount/"
    cp "$RASPIOS_DIR/configurations/cmdline.txt" "$boot_mount/"
    
    # Enable SSH by default
    touch "$boot_mount/ssh"
    
    # Copy first boot script
    cp "$RASPIOS_DIR/configurations/firstboot.sh" "$boot_mount/"
    chmod +x "$boot_mount/firstboot.sh"
    
    # Customize root partition
    log "Customizing root partition..."
    
    # Copy Ansible playbooks
    mkdir -p "$root_mount/opt/raven"
    cp -r "$RASPIOS_DIR/ansible" "$root_mount/opt/raven/"
    
    # Copy OS stripping script
    cp "$RASPIOS_DIR/scripts/strip-os.sh" "$root_mount/opt/raven/"
    chmod +x "$root_mount/opt/raven/strip-os.sh"
    
    # Copy all configuration scripts
    cp "$RASPIOS_DIR/scripts/configure-kodi.sh" "$root_mount/opt/raven/"
    chmod +x "$root_mount/opt/raven/configure-kodi.sh"
    
    # Copy video optimization script
    cp "$RASPIOS_DIR/scripts/optimize-video.sh" "$root_mount/opt/raven/"
    chmod +x "$root_mount/opt/raven/optimize-video.sh"
    
    # Copy boot splash scripts
    cp "$RASPIOS_DIR/scripts/configure-boot-splash.sh" "$root_mount/opt/raven/"
    chmod +x "$root_mount/opt/raven/configure-boot-splash.sh"
    
    cp "$RASPIOS_DIR/scripts/simple-boot-splash.sh" "$root_mount/opt/raven/"
    chmod +x "$root_mount/opt/raven/simple-boot-splash.sh"
    
    # Copy logo for boot splash (MANDATORY)
    if [ -f "$RASPIOS_DIR/configurations/logo.png" ]; then
        mkdir -p "$root_mount/opt/raven/configurations"
        cp "$RASPIOS_DIR/configurations/logo.png" "$root_mount/opt/raven/configurations/"
        success "Project Raven logo copied successfully"
    else
        error "CRITICAL: Project Raven logo not found at $RASPIOS_DIR/configurations/logo.png"
        error "Boot splash logo is mandatory for Project Raven systems"
        exit 1
    fi
    
    # Create systemd service for first boot
    cat > "$root_mount/etc/systemd/system/raven-firstboot.service" << 'EOF'
[Unit]
Description=Project Raven First Boot Setup
After=multi-user.target
Before=getty@tty1.service

[Service]
Type=oneshot
ExecStart=/boot/firstboot.sh
StandardOutput=journal+console
StandardError=journal+console
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the first boot service
    ln -sf /etc/systemd/system/raven-firstboot.service "$root_mount/etc/systemd/system/multi-user.target.wants/"
    
    # Add Project Raven version info
    cat > "$root_mount/opt/raven/VERSION" << EOF
Project Raven - Raspberry Pi OS Edition
Version: $(date '+%Y.%m.%d')
Build Date: $(date '+%Y-%m-%d %H:%M:%S')
Base OS: Raspberry Pi OS Bookworm
Architecture: arm64
EOF
    
    success "Image customization completed"
    
    # Cleanup mounts
    umount "$boot_mount" "$root_mount"
    rmdir "$boot_mount" "$root_mount"
    losetup -d "$loop_device"
    
    # Copy customized image to output
    mkdir -p "$IMAGES_DIR"
    cp "$image_path" "$IMAGES_DIR/$output_name"
    
    success "Created customized image: $IMAGES_DIR/$output_name"
}

# Function to build for specific device
build_device_image() {
    local device="$1"
    local variant="$2"
    
    log "Building Project Raven image for $device ($variant)..."
    
    # Download base image
    local base_image
    base_image=$(download_base_image "$variant")
    
    # Create device-specific image name
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local output_name="project-raven-${device}-${variant}-${timestamp}.img"
    
    # Customize the image
    customize_image "$base_image" "$output_name"
    
    # Compress the final image
    log "Compressing final image..."
    cd "$IMAGES_DIR"
    xz -9 -T 0 "$output_name"
    
    success "Built and compressed: ${output_name}.xz"
    
    # Generate checksums
    sha256sum "${output_name}.xz" > "${output_name}.xz.sha256"
    success "Generated checksum: ${output_name}.xz.sha256"
}

# Function to show build information
show_build_info() {
    echo ""
    echo "Project Raven - Raspberry Pi OS Image Builder"
    echo "================================================"
    echo ""
    echo "This builder creates customized Raspberry Pi OS images with:"
    echo "  - Kodi media center (auto-starting)"
    echo "  - Tailscale VPN integration"
    echo "  - Performance optimizations"
    echo "  - Automated first-boot configuration"
    echo ""
    echo "Supported devices:"
    echo "  - rpi4 (Raspberry Pi 4)"
    echo "  - rpi5 (Raspberry Pi 5)"
    echo "  - rpi-zero-2w (Raspberry Pi Zero 2 W)"
    echo ""
    echo "Image variants:"
    echo "  - lite (minimal, headless)"
    echo "  - desktop (full desktop environment)"
    echo ""
}

# Function to show usage
show_usage() {
    show_build_info
    echo "Usage: $0 [DEVICE] [VARIANT]"
    echo ""
    echo "Examples:"
    echo "  $0 rpi5 lite      # Raspberry Pi 5 with lite OS"
    echo "  $0 rpi4 desktop   # Raspberry Pi 4 with desktop OS"
    echo "  $0 all lite       # All devices with lite OS"
    echo ""
    echo "Special commands:"
    echo "  $0 clean          # Clean build directory"
    echo "  $0 list           # List available images"
    echo "  $0 help           # Show this help"
    echo ""
}

# Function to build all device images
build_all_images() {
    local variant="$1"
    local devices=("rpi4" "rpi5" "rpi-zero-2w")
    
    log "Building Project Raven images for all devices ($variant)..."
    
    for device in "${devices[@]}"; do
        build_device_image "$device" "$variant"
    done
    
    success "All device images built successfully!"
}

# Function to clean build directory
clean_build() {
    log "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    success "Build directory cleaned"
}

# Function to list available images
list_images() {
    log "Available Project Raven images:"
    echo ""
    
    if [ -d "$IMAGES_DIR" ] && [ "$(ls -A "$IMAGES_DIR")" ]; then
        ls -la "$IMAGES_DIR"
    else
        info "No images found. Run a build first."
    fi
}

# Main execution
main() {
    case "${1:-help}" in
        "rpi4"|"rpi5"|"rpi-zero-2w")
            check_prerequisites
            build_device_image "$1" "${2:-lite}"
            ;;
        "all")
            check_prerequisites
            build_all_images "${2:-lite}"
            ;;
        "clean")
            clean_build
            ;;
        "list")
            list_images
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            error "Unknown command: $1. Use '$0 help' for usage information."
            ;;
    esac
}

# Run main function with all arguments
main "$@"
