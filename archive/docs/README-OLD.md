# Project Raven - Custom LibreELEC Images

[LAUNCH] **Automated custom LibreELEC image builder** with built-in Tailscale VPN that creates releases for Raspberry Pi 5 and Pi Zero W2.

##  Quick Start

### Option 1: Download Pre-Built Releases (Recommended)
1. **[[PACKAGE] Go to Releases](https://github.com/SysGrimm/Project-Raven/releases)**
2. **Download** the latest release for your device:
   - `LibreELEC-RPi5-*-Raven-Config.tar.gz` (Raspberry Pi 5)
   - `LibreELEC-RPiZeroW2-*-Raven-Config.tar.gz` (Raspberry Pi Zero W2)
3. **Flash** the `.img.gz` to SD card using Raspberry Pi Imager
4. **Extract** the config package and copy to SD card
5. **Boot** - your system auto-configures!

### Option 2: Build Custom
1. **Fork** this repository  
2. **Run** GitHub Actions workflow: "Automated Release Build"
3. **Download** your custom builds from the artifacts

##  Features

-  **Auto-Release System**: Triggers new releases when LibreELEC or Tailscale updates
- [SECURITY] **Built-in Tailscale VPN**: Secure remote access with LibreELEC settings interface
- [MOBILE] **Multiple Devices**: Raspberry Pi 5 and Pi Zero W2 support
-  **Official LibreELEC Base**: Uses unmodified official releases
- [LAUNCH] **Automated Builds**: GitHub Actions CI/CD pipeline
- [TOOL] **Custom Configurations**: Pre-configured Kodi settings and optimizations
- [PACKAGE] **Easy Installation**: Download, flash, boot - that's it!

## Project Structure

```
├── configurations/           # Custom configuration files
│   ├── config.txt           # Boot configuration (GPU memory, performance)
│   ├── cmdline.txt          # Kernel command line parameters
│   ├── first-boot.sh        # First boot customization script
│   └── storage/             # Files to copy to storage partition
│       └── .kodi/userdata/  # Kodi settings and configurations
├── scripts/
│   └── customize-libreelec.sh  # Main customization script
├── image-customization/     # Working directory for image modification
└── output/                  # Generated custom images

```

## Customizations Applied

### Boot Configuration (`config.txt`)
- GPU memory allocation optimized for 4K video
- 4K 60fps support enabled
- Performance overclocking settings
- Audio and HDMI optimizations

### Kodi Settings (`guisettings.xml`)
- Optimized video playbook settings
- Audio passthrough configuration
- Web server enabled for remote control
- Media-friendly display settings

### System Configuration
- SSH enabled by default
- First-boot customization script
- Custom directory structure
- Network optimizations

## Building Custom Images

### Via GitHub Actions (Recommended)

## 🤖 Automated Release System

Project Raven automatically creates new releases when:

- **[PACKAGE] New LibreELEC versions** are released
- **[SECURITY] New Tailscale versions** are available  
- ** Code changes** are pushed to main branch

### Release Schedule
- **🕕 Daily checks** at 6 AM UTC for version updates
- **[PERFORMANCE] Immediate builds** when code changes are detected
- **[MOBILE] Manual triggers** available via GitHub Actions

### What You Get
Each release includes:
- **RPi5 Images**: `LibreELEC-RPi5-*` files (Raspberry Pi 5)
- **RPi Zero W2 Images**: `LibreELEC-RPiZeroW2-*` files (Pi Zero W2)  
- **Configuration Packages**: Custom settings and Tailscale integration
- **Checksums**: `.sha256` files for verification
- **Latest Versions**: Always uses newest LibreELEC + Tailscale

## [LAUNCH] Build Your Own

### Via GitHub Actions

1. Go to the **Actions** tab in this repository
2. Click **"Automated Release Build"** for automatic releases
3. Or click **"Build Custom LibreELEC Image"** for manual builds
4. Select your target device (RPi4, RPi5, RPiZeroW2, or Generic)
5. Download from the generated release

### Locally

```bash
# Set your target device
export TARGET_DEVICE=RPi5  # or RPi4, Generic

# Run the customization script
./scripts/customize-libreelec.sh

# Find your custom image in the output/ directory
ls output/
```

##  Supported Devices

- **Raspberry Pi 5**: `LibreELEC-RPi5-*` (aarch64, latest performance)
- **Raspberry Pi Zero W2**: `LibreELEC-RPiZeroW2-*` (arm, compact build)
- **Raspberry Pi 4**: `LibreELEC-RPi4-*` (aarch64, manual builds only)
- **Generic PC**: `LibreELEC-Generic-*` (x86_64, manual builds only)

## Configuration

### Adding Custom Files

Place any files you want included in the final image in the `configurations/storage/` directory. These will be copied to the LibreELEC storage partition.

### Modifying Boot Settings

Edit `configurations/config.txt` to change boot parameters, GPU settings, overclocking, etc.

### Custom First-Boot Actions

Modify `configurations/first-boot.sh` to add custom setup steps that run on the first boot.

## Architecture

This project takes a **release-based approach** rather than building LibreELEC from source:

1. **Download**: Fetches the latest official LibreELEC release
2. **Extract**: Decompresses and mounts the image file
3. **Customize**: Applies configuration files and scripts
4. **Repackage**: Compresses the modified image for distribution

This approach is:
- [SUCCESS] **Faster**: No compilation time
- [SUCCESS] **More Reliable**: Uses tested official releases
- [SUCCESS] **Easier to Maintain**: No source code management
- [SUCCESS] **Always Updated**: Automatically uses latest LibreELEC versions

## Releases

Custom images are automatically published as GitHub releases when changes are pushed to the main branch. Each release includes:

- Custom LibreELEC image (`.img.gz`)
- SHA256 checksum for verification
- Build configuration details
- Installation instructions

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add your customizations to the `configurations/` directory
4. Test your changes
5. Submit a pull request

## Legacy Components

This repository contains legacy components from previous approaches:

- `libreelec-custom-build/`: Previous source-based build system (deprecated)
- `libreelec-tailscale-addon/`: Tailscale addon (can be integrated into new approach)
- Various old scripts in `scripts/` directory

These are kept for reference but the main focus is now on the official release customization approach.

---

**Project Raven** - Making LibreELEC deployment simple and repeatable! [LAUNCH]
