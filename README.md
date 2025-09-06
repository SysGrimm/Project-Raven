# Project-Raven 🎬

**A complete LibreELEC media center solution with integrated VPN, Jellyfin support, and automated setup.**

Project-Raven transforms your Raspberry Pi into a powerful, remotely accessible media center with zero-configuration networking and beautiful themes.

## ✨ Features

### 🎯 **Core Components**
- **LibreELEC 12.x** - Optimized media center OS with CEC support
- **Tailscale VPN** - Secure remote access with mesh networking
- **Jellyfin Integration** - Native connection to Jellyfin media servers
- **Copacetic Theme** - Modern, clean interface optimized for TV viewing
- **Setup Wizard** - Guided first-boot configuration

### 🔧 **What Makes It Special**
- **Zero-Config CEC** - TV remote control works out of the box
- **One-Click VPN** - Authenticate with Tailscale auth keys
- **Auto Jellyfin Setup** - Connect to your media server during setup
- **Beautiful UI** - Copacetic theme pre-configured and optimized
- **Turnkey Solution** - Flash image and run setup wizard

## 🚀 Quick Start

### 1. Download & Flash
```bash
# Download latest release
curl -L -o libreelec-raven.img.gz 
  "https://github.com/SysGrimm/Project-Raven/releases/latest/download/LibreELEC-RPi4-raven.img.gz"

# Flash to SD card (8GB+ recommended)
# Use Raspberry Pi Imager or similar tool
```

### 2. First Boot Setup
1. **Insert SD card** into Raspberry Pi 4/5
2. **Connect to TV** via HDMI (for CEC remote support)
3. **Connect network** (Ethernet or WiFi)
4. **Power on** - Setup wizard starts automatically

### 3. Configuration Wizard
The setup wizard will guide you through:
- **Jellyfin Server**: Enter server URL, username, password
- **Tailscale VPN**: Paste auth key for automatic connection
- **Device Hostname**: Choose name for your media center
- **Theme Setup**: Copacetic theme activated automatically

### 4. Enjoy! 
- Use TV remote to navigate Kodi
- Access remotely via Tailscale network
- Stream from Jellyfin server seamlessly

## 📦 What's Included

### **Pre-installed Add-ons**
- **Jellyfin for Kodi** - Native Jellyfin integration
- **Tailscale VPN** - Secure mesh networking
- **YouTube** - Stream YouTube content
- **UPnP/DLNA** - Network media sharing

### **Custom Theme**
- **Copacetic Skin** - Clean, modern interface
- **Optimized for TV** - Perfect for couch viewing
- **Remote-friendly** - Easy navigation with TV remote

### **System Optimizations**
- **CEC Support** - TV remote control enabled
- **Hardware Acceleration** - Optimized video decoding
- **Network Performance** - VPN and streaming optimized
- **Auto-updates** - Security patches via image updates

## 💻 Supported Hardware

| Device | Status | Performance | Notes |
|--------|--------|-------------|-------|
| **Raspberry Pi 4** (4GB+) | ✅ **Recommended** | Excellent | Best price/performance |
| **Raspberry Pi 5** (4GB+) | ✅ **Best** | Outstanding | Latest features |
| **Raspberry Pi 3** | ⚠️ Limited | Good | Basic 1080p playback |
| **Generic x86_64** | ✅ Supported | Varies | NUC, mini-PC builds |

### **Requirements**
- **Storage**: 8GB+ microSD card (Class 10+)
- **Network**: Ethernet or WiFi connection
- **Display**: HDMI TV/monitor with CEC support
- **Power**: Official power adapter recommended

## 🔧 Advanced Configuration

### **Jellyfin Setup**
- Server discovery during setup wizard
- Automatic library sync
- Hardware transcoding support
- Multiple user profiles

### **Tailscale Network**
- Mesh VPN with automatic NAT traversal
- Exit node capability
- Subnet routing support
- Mobile device access

### **Remote Access**
Once connected to Tailscale:
- **Kodi Web Interface**: `http://100.x.x.x:8080`
- **SSH Access**: `ssh root@100.x.x.x`
- **File Sharing**: `\100.x.x.x` or `smb://100.x.x.x`

## 🛠 Building Custom Images

