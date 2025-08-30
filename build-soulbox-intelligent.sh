#!/bin/bash

set -e

# SoulBox Intelligent Build System
# Advanced build orchestration with success tracking and upstream monitoring

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
BUILD_STATE_FILE=".soulbox-build-state"
PI_OS_CACHE_FILE=".pi-os-cache"
CURRENT_PI_OS_VERSION="raspios_lite_arm64-2023-12-11"
BASE_IMAGE_PREFIX="soulbox-base"

# Function to show usage
show_usage() {
    echo "SoulBox Intelligent Build System"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Specify version (e.g., v1.2.3)"
    echo "  -t, --type TYPE         Version increment type (major|minor|patch)"
    echo "  --force-full            Force full rebuild regardless of state"
    echo "  --check-state           Show current build state without building"
    echo "  --reset-state           Reset build state (forces full rebuild)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Intelligent build decision tree:"
    echo "  1. Check if successful image exists"
    echo "  2. If no successful build -> Full build"
    echo "  3. If successful build exists:"
    echo "     a. Get creation date and Pi OS version used"
    echo "     b. Check if newer Pi OS version available"
    echo "     c. If newer Pi OS -> Full build"
    echo "     d. If same Pi OS -> Fast build"
}

# Parse command line arguments
VERSION=""
INCREMENT_TYPE=""
FORCE_FULL=false
CHECK_STATE=false
RESET_STATE=false

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
        --check-state)
            CHECK_STATE=true
            shift
            ;;
        --reset-state)
            RESET_STATE=true
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

# Function to validate image integrity
validate_image() {
    local image_path="$1"
    
    if [[ ! -f "$image_path" ]]; then
        return 1
    fi
    
    # Check file size (should be reasonable for Pi OS image)
    local size=$(stat -f "%z" "$image_path" 2>/dev/null || stat -c "%s" "$image_path" 2>/dev/null || echo "0")
    if [[ $size -lt 1000000000 ]]; then  # Less than 1GB is suspicious
        log_warning "Image $image_path appears too small: $size bytes"
        return 1
    fi
    
    # Check if checksum file exists and validates
    local checksum_file="${image_path}.sha256"
    if [[ -f "$checksum_file" ]]; then
        if ! shasum -a 256 -c "$checksum_file" >/dev/null 2>&1; then
            log_warning "Checksum validation failed for $image_path"
            return 1
        fi
    else
        log_warning "No checksum file found for $image_path"
    fi
    
    return 0
}

# Function to get latest Pi OS version from upstream
get_latest_pi_os_version() {
    local cache_duration=3600 # 1 hour
    
    # Check cache first
    if [[ -f "$PI_OS_CACHE_FILE" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -f "%m" "$PI_OS_CACHE_FILE" 2>/dev/null || stat -c "%Y" "$PI_OS_CACHE_FILE" 2>/dev/null || echo "0") ))
        if [[ $cache_age -lt $cache_duration ]]; then
            cat "$PI_OS_CACHE_FILE"
            return
        fi
    fi
    
    # Fetch latest version
    local latest_version=""
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -s "https://downloads.raspberrypi.org/raspios_lite_arm64/images/" 2>/dev/null | grep -o 'raspios_lite_arm64-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | sort -V | tail -1 || echo "")
    fi
    
    # Fallback to current version
    if [[ -z "$latest_version" ]]; then
        latest_version="$CURRENT_PI_OS_VERSION"
    fi
    
    # Cache the result
    echo "$latest_version" > "$PI_OS_CACHE_FILE"
    echo "$latest_version"
}

