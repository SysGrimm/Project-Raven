#!/bin/bash

echo "=== Minimal SoulBox Build with ARM64 Emulation ==="

# Use a more efficient Docker approach with minimal package installation
docker run -it --privileged \
  --rm \
  -v "$(pwd)":/workspace \
  ubuntu:22.04 bash -c '
set -e
cd /workspace

echo "=== Installing core packages only ==="
apt-get update -q
apt-get install -y --no-install-recommends \
    debootstrap \
    qemu-user-static \
    binfmt-support \
    parted \
    kpartx \
    dosfstools

echo "=== Setting up ARM64 emulation ==="
mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null || echo "binfmt_misc already mounted"

echo "binfmt_misc status: $(cat /proc/sys/fs/binfmt_misc/status)"

# Register qemu-aarch64 
if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    echo "Registering qemu-aarch64..."
    echo ":qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F" > /proc/sys/fs/binfmt_misc/register
    echo "✅ qemu-aarch64 registered"
else
    echo "✅ qemu-aarch64 already registered"
fi

echo "ARM64 emulation status:"
cat /proc/sys/fs/binfmt_misc/qemu-aarch64

echo "=== Installing additional build tools as needed ==="
apt-get install -y --no-install-recommends git sudo systemd

echo "=== Starting SoulBox build ==="
timeout 3600 ./scripts/build-image.sh

echo "=== Build completed successfully! ==="
'
