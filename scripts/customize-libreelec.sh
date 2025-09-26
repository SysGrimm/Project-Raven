#!/bin/bash

# LibreELEC Image Customization Script
# Downloads latest LibreELEC release and applies custom configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configurations"
OUTPUT_DIR="$PROJECT_DIR/output"

# Configuration
TARGET_DEVICE="${TARGET_DEVICE:-RPi5}"  # RPi4, RPi5, Generic
LIBREELEC_VERSION="${LIBREELEC_VERSION:-latest}"

echo "🚀 LibreELEC Image Customization"
echo "================================="
echo "Target Device: $TARGET_DEVICE"
echo "LibreELEC Version: $LIBREELEC_VERSION"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to get latest LibreELEC release info
get_latest_release() {
    local device="$1"
    
    echo "📡 Fetching latest LibreELEC release information..."
    
    # Get latest version from GitHub API with error handling
    local api_url="https://api.github.com/repos/LibreELEC/LibreELEC.tv/releases/latest"
    local release_info
    
    if ! release_info=$(curl -s "$api_url" 2>/dev/null); then
        echo "❌ Failed to fetch release information from GitHub API"
        exit 1
    fi
    
    # Extract tag name with better error handling
    local tag_name
    if ! tag_name=$(echo "$release_info" | grep '"tag_name":' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null); then
        echo "❌ Failed to parse version information"
        echo "Raw API response: $release_info"
        exit 1
    fi
    
    if [ -z "$tag_name" ]; then
        echo "❌ Could not extract version tag from API response"
        echo "Raw API response: $release_info"
        exit 1
    fi
    
    echo "Latest LibreELEC version: $tag_name"
    
    # LibreELEC uses their own download system with correct architecture naming
    local base_url="https://releases.libreelec.tv"
    local download_url=""
    
    case "$device" in
        "RPi4")
            download_url="${base_url}/LibreELEC-RPi4.aarch64-${tag_name}.img.gz"
            ;;
        "RPi5")
            download_url="${base_url}/LibreELEC-RPi5.aarch64-${tag_name}.img.gz"
            ;;
        "Generic")
            download_url="${base_url}/LibreELEC-Generic.x86_64-${tag_name}.img.gz"
            ;;
        *)
            echo "❌ Unsupported device: $device"
            exit 1
            ;;
    esac
    
    echo "🔗 Constructed download URL: $download_url"
    
    # Verify URL exists (with timeout and better error handling)
    echo "🔍 Verifying download URL accessibility..."
    if curl --connect-timeout 10 --max-time 30 --output /dev/null --silent --head --fail "$download_url" 2>/dev/null; then
        echo "✅ Download URL verified"
    else
        echo "⚠️  Download URL verification failed, but continuing..."
        echo "ℹ️  URL: $download_url"
        echo "ℹ️  This might work during actual download (some servers block HEAD requests)"
    fi
    
    echo "$download_url"
}

# Function to download LibreELEC image
download_libreelec() {
    local download_url="$1"
    local filename=$(basename "$download_url")
    local filepath="$OUTPUT_DIR/$filename"
    
    if [ -f "$filepath" ]; then
        echo "📁 LibreELEC image already exists: $filepath"
        echo "$filepath"
        return
    fi
    
    echo "⬇️  Downloading LibreELEC image..."
    echo "URL: $download_url"
    echo "Destination: $filepath"
    
    curl -L -o "$filepath" "$download_url"
    
    if [ $? -eq 0 ] && [ -f "$filepath" ]; then
        echo "✅ Download completed: $filepath"
        echo "$filepath"
    else
        echo "❌ Download failed"
        exit 1
    fi
}

# Function to customize the image
customize_image() {
    local source_image="$1"
    local custom_image="${source_image%.img.gz}-custom.img.gz"
    
    echo "🎨 Customizing LibreELEC image..."
    echo "Source: $source_image"
    echo "Custom: $custom_image"
    
    # Create working directory
    local work_dir="/tmp/libreelec-custom-$$"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Extract the image
    echo "📂 Extracting image..."
    gunzip -c "$source_image" > original.img
    
    # Create a copy for customization
    cp original.img custom.img
    
    # Mount the image partitions
    echo "🔧 Mounting image partitions..."
    
    # Get loop device
    local loop_device=$(sudo losetup -f)
    sudo losetup -P "$loop_device" custom.img
    
    # Create mount points
    mkdir -p boot system storage
    
    # Mount partitions
    sudo mount "${loop_device}p1" boot     # Boot partition (FAT32)
    sudo mount "${loop_device}p2" system   # System partition (ext4) - read-only
    
    # Apply customizations
    echo "⚙️  Applying customizations..."
    
    # Boot configuration
    if [ -f "$CONFIG_DIR/config.txt" ]; then
        echo "📝 Applying boot config.txt..."
        sudo cp "$CONFIG_DIR/config.txt" boot/
    fi
    
    if [ -f "$CONFIG_DIR/cmdline.txt" ]; then
        echo "📝 Applying boot cmdline.txt..."
        sudo cp "$CONFIG_DIR/cmdline.txt" boot/
    fi
    
    # Add custom files to storage partition (this is where user data goes)
    if [ -d "$CONFIG_DIR/storage" ]; then
        echo "📁 Adding custom storage files..."
        # Note: Storage partition might not be mounted, we'll add files to be copied on first boot
        if sudo mountpoint -q storage 2>/dev/null; then
            sudo cp -r "$CONFIG_DIR/storage/"* storage/ 2>/dev/null || true
        else
            echo "ℹ️  Storage partition not available - files will be added via first-boot script"
        fi
    fi
    
    # Add first-boot customization script
    echo "🚀 Adding first-boot customization script..."
    if [ -f "$CONFIG_DIR/first-boot.sh" ]; then
        sudo cp "$CONFIG_DIR/first-boot.sh" boot/
    fi
    
    # Unmount and cleanup
    echo "🧹 Cleaning up..."
    sudo umount boot system 2>/dev/null || true
    sudo losetup -d "$loop_device"
    
    # Compress the customized image
    echo "🗜️  Compressing customized image..."
    gzip -c custom.img > "$custom_image"
    
    # Cleanup
    cd "$OUTPUT_DIR"
    rm -rf "$work_dir"
    
    echo "✅ Customization complete: $custom_image"
    echo "$custom_image"
}

# Main execution
main() {
    echo "🔍 Getting latest LibreELEC release..."
    
    # Debug: Show environment
    echo "Debug: TARGET_DEVICE=${TARGET_DEVICE}"
    echo "Debug: LIBREELEC_VERSION=${LIBREELEC_VERSION}"
    echo "Debug: CONFIG_DIR=${CONFIG_DIR}"
    echo "Debug: OUTPUT_DIR=${OUTPUT_DIR}"
    
    # Ensure output directory exists
    mkdir -p "$OUTPUT_DIR"
    
    if ! download_url=$(get_latest_release "$TARGET_DEVICE"); then
        echo "❌ Failed to get latest release information"
        exit 1
    fi
    
    echo "⬇️  Downloading LibreELEC..."
    if ! source_image=$(download_libreelec "$download_url"); then
        echo "❌ Failed to download LibreELEC image"
        exit 1
    fi
    
    echo "🎨 Customizing image..."
    if ! custom_image=$(customize_image "$source_image"); then
        echo "❌ Failed to customize image"
        exit 1
    fi
    
    echo ""
    echo "🎉 Success!"
    echo "=========================="
    echo "Original image: $source_image"
    echo "Custom image:   $custom_image"
    echo ""
    echo "Flash the custom image to your SD card and enjoy!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
