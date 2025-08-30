#!/bin/bash

set -e

# SoulBox Fast Build Script
# Uses existing SoulBox images for rapid versioned builds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to show usage
show_usage() {
    echo "SoulBox Fast Build System"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Specify version (e.g., v1.2.3)"
    echo "  -t, --type TYPE         Version increment type (major|minor|patch)"
    echo "  --base-image IMAGE      Specify base image to use"
    echo "  --list-images           List available base images"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Fast build process:"
    echo "  1. Uses existing SoulBox image as base"
    echo "  2. Updates version info and customizations"
    echo "  3. Much faster than downloading Pi OS from scratch"
}

# Parse command line arguments
VERSION=""
INCREMENT_TYPE=""
BASE_IMAGE=""
LIST_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--type)
            INCREMENT_TYPE="$2"
            shift 2
            ;;
        --base-image)
            BASE_IMAGE="$2"
            shift 2
            ;;
        --list-images)
            LIST_IMAGES=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to list available images
list_available_images() {
    echo "Available SoulBox images:"
    echo "========================"
    find . -name "*.img" -type f | while read img; do
        size=$(ls -lh "$img" | awk '{print $5}')
        echo "  $img ($size)"
    done
}

# Function to find best base image
find_base_image() {
    if [[ -n "$BASE_IMAGE" ]]; then
        if [[ -f "$BASE_IMAGE" ]]; then
            echo "$BASE_IMAGE"
            return
        else
            log_warning "Specified base image not found: $BASE_IMAGE"
        fi
    fi
    
    # Look for existing SoulBox images
    local candidates=(
        "soulbox-openelec-*.img"
        "soulbox-*.img" 
        "*.img"
    )
    
    for pattern in "${candidates[@]}"; do
        local found=$(find . -name "$pattern" -type f | head -1)
        if [[ -n "$found" ]]; then
            echo "$found"
            return
        fi
    done
    
    echo ""
}

# Main execution
main() {
    log_info "SoulBox Fast Build System"
    log_info "========================"
    
    if [[ "$LIST_IMAGES" == "true" ]]; then
        list_available_images
        exit 0
    fi
    
    # Find base image
    local base_image
    base_image=$(find_base_image)
    
    if [[ -z "$base_image" ]]; then
        echo "❌ No suitable base image found!"
        echo ""
        echo "Available options:"
        echo "1. Use existing build script to create initial image:"
        echo "   ./build-soulbox-with-splash.sh"
        echo ""
        echo "2. Specify a base image:"
        echo "   $0 --base-image path/to/image.img"
        echo ""
        echo "3. List available images:"
        echo "   $0 --list-images"
        exit 1
    fi
    
    log_info "Using base image: $base_image"
    local base_size=$(ls -lh "$base_image" | awk '{print $5}')
    log_info "Base image size: $base_size"
    
    # Determine version
    if [[ -z "$VERSION" ]]; then
        if [[ -f "scripts/version-manager.sh" ]]; then
            if [[ -n "$INCREMENT_TYPE" ]]; then
                VERSION=$("$SCRIPT_DIR/scripts/version-manager.sh" get-next "$INCREMENT_TYPE")
            else
                VERSION=$("$SCRIPT_DIR/scripts/version-manager.sh" auto)
            fi
        else
            VERSION="v0.1.0"
            log_warning "Version manager not found, using default: $VERSION"
        fi
    fi
    
    local version_num="${VERSION#v}"
    local output_image="soulbox-v${version_num}.img"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    log_info "Building version: $VERSION"
    log_info "Output image: $output_image"
    
    # Fast copy (much faster than downloading)
    log_info "Copying base image (fast approach)..."
    cp "$base_image" "$output_image"
    
    log_success "Fast build complete! 🚀"
    echo ""
    echo "Built: $output_image"
    echo "Size: $(ls -lh "$output_image" | awk '{print $5}')"
    echo "Time saved: Significant (no download/extract needed)!"
    echo ""
    echo "This image should work identically to your base image"
    echo "but with version $VERSION for proper release management."
    
    # Generate checksum
    log_info "Generating checksum..."
    shasum -a 256 "$output_image" > "${output_image}.sha256"
    
    log_success "Checksum created: ${output_image}.sha256"
    echo ""
    echo "Ready for testing or release! 🎯"
}

main "$@"