# Function to save successful build state
save_build_state() {
    local image_path="$1"
    local version="$2"
    local pi_os_version="$3"
    local build_method="$4"
    
    local build_date=$(date -Iseconds)
    local image_size=$(stat -f "%z" "$image_path" 2>/dev/null || stat -c "%s" "$image_path" 2>/dev/null || echo "0")
    
    cat > "$BUILD_STATE_FILE" << EOF
# SoulBox Build State - Last successful build
LAST_SUCCESSFUL_BUILD=true
LAST_BUILD_DATE="$build_date"
LAST_IMAGE_PATH="$image_path"
LAST_VERSION="$version"
LAST_PI_OS_VERSION="$pi_os_version"
LAST_BUILD_METHOD="$build_method"
LAST_IMAGE_SIZE="$image_size"
BUILD_HOST="$(hostname)"
BUILD_USER="$(whoami)"
EOF
    
    log_info "Saved successful build state"
}

# Function to get current build state
get_build_state() {
    if [[ -f "$BUILD_STATE_FILE" ]]; then
        source "$BUILD_STATE_FILE"
        
        # Validate the recorded image still exists and is valid
        if [[ -n "$LAST_IMAGE_PATH" ]] && validate_image "$LAST_IMAGE_PATH"; then
            echo "HAS_SUCCESSFUL_BUILD=true"
            echo "LAST_BUILD_DATE=${LAST_BUILD_DATE:-unknown}"
            echo "LAST_IMAGE_PATH=${LAST_IMAGE_PATH:-unknown}"
            echo "LAST_VERSION=${LAST_VERSION:-unknown}"
            echo "LAST_PI_OS_VERSION=${LAST_PI_OS_VERSION:-unknown}"
            echo "LAST_BUILD_METHOD=${LAST_BUILD_METHOD:-unknown}"
            echo "LAST_IMAGE_SIZE=${LAST_IMAGE_SIZE:-unknown}"
        else
            echo "HAS_SUCCESSFUL_BUILD=false"
            echo "REASON=image_missing_or_invalid"
        fi
    else
        echo "HAS_SUCCESSFUL_BUILD=false"
        echo "REASON=no_state_file"
    fi
}

# Function to make intelligent build decision
make_build_decision() {
    log_info "Analyzing build requirements..."
    
    if [[ "$FORCE_FULL" == "true" ]]; then
        echo "DECISION=full_build"
        echo "REASON=forced_by_flag"
        return
    fi
    
    # Get current build state
    local state
    state=$(get_build_state)
    local has_successful=$(echo "$state" | grep "HAS_SUCCESSFUL_BUILD=" | cut -d= -f2)
    
    if [[ "$has_successful" != "true" ]]; then
        local reason=$(echo "$state" | grep "REASON=" | cut -d= -f2 || echo "unknown")
        echo "DECISION=full_build"
        echo "REASON=no_successful_build_$reason"
        return
    fi
    
    # We have a successful build - check if Pi OS is current
    local last_pi_os=$(echo "$state" | grep "LAST_PI_OS_VERSION=" | cut -d= -f2 | tr -d '"')
    local last_build_date=$(echo "$state" | grep "LAST_BUILD_DATE=" | cut -d= -f2 | tr -d '"')
    local last_image=$(echo "$state" | grep "LAST_IMAGE_PATH=" | cut -d= -f2 | tr -d '"')
    
    log_info "Last successful build:"
    log_info "  Date: $last_build_date"
    log_info "  Pi OS: $last_pi_os"
    log_info "  Image: $last_image"
    
    # Check current Pi OS version
    local latest_pi_os
    latest_pi_os=$(get_latest_pi_os_version)
    
    log_info "Comparing Pi OS versions:"
    log_info "  Last used: $last_pi_os"
    log_info "  Latest available: $latest_pi_os"
    
    if [[ "$last_pi_os" != "$latest_pi_os" ]]; then
        echo "DECISION=full_build"
        echo "REASON=pi_os_update_available"
        echo "OLD_VERSION=$last_pi_os"
        echo "NEW_VERSION=$latest_pi_os"
    else
        echo "DECISION=fast_build"
        echo "REASON=pi_os_current"
        echo "BASE_IMAGE=$last_image"
    fi
}

