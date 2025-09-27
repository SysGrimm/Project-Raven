# Quick Start Guide

Get up and running with Project-Raven in under 30 minutes! This guide covers the fastest path from zero to a working custom LibreELEC media center with VPN capabilities.

## What You'll Get

- **LibreELEC** media center with working CEC remote control
- **Tailscale VPN** for secure remote access
- **Custom theme** and pre-installed add-ons
- **Turnkey solution** ready to deploy

## 5-Minute Quick Start

### Prerequisites Check
```bash
# Verify you have the essentials
git --version          # Git for source control
docker --version       # Docker for containerized builds (optional)
curl --version         # For downloading components
```

### Get Project-Raven
```bash
# Clone the repository
git clone https://github.com/SysGrimm/Project-Raven.git
cd Project-Raven

# Quick environment check
ls -la libreelec-custom-build/
```

### Choose Your Path

#### Path A: Pre-built Image (Fastest) 
```bash
# Download pre-built image (when available)
curl -L -o libreelec-raven.img.gz \
  "https://github.com/SysGrimm/Project-Raven/releases/latest/download/LibreELEC-RPi4-raven.img.gz"

# Flash to SD card
gunzip libreelec-raven.img.gz
# Use Raspberry Pi Imager or dd to flash
```

#### Path B: Custom Build (30 minutes)
```bash
# Run automated build
cd libreelec-custom-build
./scripts/build-image.sh

# Wait for build completion
# Output: LibreELEC-RPi.RPi4-raven-YYYYMMDD.img
```

## Hardware Setup

### Supported Devices
| Device | Status | Notes |
|--------|--------|-------|
| Raspberry Pi 4 |  Fully Supported | Recommended |
| Raspberry Pi 5 |  Fully Supported | Best Performance |
| Raspberry Pi 3 |  Limited | Basic functionality |
| Generic x86_64 |  Supported | PC/NUC builds |

### Required Hardware
- **Raspberry Pi 4/5** (4GB+ RAM recommended)
- **MicroSD Card** (32GB+ Class 10)
- **HDMI Cable** (for CEC remote functionality)
- **Network Connection** (Ethernet or WiFi)
- **TV with CEC Support** (for remote control)

