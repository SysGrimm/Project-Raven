#!/bin/bash

# LibreELEC Custom Build Setup Script
# Project Raven - Custom LibreELEC Image Builder

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LIBREELEC_VERSION="12.0"
BUILD_DIR="$(pwd)/LibreELEC.tv"
CUSTOM_DIR="$(pwd)"
PROJECT="RPi"  # Change to Generic, RPi, etc. as needed
ARCH="arm"     # Change to aarch64, x86_64 as needed

echo -e "${BLUE}🚀 LibreELEC Custom Build Setup - Project Raven${NC}"
echo "=================================================="

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check for required tools
for cmd in git wget tar make gcc; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ Required tool missing: $cmd${NC}"
        echo "Please install build essentials first:"
        echo "  macOS: xcode-select --install"
        echo "  Ubuntu: apt-get install build-essential git wget"
        exit 1
    fi
done

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Clone LibreELEC source if not exists
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}📥 Cloning LibreELEC source...${NC}"
    git clone https://github.com/LibreELEC/LibreELEC.tv.git
    cd "$BUILD_DIR"
    git checkout $LIBREELEC_VERSION
    cd "$CUSTOM_DIR"
else
    echo -e "${GREEN}✅ LibreELEC source already exists${NC}"
fi

# Create custom packages directory structure
echo -e "${YELLOW}📁 Setting up custom package structure...${NC}"
mkdir -p packages/addons/service/tailscale
mkdir -p config
mkdir -p customizations/{themes,addons,settings}
mkdir -p scripts

# Copy our Tailscale add-on
echo -e "${YELLOW}📦 Installing Tailscale add-on...${NC}"
cp -r ../libreelec-tailscale-addon/* packages/addons/service/tailscale/

# Create build configuration
cat > config/options.conf << 'EOF'
# LibreELEC Build Options - Project Raven Custom Build

# Project and architecture
PROJECT="RPi"
ARCH="arm"

# Include custom add-ons in image
ADDITIONAL_PACKAGES="tailscale"

# Enable debugging (optional)
DEBUG="no"

# Optimization
OPTIMIZATIONS="size"

# Custom image name
IMAGE_SUFFIX="-project-raven"
EOF

echo -e "${YELLOW}⚙️ Creating build scripts...${NC}"

# Create main build script
cat > scripts/build-image.sh << 'EOF'
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$CUSTOM_DIR/LibreELEC.tv"

cd "$BUILD_DIR"

# Load custom configuration
source "$CUSTOM_DIR/config/options.conf"

echo "🔨 Starting LibreELEC custom build..."
echo "Project: $PROJECT"
echo "Architecture: $ARCH" 
echo "Additional packages: $ADDITIONAL_PACKAGES"

# Copy custom packages to LibreELEC build
cp -r "$CUSTOM_DIR/packages"/* packages/ 2>/dev/null || true

# Start the build
PROJECT=$PROJECT ARCH=$ARCH make image

echo "✅ Build complete! Image location:"
find target/ -name "*.img.gz" -exec echo "📀 {}" \;
EOF

chmod +x scripts/build-image.sh

echo -e "${GREEN}✅ Build environment setup complete!${NC}"
echo ""
echo -e "${BLUE}🎯 Next Steps:${NC}"
echo "1. Customize your build:"
echo "   • Edit config/options.conf for build settings"
echo "   • Add themes to customizations/themes/"
echo "   • Add more add-ons to customizations/addons/"
echo ""
echo "2. Build your custom image:"
echo "   cd scripts && ./build-image.sh"
echo ""
echo "3. Flash the resulting .img file to SD card"
echo ""
echo -e "${YELLOW}💡 Want to add more customizations first? Continue with the customization steps...${NC}"