### **Prerequisites**
```bash
# macOS
brew install wget git rsync gawk coreutils

# Ubuntu/Debian  
sudo apt install build-essential git wget rsync gawk
```

### **Build Process**
```bash
# Clone repository
git clone https://github.com/SysGrimm/Project-Raven.git
cd Project-Raven/libreelec-custom-build

# Configure build (edit config/project.conf)
# Set PROJECT=RPi, DEVICE=RPi4, ARCH=arm, etc.

# Run build
./scripts/build-image.sh

# Output: LibreELEC-RPi.RPi4-raven-YYYYMMDD.img
```

### **Repository Structure**
```
Project-Raven/
├── libreelec-custom-build/    # Custom LibreELEC build system
├── libreelec-tailscale-addon/ # Tailscale VPN service add-on
├── wiki/                      # Comprehensive documentation
└── README.md                  # This file
```

## 📖 Documentation

**All documentation is available in the [GitHub Wiki](https://github.com/SysGrimm/Project-Raven/wiki)** with comprehensive coverage of all aspects of the system.

### **User Guides**
- **[Quick Start Guide](https://github.com/SysGrimm/Project-Raven/wiki/Quick-Start-Guide)** - Get running in 30 minutes
- **[CEC Troubleshooting](https://github.com/SysGrimm/Project-Raven/wiki/CEC-Troubleshooting)** - Fix common remote control issues
- **[Tailscale Add-on](https://github.com/SysGrimm/Project-Raven/wiki/Tailscale-Add-on)** - VPN setup and configuration

### **Developer Resources**
- **[Architecture Overview](https://github.com/SysGrimm/Project-Raven/wiki/Architecture-Overview)** - Complete system design documentation
- **[Universal Package Download System](https://github.com/SysGrimm/Project-Raven/wiki/Universal-Package-Download-System)** - Build reliability framework
- **[Custom LibreELEC Build](https://github.com/SysGrimm/Project-Raven/wiki/Custom-LibreELEC-Build)** - Custom image creation process

### **Technical References**
- **[Known Issues](https://github.com/SysGrimm/Project-Raven/wiki/Known-Issues)** - Current limitations and workarounds
- **[Changelog](https://github.com/SysGrimm/Project-Raven/wiki/Changelog)** - Complete version history with v2.1.0 Universal Package Download System
- **[Version 2.0 Enhancements](https://github.com/SysGrimm/Project-Raven/wiki/Version-2.0-Enhancements)** - Major improvements and new features

## 🤝 Community

### **Getting Help**
- **[GitHub Issues](https://github.com/SysGrimm/Project-Raven/issues)** - Bug reports and feature requests
- **[Discussions](https://github.com/SysGrimm/Project-Raven/discussions)** - Community support
- **[Wiki](https://github.com/SysGrimm/Project-Raven/wiki)** - Comprehensive documentation

### **Contributing**
We welcome contributions! Areas where you can help:
- Code contributions and bug fixes
- Documentation improvements  
- Bug reports and testing
- Feature suggestions and feedback

## 📜 License

Project-Raven is licensed under [GPL-2.0-or-later](LICENSE).

### **Third-party Components**
- **LibreELEC**: [GPL-2.0](https://github.com/LibreELEC/LibreELEC.tv/blob/master/LICENSE)
- **Kodi**: [GPL-2.0](https://github.com/xbmc/xbmc/blob/master/LICENSE.md)
- **Tailscale**: [BSD-3-Clause](https://github.com/tailscale/tailscale/blob/main/LICENSE)
- **Jellyfin**: [GPL-2.0](https://github.com/jellyfin/jellyfin/blob/master/LICENSE)
- **Copacetic Theme**: [GPL-2.0](https://github.com/scarfa/Copacetic/blob/master/LICENSE.txt)

## ⭐ Credits

**Created by**: [SysGrimm](https://github.com/SysGrimm)

**Special Thanks**:
- LibreELEC Team - Excellent foundation
- Tailscale Team - Revolutionary networking
- Jellyfin Team - Open source media server
- Kodi Community - Endless possibilities
- Copacetic Theme Authors - Beautiful design

---

**🎉 Ready to transform your media experience?** [Download the latest release](https://github.com/SysGrimm/Project-Raven/releases) and get started!

## What is Project Raven?

Project Raven automatically builds custom Raspberry Pi OS images that include:

- **Kodi Media Center** - Auto-starting entertainment system
- **Tailscale VPN** - Secure remote access out of the box
- **Headless Ready** - Perfect for media centers and home servers
- **Zero Configuration** - Flash and boot, that's it!

## Quick Start

### 1. Download
Get the latest release from [Releases](../../releases/latest)

### 2. Flash
Use [Raspberry Pi Imager](https://www.raspberrypi.org/software/) or [balenaEtcher](https://www.balena.io/etcher/) to flash the `.img.xz` file to an SD card (8GB minimum)

### 3. Boot
Insert the SD card into your Raspberry Pi and power it on. Kodi will start automatically after the initial setup (2-3 minutes).

### 4. Configure Tailscale
```bash
# SSH into your Pi (default user: kodi)
ssh kodi@your-pi-ip

# Set up Tailscale
sudo tailscale up

# Follow the authentication URL provided
```

## Features

### Kodi Media Center
- **Auto-starts on boot** - No manual intervention needed
- **Hardware acceleration** - Optimized for Raspberry Pi performance
- **Audio/video drivers** - Pre-configured for best compatibility
- **Web interface** - Access at `http://your-pi-ip:8080`

### Tailscale VPN
- **Pre-installed** - Ready to configure with one command
- **Secure remote access** - Access your media center from anywhere
- **Zero-config networking** - No port forwarding or firewall setup needed
- **Cross-platform** - Works with all your devices

### System Optimization
- **SSH enabled** - Remote access ready out of the box
- **Headless operation** - No monitor required after setup
- **Auto-login** - Seamless user experience
- **Service management** - Systemd integration for reliability

## Supported Hardware

| Device | Status | Notes |
|--------|--------|-------|
| Raspberry Pi 5 | Full support | Best performance |
| Raspberry Pi 4 | Full support | All variants (2GB/4GB/8GB) |
| Raspberry Pi Zero 2 W | Limited support | Slower performance, WiFi only |
| Raspberry Pi 3 | Not supported | ARM64 architecture required |

### Storage Requirements
- **Minimum:** 8GB Class 10 SD card
- **Recommended:** 32GB+ high-endurance SD card
- **Best:** SSD via USB for better performance and reliability

## Network Access

### Local Network
- **SSH:** `ssh kodi@your-pi-ip`
- **Kodi Web:** `http://your-pi-ip:8080`
- **Kodi JSON-RPC:** `http://your-pi-ip:8080/jsonrpc`

### Tailscale Network (after setup)
- **SSH:** `ssh kodi@your-tailscale-ip`
- **Kodi Web:** `http://your-tailscale-ip:8080`
- **Secure streaming** - Direct access from any Tailscale device

## Build Automation

Project Raven includes sophisticated automation:

### Scheduled Builds
- **Weekly checks** - Every Monday at 6 AM UTC
- **New release detection** - Automatically detects Pi OS updates
- **Version tagging** - Clean versioning based on Pi OS release dates
- **Artifact management** - Automatic release creation with checksums

### Manual Builds
Trigger builds manually via GitHub Actions:

1. Go to [Actions](../../actions) tab
2. Select "Build Raspberry Pi OS with Tailscale & Kodi"
3. Click "Run workflow"
4. Optionally specify version or force rebuild

### Local Testing
Test builds on your own machine:

```bash
# Clone the repository
git clone https://github.com/SysGrimm/Project-Raven.git
cd Project-Raven

# Run local build test (requires Docker on macOS, native tools on Linux)
./scripts/local-build-test.sh

# Check for latest Pi OS version
./scripts/check-version.sh
```

## Setup Guide

### First Boot Process
1. **Initial boot** (30-60 seconds) - System initialization
2. **Package installation** (2-3 minutes) - Kodi and Tailscale setup
3. **Service configuration** (30 seconds) - Auto-login and service enablement
4. **Automatic reboot** - System restarts to activate all services
5. **Kodi starts** - Media center launches automatically

### User Accounts
- **Default user:** `kodi`
- **Password:** None (passwordless sudo enabled)
- **Groups:** `audio`, `video`, `input`, `dialout`, `plugdev`, `tty`, `users`

### Helper Scripts
Located in `/home/kodi/`:
- `setup-tailscale.sh` - Tailscale configuration guide
- `network-info.sh` - Display network and access information

## Troubleshooting

### Common Issues

#### Kodi Won't Start
```bash
# Check Kodi service status
sudo systemctl status kodi

# Restart Kodi service
sudo systemctl restart kodi

# View Kodi logs
sudo journalctl -u kodi -f
```

#### Tailscale Connection Problems
```bash
# Check Tailscale status
sudo tailscale status

# Reset Tailscale
sudo tailscale up --reset

# View Tailscale logs
sudo journalctl -u tailscaled -f
```

#### SSH Access Issues
```bash
# Enable SSH (if disabled)
sudo systemctl enable ssh
sudo systemctl start ssh

# Check SSH status
sudo systemctl status ssh
```

#### Performance Issues
```bash
# Check system resources
htop

# Check temperature
vcgencmd measure_temp

# Check for throttling
vcgencmd get_throttled
```

### Log Files
- **Kodi logs:** `/home/kodi/.kodi/temp/kodi.log`
- **System logs:** `sudo journalctl -f`
- **Kodi service:** `sudo journalctl -u kodi -f`
- **Tailscale:** `sudo journalctl -u tailscaled -f`

## Development

### Project Structure
```
Project-Raven/
├── .github/workflows/           # GitHub Actions automation
│   └── build-pios-tailscale.yml
├── scripts/                     # Build and utility scripts
│   ├── check-version.sh         # Pi OS version checker
│   ├── customize-image.sh       # Image customization
│   └── local-build-test.sh      # Local testing
├── build/                       # Local build output (gitignored)
└── README.md                    # This file
```

### Contributing

1. **Fork** this repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Test** your changes with `./scripts/local-build-test.sh`
4. **Commit** your changes (`git commit -m 'Add amazing feature'`)
5. **Push** to the branch (`git push origin feature/amazing-feature`)
6. **Open** a Pull Request

### Testing Changes

#### Local Testing
```bash
# Test build process
./scripts/local-build-test.sh

# Test version checking
./scripts/check-version.sh --json

# Clean build
./scripts/local-build-test.sh --clean
```

#### GitHub Actions Testing
- Create a pull request to test the full automation
- Use workflow dispatch to test specific scenarios
- Check action logs for detailed build information

## Advanced Configuration

### Build Customization
Modify `scripts/customize-image.sh` to:
- Add additional software packages
- Change system configurations
- Customize Kodi settings
- Add startup scripts

### Workflow Customization
Edit `.github/workflows/build-pios-tailscale.yml` to:
- Change build schedule
- Modify build parameters
- Add additional testing
- Change release format

## Security Considerations

### Default Configuration
- **SSH enabled** with key-based authentication recommended
- **No default passwords** - passwordless sudo for kodi user
- **Tailscale integration** - Secure by default when configured
- **Automatic updates** - Pi OS security updates included

### Recommendations
1. **Change default user** - Consider creating a custom user account
2. **Configure SSH keys** - Disable password authentication
3. **Set up Tailscale** - Enable secure remote access
4. **Regular updates** - Keep system packages current

## License

This project is open source and includes:
- **Raspberry Pi OS** - [Raspberry Pi Foundation License](https://www.raspberrypi.org/about/)
- **Kodi** - [GPL v2](https://github.com/xbmc/xbmc/blob/master/LICENSE.md)
- **Tailscale** - [BSD 3-Clause](https://github.com/tailscale/tailscale/blob/main/LICENSE)

## Support

- **Documentation:** Check the [Wiki](../../wiki) (coming soon)
- **Bug Reports:** [Issues](../../issues)
- **Questions:** [Discussions](../../discussions)
- **Feature Requests:** [Issues](../../issues) with enhancement label

## Acknowledgments

- [Raspberry Pi Foundation](https://www.raspberrypi.org/) - Amazing ARM hardware
- [Kodi Team](https://kodi.tv/) - Excellent media center software
- [Tailscale](https://tailscale.com/) - Revolutionary mesh VPN
- [GitHub Actions](https://github.com/features/actions) - Powerful CI/CD platform

---

**Built with care for the Raspberry Pi community**

*Ready to flash and boot!*
