#!/bin/bash

# Dry-run test of the LibreELEC customization system
# This validates the approach without requiring sudo or downloading large files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configurations"
OUTPUT_DIR="$PROJECT_DIR/output"

# Configuration
TARGET_DEVICE="${TARGET_DEVICE:-RPi5}"

echo "🧪 LibreELEC Customization Dry Run"
echo "==================================="
echo "Target Device: $TARGET_DEVICE"
echo "Mode: Test/Validation only"
echo ""

# Function to get latest LibreELEC release info
test_latest_release() {
    local device="$1"
    
    echo "📡 Testing LibreELEC release API..."
    
    # Get latest version from GitHub API
    local api_url="https://api.github.com/repos/LibreELEC/LibreELEC.tv/releases/latest"
    local release_info=$(curl -s "$api_url")
    local tag_name=$(echo "$release_info" | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    
    echo "✅ Latest LibreELEC version: $tag_name"
    
    # Construct expected download URL
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
    esac
    
    echo "🔗 Expected download URL: $download_url"
    
    # Test if URL is accessible (just HEAD request)
    echo "🔍 Testing download URL accessibility..."
    if curl --output /dev/null --silent --head --fail "$download_url"; then
        echo "✅ Download URL is accessible"
    else
        echo "⚠️  Download URL not accessible (may need manual verification)"
        echo "ℹ️  This could be due to URL format changes or network issues"
    fi
    
    return 0
}

# Test configuration validation
test_configurations() {
    echo ""
    echo "🔧 Testing configuration files..."
    
    # Check required files
    local required_files=(
        "$CONFIG_DIR/config.txt"
        "$CONFIG_DIR/cmdline.txt"
        "$CONFIG_DIR/first-boot.sh"
        "$CONFIG_DIR/storage/.kodi/userdata/guisettings.xml"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ Found: $(basename "$file")"
            
            # Basic content validation
            case "$(basename "$file")" in
                "config.txt")
                    if grep -q "gpu_mem" "$file"; then
                        echo "   📝 Contains GPU memory settings"
                    fi
                    ;;
                "guisettings.xml")
                    if command -v xmllint >/dev/null 2>&1; then
                        if xmllint --noout "$file" 2>/dev/null; then
                            echo "   📝 Valid XML structure"
                        else
                            echo "   ❌ Invalid XML structure"
                            return 1
                        fi
                    fi
                    ;;
                "first-boot.sh")
                    if [ -x "$file" ]; then
                        echo "   📝 Script is executable"
                    else
                        echo "   ⚠️  Script is not executable"
                    fi
                    ;;
            esac
        else
            echo "❌ Missing: $file"
            return 1
        fi
    done
    
    return 0
}

# Test system dependencies
test_dependencies() {
    echo ""
    echo "🛠️  Testing system dependencies..."
    
    local required_tools=("curl" "gzip" "gunzip")
    local optional_tools=("losetup" "mount" "umount")
    
    echo "Required tools:"
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "✅ $tool available"
        else
            echo "❌ $tool missing"
            return 1
        fi
    done
    
    echo "Optional tools (for actual image modification):"
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "✅ $tool available"
        else
            echo "⚠️  $tool missing (required for actual image modification)"
        fi
    done
    
    return 0
}

# Test workflow simulation
simulate_workflow() {
    echo ""
    echo "🎬 Simulating customization workflow..."
    
    echo "1. ⬇️  Download phase:"
    echo "   - Would download LibreELEC image from releases.libreelec.tv"
    echo "   - File size typically 100-300MB compressed"
    echo "   - Would save to: $OUTPUT_DIR/"
    
    echo "2. 📂 Extract phase:"
    echo "   - Would decompress .img.gz file"
    echo "   - Would use losetup to create loop device"
    echo "   - Would mount boot and system partitions"
    
    echo "3. 🎨 Customize phase:"
    echo "   - Would copy config.txt to boot partition"
    echo "   - Would copy cmdline.txt to boot partition"
    echo "   - Would copy first-boot.sh to boot partition"
    echo "   - Would copy Kodi settings to storage area"
    
    echo "4. 📦 Repackage phase:"
    echo "   - Would unmount all partitions"
    echo "   - Would compress modified image"
    echo "   - Would generate checksums"
    
    echo "5. ✅ Complete:"
    echo "   - Custom image ready for flashing"
    echo "   - Typical output: LibreELEC-$TARGET_DEVICE-*-custom.img.gz"
    
    return 0
}

# Main execution
main() {
    test_latest_release "$TARGET_DEVICE"
    test_configurations
    test_dependencies
    simulate_workflow
    
    echo ""
    echo "🎉 Dry run completed successfully!"
    echo "=================================="
    echo ""
    echo "The system is ready for actual image customization."
    echo ""
    echo "To run the full process (requires sudo):"
    echo "  export TARGET_DEVICE=$TARGET_DEVICE"
    echo "  ./scripts/customize-libreelec.sh"
    echo ""
    echo "Or use the GitHub Actions workflow for cloud building."
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
