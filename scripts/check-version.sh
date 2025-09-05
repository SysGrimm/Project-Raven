#!/bin/bash
set -e

# Raspberry Pi OS Version Checker
# Checks for new Pi OS releases and returns version information

# Configuration
BASE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images"
FALLBACK_URL="https://downloads.raspberrypi.org/raspios_lite_arm64_latest"

# Function to get latest version from directory listing
get_latest_from_downloads() {
    echo "Checking Pi OS downloads directory..." >&2
    
    # Get directory listing and extract version dates
    curl -s "$BASE_URL/" | \
    grep -oE 'raspios_lite_arm64-[0-9]{4}-[0-9]{2}-[0-9]{2}' | \
    sort -u | \
    tail -1
}

# Function to get version from GitHub releases (backup method)
get_latest_from_github() {
    echo "Checking GitHub releases..." >&2
    
    # Check pi-gen releases for version info
    curl -s "https://api.github.com/repos/RPi-Distro/pi-gen/releases/latest" | \
    jq -r '.tag_name' | \
    sed 's/^v//'
}

# Function to extract date from image name
extract_date_from_image() {
    echo "$1" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1
}

# Main version check
main() {
    local latest_image=""
    local version_date=""
    local download_url=""
    
    # Try to get latest from downloads page
    latest_image=$(get_latest_from_downloads)
    
    if [ -n "$latest_image" ]; then
        version_date=$(extract_date_from_image "$latest_image")
        download_url="$BASE_URL/$latest_image/$latest_image.img.xz"
        echo "Found latest image: $latest_image" >&2
    else
        echo "Could not parse downloads page, using fallback method" >&2
        
        # Fallback: use current date and latest URL
        version_date=$(date +%Y-%m-%d)
        download_url="$FALLBACK_URL"
        
        # Try to get more specific version from GitHub
        github_version=$(get_latest_from_github)
        if [ -n "$github_version" ] && [[ "$github_version" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            version_date="$github_version"
        fi
    fi
    
    # Validate we have required info
    if [ -z "$version_date" ] || [ -z "$download_url" ]; then
        echo "Error: Could not determine version information" >&2
        exit 1
    fi
    
    # Output JSON for easy parsing
    cat << EOF
{
    "version_date": "$version_date",
    "download_url": "$download_url",
    "latest_image": "$latest_image",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Handle command line arguments
case "${1:-}" in
    --version-only)
        main | jq -r '.version_date'
        ;;
    --url-only)
        main | jq -r '.download_url'
        ;;
    --json)
        main
        ;;
    --help|-h)
        cat << 'EOF'
Raspberry Pi OS Version Checker

Usage:
    check-version.sh [options]

Options:
    --version-only    Output only the version date
    --url-only        Output only the download URL
    --json            Output full JSON (default)
    --help, -h        Show this help

Examples:
    ./check-version.sh --version-only
    ./check-version.sh --url-only
    ./check-version.sh --json
EOF
        ;;
    *)
        main
        ;;
esac