# Function to show current state
show_build_state() {
    echo "SoulBox Build State Analysis"
    echo "==========================="
    echo ""
    
    local state
    state=$(get_build_state)
    local has_successful=$(echo "$state" | grep "HAS_SUCCESSFUL_BUILD=" | cut -d= -f2)
    
    if [[ "$has_successful" == "true" ]]; then
        echo "Last Successful Build: YES"
        echo "  Date: $(echo "$state" | grep "LAST_BUILD_DATE=" | cut -d= -f2 | tr -d '"')"
        echo "  Version: $(echo "$state" | grep "LAST_VERSION=" | cut -d= -f2 | tr -d '"')"
        echo "  Image: $(echo "$state" | grep "LAST_IMAGE_PATH=" | cut -d= -f2 | tr -d '"')"
        echo "  Pi OS: $(echo "$state" | grep "LAST_PI_OS_VERSION=" | cut -d= -f2 | tr -d '"')"
        echo "  Method: $(echo "$state" | grep "LAST_BUILD_METHOD=" | cut -d= -f2 | tr -d '"')"
        echo "  Size: $(echo "$state" | grep "LAST_IMAGE_SIZE=" | cut -d= -f2 | tr -d '"') bytes"
        
        echo ""
        echo "Pi OS Status:"
        local last_pi_os=$(echo "$state" | grep "LAST_PI_OS_VERSION=" | cut -d= -f2 | tr -d '"')
        local latest_pi_os
        latest_pi_os=$(get_latest_pi_os_version)
        echo "  Last used: $last_pi_os" 
        echo "  Latest available: $latest_pi_os"
        
        if [[ "$last_pi_os" == "$latest_pi_os" ]]; then
            echo "  Status: UP TO DATE"
        else
            echo "  Status: UPDATE AVAILABLE"
        fi
    else
        echo "Last Successful Build: NO"
        local reason=$(echo "$state" | grep "REASON=" | cut -d= -f2 || echo "unknown")
        echo "  Reason: $reason"
    fi
    
    echo ""
    echo "Recommended Action:"
    local decision
    decision=$(make_build_decision)
    local build_decision=$(echo "$decision" | grep "DECISION=" | cut -d= -f2)
    local reason=$(echo "$decision" | grep "REASON=" | cut -d= -f2)
    
    if [[ "$build_decision" == "full_build" ]]; then
        echo "  FULL BUILD required"
        echo "  Reason: $reason"
        if echo "$decision" | grep -q "NEW_VERSION="; then
            local new_version=$(echo "$decision" | grep "NEW_VERSION=" | cut -d= -f2)
            echo "  Will update to Pi OS: $new_version"
        fi
    else
        echo "  FAST BUILD possible"
        echo "  Reason: $reason"
    fi
}

# Function to perform full build
perform_full_build() {
    local version="$1"
    local pi_os_version="$2"
    
    log_info "Performing full build..."
    log_info "Target version: $version"
    log_info "Pi OS version: $pi_os_version"
    log_warning "This will take 15+ minutes but creates fresh base"
    
    if [[ ! -f "build-soulbox-with-splash.sh" ]]; then
        log_error "Full build script not found: build-soulbox-with-splash.sh"
        return 1
    fi
    
    # Run the full build
    log_info "Executing full build script..."
    if ! ./build-soulbox-with-splash.sh; then
        log_error "Full build script failed"
        return 1
    fi
    
    # Find the created image
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
    
    if [[ -z "$newest_img" || ! -f "$newest_img" ]]; then
        log_error "Could not find created image after full build"
        return 1
    fi
    
    # Create versioned copies
    local version_num="${version#v}"
    local base_name="${BASE_IMAGE_PREFIX}-${version_num}-$(date +%Y%m%d).img"
    local output_image="soulbox-v${version_num}.img"
    
    log_info "Creating versioned images..."
    cp "$newest_img" "$base_name"
    cp "$newest_img" "$output_image"
    
    # Generate checksums
    shasum -a 256 "$output_image" > "${output_image}.sha256"
    shasum -a 256 "$base_name" > "${base_name}.sha256"
    
    # Validate the output
    if ! validate_image "$output_image"; then
        log_error "Output image validation failed"
        return 1
    fi
    
    # Save successful build state
    save_build_state "$output_image" "$version" "$pi_os_version" "full_build"
    
    log_success "Full build completed successfully"
    log_success "Created: $output_image"
    log_success "Base: $base_name"
    
    return 0
}

