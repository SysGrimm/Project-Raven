# SoulBox - Raspberry Pi 5 OS

A Debian-based Raspberry Pi 5 operating system with Docker-based cross-compilation build system.

## 🚀 Quick Start

### Download Pre-built Images
Ready-to-flash SD card images are automatically built on every commit:
- Check the [Releases page](https://github.com/yourusername/soulbox/releases) for the latest builds
- Download the `.img` file and flash it to an SD card (8GB+ recommended)
- Use [balenaEtcher](https://www.balena.io/etcher/) or [Raspberry Pi Imager](https://rpi.org/imager)

### Building from Source

#### Prerequisites
- Docker installed and running
- Privileged container support
- At least 10GB free disk space

#### Build Commands
```bash
# Clone the repository
git clone https://github.com/yourusername/soulbox.git
cd soulbox

# Run the Docker-based build
chmod +x build-minimal-emulation.sh
./build-minimal-emulation.sh
```

The build process will:
1. Create a 4GB disk image with proper partitioning
2. Bootstrap a complete Debian Bookworm ARM64 system
3. Configure networking, SSH, and basic services
4. Output a bootable `.img` file in the `build/` directory

## 🏗️ Architecture

### Cross-Platform Build System
- **Docker-based**: Runs on any system with Docker support
- **ARM64 Emulation**: Uses QEMU user-static for cross-architecture builds
- **Unraid Compatible**: Tested and optimized for Unraid NAS systems
- **CI/CD Ready**: Automated builds via GitHub Actions

### Key Technologies
- **Base System**: Debian Bookworm (ARM64)
- **Bootloader**: systemd-boot / U-Boot
- **Emulation**: qemu-user-static with binfmt_misc
- **Containerization**: Docker with privileged mode
- **Build Tool**: debootstrap (two-stage process)

## 📁 Project Structure

```
soulbox/
├── build/                      # Build output directory
│   ├── soulbox-YYYYMMDD.img   # Generated SD card image
│   ├── boot/                   # FAT32 boot partition content
│   └── rootfs/                 # ext4 root filesystem
├── scripts/
│   └── build-image.sh          # Main build script
├── config/                     # System configuration files
├── .github/workflows/          # CI/CD automation
├── build-minimal-emulation.sh  # Docker wrapper script
└── TFM.md                      # Technical documentation
```

## 🔧 Development

### Local Testing
```bash
# Test the build process
./build-minimal-emulation.sh

# Check the generated image
file build/soulbox-*.img
fdisk -l build/soulbox-*.img
```

### Customization
- Edit `scripts/build-image.sh` for system configuration changes
- Modify `config/` files for specific service configurations  
- Update package lists in the bootstrap section

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes with the Docker build
4. Submit a pull request

### Automated Testing
Every push triggers:
- Full ARM64 image build via GitHub Actions
- Automated artifact generation and upload
- Release creation for main branch pushes

## 📋 System Requirements

### Build Host
- **OS**: Any system with Docker support
- **RAM**: 4GB+ recommended  
- **Storage**: 10GB+ free space
- **Docker**: Version 20.10+ with privileged container support

### Target Hardware
- **Device**: Raspberry Pi 4 or 5
- **RAM**: 4GB+ recommended
- **Storage**: 8GB+ SD card (Class 10)
- **Network**: Ethernet or WiFi capability

## 🔍 Troubleshooting

### Common Build Issues

#### "No space left on device"
- Increase Docker storage allocation
- Clean up unused containers: `docker system prune -a`

#### "Exec format error" 
- Ensure binfmt_misc is properly configured
- Check ARM64 emulation: `docker run --rm --platform linux/arm64 ubuntu:22.04 uname -m`

#### Loop device errors
- Run with sufficient privileges (`--privileged`)
- Clean up stale loop devices: `losetup -D`

### Boot Issues

#### SD card not detected
- Verify the image was flashed completely
- Check SD card compatibility (Class 10 recommended)
- Test on different Pi models

#### Network not working
- Check Ethernet cable connection
- Verify DHCP is available on network
- SSH is enabled by default (user: `pi`, check logs)

## 📖 Documentation

- **[TFM.md](TFM.md)**: Comprehensive technical documentation
- **[Build Process](TFM.md#build-process-flow)**: Detailed build steps
- **[Docker Integration](TFM.md#docker-based-build-environment)**: Container setup
- **[Troubleshooting Guide](TFM.md#troubleshooting-guide)**: Common issues and solutions

## 📄 License

This project is open source. See LICENSE file for details.

## 🙏 Acknowledgments

- [Raspberry Pi Foundation](https://www.raspberrypi.org/) for excellent ARM hardware
- [Debian Project](https://www.debian.org/) for the solid base system  
- [Docker](https://www.docker.com/) for containerization technology
- [GitHub Actions](https://github.com/features/actions) for CI/CD automation

---

**Build Status**: ![Build Status](https://github.com/yourusername/soulbox/workflows/Build%20SoulBox%20SD%20Card%20Image/badge.svg)

Ready to flash and boot! 🔥
