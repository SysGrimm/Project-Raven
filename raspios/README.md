# Project Raven - Raspberry Pi OS Edition

[LAUNCH] A complete media center and VPN solution built on Raspberry Pi OS with Tailscale integration.

## Overview

This is the **Raspberry Pi OS variant** of Project Raven, offering more flexibility and testability compared to the LibreELEC version. It provides:

- [MEDIA] **Kodi Media Center** - Auto-starting, optimized configuration
- [SECURITY] **Tailscale VPN** - Seamless secure remote access
- [PERFORMANCE] **Performance Optimizations** - Tuned for media streaming
- **Pi-CI Testing** - Local virtualized testing with Docker
- 🤖 **Ansible Automation** - Infrastructure as Code management

## Quick Start

### Option 1: Pre-built Images (Coming Soon)
Download pre-built images from our releases page and flash to SD card.

### Option 2: Build Your Own
```bash
# Clone the repository
git clone https://github.com/SysGrimm/Project-Raven.git
cd Project-Raven/raspios

# Test configurations locally with Pi-CI
./scripts/pi-ci-test.sh setup
./scripts/pi-ci-test.sh test

# Build custom image (Linux only)
sudo ./scripts/build-image.sh rpi5 lite
```

### Option 3: Configure Existing Installation
```bash
# On your Raspberry Pi OS device
git clone https://github.com/SysGrimm/Project-Raven.git
cd Project-Raven/raspios

# Apply configurations with Ansible
cd ansible
ansible-playbook -i inventory.ini site.yml
```

## Supported Devices

| Device | Status | Notes |
|--------|---------|-------|
| Raspberry Pi 5 | [SUCCESS] | Recommended, best performance |
| Raspberry Pi 4 | [SUCCESS] | Excellent performance |
| Raspberry Pi Zero 2 W | [SUCCESS] | Basic media playback |

## Features

### [MEDIA] Media Center
- **Kodi 20+** with optimized settings
- **Hardware acceleration** for 4K content
- **Audio/Video codecs** pre-configured
- **Auto-start** on boot to tty1

### [SECURITY] VPN Integration
- **Tailscale** for secure remote access
- **Subnet routing** enabled
- **Easy setup** with `sudo tailscale up`
- **Status monitoring** built-in

### [PERFORMANCE] System Optimizations
- **GPU memory** allocated (128MB)
- **I/O scheduler** optimized for media
- **File limits** increased for streaming
- **Swap disabled** for better performance

### Testing with Pi-CI
- **Local testing** without real hardware
- **Docker-based** Raspberry Pi emulation
- **Automated testing** of configurations
- **CI/CD integration** ready

## Directory Structure

```
raspios/
├── configurations/          # System configuration files
│   ├── config.txt          # Raspberry Pi boot config
│   ├── cmdline.txt         # Kernel command line
│   └── firstboot.sh        # First boot setup script
├── ansible/                # Infrastructure automation
│   ├── site.yml            # Main playbook
│   ├── inventory.ini       # Device inventory
│   └── ansible.cfg         # Ansible configuration
├── scripts/                # Build and test scripts
│   ├── build-image.sh      # Image builder
│   └── pi-ci-test.sh       # Pi-CI testing
└── README.md              # This file
```

## Testing

### Local Testing with Pi-CI

Pi-CI allows you to test Raspberry Pi configurations locally using Docker:

```bash
# First-time setup
./scripts/pi-ci-test.sh setup

# Run all tests
./scripts/pi-ci-test.sh test

# Test only Ansible configurations
./scripts/pi-ci-test.sh ansible
```

### Manual Testing

```bash
# Test Ansible syntax
cd ansible
ansible-playbook --syntax-check site.yml

# Test on real device
ansible-playbook -i inventory.ini site.yml --check
```

## Building Images

### Prerequisites (Linux Only)
- Root access (for image mounting)
- Tools: `wget`, `xz`, `parted`, `losetup`

### Build Commands
```bash
# Build for specific device
sudo ./scripts/build-image.sh rpi5 lite

# Build for all devices
sudo ./scripts/build-image.sh all lite

# Clean build files
sudo ./scripts/build-image.sh clean
```

### Build Output
Built images are saved to `../images/` with:
- Compressed `.img.xz` files
- SHA256 checksums
- Timestamp in filename

## Configuration

### Device Inventory
Edit `ansible/inventory.ini` to add your devices:

```ini
[raven_devices]
raven-pi-001 ansible_host=192.168.1.100 ansible_user=pi
```

### Custom Settings
Modify `ansible/site.yml` to customize:
- GPU memory allocation
- Package installations
- Service configurations

### Boot Configuration
Edit `configurations/config.txt` for hardware settings:
- Overclocking
- Hardware interfaces
- Audio/video options

## First Boot Process

1. **Automatic setup** runs via `firstboot.sh`
2. **System updates** and package installation
3. **Kodi installation** with user creation
4. **Tailscale setup** (requires manual connection)
5. **Optimizations** applied
6. **Automatic reboot** to complete setup

## Usage

### Connecting to Tailscale
```bash
# On the Raspberry Pi
sudo tailscale up

# Follow the authentication URL
# Device will appear in your Tailscale network
```

### Managing Kodi
```bash
# Check Kodi status
systemctl status kodi

# Restart Kodi
sudo systemctl restart kodi

# View Kodi logs
journalctl -u kodi -f
```

### System Monitoring
```bash
# Check system status
htop

# View system logs
journalctl -f

# Check disk usage
df -h
```

## Troubleshooting

### Common Issues

**Kodi won't start:**
```bash
# Check service status
systemctl status kodi

# Check user permissions
groups kodi

# Restart service
sudo systemctl restart kodi
```

**Tailscale connection fails:**
```bash
# Check service status
sudo systemctl status tailscaled

# View logs
sudo journalctl -u tailscaled

# Reset connection
sudo tailscale logout
sudo tailscale up
```

**Performance issues:**
```bash
# Check GPU memory
vcgencmd get_mem gpu

# Check temperature
vcgencmd measure_temp

# Check config
cat /boot/config.txt
```

### Getting Help

- 📚 [Project Wiki](https://github.com/SysGrimm/Project-Raven/wiki)
- 🐛 [Issue Tracker](https://github.com/SysGrimm/Project-Raven/issues)
- [CHAT] [Discussions](https://github.com/SysGrimm/Project-Raven/discussions)

## Migration from LibreELEC

See [MIGRATION-PLAN.md](../MIGRATION-PLAN.md) for detailed migration instructions.

Key differences:
- Full Debian base instead of read-only system
- Systemd services instead of LibreELEC add-ons
- APT package management
- Standard Linux file system layout

## Contributing

1. Fork the repository
2. Create feature branch
3. Test with Pi-CI: `./scripts/pi-ci-test.sh test`
4. Submit pull request

### Development Workflow

```bash
# Test changes locally
./scripts/pi-ci-test.sh test

# Build test image
sudo ./scripts/build-image.sh rpi5 lite

# Test on real hardware
ansible-playbook -i inventory.ini site.yml
```

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Acknowledgments

- [Pi-CI](https://github.com/ptrsr/pi-ci/) - Raspberry Pi CI/CD testing
- [Raspberry Pi Foundation](https://www.raspberrypi.org/) - Base OS
- [Tailscale](https://tailscale.com/) - Zero-config VPN
- [Kodi](https://kodi.tv/) - Media center software