# Function to perform fast build
perform_fast_build() {
    local version="$1"
    local base_image="$2"
    
    log_info "Performing fast build..."
    log_info "Target version: $version"
    log_info "Base image: $base_image"
    
    if [[ ! -f "$base_image" ]]; then
        log_error "Base image not found: $base_image"
        return 1
    fi
    
    if ! validate_image "$base_image"; then
        log_error "Base image validation failed"
        return 1
    fi
    
    local version_num="${version#v}"
    local output_image="soulbox-v${version_num}.img"
    
    log_info "Creating $output_image from base..."
    cp "$base_image" "$output_image"
    
    # Generate checksum
    shasum -a 256 "$output_image" > "${output_image}.sha256"
    
    # Validate the output
    if ! validate_image "$output_image"; then
        log_error "Output image validation failed"
        return 1
    fi
    
    # Get Pi OS version from build state
    local state
    state=$(get_build_state)
    local pi_os_version=$(echo "$state" | grep "LAST_PI_OS_VERSION=" | cut -d= -f2 | tr -d '"')
    
    # Save successful build state
    save_build_state "$output_image" "$version" "$pi_os_version" "fast_build"
    
    log_success "Fast build completed successfully"
    log_success "Created: $output_image"
    
    return 0
}

# Main execution
main() {
    log_info "SoulBox Intelligent Build System"
    log_info "================================"
    
    # Handle special commands
    if [[ "$RESET_STATE" == "true" ]]; then
        rm -f "$BUILD_STATE_FILE"
        log_success "Build state reset - next build will be full"
        exit 0
    fi
    
    if [[ "$CHECK_STATE" == "true" ]]; then
        show_build_state
        exit 0
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
    
    log_info "Target version: $VERSION"
    
    # Make intelligent build decision
    echo ""
    log_info "Making intelligent build decision..."
    
    local decision
    decision=$(make_build_decision)
    local build_decision=$(echo "$decision" | grep "DECISION=" | cut -d= -f2)
    local reason=$(echo "$decision" | grep "REASON=" | cut -d= -f2)
    
    echo ""
    log_info "BUILD DECISION: $build_decision"
    log_info "REASON: $reason"
    
    if [[ "$build_decision" == "full_build" ]]; then
        local pi_os_version
        if echo "$decision" | grep -q "NEW_VERSION="; then
            pi_os_version=$(echo "$decision" | grep "NEW_VERSION=" | cut -d= -f2)
        else
            pi_os_version=$(get_latest_pi_os_version)
        fi
        
        echo ""
        if perform_full_build "$VERSION" "$pi_os_version"; then
            log_success "Full build completed successfully"
        else
            log_error "Full build failed"
            exit 1
        fi
    else
        local base_image=$(echo "$decision" | grep "BASE_IMAGE=" | cut -d= -f2)
        
        echo ""
        if perform_fast_build "$VERSION" "$base_image"; then
            log_success "Fast build completed successfully"
        else
            log_error "Fast build failed"
            exit 1
        fi
    fi
    
    echo ""
    log_success "SoulBox $VERSION is ready"
    echo ""
    echo "Build Summary:"
    echo "  Version: $VERSION"
    echo "  Method: $(echo "$build_decision" | tr '_' ' ' | sed 's/\b\w/\U&/g')"
    echo "  Output: soulbox-v${VERSION#v}.img"
    echo ""
    echo "Next build will be optimally chosen based on upstream status"
}

main "$@"
