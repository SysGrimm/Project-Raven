# SoulBox Deployment Guide

This guide covers everything you need to know about deploying SoulBox images, from downloading pre-built releases to flashing SD cards and configuring your media center.

## Quick Deployment

### Option 1: Pre-built Images (Recommended)

The fastest way to get SoulBox running is using our pre-built images:

1. **📥 [Download Latest Release](https://192.168.176.113:3000/yourusername/soulbox/releases/latest)**
2. **Flash to SD Card** using balenaEtcher or Raspberry Pi Imager
3. **Insert & Boot** on your Raspberry Pi 5
4. **Wait for Setup** - First boot takes ~10 minutes for package installation
5. **Enjoy Kodi** - System will auto-reboot into Kodi media center

### Option 2: Build from Source

For developers or custom builds:

```bash
# Clone repository
git clone https://192.168.176.113:3000/yourusername/soulbox.git
cd soulbox

# Run the container-friendly build
chmod +x build-soulbox-containerized.sh
./build-soulbox-containerized.sh --version "v1.0.0" --clean

# Output: build/soulbox-v1.0.0.img ready to flash
```

## Detailed Deployment Steps

### Step 1: Download Images

#### From Gitea Releases
- Navigate to the [Releases page](https://192.168.176.113:3000/yourusername/soulbox/releases)
- Download the latest `.img` file or compressed `.tar.gz`
- Verify integrity using provided SHA256 checksums

#### Build Artifacts
Recent release artifacts include:
```
soulbox-v0.2.1.img               # Complete bootable image (1.1GB)
soulbox-v0.2.1.img.sha256        # Integrity checksum
soulbox-v0.2.1.img.tar.gz        # Compressed archive (56MB)
soulbox-v0.2.1.img.tar.gz.sha256 # Compressed checksum
version.txt                      # Version information
```

### Step 2: Prepare SD Card

#### Requirements
- **Capacity**: 8GB minimum, 16GB+ recommended
- **Class**: Class 10 or better for optimal performance
- **Compatibility**: Standard SD, SDHC, or SDXC

#### Recommended Flashing Tools

**balenaEtcher (Cross-platform)**
1. Download from [balena.io/etcher](https://www.balena.io/etcher/)
2. Select SoulBox `.img` file
3. Select target SD card
4. Click "Flash" and wait for completion

**Raspberry Pi Imager**
1. Download from [rpi.org/imager](https://rpi.org/imager)
2. Choose "Use custom image" 
3. Select SoulBox `.img` file
4. Select SD card and write

**Command Line (Linux/macOS)**
```bash
# Find SD card device
lsblk  # or diskutil list on macOS

# Write image (replace /dev/sdX with your SD card)
sudo dd if=soulbox-v0.2.1.img of=/dev/sdX bs=4M status=progress
sudo sync
```

### Step 3: First Boot Setup

#### What Happens During First Boot

The first boot is a **self-configuring process** that takes approximately 10 minutes:

1. **Boot Phase** (2-3 minutes)
   - System boots from SD card
   - Basic hardware initialization
   - Network configuration (DHCP)

2. **Package Installation** (5-7 minutes)
   - Updates package lists
   - Installs Kodi media center
   - Installs Tailscale VPN
   - Installs additional utilities

3. **User Configuration** (1-2 minutes)
   - Creates `soulbox` user account
   - Sets default passwords
   - Configures media directories
   - Enables system services

4. **Final Setup** (1 minute)
   - Service configuration
   - Cleanup and optimization
   - **Automatic reboot**

#### First Boot Monitoring

You can monitor the first boot process via:

**HDMI Display**: Watch the setup progress with real-time log output

**SSH Connection** (after network is up):
```bash
# Default credentials during setup
ssh pi@<raspberry-pi-ip>
# Password: soulbox

# Monitor setup log
tail -f /var/log/soulbox-setup.log
```

### Step 4: Initial Configuration

#### Default User Accounts

After first boot completion:

| User | Password | Groups | Purpose |
|------|----------|--------|---------|
| `soulbox` | `soulbox` | sudo,audio,video,plugdev | Primary media center user |
| `pi` | `soulbox` | sudo,audio,video | Traditional Pi user |
| `root` | `soulbox` | root | System administration |

#### Network Configuration

**Ethernet**: Automatic DHCP configuration

**WiFi Setup**:
```bash
# Connect via SSH and configure WiFi
sudo nmtui  # Network Manager TUI
# or
sudo nmcli device wifi connect "YourNetwork" password "YourPassword"
```

#### SSH Access

SSH is enabled by default:
```bash
# Connect to SoulBox
ssh soulbox@<ip-address>
# Password: soulbox

# Find IP address on the device
ip addr show
```

## CI/CD Deployment

### Gitea Actions Integration

Our automated CI/CD pipeline builds and releases images on every commit:

#### Workflow Features
- **Trigger**: Push to main, pull request, or manual dispatch
- **Environment**: Ubuntu-latest runners with 20GB storage  
- **Dependencies**: Auto-installs required tools (e2tools, mtools, parted)
- **Build Process**: Container-friendly build with no privileges required
- **Output**: Complete bootable images with checksums
- **Release**: Automatic release creation with downloadable assets

#### Build Artifacts
Every successful build produces:
- Bootable `.img` file (1.1GB)
- Compressed `.tar.gz` archive (56MB)
- SHA256 checksums for integrity verification
- Version information and build logs

### Local Development Deployment

For development and testing:

```bash
# Build locally
./build-soulbox-containerized.sh --debug --keep-temp

# Test image before deployment
qemu-system-aarch64 \
    -M raspi4b \
    -kernel kernel8.img \
    -dtb bcm2711-rpi-4-b.dtb \
    -drive file=soulbox-test.img,format=raw \
    -netdev user,id=net0 \
    -device usb-net,netdev=net0

# Flash for hardware testing
sudo dd if=build/soulbox-*.img of=/dev/sdX bs=4M status=progress
```

## Hardware Deployment

### Target Hardware

#### Primary Target: Raspberry Pi 5
- **CPU**: Broadcom BCM2712 (Cortex-A76 quad-core)
- **RAM**: 4GB or 8GB LPDDR4X
- **GPU**: VideoCore VII with hardware video decode
- **Storage**: SD card slot, optional NVMe via HAT
- **Connectivity**: Gigabit Ethernet, 802.11ac WiFi, Bluetooth

#### Compatible Hardware: Raspberry Pi 4
- **CPU**: Broadcom BCM2711 (Cortex-A72 quad-core)
- **RAM**: 2GB, 4GB, or 8GB LPDDR4
- **GPU**: VideoCore VI with hardware video decode
- **Storage**: SD card slot, USB 3.0 storage
- **Connectivity**: Gigabit Ethernet, 802.11ac WiFi, Bluetooth

### Hardware Setup

#### Power Requirements
- **Pi 5**: Official 27W USB-C power supply recommended
- **Pi 4**: Official 15W USB-C power supply or compatible 3A supply
- **Avoid**: Generic phone chargers (may cause instability)

#### Display Connection
- **HDMI**: Use micro-HDMI to HDMI cable (Pi 4/5)
- **Resolution**: Supports up to 4K@60Hz on compatible displays
- **Audio**: HDMI audio enabled by default

#### Storage Performance
- **Class 10+**: Minimum recommended SD card speed
- **A1/A2**: Application Performance Class for better random I/O
- **NVMe**: Pi 5 supports NVMe SSDs via official HAT for best performance

## Post-Deployment Configuration

### Kodi Media Center Setup

#### Media Library Configuration

```bash
# Default media directories (auto-created)
/home/soulbox/Videos/     # Video content
/home/soulbox/Music/      # Audio content  
/home/soulbox/Pictures/   # Photo content
/home/soulbox/Downloads/  # Temporary downloads
```

#### Adding Media Sources
1. Start Kodi (auto-starts after boot)
2. Navigate to "Videos" → "Files"
3. Select "Add videos..."
4. Browse to media location or add network sources
5. Configure content type and scraper settings

#### Network Media Sources
```bash
# SMB/CIFS shares
smb://192.168.1.100/media/

# NFS shares  
nfs://192.168.1.100/export/media/

# FTP/SFTP
ftp://192.168.1.100/media/
sftp://192.168.1.100/media/
```

### Tailscale VPN Setup

Tailscale is pre-installed for secure remote access:

```bash
# Authenticate device (one-time setup)
sudo tailscale up

# Check status
tailscale status

# Get Tailscale IP
tailscale ip -4
```

#### Remote Access Benefits
- Secure access to media center from anywhere
- Direct SSH connection via Tailscale network
- No port forwarding or firewall configuration needed
- Encrypted mesh networking

### System Services

#### Service Management
```bash
# Check Kodi service
systemctl status kodi-standalone.service

# Restart Kodi
sudo systemctl restart kodi-standalone.service

# Check SSH service
systemctl status ssh

# Check Tailscale
systemctl status tailscaled
```

#### Service Configuration Files
- Kodi: `/etc/systemd/system/kodi-standalone.service`
- SSH: `/etc/ssh/sshd_config`  
- Tailscale: `/etc/default/tailscaled`

## Advanced Deployment Options

### Custom Image Builds

#### Build Script Options
```bash
# Clean build with specific version
./build-soulbox-containerized.sh --version "v2.0.0" --clean

# Debug build with preserved temporary files
./build-soulbox-containerized.sh --debug --keep-temp

# Custom work directory
./build-soulbox-containerized.sh --work-dir "/tmp/custom-build"

# Custom output location
./build-soulbox-containerized.sh --output-dir "./releases"
```

#### Environment Variables
```bash
# Customize base image
export SOULBOX_PI_OS_URL="https://custom-mirror.com/pi-os/"
export SOULBOX_BASE_IMAGE="custom-bookworm-arm64.img.xz"

# Build parameters
export SOULBOX_IMAGE_SIZE="2048"  # 2GB image
export SOULBOX_BOOT_SIZE="512"   # 512MB boot partition
```

### Container Deployment

#### Docker Build Environment
```bash
# Build in Docker container (any platform)
docker run -it --rm \
    -v "$(pwd):/workspace" \
    -w /workspace \
    ubuntu:22.04 bash

# Install dependencies and build
apt-get update && apt-get install -y \
    e2fsprogs e2fsprogs-extra mtools parted \
    dosfstools curl xz-utils

./build-soulbox-containerized.sh
```

#### Unraid Integration
For Unraid NAS users:

1. **Install Dependencies**:
   ```bash
   # Install Nerd Tools plugin
   # Enable: e2fsprogs, mtools, parted
   ```

2. **Run Build**:
   ```bash
   # Navigate to user scripts
   cd /boot/config/plugins/user.scripts/scripts/
   
   # Create SoulBox build script
   ./build-soulbox-containerized.sh --output-dir "/mnt/user/builds/"
   ```

### Network Deployment

#### Automated Installation via PXE
For deploying to multiple devices:

```bash
# Set up TFTP server with SoulBox kernel
sudo cp soulbox-kernel8.img /tftpboot/
sudo cp soulbox-initrd.img /tftpboot/

# Configure DHCP for PXE boot
# Point to SoulBox installer image
```

#### Remote Flashing
```bash
# Use balenaEtcher CLI for remote flashing
npx etcher-cli soulbox-v0.2.1.img --drive /dev/sdX --yes

# Or via SSH to build machine
ssh build-server "cat soulbox-latest.img" | sudo dd of=/dev/sdX bs=4M
```

## Security Considerations

### Default Security Posture
- **SSH Enabled**: Change default passwords immediately
- **Firewall**: UFW disabled by default (media center use)
- **Users**: Standard sudo access for soulbox user  
- **Updates**: Base image includes latest Pi OS security updates

### Recommended Hardening

#### Change Default Passwords
```bash
# Change all user passwords
sudo passwd soulbox
sudo passwd pi  
sudo passwd root
```

#### Enable Firewall
```bash
# Configure UFW for basic security
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH from local network
sudo ufw allow from 192.168.0.0/16 to any port 22

# Allow Kodi web interface (optional)
sudo ufw allow from 192.168.0.0/16 to any port 8080
```

#### System Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Enable automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

#### SSH Security
```bash
# Disable password authentication (use SSH keys)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart ssh
```

---

## Deployment Troubleshooting

For issues during deployment, see the **[[Troubleshooting]]** page for comprehensive solutions to common problems.

### Quick Fixes

**SD card not detected**: Verify image was flashed completely
**Network not working**: Check Ethernet cable, verify DHCP available
**Kodi won't start**: Ensure Pi 5 hardware and HDMI connection
**SSH refused**: Wait for first boot completion (~10 minutes)

---

*Ready to deploy SoulBox? Flash an image and enjoy your turnkey media center! 🔥*

**← Back to [[Build-System]] | Next: [[Features]] →**
