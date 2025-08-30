#!/bin/bash
# SoulBox Image Builder
# Creates a custom Raspberry Pi OS image with SoulBox configuration
#
# Usage: ./build-image.sh [output-directory]
#
# Requirements:
# - debootstrap
# - qemu-user-static
# - parted
# - kpartx

set -euo pipefail

# Configuration
PROJECT_DIR=$(dirname $(dirname $(realpath $0)))
BUILD_DIR="${1:-${PROJECT_DIR}/build}"
IMAGE_NAME="soulbox-$(date +%Y%m%d).img"
IMAGE_SIZE="4G"
DEBIAN_SUITE="bookworm"
DEBIAN_MIRROR="http://deb.debian.org/debian"
ARCH="arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    
    local deps=("debootstrap" "parted" "kpartx" "losetup")
# Clean up any existing loop devices for this image
cleanup_existing_loops() {
    local image_file="${BUILD_DIR}/${IMAGE_NAME}"
    if [ -f "$image_file" ]; then
        local existing_loops=$(losetup -j "$image_file" | cut -d: -f1)
        if [ -n "$existing_loops" ]; then
            log_info "Cleaning up existing loop devices for $image_file"
            echo "$existing_loops" | while read loop_dev; do
                # Remove any partition mappings first
                kpartx -dv "$loop_dev" 2>/dev/null || true
                # Detach the loop device
                losetup -d "$loop_dev" 2>/dev/null || true
            done
        fi
    fi
}

    for dep in "${deps[@]}"; do
        if ! command -v ${dep} >/dev/null 2>&1; then
            log_error "Missing dependency: ${dep}"
            log_error "Install with: sudo apt-get install ${dep}"
            exit 1
        fi
    done

    # Check for qemu-user-static binaries
    if [[ ! -f "/usr/bin/qemu-arm-static" ]] || [[ ! -f "/usr/bin/qemu-aarch64-static" ]]; then
        log_error "Missing qemu-user-static binaries"
        log_error "Install with: sudo apt-get install qemu-user-static"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    log_info "Dependencies check passed"
}

# Create build directories
setup_build_env() {
    log_info "Setting up build environment..."
    # Clean up any existing loop devices first
    cleanup_existing_loops

    
    mkdir -p "${BUILD_DIR}"/{image,rootfs,boot}
    
    # Clean up any previous builds
    if [[ -f "${BUILD_DIR}/${IMAGE_NAME}" ]]; then
        log_warn "Removing existing image: ${IMAGE_NAME}"
        rm -f "${BUILD_DIR}/${IMAGE_NAME}"
    fi
    
    log_info "Build environment ready"
}

# Create blank image file
create_image() {
    log_info "Creating blank image file (${IMAGE_SIZE})..."
    
    fallocate -l ${IMAGE_SIZE} "${BUILD_DIR}/${IMAGE_NAME}"
    
    log_info "Image file created: ${BUILD_DIR}/${IMAGE_NAME}"
}

# Partition the image
partition_image() {
    log_info "Partitioning image..."
    
    # Create partition table
    parted "${BUILD_DIR}/${IMAGE_NAME}" --script -- mklabel msdos
    
    # Boot partition (256MB, FAT32)
    parted "${BUILD_DIR}/${IMAGE_NAME}" --script -- mkpart primary fat32 1MiB 257MiB
    parted "${BUILD_DIR}/${IMAGE_NAME}" --script -- set 1 boot on
    
    # Root partition (remaining space, ext4)
    parted "${BUILD_DIR}/${IMAGE_NAME}" --script -- mkpart primary ext4 257MiB 100%
    
    log_info "Image partitioned successfully"
}

