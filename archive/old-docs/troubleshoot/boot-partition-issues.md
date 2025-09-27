# Boot Partition Issues - Troubleshooting Guide

## Problem Description
Raspberry Pi 5 failing to boot with partition read errors:
- "Failed to open partition 4"
- "Failed to open partition 5" 
- "Unable to read partition as FAT"

## Root Causes

### 1. Incomplete Image Flash
The LibreELEC image may not have been fully written to the SD card.

### 2. SD Card Issues
- Corrupted SD card
- Incompatible SD card (need Class 10 or better)
- SD card too small (need 8GB minimum)

### 3. Flash Process Issues
- Interrupted flash process
- Wrong image file used
- Verification failed during flash

## Troubleshooting Steps

### Step 1: Verify Downloaded Files
```bash
# Check if the image file downloaded completely
ls -la LibreELEC-RPi5.aarch64-12.2.0.img.gz

# Verify checksum
sha256sum -c LibreELEC-RPi5.aarch64-12.2.0.img.gz.sha256
```

### Step 2: Re-flash the Image
1. **Use Raspberry Pi Imager** (recommended)
   - Download from https://rpi.org/imager
   - Select "Use custom image"
   - Choose the `.img.gz` file (don't extract it)
   - Select your SD card
   - Click "Write"

2. **Alternative: Use Balena Etcher**
   - Download from https://www.balena.io/etcher/
   - Flash the `.img.gz` file directly

### Step 3: SD Card Recommendations
- **Minimum**: 8GB Class 10
- **Recommended**: 16GB+ SanDisk Extreme or Samsung EVO Select
- **Speed**: U3 or A2 rated for better performance

### Step 4: Apply Configuration Package
After successful image flash:

1. Extract the config package:
   ```bash
   tar -xzf LibreELEC-RPi5-12.2.0-Raven-Config.tar.gz
   ```

2. Copy boot files to SD card:
   - Mount the SD card boot partition
   - Copy contents of `boot/` folder from config package
   - Safely eject SD card

### Step 5: Hardware Check
- Try a different SD card
- Check SD card reader/adapter
- Ensure Pi 5 has adequate power supply (5V 5A recommended)

## Quick Fix Commands

```bash
# Re-download if needed
wget https://github.com/SysGrimm/Project-Raven/releases/download/v20250926-0230-le12.2.0-ts1.88.3/LibreELEC-RPi5.aarch64-12.2.0.img.gz

# Verify download
wget https://github.com/SysGrimm/Project-Raven/releases/download/v20250926-0230-le12.2.0-ts1.88.3/LibreELEC-RPi5.aarch64-12.2.0.img.gz.sha256
sha256sum -c LibreELEC-RPi5.aarch64-12.2.0.img.gz.sha256
```

## Expected Boot Process
A successful boot should show:
```
Raspberry Pi 5 - 4GB
bootloader: 000d3ca2 2025/08/27
[... normal boot messages ...]
LibreELEC (official) Version: 12.2.0
```

## If Still Failing
1. Try a different SD card
2. Test with official LibreELEC image first
3. Check Pi 5 hardware with known good SD card
4. Report issue with SD card model and flash method used
