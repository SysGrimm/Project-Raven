#!/bin/bash
# SoulBox rpi-imager Compatible Image Builder
# Creates a compressed image with metadata for use with Raspberry Pi Imager
#
# Usage: ./build-rpi-imager-image.sh [options]

set -euo pipefail

# Configuration
PROJECT_DIR=$(dirname $(dirname $(realpath $0)))
BUILD_DIR="${PROJECT_DIR}/build"
DIST_DIR="${PROJECT_DIR}/dist"
IMAGE_VERSION="${IMAGE_VERSION:-$(date +%Y%m%d)}"
IMAGE_NAME="soulbox-${IMAGE_VERSION}"
FINAL_IMAGE="${DIST_DIR}/${IMAGE_NAME}.img"
COMPRESSED_IMAGE="${DIST_DIR}/${IMAGE_NAME}.img.xz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show usage
show_usage() {
    cat << EOF
SoulBox rpi-imager Compatible Image Builder

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --version VER       Set image version (default: YYYYMMDD)
    --dist-dir DIR      Distribution directory (default: ./dist)
    --compress          Compress final image with xz
    --metadata          Generate rpi-imager metadata JSON
    --help              Show this help

EXAMPLES:
    $0                              # Build basic image
    $0 --compress --metadata        # Build compressed image with metadata
    $0 --version v1.2.0             # Build with specific version

OUTPUT:
    dist/soulbox-VERSION.img        # Raw image file
    dist/soulbox-VERSION.img.xz     # Compressed image (if --compress)
    dist/soulbox-metadata.json      # rpi-imager metadata (if --metadata)

EOF
}

# Check if we're running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        log_error "Building system images requires root privileges"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local deps=("debootstrap" "qemu-user-static" "parted" "kpartx" "losetup")
    for dep in "${deps[@]}"; do
        if ! command -v ${dep} >/dev/null 2>&1; then
            log_error "Missing dependency: ${dep}"
            log_error "Install with: sudo apt-get install ${dep}"
            exit 1
        fi
    done
    
    # Check for compression tools if needed
    if [[ "${COMPRESS:-false}" == "true" ]]; then
        if ! command -v xz >/dev/null 2>&1; then
            log_error "Missing dependency: xz (required for compression)"
            log_error "Install with: sudo apt-get install xz-utils"
            exit 1
        fi
    fi
    
    log_info "Dependencies check passed"
}

# Prepare distribution directory
prepare_dist() {
    log_info "Preparing distribution directory: ${DIST_DIR}"
    
    mkdir -p "${DIST_DIR}"
    
    # Clean up any existing files for this version
    rm -f "${FINAL_IMAGE}" "${COMPRESSED_IMAGE}" "${DIST_DIR}/${IMAGE_NAME}.*"
    
    log_info "Distribution directory ready"
}

# Build the base image using our existing script
build_base_image() {
    log_info "Building base SoulBox image..."
    
    # Use our existing build script
    "${PROJECT_DIR}/scripts/build-image.sh" "${BUILD_DIR}"
    
    # Find the created image
    local built_image=$(find "${BUILD_DIR}" -name "soulbox-*.img" -type f | head -1)
    
    if [[ -z "${built_image}" ]]; then
        log_error "No built image found in ${BUILD_DIR}"
        exit 1
    fi
    
    # Copy to distribution directory with proper name
    cp "${built_image}" "${FINAL_IMAGE}"
    
    log_info "Base image built: ${FINAL_IMAGE}"
}

# Optimize image for distribution
optimize_image() {
    log_info "Optimizing image for distribution..."
    
    # Get image info
    local image_size=$(stat -f%z "${FINAL_IMAGE}" 2>/dev/null || stat -c%s "${FINAL_IMAGE}")
    local image_size_mb=$((image_size / 1024 / 1024))
    
    log_info "Image size: ${image_size_mb} MB"
    
    # TODO: Could add image shrinking here if needed
    # For now, just report the size
    
    log_info "Image optimization complete"
}

# Compress image if requested
compress_image() {
    if [[ "${COMPRESS:-false}" != "true" ]]; then
        log_info "Skipping compression (not requested)"
        return
    fi
    
    log_info "Compressing image with xz..."
    
    # Compress with maximum compression
    xz -9 -c "${FINAL_IMAGE}" > "${COMPRESSED_IMAGE}"
    
    # Get compression ratio
    local original_size=$(stat -f%z "${FINAL_IMAGE}" 2>/dev/null || stat -c%s "${FINAL_IMAGE}")
    local compressed_size=$(stat -f%z "${COMPRESSED_IMAGE}" 2>/dev/null || stat -c%s "${COMPRESSED_IMAGE}")
    local ratio=$(echo "scale=1; ${compressed_size} * 100 / ${original_size}" | bc -l 2>/dev/null || echo "N/A")
    
    log_info "Compression complete: ${ratio}% of original size"
    log_info "Compressed image: ${COMPRESSED_IMAGE}"
}

# Generate SHA256 checksums
generate_checksums() {
    log_info "Generating checksums..."
    
    cd "${DIST_DIR}"
    
    # Generate checksums for all image files
    for file in "${IMAGE_NAME}".img*; do
        if [[ -f "${file}" ]]; then
            sha256sum "${file}" > "${file}.sha256"
            log_info "Checksum created: ${file}.sha256"
        fi
    done
    
    cd - >/dev/null
}