# Mount image partitions
mount_image() {
    log_info "Mounting image partitions..."
    
    # Use absolute path for the image file
    local image_path="$(readlink -f "${BUILD_DIR}/${IMAGE_NAME}")"
    
    # Set up loop device
    local loop_device=$(losetup --find --show "${image_path}")
    echo ${loop_device} > "${BUILD_DIR}/loop_device"

    # Use kpartx to create partition mappings
    kpartx -av ${loop_device}
    sleep 2
    
    # Get device basename for mapper names
    local loop_base=$(basename ${loop_device})
    local boot_dev="/dev/mapper/${loop_base}p1"
    local root_dev="/dev/mapper/${loop_base}p2"
    
    # Format partitions
    mkfs.vfat -F 32 -n "SOULBOOT" ${boot_dev}
    mkfs.ext4 -L "SOULROOT" ${root_dev}
    
    # Mount partitions
    mount ${root_dev} "${BUILD_DIR}/rootfs"
    mkdir -p "${BUILD_DIR}/rootfs/boot/firmware"
    mount ${boot_dev} "${BUILD_DIR}/rootfs/boot/firmware"
    
    log_info "Image partitions mounted"
}

# Bootstrap Debian system
bootstrap_system() {
    log_info "Bootstrapping Debian ${DEBIAN_SUITE} system..."
    
    # Stage 1: Extract packages without configuration (foreign mode)
    debootstrap --arch=${ARCH} --foreign --include=systemd,udev,kmod,ifupdown,iproute2,iputils-ping,wget,ca-certificates,openssh-server,curl,apt-transport-https,gnupg,lsb-release,jq \
        ${DEBIAN_SUITE} "${BUILD_DIR}/rootfs" ${DEBIAN_MIRROR}
    
    # Copy QEMU static for chroot operations
    cp /usr/bin/qemu-aarch64-static "${BUILD_DIR}/rootfs/usr/bin/"
    
    # Enable binfmt for aarch64 if not already enabled
    if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
        echo ":qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F" > /proc/sys/fs/binfmt_misc/register
    fi
    
    # Stage 2: Complete the bootstrap inside chroot with emulation
    chroot "${BUILD_DIR}/rootfs" /debootstrap/debootstrap --second-stage
    
    log_info "Base system bootstrapped"
}

# Configure base system
configure_system() {
    log_info "Configuring base system..."
    
    # Mount virtual filesystems for chroot
    mount -t proc proc "${BUILD_DIR}/rootfs/proc"
    mount -t sysfs sysfs "${BUILD_DIR}/rootfs/sys"
    mount -t devtmpfs dev "${BUILD_DIR}/rootfs/dev"
    mount -t devpts devpts "${BUILD_DIR}/rootfs/dev/pts"
    
    # Configure APT sources
    cat > "${BUILD_DIR}/rootfs/etc/apt/sources.list" << EOF
deb ${DEBIAN_MIRROR} ${DEBIAN_SUITE} main contrib non-free
deb http://security.debian.org/debian-security ${DEBIAN_SUITE}-security main contrib non-free
deb ${DEBIAN_MIRROR} ${DEBIAN_SUITE}-updates main contrib non-free
EOF
    
    # Add Raspberry Pi repository
    cat > "${BUILD_DIR}/rootfs/etc/apt/sources.list.d/raspi.list" << EOF
deb http://raspbian.raspberrypi.org/raspbian/ ${DEBIAN_SUITE} main contrib non-free rpi
EOF
    
    # Add repository key
    chroot "${BUILD_DIR}/rootfs" /bin/bash -c "
        apt-get update
        apt-get install -y gnupg
        wget -qO - https://archive.raspberrypi.org/debian/raspberrypi.gpg.key | apt-key add -
        apt-get update
    "
    
    # Set hostname
    echo "soulbox" > "${BUILD_DIR}/rootfs/etc/hostname"
    
    # Configure hosts file
    cat > "${BUILD_DIR}/rootfs/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   soulbox
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF
    
    # Configure network
    cat > "${BUILD_DIR}/rootfs/etc/network/interfaces" << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
    
    log_info "Base system configured"
}

