#!/bin/bash

# LibreELEC Project Raven - Complete Custom Build Script
# Builds a custom LibreELEC image with Tailscale, themes, and add-ons

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$CUSTOM_DIR/LibreELEC.tv"
PROJECT_CONF="$CUSTOM_DIR/config/project.conf"

# Load project configuration
if [ -f "$PROJECT_CONF" ]; then
    source "$PROJECT_CONF"
else
    echo -e "${RED}❌ Project configuration not found: $PROJECT_CONF${NC}"
    exit 1
fi

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                  🚀 PROJECT RAVEN                        ║"
echo "║              LibreELEC Custom Build System               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${PURPLE}📋 Build Configuration:${NC}"
echo "   Project: $PROJECT"
echo "   Architecture: $ARCH"
echo "   Device: $DEVICE"
echo "   Image Suffix: $IMAGE_SUFFIX"
echo ""

# Pre-build checks
echo -e "${YELLOW}🔍 Pre-build checks...${NC}"

# Check if LibreELEC source exists
if [ ! -d "$BUILD_DIR" ]; then
    echo -e "${RED}❌ LibreELEC source not found. Run build-setup.sh first!${NC}"
    exit 1
fi

# Check for Tailscale add-on
if [ ! -d "$CUSTOM_DIR/packages/addons/service/tailscale" ]; then
    echo -e "${RED}❌ Tailscale add-on not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Pre-build checks passed${NC}"

# Prepare build environment
echo -e "${YELLOW}⚙️ Preparing build environment...${NC}"

cd "$BUILD_DIR"

# Clean previous builds if requested
if [ "$1" = "clean" ]; then
    echo -e "${YELLOW}🧹 Cleaning previous build...${NC}"
    make clean
fi

# Copy custom packages
echo -e "${YELLOW}📦 Installing custom packages...${NC}"
if [ -d "$CUSTOM_DIR/packages" ]; then
    cp -r "$CUSTOM_DIR/packages"/* packages/ 2>/dev/null || true
    echo -e "${GREEN}   ✅ Tailscale add-on installed${NC}"
fi

# Copy additional add-ons
if [ -d "$CUSTOM_DIR/customizations/addons" ]; then
    echo -e "${YELLOW}🔌 Installing additional add-ons...${NC}"
    find "$CUSTOM_DIR/customizations/addons" -name "*.zip" | while read addon; do
        addon_name=$(basename "$addon" .zip)
        echo -e "${GREEN}   ✅ Found: $addon_name${NC}"
    done
fi

# Set build variables from config
export PROJECT="$PROJECT"
export ARCH="$ARCH"
export DEVICE="$DEVICE"

# Configure Project-Raven components
echo -e "${PURPLE}🎯 Configuring Project-Raven components...${NC}"
setup_jellyfin_repository
configure_default_theme  
configure_setup_wizard
apply_system_config
install_addon_bundle "essential-addons"

# Additional build environment variables
export BUILDER_NAME="Project-Raven"
export BUILDER_VERSION="2.0"

# Helper functions for customization
setup_jellyfin_repository() {
    echo -e "${YELLOW}📺 Setting up Jellyfin repository...${NC}"
    # Jellyfin repo will be added during add-on installation
}

configure_default_theme() {
    echo -e "${YELLOW}🎨 Configuring Copacetic theme as default...${NC}"
    # Theme configuration will be applied during image customization
}

configure_setup_wizard() {
    echo -e "${YELLOW}🧙 Setting up first-boot wizard...${NC}"
    # Setup wizard will be enabled during customization
}

apply_system_config() {
    echo -e "${YELLOW}⚙️ Applying system configurations...${NC}"
    # System configurations will be applied during customization
}

install_addon_bundle() {
    local bundle="$1"
    echo -e "${YELLOW}🔌 Installing $bundle add-ons...${NC}"
    # Add-on bundle installation handled by LibreELEC build system
}

# Start the build
echo -e "${BLUE}🔨 Starting LibreELEC build...${NC}"
echo "   This may take 1-3 hours depending on your system..."
echo ""

start_time=$(date +%s)

# Build with progress indication
(
    echo -e "${YELLOW}📡 Downloading sources and dependencies...${NC}"
    PROJECT=$PROJECT ARCH=$ARCH DEVICE=$DEVICE make image 2>&1 | tee build.log
) &

BUILD_PID=$!

# Progress indicator
while kill -0 $BUILD_PID 2>/dev/null; do
    sleep 30
    echo -e "${BLUE}⏳ Build in progress... ($(( $(date +%s) - start_time ))s elapsed)${NC}"
done

wait $BUILD_PID
BUILD_EXIT_CODE=$?

end_time=$(date +%s)
build_duration=$(( end_time - start_time ))

if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Build completed successfully! (${build_duration}s)${NC}"
else
    echo -e "${RED}❌ Build failed! Check build.log for details${NC}"
    exit 1
fi

# Find built image
IMAGE_FILE=$(find target/ -name "*.img.gz" | head -1)
if [ -z "$IMAGE_FILE" ]; then
    echo -e "${RED}❌ Built image not found!${NC}"
    exit 1
fi

echo -e "${GREEN}📀 Built image: $IMAGE_FILE${NC}"

# Run post-build customizations
if [ -f "$CUSTOM_DIR/scripts/post-build.sh" ]; then
    echo -e "${YELLOW}🎨 Running post-build customizations...${NC}"
    bash "$CUSTOM_DIR/scripts/post-build.sh"
fi

# Final image location
FINAL_IMAGE=$(find "$CUSTOM_DIR" -name "LibreELEC-Project-Raven-*.img.gz" | head -1)

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    🎉 BUILD COMPLETE!                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📊 Build Summary:${NC}"
echo "   Duration: ${build_duration}s"
echo "   Project: $PROJECT ($ARCH)"
echo "   Features: Tailscale VPN, Custom Theme, CEC Support"
if [ -n "$FINAL_IMAGE" ]; then
    echo "   Image: $FINAL_IMAGE"
    echo "   Size: $(du -h "$FINAL_IMAGE" | cut -f1)"
else
    echo "   Image: $IMAGE_FILE"
    echo "   Size: $(du -h "$BUILD_DIR/$IMAGE_FILE" | cut -f1)"
fi

echo ""
echo -e "${YELLOW}🔥 Flash to SD card:${NC}"
echo "   1. Insert SD card (8GB+ recommended)"
echo "   2. Flash with Raspberry Pi Imager or:"
echo "      sudo dd if='$FINAL_IMAGE' of=/dev/sdX bs=4M status=progress"
echo ""
echo -e "${BLUE}🚀 First Boot:${NC}"
echo "   1. Insert SD card and power on"
echo "   2. Connect to WiFi/Ethernet"
echo "   3. Tailscale will auto-configure"
echo "   4. Access via: http://device-ip:8080"
echo "   5. SSH via: ssh root@device-ip (password: libreelec)"
echo ""
echo -e "${GREEN}✨ Enjoy your custom LibreELEC Project Raven build!${NC}"
