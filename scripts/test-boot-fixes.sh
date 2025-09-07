#!/bin/bash

# Project Raven - Boot Fix Test Script
# Run this to test a new build before flashing to SD card

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[PASS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[FAIL]${NC} $1"; }

echo -e "${BLUE}🚀 Project Raven Boot Fix Validator${NC}"
echo "Testing LibreELEC image for Pi 5 boot compatibility..."
echo

# Check if image file exists
IMAGE_FILE="$1"
if [ -z "$IMAGE_FILE" ]; then
    error "Usage: $0 <libreelec-image.img.gz>"
    echo "Example: $0 LibreELEC-RPi5.arm-12.0-devel-*.img.gz"
    exit 1
fi

if [ ! -f "$IMAGE_FILE" ]; then
    error "Image file not found: $IMAGE_FILE"
    exit 1
fi

log "Found image file: $(basename "$IMAGE_FILE")"
log "Image size: $(du -h "$IMAGE_FILE" | cut -f1)"

# Create temporary working directory
WORK_DIR="/tmp/raven-boot-test-$$"
mkdir -p "$WORK_DIR"
trap "rm -rf '$WORK_DIR'" EXIT

cd "$WORK_DIR"

# Extract and mount image
log "Extracting image..."
if [[ "$IMAGE_FILE" == *.gz ]]; then
    gunzip -c "$IMAGE_FILE" > image.img
else
    cp "$IMAGE_FILE" image.img
fi

# Create loop device and mount
log "Mounting image partitions..."
LOOP_DEV=$(sudo losetup --find --show image.img)
sleep 2
sudo partprobe "$LOOP_DEV"

# Mount boot partition
mkdir -p boot
sudo mount "${LOOP_DEV}p1" boot 2>/dev/null || {
    error "Failed to mount boot partition"
    sudo losetup -d "$LOOP_DEV"
    exit 1
}

echo
echo -e "${YELLOW}=== BOOT CONFIGURATION VALIDATION ===${NC}"

# Test 1: Check config.txt modifications
log "Checking config.txt for Raven optimizations..."
if sudo grep -q "Project Raven" boot/config.txt 2>/dev/null; then
    success "Raven boot optimizations found in config.txt"
    
    # Check specific optimizations
    if sudo grep -q "gpu_mem=" boot/config.txt; then
        success "GPU memory configuration found"
    else
        warning "GPU memory not configured"
    fi
    
    if sudo grep -q "dtoverlay=vc4-kms-v3d-pi5" boot/config.txt; then
        success "Pi 5 video driver configured"
    else
        warning "Pi 5 video driver not found"
    fi
    
    if sudo grep -q "hdmi_cec_enable=1" boot/config.txt; then
        success "CEC configuration found"
    else
        warning "CEC not configured"
    fi
    
    if sudo grep -q "temp_limit=" boot/config.txt; then
        success "Thermal management configured"
    else
        warning "Thermal management not found"
    fi
else
    error "Raven boot optimizations not found in config.txt"
fi

# Test 2: Check cmdline.txt
log "Checking cmdline.txt for kernel parameters..."
if sudo grep -q "vc4.enable_cec_follower=1" boot/cmdline.txt 2>/dev/null; then
    success "CEC follower mode enabled"
else
    warning "CEC follower mode not enabled"
fi

if sudo grep -q "loglevel=7" boot/cmdline.txt 2>/dev/null; then
    success "Proper log level set"
else
    warning "Log level not optimized"
fi

if sudo grep -q "coherent_pool=" boot/cmdline.txt 2>/dev/null; then
    success "Memory coherent pool configured"
else
    warning "Memory coherent pool not configured"
fi

# Test 3: Check for kernel files
log "Checking kernel files..."
if sudo ls boot/kernel*.img >/dev/null 2>&1; then
    KERNEL_FILE=$(sudo ls boot/kernel*.img | head -1)
    success "Kernel found: $(basename "$KERNEL_FILE")"
    KERNEL_SIZE=$(sudo du -h "$KERNEL_FILE" | cut -f1)
    log "Kernel size: $KERNEL_SIZE"
else
    error "No kernel files found"
fi

# Test 4: Check device tree files
log "Checking device tree files..."
if sudo ls boot/*.dtb >/dev/null 2>&1; then
    DTB_COUNT=$(sudo ls boot/*.dtb | wc -l)
    success "Device tree files found: $DTB_COUNT files"
else
    error "No device tree files found"
fi

# Mount system partition if it exists
if [ -b "${LOOP_DEV}p2" ]; then
    mkdir -p system
    if sudo mount "${LOOP_DEV}p2" system 2>/dev/null; then
        log "System partition mounted successfully"
        
        # Test 5: Check for Raven services
        log "Checking for Raven services..."
        if sudo find system -name "raven-*.service" | grep -q .; then
            SERVICES=$(sudo find system -name "raven-*.service" | wc -l)
            success "Raven services found: $SERVICES services"
        else
            warning "Raven services not found"
        fi
        
        # Test 6: Check for Raven scripts
        log "Checking for Raven scripts..."
        if sudo find system -name "raven-*.sh" | grep -q .; then
            SCRIPTS=$(sudo find system -name "raven-*.sh" | wc -l)
            success "Raven scripts found: $SCRIPTS scripts"
        else
            warning "Raven scripts not found"
        fi
        
        sudo umount system
    else
        warning "Could not mount system partition"
    fi
fi

# Cleanup
sudo umount boot
sudo losetup -d "$LOOP_DEV"

echo
echo -e "${YELLOW}=== COMPATIBILITY ASSESSMENT ===${NC}"

# Generate compatibility score
SCORE=0
TOTAL=8

# Score based on tests
if sudo grep -q "Project Raven" "$WORK_DIR/boot/config.txt" 2>/dev/null; then ((SCORE++)); fi
if sudo grep -q "gpu_mem=" "$WORK_DIR/boot/config.txt" 2>/dev/null; then ((SCORE++)); fi
if sudo grep -q "dtoverlay=vc4-kms-v3d-pi5" "$WORK_DIR/boot/config.txt" 2>/dev/null; then ((SCORE++)); fi
if sudo grep -q "hdmi_cec_enable=1" "$WORK_DIR/boot/config.txt" 2>/dev/null; then ((SCORE++)); fi
if sudo grep -q "temp_limit=" "$WORK_DIR/boot/config.txt" 2>/dev/null; then ((SCORE++)); fi
if sudo grep -q "vc4.enable_cec_follower=1" "$WORK_DIR/boot/cmdline.txt" 2>/dev/null; then ((SCORE++)); fi
if sudo grep -q "loglevel=7" "$WORK_DIR/boot/cmdline.txt" 2>/dev/null; then ((SCORE++)); fi
if sudo grep -q "coherent_pool=" "$WORK_DIR/boot/cmdline.txt" 2>/dev/null; then ((SCORE++)); fi

PERCENTAGE=$((SCORE * 100 / TOTAL))

if [ $PERCENTAGE -ge 80 ]; then
    success "Boot compatibility score: $PERCENTAGE% ($SCORE/$TOTAL) - EXCELLENT"
    echo -e "${GREEN}✅ This image should boot successfully on Pi 5${NC}"
elif [ $PERCENTAGE -ge 60 ]; then
    warning "Boot compatibility score: $PERCENTAGE% ($SCORE/$TOTAL) - GOOD"
    echo -e "${YELLOW}⚠️  This image may boot but could have issues${NC}"
else
    error "Boot compatibility score: $PERCENTAGE% ($SCORE/$TOTAL) - POOR"
    echo -e "${RED}❌ This image is likely to have boot problems${NC}"
fi

echo
echo -e "${BLUE}📋 Recommendations:${NC}"
if [ $PERCENTAGE -ge 80 ]; then
    echo "• Flash to SD card with confidence"
    echo "• First boot may take 60-90 seconds"
    echo "• Use official Pi 5 power adapter (5V/5A)"
    echo "• Ensure adequate cooling for stability"
else
    echo "• Review build configuration"
    echo "• Check Universal Package Download System v5.0"
    echo "• Verify Boot Optimization v1.0 was applied"
    echo "• Consider rebuilding with latest fixes"
fi

echo
echo -e "${BLUE}🚀 Ready to test!${NC}"
echo "Flash this image to an SD card and test on your Pi 5"

exit 0
