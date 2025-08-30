#!/bin/bash

set -e

# Raspberry Pi OS Upstream Checker
# Checks for new Pi OS releases and compares with current version

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
PI_OS_IMAGES_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/"
CURRENT_VERSION="raspios_lite_arm64-2023-12-11"
CACHE_FILE=".pi-os-cache"
CACHE_DURATION=3600 # 1 hour

# Function to get latest Pi OS version from upstream
get_latest_pi_os_version() {
    log_info "Checking Raspberry Pi OS releases..."
    
    # Check cache first
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age=$(( $(date +%s) - $(stat -f "%m" "$CACHE_FILE" 2>/dev/null || stat -c "%Y" "$CACHE_FILE" 2>/dev/null || echo "0") ))
        if [[ $cache_age -lt $CACHE_DURATION ]]; then
            log_info "Using cached results (age: ${cache_age}s)"
            cat "$CACHE_FILE"
            return
        fi
    fi
    
    log_info "Fetching latest release information..."
    
    # Try to get the latest version directory listing
    local latest_version=""
    
    if command -v curl >/dev/null 2>&1; then
        # Use curl to get the directory listing
        local versions=$(curl -s "$PI_OS_IMAGES_URL" 2>/dev/null | grep -o 'raspios_lite_arm64-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | sort -V | tail -1 || echo "")
        
        if [[ -n "$versions" ]]; then
            latest_version="$versions"
            log_info "Found latest version: $latest_version"
        fi
    fi
    
    # Fallback: if we can't get upstream info, assume current is latest
    if [[ -z "$latest_version" ]]; then
        log_warning "Could not fetch upstream information, assuming current version is latest"
        latest_version="$CURRENT_VERSION"
    fi
    
    # Cache the result
    echo "$latest_version" > "$CACHE_FILE"
    echo "$latest_version"
}

# Function to compare versions
compare_versions() {
    local current="$1"
    local latest="$2"
    
    log_info "Comparing versions:"
    log_info "  Current: $current"
    log_info "  Latest:  $latest"
    
    if [[ "$current" == "$latest" ]]; then
        log_success "✅ Up to date"
        return 1 # No update needed
    else
        log_warning "🔄 Update available"
        return 0 # Update needed
    fi
}

# Function to show version details
show_version_details() {
    local version="$1"
    
    echo ""
    echo "📋 Version Details:"
    echo "   Version: $version"
    
    # Extract date from version string
    if [[ "$version" =~ raspios_lite_arm64-([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        local day="${BASH_REMATCH[3]}"
        echo "   Release Date: $year-$month-$day"
        
        # Calculate age
        local release_date=$(date -j -f "%Y-%m-%d" "$year-$month-$day" +%s 2>/dev/null || date -d "$year-$month-$day" +%s 2>/dev/null || echo "0")
        local current_date=$(date +%s)
        local age_days=$(( (current_date - release_date) / 86400 ))
        
        if [[ $age_days -gt 0 ]]; then
            echo "   Age: $age_days days"
        fi
    fi
}

# Main function
main() {
    local action="$1"
    
    case "$action" in
        "check")
            log_info "Checking for Raspberry Pi OS updates..."
            local latest_version
            latest_version=$(get_latest_pi_os_version)
            
            show_version_details "$CURRENT_VERSION"
            show_version_details "$latest_version"
            
            if compare_versions "$CURRENT_VERSION" "$latest_version"; then
                echo ""
                echo "🔄 Action Required: Update to $latest_version"
                echo "   Run: ./build-soulbox-smart.sh --update-base"
                exit 1
            else
                echo ""
                echo "✅ No update needed"
                exit 0
            fi
            ;;
        "latest")
            get_latest_pi_os_version
            ;;
        "current")
            echo "$CURRENT_VERSION"
            ;;
        "clear-cache")
            rm -f "$CACHE_FILE"
            log_success "Cache cleared"
            ;;
        *)
            echo "Usage: $0 {check|latest|current|clear-cache}"
            echo ""
            echo "Commands:"
            echo "  check       - Check for updates and show comparison"
            echo "  latest      - Get latest version from upstream"
            echo "  current     - Show current version"
            echo "  clear-cache - Clear cached results"
            exit 1
            ;;
    esac
}

main "$@"
