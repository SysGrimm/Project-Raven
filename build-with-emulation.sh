#!/bin/bash

echo "=== Enhanced SoulBox Build with ARM64 Emulation ==="
echo "Building with proper binfmt_misc support..."

# Enhanced Docker command with proper emulation support
docker run -it --privileged \
  --rm \
  -v "$(pwd)":/workspace \
  ubuntu:22.04 bash -c '
set -e

cd /workspace

echo "=== Installing build dependencies with emulation support ==="
apt-get update -q
apt-get install -y \
    debootstrap \
    qemu-user-static \
    binfmt-support \
    parted \
    kpartx \
    git \
    sudo \
    dosfstools \
    systemd \
    ca-certificates \
    arch-test \
    wget \
    curl

echo "=== Setting up ARM64 emulation ==="
# Mount binfmt_misc filesystem
mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || echo "binfmt_misc already mounted"

echo "binfmt_misc status: $(cat /proc/sys/fs/binfmt_misc/status)"

# Register qemu-aarch64 if not already registered
if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    echo "Registering qemu-aarch64 binary format..."
    echo ":qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F" > /proc/sys/fs/binfmt_misc/register
    echo "✅ qemu-aarch64 registration completed"
else
    echo "✅ qemu-aarch64 already registered"
fi

# Verify registration
echo "ARM64 emulation status:"
cat /proc/sys/fs/binfmt_misc/qemu-aarch64

echo "Available architectures:"
arch-test

echo "=== Testing ARM64 binary execution ==="
# Create a simple ARM64 test
echo "Testing if we can execute ARM64 binaries..."
if /usr/bin/qemu-aarch64-static /bin/true 2>/dev/null; then
    echo "✅ ARM64 binary execution works!"
else
    echo "❌ ARM64 binary execution failed"
    exit 1
fi

echo "=== Starting SoulBox build ==="
timeout 3600 ./scripts/build-image.sh

echo "=== Build completed successfully! ==="
'

chmod +x build-with-emulation.sh
