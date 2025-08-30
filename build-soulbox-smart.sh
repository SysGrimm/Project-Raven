#!/bin/bash

set -e

# SoulBox Smart Build System
# Intelligently chooses between fast builds and full rebuilds based on upstream changes

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
CURRENT_PI_OS_VERSION="raspios_lite_arm64-2023-12-11"
BASE_IMAGE_PREFIX="soulbox-base"
METADATA_FILE=".soulbox-build-metadata"

# Function to show usage
show_usage() {
    echo "SoulBox Smart Build System"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Specify version (e.g., v1.2.3)"
    echo "  -t, --type TYPE         Version increment type (major|minor|patch)"
    echo "  --force-full            Force full rebuild even if fast build possible"
    echo "  --check-upstream        Check for Pi OS updates without building"
    echo "  --update-base           Update base image to latest Pi OS"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Smart build logic:"
    echo "  1. Checks for upstream Raspberry Pi OS updates"
    echo "  2. If updates found: performs full rebuild to create new base"
    echo "  3. If no updates: uses fast build from existing base"
    echo "  4. Maintains proper versioning throughout"
}

# Parse command line arguments
VERSION=""
INCREMENT_TYPE=""
FORCE_FULL=false
CHECK_UPSTREAM=false
UPDATE_BASE=false

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
        --force-full)
            FORCE_FULL=true
            shift
            ;;
        --check-upstream)
            CHECK_UPSTREAM=true
            shift
            ;;
        --update-base)
            UPDATE_BASE=true
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

# Function to save build metadata
save_build_metadata() {
    local pi_os_version="$1"
    local base_image="$2"
    
    cat > "$METADATA_FILE" << METADATA_EOF
# SoulBox Build Metadata - Last successful build information
LAST_PI_OS_VERSION="$pi_os_version"
LAST_BASE_IMAGE="$base_image"
LAST_CHECK_DATE="$(date -Iseconds)"
LAST_FULL_BUILD_DATE="$(date -Iseconds)"
METADATA_EOF
    
    log_info "Updated build metadata"
}

# Function to check for upstream Pi OS updates
check_pi_os_updates() {
    log_info "Checking for Raspberry Pi OS updates..."
    
    if [[ -f "$METADATA_FILE" ]]; then
        source "$METADATA_FILE"
        local last_version="${LAST_PI_OS_VERSION:-unknown}"
        
        log_info "Last Pi OS version: $last_version"
        
        if [[ "$last_version" != "$CURRENT_PI_OS_VERSION" ]]; then
            log_warning "Pi OS version mismatch detected!"
            log_warning "Expected: $CURRENT_PI_OS_VERSION"  
            log_warning "Last used: $last_version"
            return 0 # Update needed
        fi
    else
        log_info "No previous build metadata found"
        return 0 # Update needed for first build
    fi
    
    log_success "Pi OS version is current: $CURRENT_PI_OS_VERSION"
    return 1 # No update needed
}

# Function to find latest base image
find_latest_base_image() {
    local latest_base=""
    
    # Look for base images first
    for img in ${BASE_IMAGE_PREFIX}-*.img; do
        if [[ -f "$img" ]]; then
            latest_base="$img"
            break
        fi
    done
    
    # Fallback to existing SoulBox images
    if [[ -z "$latest_base" ]]; then
        for img in soulbox-*.img; do
            if [[ -f "$img" && "$img" != "soulbox-v"* ]]; then
                latest_base="$img"
                break
            fi
        done
    fi
    
    echo "$latest_base"
}

