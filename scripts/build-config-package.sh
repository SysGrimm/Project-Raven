#!/bin/bash

# Simplified LibreELEC Image Customization Script for GitHub Actions
# This version creates a configuration package instead of modifying the image directly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configurations"
OUTPUT_DIR="$PROJECT_DIR/output"

# Configuration
TARGET_DEVICE="${TARGET_DEVICE:-RPi5}"
LIBREELEC_VERSION="${LIBREELEC_VERSION:-latest}"

echo "🚀 LibreELEC Configuration Package Builder"
echo "==========================================="
echo "Target Device: $TARGET_DEVICE"
echo "LibreELEC Version: $LIBREELEC_VERSION"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to get latest LibreELEC release info
get_latest_release() {
    local device="$1"
    
    echo "📡 Fetching latest LibreELEC release information..."
    
    # Get latest version from GitHub API
    local api_url="https://api.github.com/repos/LibreELEC/LibreELEC.tv/releases/latest"
    local release_info
    
    if ! release_info=$(curl -s "$api_url" 2>/dev/null); then
        echo "❌ Failed to fetch release information from GitHub API"
        exit 1
    fi
    
    # Extract tag name
    local tag_name
    tag_name=$(echo "$release_info" | grep '"tag_name":' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    
    if [ -z "$tag_name" ]; then
        echo "❌ Could not extract version tag from API response"
        echo "Debug: raw grep result:"
        echo "$release_info" | grep '"tag_name":' | head -1
        exit 1
    fi
    
    echo "✅ Latest LibreELEC version: $tag_name"
    
    # Construct download URL based on device
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
    
    echo "$download_url|$tag_name"
}

# Function to download LibreELEC image
download_libreelec() {
    local download_url="$1"
    local filename=$(basename "$download_url")
    local filepath="$OUTPUT_DIR/$filename"
    
    if [ -f "$filepath" ]; then
        echo "📁 LibreELEC image already exists: $filepath"
        echo "$filepath"
        return 0
    fi
    
    echo "⬇️  Downloading LibreELEC image..."
    echo "URL: $download_url"
    echo "Destination: $filepath"
    
    if curl -L -f -o "$filepath" "$download_url"; then
        echo "✅ Download completed: $filepath"
        echo "$filepath"
    else
        echo "❌ Download failed"
        exit 1
    fi
}

# Function to create configuration package
create_config_package() {
    local version="$1"
    local device="$2"
    
    echo "📦 Creating configuration package..."
    
    local package_name="LibreELEC-${device}-${version}-Raven-Config"
    local package_dir="$OUTPUT_DIR/$package_name"
    
    # Create package directory structure
    mkdir -p "$package_dir/boot"
    mkdir -p "$package_dir/storage"
    mkdir -p "$package_dir/instructions"
    
    # Copy boot configuration files
    if [ -f "$CONFIG_DIR/config.txt" ]; then
        cp "$CONFIG_DIR/config.txt" "$package_dir/boot/"
        echo "✅ Added config.txt"
    fi
    
    if [ -f "$CONFIG_DIR/cmdline.txt" ]; then
        cp "$CONFIG_DIR/cmdline.txt" "$package_dir/boot/"
        echo "✅ Added cmdline.txt"
    fi
    
    if [ -f "$CONFIG_DIR/first-boot.sh" ]; then
        cp "$CONFIG_DIR/first-boot.sh" "$package_dir/boot/"
        chmod +x "$package_dir/boot/first-boot.sh"
        echo "✅ Added first-boot.sh"
    fi
    
    # Copy storage files (Kodi settings, etc.)
    if [ -d "$CONFIG_DIR/storage" ]; then
        cp -r "$CONFIG_DIR/storage/"* "$package_dir/storage/" 2>/dev/null || true
        echo "✅ Added storage files"
    fi
    
    # Create installation instructions
    cat > "$package_dir/instructions/README.md" << 'EOF'
# LibreELEC Raven Configuration Package

## Automatic Installation (Recommended)

1. **Flash the LibreELEC image** to your SD card using Raspberry Pi Imager
2. **Before first boot**, copy the files from this package:
   - Copy `boot/*` files to the SD card's boot partition (visible on any computer)
   - The `storage/` files will be applied on first boot via the first-boot.sh script

## Manual Installation

### Boot Configuration
Copy these files to the SD card's boot partition:
- `boot/config.txt` - Boot configuration with 4K support and performance tuning
- `boot/cmdline.txt` - Kernel parameters
- `boot/first-boot.sh` - First-boot customization script

### Kodi Settings
After LibreELEC boots for the first time:
1. Enable SSH in LibreELEC settings
2. Copy `storage/.kodi/` to `/storage/.kodi/` on the device
3. Restart Kodi or reboot

## What's Included

### Boot Configuration (`config.txt`)
- GPU memory optimized for 4K video (256MB)
- 4K 60fps support enabled  
- Performance overclocking settings
- Audio and HDMI optimizations

### Kodi Settings (`guisettings.xml`)
- Optimized video playback settings
- Audio passthrough configuration
- Web server enabled for remote control
- Media-friendly display settings

### System Configuration
- SSH enabled by default
- First-boot customization script
- Custom directory structure
- Network optimizations

Enjoy your customized LibreELEC system!
EOF

    # Create a compressed package
    cd "$OUTPUT_DIR"
    tar -czf "${package_name}.tar.gz" "$package_name"
    
    echo "✅ Configuration package created: ${package_name}.tar.gz"
    echo "$OUTPUT_DIR/${package_name}.tar.gz"
}

# Main execution
main() {
    echo "🔍 Getting latest LibreELEC release..."
    
    # Get release info
    local release_info
    release_info=$(get_latest_release "$TARGET_DEVICE")
    
    # Parse download URL and version
    local download_url=$(echo "$release_info" | cut -d'|' -f1)
    local version=$(echo "$release_info" | cut -d'|' -f2)
    
    echo "⬇️  Downloading LibreELEC..."
    local source_image
    source_image=$(download_libreelec "$download_url")
    
    echo "📦 Creating configuration package..."
    local config_package
    config_package=$(create_config_package "$version" "$TARGET_DEVICE")
    
    # Generate checksums
    echo "🔐 Generating checksums..."
    cd "$OUTPUT_DIR"
    for file in *.img.gz *.tar.gz; do
        if [ -f "$file" ]; then
            sha256sum "$file" > "${file}.sha256"
            echo "✅ Checksum created: ${file}.sha256"
        fi
    done
    
    echo ""
    echo "🎉 Success!"
    echo "=========================="
    echo "LibreELEC Image: $(basename "$source_image")"
    echo "Config Package:  $(basename "$config_package")"
    echo "Location: $OUTPUT_DIR"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Download both files from the GitHub Actions artifacts"
    echo "2. Flash the .img.gz file to your SD card"
    echo "3. Extract the config package and follow the instructions"
    echo "4. Boot your customized LibreELEC system!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