# Generate rpi-imager metadata JSON
generate_metadata() {
    if [[ "${METADATA:-false}" != "true" ]]; then
        log_info "Skipping metadata generation (not requested)"
        return
    fi
    
    log_info "Generating rpi-imager metadata..."
    
    local metadata_file="${DIST_DIR}/soulbox-metadata.json"
    local image_file="${FINAL_IMAGE}"
    local compressed_file="${COMPRESSED_IMAGE}"
    
    # Use compressed image if available, otherwise raw image
    local target_image="${image_file}"
    local target_compressed="false"
    
    if [[ -f "${compressed_file}" ]]; then
        target_image="${compressed_file}"
        target_compressed="true"
    fi
    
    # Get image information
    local image_size=$(stat -f%z "${target_image}" 2>/dev/null || stat -c%s "${target_image}")
    local sha256=$(sha256sum "${target_image}" | cut -d' ' -f1)
    local filename=$(basename "${target_image}")
    
    # Generate metadata JSON
    cat > "${metadata_file}" << EOF
{
  "os_list": [
    {
      "os": "soulbox",
      "name": "SoulBox Media Center",
      "description": "Debian-based Raspberry Pi 5 OS optimized for Kodi media center with Tailscale VPN integration",
      "version": "${IMAGE_VERSION}",
      "release_date": "$(date -u +%Y-%m-%d)",
      "website": "https://github.com/your-username/soulbox",
      "extract_size": ${image_size},
      "extract_sha256": "${sha256}",
      "image_download_size": ${image_size},
      "image_download_sha256": "${sha256}",
      "archive_download_size": ${image_size},
      "archive_download_sha256": "${sha256}",
      "url": "file://${PWD}/${target_image}",
      "subitems_url": "file://${PWD}/${metadata_file}",
      "init_format": "systemd",
      "supported_models": [
        "Pi 5"
      ],
      "feature_level": 20230419
    }
  ]
}
EOF
    
    log_info "Metadata generated: ${metadata_file}"
    
    # Also create a simplified version for local testing
    cat > "${DIST_DIR}/local-images.json" << EOF
{
  "imager": {
    "version_latest": "1.8.5",
    "version_list": []
  },
  "os_list": [
    {
      "name": "SoulBox v${IMAGE_VERSION}",
      "description": "Kodi Media Center with Tailscale VPN",
      "icon": "https://github.com/raspberrypi/rpi-imager/raw/qml/src/icons/rpi-imager.ico",
      "subitems": [
        {
          "name": "SoulBox Media Center v${IMAGE_VERSION}",
          "description": "Complete media center with VPN support for Raspberry Pi 5",
          "icon": "https://github.com/raspberrypi/rpi-imager/raw/qml/src/icons/rpi-imager.ico",
          "url": "file://${PWD}/${target_image}",
          "extract_size": ${image_size},
          "extract_sha256": "${sha256}",
          "image_download_size": ${image_size},
          "compressed": ${target_compressed},
          "init_format": "systemd"
        }
      ]
    }
  ]
}
EOF
    
    log_info "Local testing metadata: ${DIST_DIR}/local-images.json"
}

# Display final information
show_results() {
    log_info "SoulBox rpi-imager image build complete!"
    echo ""
    echo "=== Build Results ==="
    echo ""
    
    # List all created files
    ls -lh "${DIST_DIR}/${IMAGE_NAME}"* 2>/dev/null || true
    
    echo ""
    echo "=== Usage Instructions ==="
    echo ""
    echo "1. RASPBERRY PI IMAGER SETUP:"
    echo "   - Open Raspberry Pi Imager"
    echo "   - Click gear icon -> Options -> Set custom repository"
    echo "   - Enter: file://${DIST_DIR}/local-images.json"
    echo "   - Or use 'Use custom image' and select: ${FINAL_IMAGE}"
    echo ""
    echo "2. CONFIGURATION (Optional):"
    echo "   - Generate Tailscale config:"
    echo "     ${PROJECT_DIR}/scripts/create-tailscale-config.sh --interactive"
    echo "   - Copy config files to SD card boot partition after flashing"
    echo ""
    echo "3. DISTRIBUTION:"
    if [[ -f "${COMPRESSED_IMAGE}" ]]; then
        echo "   - Distribute compressed image: ${COMPRESSED_IMAGE}"
        echo "   - Include checksum: ${COMPRESSED_IMAGE}.sha256"
    else
        echo "   - Distribute raw image: ${FINAL_IMAGE}"
        echo "   - Include checksum: ${FINAL_IMAGE}.sha256"
    fi
    
    if [[ "${METADATA:-false}" == "true" ]]; then
        echo "   - Include metadata: ${DIST_DIR}/soulbox-metadata.json"
    fi
    
    echo ""
    echo "=== Advanced Usage ==="
    echo "   - Host images on web server for remote distribution"
    echo "   - Update metadata JSON URLs to point to hosted files"
    echo "   - Users can add custom repository URL in rpi-imager"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                IMAGE_VERSION="$2"
                IMAGE_NAME="soulbox-${IMAGE_VERSION}"
                FINAL_IMAGE="${DIST_DIR}/${IMAGE_NAME}.img"
                COMPRESSED_IMAGE="${DIST_DIR}/${IMAGE_NAME}.img.xz"
                shift 2
                ;;
            --dist-dir)
                DIST_DIR="$2"
                FINAL_IMAGE="${DIST_DIR}/${IMAGE_NAME}.img"
                COMPRESSED_IMAGE="${DIST_DIR}/${IMAGE_NAME}.img.xz"
                shift 2
                ;;
            --compress)
                COMPRESS="true"
                shift
                ;;
            --metadata)
                METADATA="true"
                shift
                ;;
            --help)
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
}

# Main execution
main() {
    log_info "Starting SoulBox rpi-imager compatible image build"
    log_info "Version: ${IMAGE_VERSION}"
    
    parse_args "$@"
    check_root
    check_dependencies
    prepare_dist
    build_base_image
    optimize_image
    compress_image
    generate_checksums
    generate_metadata
    show_results
    
    log_info "Build process completed successfully!"
}

# Execute main function
main "$@"