### Optional Hardware
- **USB Storage** (for media library)
- **IR Receiver** (if TV doesn't support CEC)
- **USB Keyboard** (for initial setup)

## [MEDIA] Installation Steps

### Step 1: Flash the Image
```bash
# Using Raspberry Pi Imager (Recommended)
# 1. Download and install RPi Imager
# 2. Select "Use custom image"
# 3. Choose your Project-Raven image
# 4. Select SD card and flash

# Using dd (Advanced)
sudo dd if=LibreELEC-RPi.RPi4-raven.img of=/dev/sdX bs=4M status=progress
sync
```

### Step 2: First Boot
1. **Insert SD card** into Raspberry Pi
2. **Connect HDMI** to CEC-capable TV
3. **Connect network** (Ethernet recommended for first boot)
4. **Power on** and wait for LibreELEC to boot

### Step 3: Initial Setup
```bash
# LibreELEC will start automatically
# Follow on-screen setup wizard:
# 1. Select language and region
# 2. Configure network (if using WiFi)
# 3. Enable SSH (for remote management)
# 4. Set SSH password
```

## Tailscale VPN Setup

### Automatic Configuration
1. Navigate to **Settings** → **Add-ons** → **My Add-ons** → **Services**
2. Find **Tailscale VPN** and click **Configure**
3. Enable **Auto-login on startup**
4. Click **OK** to save settings

### Authentication
```bash
# Tailscale will show authentication notification
# 1. Note the authentication URL displayed
# 2. Visit URL on another device
# 3. Approve the LibreELEC device
# 4. VPN connection establishes automatically
```

### Verify Connection
```bash
# SSH into LibreELEC (use Tailscale IP)
ssh root@100.x.x.x  # Your Tailscale IP

# Check Tailscale status
tailscale status
```

## CEC Remote Setup

### Automatic CEC (Most TVs)
CEC should work immediately with most modern TVs:
- **Power on/off**: TV remote controls LibreELEC
- **Navigation**: Use TV remote arrow keys
- **Media control**: Play/pause with TV remote

### Verify CEC Function
1. Use TV remote to navigate Kodi interface
2. Test play/pause with media files
3. Try power off from TV remote

### Troubleshooting CEC
```bash
# SSH into LibreELEC
ssh root@libreelec-ip

# Check CEC status
echo "scan" | cec-client -s -d 1

# View CEC devices
cec-client -l
```

## [MOBILE] Remote Access

### Access Methods
Once Tailscale is connected:

| Service | URL/Method | Port |
|---------|------------|------|
| Kodi Web Interface | `http://tailscale-ip:8080` | 8080 |
| SSH Access | `ssh root@tailscale-ip` | 22 |
| File Sharing | `smb://tailscale-ip` | 445 |

### Mobile Apps
- **Kore** (Android/iOS): Official Kodi remote
- **Sybu** (Android): Advanced Kodi remote  
- **Tailscale** (Mobile): VPN status and control

## Customization Quick Wins

### Change Theme
1. **Settings** → **Interface** → **Skin**
2. Select **Estuary Raven** (pre-installed)
3. Explore theme color options

### Add Content Sources
```bash
# Add network shares
# Settings → Media → Library → Videos → Add videos...
# Enter paths like:
smb://192.168.1.100/Movies
nfs://192.168.1.100/media
```

### Install Add-ons
1. **Settings** → **Add-ons** → **Install from repository**
2. Browse available add-ons
3. Popular choices: YouTube, Emby, Plex

## Health Check

### Verify Everything Works
```bash
# Check system status
systemctl status kodi

# Verify Tailscale
tailscale status

# Test CEC
echo "pow 0" | cec-client -s -d 1

# Check available storage
df -h /storage
```

### Performance Check
- **Video Playback**: Test 4K content if applicable
- **Network Speed**: Test streaming from network sources
- **Remote Response**: Verify CEC remote responsiveness

## 🆘 Quick Troubleshooting

### Common Issues & Solutions

#### CEC Not Working
```bash
# Check CEC adapter
ls -la /dev/cec*

# Restart CEC service
systemctl restart cec-adapter@1
```

#### Tailscale Connection Issues
```bash
# Reset Tailscale authentication
systemctl stop tailscaled
rm -f /storage/.config/tailscale/tailscaled.state
systemctl start tailscaled
```

#### Network Connection Problems
```bash
# Check network status
connmanctl services

# Reset network configuration
connmanctl config reset
```

#### Performance Issues
```bash
# Check system load
top

# Monitor temperatures
vcgencmd measure_temp

# Check memory usage
free -h
```

## 📚 Next Steps

### Essential Reading
- **[[CEC-Troubleshooting]]** - Deep dive into remote control issues
- **[[Tailscale-Add-on]]** - Advanced VPN configuration
- **[[Custom-LibreELEC-Build]]** - Modify and rebuild images

### Advanced Topics
- **[[Theme-Customization]]** - Create custom themes
- **[[Add-on-Development]]** - Build additional add-ons
- **[[Performance-Optimization]]** - Tune for your hardware

### Community Resources
- **LibreELEC Forum**: https://forum.libreelec.tv
- **Kodi Community**: https://forum.kodi.tv
- **Tailscale Docs**: https://tailscale.com/kb

## Success Criteria

You've successfully completed the quick start when:

- [ ] LibreELEC boots and displays Kodi interface
- [ ] TV remote controls Kodi navigation (CEC working)
- [ ] Tailscale VPN shows connected status
- [ ] Can access Kodi web interface via Tailscale IP
- [ ] Media playback works smoothly
- [ ] Custom Project-Raven theme is active

**Total Time**: ~30 minutes (plus build time if building from source)

---

**[COMPLETE] Congratulations!** You now have a fully functional, remotely accessible media center with secure VPN connectivity. Explore the wiki for advanced customization options!