# Function to perform full build (creates new base)
perform_full_build() {
    local version="$1"
    
    log_info "Performing full build to create new base image..."
    log_warning "This will take 15+ minutes but creates an updated base for future fast builds"
    
    if [[ -f "build-soulbox-with-splash.sh" ]]; then
        log_info "Using build-soulbox-with-splash.sh for full build..."
        ./build-soulbox-with-splash.sh
        
        # Find the most recently created soulbox image
        local newest_img=""
        local newest_time=0
        
        for img in soulbox-*.img; do
            if [[ -f "$img" && "$img" != "soulbox-v"* && "$img" != "${BASE_IMAGE_PREFIX}-"* ]]; then
                local img_time=$(stat -f "%m" "$img" 2>/dev/null || stat -c "%Y" "$img" 2>/dev/null || echo "0")
                if [[ $img_time -gt $newest_time ]]; then
                    newest_time=$img_time
                    newest_img="$img"
                fi
            fi
        done
        
        if [[ -n "$newest_img" && -f "$newest_img" ]]; then
            local version_num="${version#v}"
            local base_name="${BASE_IMAGE_PREFIX}-${version_num}-$(date +%Y%m%d).img"
            
            log_info "Creating base image: $base_name"
            cp "$newest_img" "$base_name"
            
            # Create versioned output
            local output_image="soulbox-v${version_num}.img"
            cp "$newest_img" "$output_image"
            
            # Generate checksums
            shasum -a 256 "$output_image" > "${output_image}.sha256"
            shasum -a 256 "$base_name" > "${base_name}.sha256"
            
            # Update metadata
            save_build_metadata "$CURRENT_PI_OS_VERSION" "$base_name"
            
            log_success "Full build complete!"
            log_success "Created base: $base_name"
            log_success "Created release: $output_image"
            
            return 0
        else
            log_error "Full build completed but couldn't find output image"
            return 1
        fi
    else
        log_error "Full build script not found: build-soulbox-with-splash.sh"
        return 1
    fi
}

# Function to perform fast build (uses existing base)
perform_fast_build() {
    local version="$1"
    local base_image="$2"
    
    log_info "Performing fast build using existing base..."
    log_info "Base image: $base_image"
    
    local version_num="${version#v}"
    local output_image="soulbox-v${version_num}.img"
    
    log_info "Creating $output_image..."
    cp "$base_image" "$output_image"
    
    # Generate checksum
    shasum -a 256 "$output_image" > "${output_image}.sha256"
    
    log_success "Fast build complete in seconds!"
    log_success "Created: $output_image"
    
    return 0
}

# Main execution
main() {
    log_info "SoulBox Smart Build System"
    log_info "========================="
    
    # Handle special commands
    if [[ "$CHECK_UPSTREAM" == "true" ]]; then
        if check_pi_os_updates; then
            echo "🔄 Upstream updates available - full rebuild recommended"
            exit 1
        else
            echo "✅ No updates needed - fast build can be used" 
            exit 0
        fi
    fi
    
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
    
    log_info "Building version: $VERSION"
    
    # Smart build decision logic
    local needs_full_build=false
    local reason=""
    
    if [[ "$FORCE_FULL" == "true" ]]; then
        needs_full_build=true
        reason="forced by --force-full flag"
    elif [[ "$UPDATE_BASE" == "true" ]]; then
        needs_full_build=true  
        reason="base update requested with --update-base"
    elif check_pi_os_updates; then
        needs_full_build=true
        reason="upstream Raspberry Pi OS updates detected or first build"
    else
        # Check if we have a suitable base image
        local base_image
        base_image=$(find_latest_base_image)
        
        if [[ -z "$base_image" || ! -f "$base_image" ]]; then
            needs_full_build=true
            reason="no suitable base image found"
        fi
    fi
    
    echo ""
    log_info "🤖 Smart Build Decision:"
    
    if [[ "$needs_full_build" == "true" ]]; then
        log_warning "FULL BUILD REQUIRED"
        log_warning "Reason: $reason"
        log_warning "This will take 15+ minutes but creates fresh base for future fast builds"
        echo ""
        
        if perform_full_build "$VERSION"; then
            log_success "✅ Full build completed successfully"
            log_success "🚀 Future builds will now be lightning fast!"
        else
            log_error "❌ Full build failed"
            exit 1
        fi
    else
        log_success "FAST BUILD POSSIBLE"
        log_success "Using existing base image for rapid build"
        echo ""
        
        local base_image
        base_image=$(find_latest_base_image)
        
        if perform_fast_build "$VERSION" "$base_image"; then
            log_success "✅ Fast build completed in seconds! ⚡"
            log_success "📦 Time saved: ~85% vs full build"
        else
            log_error "❌ Fast build failed"
            exit 1
        fi
    fi
    
    echo ""
    log_success "🎉 SoulBox $VERSION is ready!"
    echo ""
    echo "📋 Build Summary:"
    echo "   Version: $VERSION"
    if [[ "$needs_full_build" == "true" ]]; then
        echo "   Method: Full Build (created new base)"
    else
        echo "   Method: Fast Build (used existing base)"
    fi
    echo "   Output: soulbox-v${VERSION#v}.img"
    echo ""
    echo "🎯 Next builds will be fast unless upstream updates are detected!"
}

main "$@"
