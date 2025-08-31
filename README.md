<div align="center">
  <img src="assets/logos/soulbox-logo-1024.png" alt="SoulBox Logo" width="200"/>
  <h1>SoulBox</h1>
  <h3>Will-o'-Wisp Media Center</h3>
  <p><em>A turnkey media center solution for ARM64 devices</em></p>

  <p>
    <a href="#quick-start">Quick Start</a> •
    <a href="#features">Features</a> •
    <a href="#installation">Installation</a> •
    <a href="#documentation">Documentation</a>
  </p>
</div>

---

## What is SoulBox?

SoulBox is a **ready-to-use media center operating system** built specifically for ARM64 devices like the Raspberry Pi 5. It combines a lightweight Debian base with a fully configured Kodi media center, creating an appliance-like experience that just works.

**Perfect for:**
- Home media servers
- Living room entertainment centers
- Digital signage displays
- Anyone wanting Kodi without the hassle

## Quick Start

### 1. Download & Flash
**Get the latest pre-built image:**
- 📥 [Download from Releases](../../releases/latest) 
- Flash to 8GB+ SD card using [balenaEtcher](https://www.balena.io/etcher/)
- Insert card and power on your device

### Building from Source

#### Prerequisites
- Docker installed and running
- Privileged container support
- At least 10GB free disk space

#### Build Commands
```bash
# Clone the repository
git clone https://192.168.176.113:3000/yourusername/soulbox.git
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
- **CI/CD Ready**: Automated builds via Gitea Actions

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
- Full ARM64 image build via Gitea Actions
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

Comprehensive documentation is available in the **[SoulBox Wiki](https://192.168.176.113:3000/yourusername/soulbox/wiki)**:

- **[🏠 Home](https://192.168.176.113:3000/yourusername/soulbox/wiki/Home)**: Overview and navigation
- **[🏗️ Architecture](https://192.168.176.113:3000/yourusername/soulbox/wiki/Architecture)**: System design and technology stack
- **[🔧 Build System](https://192.168.176.113:3000/yourusername/soulbox/wiki/Build-System)**: Container-friendly build process
- **[🚀 Deployment Guide](https://192.168.176.113:3000/yourusername/soulbox/wiki/Deployment-Guide)**: Installation and configuration
- **[🎯 Features](https://192.168.176.113:3000/yourusername/soulbox/wiki/Features)**: Complete feature overview
- **[👨‍💻 Development](https://192.168.176.113:3000/yourusername/soulbox/wiki/Development)**: Contributing and development workflow
- **[🛠️ Troubleshooting](https://192.168.176.113:3000/yourusername/soulbox/wiki/Troubleshooting)**: Common issues and solutions

## 📄 License

This project is open source. See LICENSE file for details.

## 🙏 Acknowledgments

- [Raspberry Pi Foundation](https://www.raspberrypi.org/) for excellent ARM hardware
- [Debian Project](https://www.debian.org/) for the solid base system  
- [Docker](https://www.docker.com/) for containerization technology
- [Gitea Actions](https://192.168.176.113:3000/features/actions) for CI/CD automation

---

**Build Status**: ![Build Status](https://192.168.176.113:3000/yourusername/soulbox/workflows/Build%20SoulBox%20SD%20Card%20Image/badge.svg)

Ready to flash and boot! 🔥
