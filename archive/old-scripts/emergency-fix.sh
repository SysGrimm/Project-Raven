#!/bin/bash

# Emergency fix script to create a clean release
# This will re-download and verify the LibreELEC image

set -e

echo "[CONFIG] Emergency Release Fix"
echo "========================"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo " Downloading LibreELEC RPi5 image directly..."
curl -L -o "LibreELEC-RPi5.aarch64-12.2.0.img.gz" "https://releases.libreelec.tv/LibreELEC-RPi5.aarch64-12.2.0.img.gz"

echo " Verifying download..."
file "LibreELEC-RPi5.aarch64-12.2.0.img.gz"
ls -la "LibreELEC-RPi5.aarch64-12.2.0.img.gz"

echo "[SETUP] Checking file type..."
if file "LibreELEC-RPi5.aarch64-12.2.0.img.gz" | grep -q "gzip compressed"; then
    echo "[SUCCESS] File is correctly gzipped"
else
    echo "[ERROR] File is NOT gzipped - there's an issue"
    file "LibreELEC-RPi5.aarch64-12.2.0.img.gz"
    head -c 100 "LibreELEC-RPi5.aarch64-12.2.0.img.gz" | hexdump -C
fi

echo " Test extraction..."
gzip -t "LibreELEC-RPi5.aarch64-12.2.0.img.gz"
if [ $? -eq 0 ]; then
    echo "[SUCCESS] Gzip test passed - file is valid"
else
    echo "[ERROR] Gzip test failed - file is corrupted"
fi

# Calculate checksum
echo "[SETUP] Calculating checksum..."
sha256sum "LibreELEC-RPi5.aarch64-12.2.0.img.gz" > "LibreELEC-RPi5.aarch64-12.2.0.img.gz.sha256"
cat "LibreELEC-RPi5.aarch64-12.2.0.img.gz.sha256"

echo "[FOLDER] Files in temp directory:"
ls -la

echo "🧹 Cleanup..."
cd /
rm -rf "$TEMP_DIR"

echo "[SUCCESS] Verification complete"
