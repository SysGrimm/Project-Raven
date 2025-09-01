# SoulBox Enhanced Build System

The SoulBox Media Center now has a complete build system that creates fully functional bootable disk images with real Raspberry Pi firmware, kernel, and operating system.

## Build Scripts Overview

### 1. `build-soulbox-full.sh` - Complete Local Build
**Best for: Local development and testing**

Features:
- Downloads real Pi firmware from GitHub
- Downloads official Raspberry Pi OS ARM64 image
- Creates 2GB fully functional system images
- Supports loop device mounting (requires privileges)
- Includes Pi 5 optimization and hardware acceleration
- Creates compressed artifacts and checksums

```bash
./build-soulbox-full.sh --version v0.3.0 --clean
```

### 2. `build-soulbox-enhanced-container.sh` - Container-Optimized Build
**Best for: CI/CD pipelines and Docker containers**

Features:
- Container-friendly (no loop devices required)
- Uses `mtools` and `e2tools` for filesystem manipulation
- Optimized for limited container resources
- Creates 1.5GB images for faster builds
- Real Pi firmware integration
- Compatible with GitHub Actions and similar CI

```bash
./build-soulbox-enhanced-container.sh --version v0.3.0 --clean
```

### 3. `build-soulbox-containerized.sh` - Original Container Script
**Legacy: The original container approach**

- Maintained for compatibility
- Uses LibreELEC-style staging approach
- Complex filesystem extraction methods
- Larger and more complex codebase

## What's New in Enhanced System

### Real Pi Firmware Integration
- **Authentic Boot Files**: Downloads `start4.elf`, `fixup4.dat`, `kernel8.img`, and device tree files from the official Pi firmware repository
- **Pi 5 Optimized**: Includes `bcm2712-rpi-5-b.dtb` for full Pi 5 hardware support
- **Hardware Acceleration**: Proper GPU configuration for media center use

### Complete Operating System
- **Base OS**: Uses official Raspberry Pi OS ARM64 Bookworm
- **Full Root Filesystem**: Includes all system libraries, utilities, and kernel modules
- **Package Manager**: APT package management ready for additional software installation

### SoulBox Customizations
- **Auto-boot Kodi**: Systemd service for automatic Kodi startup
- **Optimized Configuration**: Pi 5 performance settings for media streaming
- **User Management**: Pre-configured `soulbox` user with media center permissions
- **Network Ready**: SSH enabled, Tailscale VPN ready
- **Branded Experience**: Custom MOTD and hostname

## Build Output

Each build creates multiple artifacts:

```
soulbox-v0.3.0.img          # Raw disk image (flashable)
soulbox-v0.3.0.img.sha256   # Integrity checksum
soulbox-v0.3.0.img.xz       # Compressed image
soulbox-v0.3.0.img.xz.sha256 # Compressed checksum
```

## System Requirements

### For Local Build (`build-soulbox-full.sh`)
```bash
# Required tools
apt-get install curl wget xz-utils parted dosfstools e2fsprogs mtools

# Disk space: ~8GB (for downloads, staging, and output)
# RAM: 2GB+ recommended
# Privileges: sudo/root for loop device access
```

### For Container Build (`build-soulbox-enhanced-container.sh`)
```bash
# Required tools (typically in container)
apt-get install curl wget xz-utils parted dosfstools e2fsprogs mtools coreutils

# Disk space: ~5GB (optimized for containers)
# RAM: 1GB+ (container-friendly)
# Privileges: user-level (no loop devices needed)
```

## Boot Configuration

The enhanced system includes optimized Pi 5 configuration:

```ini
# GPU memory for 4K video streaming
gpu_mem=256

# Performance optimization
arm_freq=2400
over_voltage=2
force_turbo=1

# Video acceleration
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# Audio configuration
dtparam=audio=on
audio_pwm_mode=2
```

## User Experience

### Default Credentials
- **soulbox:soulbox** - Primary media center user
- **pi:soulbox** - Pi compatibility account  
- **root:soulbox** - Administrative access

### First Boot
1. System boots directly into Kodi media center
2. SSH access available on port 22
3. Automatic filesystem expansion
4. SoulBox setup script configures services

### Services Enabled
- **Kodi Media Center**: Auto-starts on boot
- **SSH Server**: Remote access enabled
- **Tailscale VPN**: Ready for secure connections

## Development Workflow

### Local Testing
```bash
# Clean build with latest changes
./build-soulbox-full.sh --clean --version v0.3.0

# Flash to SD card for testing
dd if=soulbox-v0.3.0.img of=/dev/sdX bs=4M status=progress
```

### CI/CD Integration
```bash
# In GitHub Actions or similar
./build-soulbox-enhanced-container.sh --version $VERSION

# Upload artifacts
cp soulbox-*.img* ./artifacts/
```

## Verification

### Image Integrity
```bash
# Verify checksum
sha256sum -c soulbox-v0.3.0.img.sha256

# Check partition table
parted soulbox-v0.3.0.img print
```

### Boot Files Verification
```bash
# Check boot partition contents
mdir -i soulbox-v0.3.0.img@@1M
```

Expected files:
- `start4.elf` - Pi 5 boot firmware
- `kernel8.img` - ARM64 kernel
- `config.txt` - SoulBox configuration
- `cmdline.txt` - Boot parameters
- `bcm2712-rpi-5-b.dtb` - Device tree

## Troubleshooting

### Common Issues

**Missing firmware files**: 
- Check internet connection for firmware download
- Verify GitHub accessibility

**Insufficient disk space**:
- Use `--clean` to remove previous builds
- Check available space with `df -h`

**Container permission errors**:
- Use enhanced container script instead of full build
- Ensure e2tools and mtools are available

**Boot failures**:
- Verify SD card is properly flashed
- Check power supply (Pi 5 needs 5V 5A)
- Confirm Pi 5 hardware compatibility

### Debug Mode
```bash
# Enable verbose output
set -x
./build-soulbox-enhanced-container.sh --version test-debug
```

## Architecture

### Build Pipeline
1. **Download Phase**: Pi firmware + OS base image
2. **Extract Phase**: Separate boot/root partitions
3. **Customize Phase**: Add SoulBox configurations
4. **Assembly Phase**: Create new bootable image
5. **Package Phase**: Generate checksums and compression

### Container Compatibility
- No loop device mounting required
- Uses `mtools` for FAT32 manipulation
- Uses `e2tools` for ext4 operations
- Optimized resource usage
- Parallel-safe execution

## Future Enhancements

### Planned Features
- **Kodi Addon Integration**: Pre-install media center addons
- **Tailscale Auto-Auth**: Automatic VPN connection
- **Custom Branding**: Boot splash and UI themes
- **Hardware Detection**: Auto-configure for different Pi models
- **Update System**: Over-the-air SoulBox updates

### Build Optimizations
- **Layer Caching**: Reuse downloads between builds
- **Parallel Processing**: Multi-threaded operations
- **Delta Updates**: Incremental image updates
- **Build Variants**: Different image sizes and features

## Contributing

### Build System Changes
1. Test changes with both build scripts
2. Verify container compatibility
3. Update documentation
4. Add version compatibility notes

### Adding Features
1. Modify customization scripts in staging directory
2. Test on real Pi 5 hardware
3. Document configuration changes
4. Update default credentials if needed

---

SoulBox Media Center - Ready for your media streaming experience.
