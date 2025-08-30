# SoulBox Deployment Guide

## Prerequisites

### For macOS (your current system)
```bash
# Install required tools
brew install qemu
# For full image building, you'd need a Linux system with:
# - debootstrap
# - qemu-user-static  
# - parted, kpartx, losetup
```

### For Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install debootstrap qemu-user-static parted kpartx
```

## Deployment Method 1: Existing Pi Setup (Quickest)

**Best for**: Testing and quick setup on existing Raspberry Pi OS installation

### Steps:
1. **Flash standard Raspberry Pi OS** to SD card using Raspberry Pi Imager
2. **Boot the Pi** and complete initial setup (enable SSH, etc.)
3. **Clone SoulBox** on the Pi:
   ```bash
   git clone http://192.168.176.113:3000/reaper/soulbox.git
   cd soulbox
   ```
4. **Run setup script**:
   ```bash
   sudo ./scripts/setup-system.sh
   ```
5. **Configure Tailscale** (optional):
   ```bash
   # Generate config with your auth key
   ./scripts/create-tailscale-config.sh --auth-key YOUR-TAILSCALE-KEY
   
   # Copy to boot partition
   sudo cp tailscale-authkey.txt soulbox-config.txt /boot/firmware/
   ```
6. **Reboot**:
   ```bash
   sudo reboot
   ```

## Deployment Method 2: Custom Image Build

**Best for**: Production deployment, multiple devices, or complete customization

### Linux Build System Required

**Option A: Use Linux VM/Container**
```bash
# On macOS, run Ubuntu container
docker run -it --privileged ubuntu:22.04 bash

# Inside container:
apt-get update
apt-get install git debootstrap qemu-user-static parted kpartx
git clone http://192.168.176.113:3000/reaper/soulbox.git
cd soulbox
```

**Option B: Linux System/Server**
```bash
git clone http://192.168.176.113:3000/reaper/soulbox.git
cd soulbox
```

### Build Process
```bash
# Build complete SoulBox image (requires root/sudo)
sudo ./scripts/build-image.sh

# Image will be created in build/ directory
ls -la build/*.img
```

### Flash to SD Card
```bash
# Find SD card device (be VERY careful!)
lsblk  # or diskutil list on macOS

# Flash image to SD card (replace /dev/sdX with your SD card)
sudo dd if=build/soulbox-YYYYMMDD.img of=/dev/sdX bs=4M status=progress

# Or use Raspberry Pi Imager with custom image option
```

## Deployment Method 3: Raspberry Pi Imager + Config Files

**Best for**: Standard Pi OS with SoulBox configuration overlay

### Steps:
1. **Flash Raspberry Pi OS** using official imager
2. **Enable SSH and configure WiFi** in imager advanced options
3. **Generate SoulBox configs**:
   ```bash
   # On your Mac
   git clone http://192.168.176.113:3000/reaper/soulbox.git
   cd soulbox
   
   # Generate Tailscale config
   ./scripts/create-tailscale-config.sh --interactive
   ```
4. **Copy configs to SD card**:
   ```bash
   # Mount SD card and copy to boot partition
   cp tailscale-authkey.txt soulbox-config.txt /Volumes/bootfs/
   ```
5. **Boot Pi and run setup**:
   ```bash
   # SSH into Pi after first boot
   git clone http://192.168.176.113:3000/reaper/soulbox.git
   cd soulbox
   sudo ./scripts/setup-system.sh
   sudo reboot
   ```

## Configuration Management

### Tailscale Configuration Generator

**Interactive Mode:**
```bash
./scripts/create-tailscale-config.sh --interactive
```

**Command Line Mode:**
```bash
./scripts/create-tailscale-config.sh \
  --auth-key tskey-auth-YOUR-KEY \
  --hostname soulbox-living-room \
  --exit-node 100.64.0.1 \
  --routes 192.168.1.0/24
```

**Generated Files:**
- `tailscale-authkey.txt` - Authentication key (deleted after first use)
- `soulbox-config.txt` - System configuration

### SD Card File Structure
```
/boot/firmware/
├── config.txt                 # Pi hardware config (auto-generated)  
├── tailscale-authkey.txt      # Tailscale auth key (optional)
├── soulbox-config.txt         # SoulBox settings (optional)
└── ... (other boot files)
```

## Remote Management

### Deploy Updates to Running System
```bash
# Local deployment
./scripts/deploy-config.sh

# Remote deployment 
./scripts/deploy-config.sh pi@192.168.1.100

# Interactive deployment
./scripts/deploy-config.sh -i soulbox.tailnet.ts.net
```

## Troubleshooting

### Build Issues
- **Permission Denied**: Ensure running as root/sudo for image building
- **Missing Dependencies**: Install all required packages listed above
- **Disk Space**: Ensure 8GB+ free space for image building

### Boot Issues
- **No GPU**: Check `/dev/dri/card0` exists after boot
- **Kodi Won't Start**: Check `journalctl -u kodi-standalone.service`
- **Tailscale Setup Failed**: Check `journalctl -u soulbox-tailscale-firstboot.service`

### Network Access
- **Local Network**: Find Pi IP with `nmap -sn 192.168.1.0/24`
- **Tailscale Network**: Check `tailscale status` on Pi
- **SSH Access**: Default user is `reaper` with key-based auth only

## Recommended Workflow

1. **Development/Testing**: Use Method 1 (existing Pi setup)
2. **Production Deployment**: Use Method 2 (custom image)
3. **Multiple Devices**: Build once, flash multiple SD cards
4. **Remote Management**: Use deployment scripts for updates

## Security Considerations

- SSH is key-based authentication only (no passwords)
- Tailscale auth keys are automatically cleaned up
- Firewall (UFW) is enabled and configured
- Services run as dedicated users (not root)
- Regular security updates should be applied

## Next Steps After Deployment

1. **Verify Services**: Check Kodi and Tailscale status
2. **Configure Kodi**: Set up media sources and settings
3. **Test Remote Access**: Connect via Tailscale from another device
4. **Enable Web Interface**: Configure Kodi web interface if needed
5. **Set Up Backups**: Regular system and configuration backups
