#!/bin/bash

# Script to format a CI-built disk image with proper filesystems
# This addresses the "Partition does not have a FAT file system" error in Raspberry Pi Imager

set -e

# Take input filename as argument
if [ -z "$1" ]; then
    echo "Usage: $0 <disk-image-file>"
    exit 1
fi

IMAGE_FILE="$1"
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: File $IMAGE_FILE not found"
    exit 1
fi

echo "=== Creating proper filesystems in disk image ==="
echo "Image file: $IMAGE_FILE"
echo "Current file details:"
ls -lh "$IMAGE_FILE"
file "$IMAGE_FILE"

# Get partition info
echo "Analyzing partition table..."
PART_INFO=$(parted -s "$IMAGE_FILE" unit B print)
echo "$PART_INFO"

# Extract boot partition start and size
BOOT_START=$(echo "$PART_INFO" | grep "^ 1" | awk '{print $2}' | tr -d 'B')
BOOT_END=$(echo "$PART_INFO" | grep "^ 1" | awk '{print $3}' | tr -d 'B')
BOOT_SIZE=$((BOOT_END - BOOT_START))

# Extract root partition start and size
ROOT_START=$(echo "$PART_INFO" | grep "^ 2" | awk '{print $2}' | tr -d 'B')
ROOT_END=$(echo "$PART_INFO" | grep "^ 2" | awk '{print $3}' | tr -d 'B')
ROOT_SIZE=$((ROOT_END - ROOT_START))

echo "Boot partition: start=$BOOT_START, size=$BOOT_SIZE bytes"
echo "Root partition: start=$ROOT_START, size=$ROOT_SIZE bytes"

# Create temporary files for each partition
TEMP_DIR=$(mktemp -d)
BOOT_IMG="$TEMP_DIR/boot.fat"
ROOT_IMG="$TEMP_DIR/root.ext4"

echo "Creating temporary files in $TEMP_DIR..."

# Extract boot partition
echo "Extracting boot partition..."
dd if="$IMAGE_FILE" of="$BOOT_IMG" bs=1 skip="$BOOT_START" count="$BOOT_SIZE" status=progress

# Extract root partition
echo "Extracting root partition..."
dd if="$IMAGE_FILE" of="$ROOT_IMG" bs=1 skip="$ROOT_START" count="$ROOT_SIZE" status=progress

# Format boot partition with FAT32
echo "Formatting boot partition with FAT32..."
mkfs.fat -F 32 -n "SOULBOX" "$BOOT_IMG"

# Format root partition with ext4
echo "Formatting root partition with ext4..."
mkfs.ext4 -F -L "soulbox-root" "$ROOT_IMG"

# Create basic content for boot partition
echo "Creating basic boot content..."
BOOT_MNT="$TEMP_DIR/boot_mnt"
mkdir -p "$BOOT_MNT"

if command -v fuse-ext2 >/dev/null 2>&1; then
    # Mount using FUSE if available
    mount -t vfat "$BOOT_IMG" "$BOOT_MNT"
    
    # Create minimal boot files
    echo "# SoulBox minimal boot configuration" > "$BOOT_MNT/config.txt"
    echo "arm_64bit=1" >> "$BOOT_MNT/config.txt"
    echo "dtparam=audio=on" >> "$BOOT_MNT/config.txt"
    echo "dtoverlay=vc4-kms-v3d" >> "$BOOT_MNT/config.txt"
    
    echo "console=serial0,115200 console=tty1 root=LABEL=soulbox-root rootfstype=ext4 rootwait" > "$BOOT_MNT/cmdline.txt"
    
    # Create an empty file to check validity
    dd if=/dev/zero of="$BOOT_MNT/kernel8.img" bs=1M count=1
    
    # Unmount
    umount "$BOOT_MNT"
else
    # Use mtools instead if FUSE is not available
    echo "# SoulBox minimal boot configuration" > "$TEMP_DIR/config.txt"
    echo "arm_64bit=1" >> "$TEMP_DIR/config.txt"
    echo "dtparam=audio=on" >> "$TEMP_DIR/config.txt"
    echo "dtoverlay=vc4-kms-v3d" >> "$TEMP_DIR/config.txt"
    
    echo "console=serial0,115200 console=tty1 root=LABEL=soulbox-root rootfstype=ext4 rootwait" > "$TEMP_DIR/cmdline.txt"
    
    # Create an empty file to check validity
    dd if=/dev/zero of="$TEMP_DIR/kernel8.img" bs=1M count=1
    
    # Copy files using mcopy
    mcopy -i "$BOOT_IMG" "$TEMP_DIR/config.txt" ::config.txt
    mcopy -i "$BOOT_IMG" "$TEMP_DIR/cmdline.txt" ::cmdline.txt
    mcopy -i "$BOOT_IMG" "$TEMP_DIR/kernel8.img" ::kernel8.img
fi

# Verify boot partition contents
echo "Verifying boot partition contents:"
mdir -i "$BOOT_IMG" ::

# Create backup of original image
BACKUP_FILE="${IMAGE_FILE}.backup"
echo "Creating backup of original image as $BACKUP_FILE"
cp "$IMAGE_FILE" "$BACKUP_FILE"

# Write back boot partition
echo "Writing back boot partition..."
dd if="$BOOT_IMG" of="$IMAGE_FILE" bs=1 seek="$BOOT_START" conv=notrunc status=progress

# Write back root partition
echo "Writing back root partition..."
dd if="$ROOT_IMG" of="$IMAGE_FILE" bs=1 seek="$ROOT_START" conv=notrunc status=progress

# Clean up
echo "Cleaning up temporary files..."
rm -f "$BOOT_IMG" "$ROOT_IMG"
rmdir "$BOOT_MNT" 2>/dev/null || true
rmdir "$TEMP_DIR"

echo "Done! The disk image now has properly formatted FAT32 and ext4 partitions."
echo "Original image backed up as $BACKUP_FILE"
