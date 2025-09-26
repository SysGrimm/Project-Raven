# LibreELEC Raven Configuration Package

This package contains custom configurations for LibreELEC 12.2.0 on RPi5.

## Quick Setup

1. **Flash LibreELEC**: Flash the included `.img.gz` file to your SD card
2. **Apply configs**: Before first boot, copy files from `boot/` to SD card boot partition
3. **Boot**: Start your device - first-boot script will apply remaining configurations

## What's Included

### Boot Configuration (`config.txt`)
- GPU memory: 256MB (optimized for 4K video)
- 4K 60fps support enabled
- Performance overclocking settings
- Audio and HDMI optimizations

### Kodi Settings (`guisettings.xml`)  
- Optimized video playback
- Audio passthrough enabled
- Web server enabled for remote control
- Media-friendly interface

### System Features
- SSH enabled by default
- Automated first-boot setup
- Custom directory structure
- Network optimizations

## Manual Installation

### Step 1: Flash Image
Use Raspberry Pi Imager or Balena Etcher to flash the LibreELEC image to your SD card.

### Step 2: Apply Boot Configuration
Copy these files to the SD card's boot partition (visible on any computer):
- `boot/config.txt` → `config.txt`
- `boot/cmdline.txt` → `cmdline.txt`  
- `boot/first-boot.sh` → `first-boot.sh`

### Step 3: First Boot
Insert SD card and boot your device. The first-boot script will:
- Enable SSH
- Apply Kodi settings
- Set up custom directories
- Configure system optimizations

Enjoy your customized LibreELEC system! 🚀
