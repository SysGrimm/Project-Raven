#!/bin/bash
set -e

# Local Build Test Script for Raven Pi
# Tests the build process locally (requires Docker or native Linux environment)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
WORK_DIR="/tmp/raven-build-test"
OUTPUT_DIR="$PROJECT_ROOT/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

check_requirements() {
    log "Checking requirements..."
    
    # Check if running on Linux or macOS with Docker
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Native Linux - check for required tools
        if ! command -v qemu-user-static &> /dev/null; then
            error "qemu-user-static not found. Install with: sudo apt-get install qemu-user-static"
        fi
        if ! command -v kpartx &> /dev/null; then
            error "kpartx not found. Install with: sudo apt-get install kpartx"
        fi
        success "Linux environment detected with required tools"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - require Docker
        if ! command -v docker &> /dev/null; then
            error "Docker not found. Install Docker Desktop for macOS"
        fi
        warning "macOS detected - will use Docker for build"
        USE_DOCKER=true
    else
        error "Unsupported OS: $OSTYPE"
    fi
    
    # Check for required tools
    for tool in curl jq xz wget; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool not found. Please install it first."
        fi
    done
    
    success "All requirements met"
}

prepare_workspace() {
    log "Preparing workspace..."
    
    # Clean up previous builds
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    mkdir -p "$OUTPUT_DIR"
    
    cd "$WORK_DIR"
    success "Workspace prepared: $WORK_DIR"
}

get_pi_os_version() {
    log "Checking latest Raspberry Pi OS version..."
    
    # Use our version checker script
    VERSION_INFO=$("$SCRIPT_DIR/check-version.sh" --json)
    VERSION_DATE=$(echo "$VERSION_INFO" | jq -r '.version_date')
    DOWNLOAD_URL=$(echo "$VERSION_INFO" | jq -r '.download_url')
    
    log "Latest version: $VERSION_DATE"
    log "Download URL: $DOWNLOAD_URL"
    
    echo "$VERSION_DATE" > version.txt
    echo "$DOWNLOAD_URL" > download-url.txt
}

download_pi_os() {
    log "Downloading Raspberry Pi OS..."
    
    DOWNLOAD_URL=$(cat download-url.txt)
    
    # Download with progress
    wget --progress=bar:force:noscroll -O raspios.img.xz "$DOWNLOAD_URL"
    
    # Verify download
    if [ ! -f raspios.img.xz ]; then
        error "Download failed"
    fi
    
    # Extract
    log "Extracting image..."
    xz -d raspios.img.xz
    
    success "Pi OS downloaded and extracted"
}

customize_image() {
    VERSION_DATE=$(cat version.txt)
    
    if [ "$USE_DOCKER" = true ]; then
        log "Using Docker for image customization..."
        
        # Create Dockerfile for customization
        cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    qemu-user-static \
    binfmt-support \
    parted \
    kpartx \
    xz-utils \
    curl \
    wget \
    unzip \
    systemd-container \
    jq

COPY scripts/customize-image.sh /customize-image.sh
RUN chmod +x /customize-image.sh

WORKDIR /work
EOF
        
        # Copy scripts to build context
        cp -r "$PROJECT_ROOT/scripts" .
        
        # Build Docker image
        docker build -t raven-builder .
        
        # Run customization in Docker
        docker run --privileged --rm \
            -v "$PWD:/work" \
            raven-builder \
            /customize-image.sh ./raspios.img "$VERSION_DATE"
    else
        log "Using native Linux for image customization..."
        "$SCRIPT_DIR/customize-image.sh" ./raspios.img "$VERSION_DATE"
    fi
    
    success "Image customization complete"
}

