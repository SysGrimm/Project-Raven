# Project Raven - Custom LibreELEC Images

🚀 **Automated custom LibreELEC image builder** that takes official LibreELEC releases and applies custom configurations for media center deployments.

## Quick Start

1. **Run the build**: Use GitHub Actions to build a custom image
2. **Download**: Get your customized `.img.gz` file from the releases
3. **Flash**: Write to SD card using Raspberry Pi Imager
4. **Boot**: Your customized LibreELEC system is ready!

## Features

- ✅ **Official LibreELEC Base**: Uses latest official releases (no custom compilation)
- ✅ **Automated Builds**: GitHub Actions workflow for consistent builds
- ✅ **Multiple Devices**: Support for RPi4, RPi5, and Generic x86
- ✅ **Custom Configurations**: Pre-configured Kodi settings and system tweaks
- ✅ **First-Boot Setup**: Automatic customization on first boot
- ✅ **Easy Updates**: Simply trigger a new build when LibreELEC releases updates

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

1. Go to the **Actions** tab in this repository
2. Click **"Build Custom LibreELEC Image"**
3. Select your target device (RPi4, RPi5, or Generic)
4. Click **"Run workflow"**
5. Download the custom image from the generated release

### Locally

```bash
# Set your target device
export TARGET_DEVICE=RPi5  # or RPi4, Generic

# Run the customization script
./scripts/customize-libreelec.sh

# Find your custom image in the output/ directory
ls output/
```

## Supported Devices

- **Raspberry Pi 4**: `TARGET_DEVICE=RPi4`
- **Raspberry Pi 5**: `TARGET_DEVICE=RPi5` (default)
- **Generic PC**: `TARGET_DEVICE=Generic`

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
- ✅ **Faster**: No compilation time
- ✅ **More Reliable**: Uses tested official releases
- ✅ **Easier to Maintain**: No source code management
- ✅ **Always Updated**: Automatically uses latest LibreELEC versions

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

**Project Raven** - Making LibreELEC deployment simple and repeatable! 🚀
