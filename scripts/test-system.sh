#!/bin/bash

# Test script for LibreELEC customization approach
# This script performs basic validation without requiring root privileges

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 Testing LibreELEC Customization System"
echo "==========================================="

# Test 1: Check required directories exist
echo "📁 Checking directory structure..."
required_dirs=(
    "$PROJECT_DIR/configurations"
    "$PROJECT_DIR/scripts"
    "$PROJECT_DIR/image-customization"
    "$PROJECT_DIR/output"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ $dir exists"
    else
        echo "❌ $dir missing"
        exit 1
    fi
done

# Test 2: Check required files exist
echo ""
echo "📄 Checking configuration files..."
required_files=(
    "$PROJECT_DIR/configurations/config.txt"
    "$PROJECT_DIR/configurations/cmdline.txt"
    "$PROJECT_DIR/configurations/first-boot.sh"
    "$PROJECT_DIR/configurations/storage/.kodi/userdata/guisettings.xml"
    "$PROJECT_DIR/scripts/customize-libreelec.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

# Test 3: Check script is executable
echo ""
echo "🔧 Checking script permissions..."
if [ -x "$PROJECT_DIR/scripts/customize-libreelec.sh" ]; then
    echo "✅ customize-libreelec.sh is executable"
else
    echo "❌ customize-libreelec.sh is not executable"
    exit 1
fi

# Test 4: Test GitHub API access (without API key)
echo ""
echo "🌐 Testing GitHub API access..."
if curl -s "https://api.github.com/repos/LibreELEC/LibreELEC.tv/releases/latest" | grep -q "tag_name"; then
    echo "✅ GitHub API accessible"
    
    # Get latest version info
    latest_version=$(curl -s "https://api.github.com/repos/LibreELEC/LibreELEC.tv/releases/latest" | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    echo "ℹ️  Latest LibreELEC version: $latest_version"
else
    echo "❌ GitHub API not accessible"
    exit 1
fi

# Test 5: Check for available downloads for different devices
echo ""
echo "📦 Checking available downloads..."
release_info=$(curl -s "https://api.github.com/repos/LibreELEC/LibreELEC.tv/releases/latest")

devices=("rpi4" "rpi5" "generic")
for device in "${devices[@]}"; do
    if echo "$release_info" | grep -q -i "$device.*\.img\.gz"; then
        echo "✅ $device image available"
    else
        echo "⚠️  $device image not found (might use different naming)"
    fi
done

# Test 6: Validate configuration files
echo ""
echo "🔍 Validating configuration files..."

# Check config.txt has basic boot parameters
if grep -q "gpu_mem" "$PROJECT_DIR/configurations/config.txt"; then
    echo "✅ config.txt contains GPU memory settings"
else
    echo "⚠️  config.txt missing GPU memory settings"
fi

# Check guisettings.xml is valid XML
if command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout "$PROJECT_DIR/configurations/storage/.kodi/userdata/guisettings.xml" 2>/dev/null; then
        echo "✅ guisettings.xml is valid XML"
    else
        echo "❌ guisettings.xml is invalid XML"
        exit 1
    fi
else
    echo "ℹ️  xmllint not available, skipping XML validation"
fi

# Test 7: Check for required system tools
echo ""
echo "🛠️  Checking system dependencies..."
required_tools=("curl" "gzip" "gunzip")
for tool in "${required_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool available"
    else
        echo "❌ $tool missing"
        exit 1
    fi
done

# Summary
echo ""
echo "🎉 All tests passed!"
echo "====================="
echo "The LibreELEC customization system is ready to use."
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/customize-libreelec.sh"
echo "2. Or use GitHub Actions workflow"
echo "3. Flash the generated image to your device"
echo ""
echo "For manual testing (requires sudo):"
echo "export TARGET_DEVICE=RPi5"
echo "./scripts/customize-libreelec.sh"