# Install SoulBox specific packages and configuration
install_soulbox() {
    log_info "Installing SoulBox configuration..."
    
    # Copy setup script into chroot
    cp "${PROJECT_DIR}/scripts/setup-system.sh" "${BUILD_DIR}/rootfs/tmp/"
    cp -r "${PROJECT_DIR}/configs" "${BUILD_DIR}/rootfs/tmp/"
    
    # Run setup script in chroot
    chroot "${BUILD_DIR}/rootfs" /bin/bash -c "
        cd /tmp
        chmod +x setup-system.sh
        ./setup-system.sh
    "
    
    # Clean up temporary files
    rm -rf "${BUILD_DIR}/rootfs/tmp/setup-system.sh"
    rm -rf "${BUILD_DIR}/rootfs/tmp/configs"
    
    log_info "SoulBox configuration installed"
}

# Configure kernel and boot
configure_boot() {
    log_info "Configuring boot system..."
    
    # Install Raspberry Pi kernel and bootloader
    chroot "${BUILD_DIR}/rootfs" /bin/bash -c "
        apt-get install -y raspberrypi-kernel raspberrypi-bootloader
    "
    
    # Install boot files
    if [[ -f "${PROJECT_DIR}/configs/boot/config.txt" ]]; then
        cp "${PROJECT_DIR}/configs/boot/config.txt" "${BUILD_DIR}/rootfs/boot/firmware/"
    fi
    
    # Configure fstab
    cat > "${BUILD_DIR}/rootfs/etc/fstab" << EOF
proc            /proc           proc    defaults          0       0
/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1
/dev/mmcblk0p1  /boot/firmware  vfat    defaults          0       2
EOF
    
    # Configure cmdline
    echo "console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet" \
        > "${BUILD_DIR}/rootfs/boot/firmware/cmdline.txt"
    
    log_info "Boot configuration complete"
}

# Final system configuration
finalize_system() {
    log_info "Finalizing system configuration..."
    
    # Enable SSH service
    chroot "${BUILD_DIR}/rootfs" systemctl enable ssh
    
    # Configure SSH for key-only authentication
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' "${BUILD_DIR}/rootfs/etc/ssh/sshd_config"
    
    # Set up Pi user (for initial access)
    chroot "${BUILD_DIR}/rootfs" /bin/bash -c "
        useradd -m -s /bin/bash pi
        usermod -a -G sudo pi
        mkdir -p /home/pi/.ssh
        chmod 700 /home/pi/.ssh
        chown pi:pi /home/pi/.ssh
    "
    
    # Clean up
    chroot "${BUILD_DIR}/rootfs" apt-get clean
    rm -f "${BUILD_DIR}/rootfs/usr/bin/qemu-aarch64-static"
    
    log_info "System finalized"
}

# Unmount and cleanup
cleanup() {
    log_info "Cleaning up build environment..."
    
    # Unmount virtual filesystems
    umount "${BUILD_DIR}/rootfs/dev/pts" 2>/dev/null || true
    umount "${BUILD_DIR}/rootfs/dev" 2>/dev/null || true
    umount "${BUILD_DIR}/rootfs/sys" 2>/dev/null || true
    umount "${BUILD_DIR}/rootfs/proc" 2>/dev/null || true
    
    # Unmount image partitions
    umount "${BUILD_DIR}/rootfs/boot/firmware" 2>/dev/null || true
    umount "${BUILD_DIR}/rootfs" 2>/dev/null || true
    
    # Detach loop device
    if [[ -f "${BUILD_DIR}/loop_device" ]]; then
        local loop_device=$(cat "${BUILD_DIR}/loop_device")
        kpartx -dv ${loop_device} 2>/dev/null || true
        losetup -d ${loop_device} 2>/dev/null || true
        rm -f "${BUILD_DIR}/loop_device"
    fi
    
    log_info "Cleanup complete"
}

# Trap cleanup on exit
trap cleanup EXIT

# Main build process
main() {
    log_info "Starting SoulBox image build..."
    
    check_dependencies
    setup_build_env
    create_image
    partition_image
    mount_image
    bootstrap_system
    configure_system
    install_soulbox
    configure_boot
    finalize_system
    
    log_info "SoulBox image built successfully!"
    log_info "Image location: ${BUILD_DIR}/${IMAGE_NAME}"
    log_info "Flash to SD card with: dd if=${BUILD_DIR}/${IMAGE_NAME} of=/dev/sdX bs=4M status=progress"
}

main "$@"