create_release_files() {
    VERSION_DATE=$(cat version.txt)
    OUTPUT_NAME="raven-pios-kodi-tailscale-$VERSION_DATE.img"
    
    log "Creating release files..."
    
    # Rename image
    mv raspios.img "$OUTPUT_NAME"
    
    # Compress image
    log "Compressing image (this may take a while)..."
    xz -9 -T 0 "$OUTPUT_NAME"
    
    # Generate checksums
    sha256sum "${OUTPUT_NAME}.xz" > "${OUTPUT_NAME}.xz.sha256"
    md5sum "${OUTPUT_NAME}.xz" > "${OUTPUT_NAME}.xz.md5"
    
    # Create info file
    cat > "${OUTPUT_NAME}.info" << EOF
Raven Pi Build Information
=========================

Build Date: $(date)
Pi OS Version: $VERSION_DATE
Image Name: ${OUTPUT_NAME}.xz
Compressed Size: $(ls -lh "${OUTPUT_NAME}.xz" | awk '{print $5}')
SHA256: $(cat "${OUTPUT_NAME}.xz.sha256" | cut -d' ' -f1)
MD5: $(cat "${OUTPUT_NAME}.xz.md5" | cut -d' ' -f1)

Included Software:
- Raspberry Pi OS Lite (ARM64)
- Kodi Media Center (auto-starting)
- Tailscale VPN (ready to configure)

Flash this image to an 8GB+ SD card and boot your Raspberry Pi.
Kodi will start automatically. To set up Tailscale, run: sudo tailscale up
EOF
    
    # Move files to output directory
    mv "${OUTPUT_NAME}.xz" "$OUTPUT_DIR/"
    mv "${OUTPUT_NAME}.xz.sha256" "$OUTPUT_DIR/"
    mv "${OUTPUT_NAME}.xz.md5" "$OUTPUT_DIR/"
    mv "${OUTPUT_NAME}.info" "$OUTPUT_DIR/"
    
    success "Release files created in $OUTPUT_DIR"
}

cleanup() {
    log "Cleaning up..."
    rm -rf "$WORK_DIR"
    success "Cleanup complete"
}

main() {
    echo -e "${BLUE}"
    cat << 'EOF'
██████╗  █████╗ ██╗   ██╗███████╗███╗   ██╗    ██████╗ ██╗
██╔══██╗██╔══██╗██║   ██║██╔════╝████╗  ██║    ██╔══██╗██║
██████╔╝███████║██║   ██║█████╗  ██╔██╗ ██║    ██████╔╝██║
██╔══██╗██╔══██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║    ██╔═══╝ ██║
██║  ██║██║  ██║ ╚████╔╝ ███████╗██║ ╚████║    ██║     ██║
╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝    ╚═╝     ╚═╝

Local Build Test
EOF
    echo -e "${NC}"
    
    # Process command line arguments
    case "${1:-}" in
        --help|-h)
            cat << 'EOF'
Raven Pi Local Build Test

Usage:
    ./local-build-test.sh [options]

Options:
    --clean          Clean build directory before starting
    --keep-temp      Don't clean up temporary files (for debugging)
    --help, -h       Show this help

This script will:
1. Check for the latest Raspberry Pi OS version
2. Download and extract the image
3. Customize it with Kodi and Tailscale
4. Create compressed release files with checksums

Output will be placed in the ./build directory.

Requirements:
- Linux: qemu-user-static, kpartx, xz-utils
- macOS: Docker Desktop
- All platforms: curl, jq, wget
EOF
            exit 0
            ;;
        --clean)
            rm -rf "$OUTPUT_DIR"
            log "Build directory cleaned"
            ;;
        --keep-temp)
            KEEP_TEMP=true
            ;;
    esac
    
    check_requirements
    prepare_workspace
    get_pi_os_version
    download_pi_os
    customize_image
    create_release_files
    
    if [ "$KEEP_TEMP" != true ]; then
        cleanup
    else
        log "Temporary files kept in: $WORK_DIR"
    fi
    
    echo ""
    success "Build complete! 🎉"
    echo ""
    log "Output files:"
    ls -lh "$OUTPUT_DIR"
    echo ""
    log "To flash the image:"
    echo "  1. Use Raspberry Pi Imager or balenaEtcher"
    echo "  2. Flash the .img.xz file directly to SD card"
    echo "  3. Boot your Pi and enjoy!"
}

# Handle Ctrl+C
trap 'error "Build interrupted by user"' INT

# Run main function
main "$@"
