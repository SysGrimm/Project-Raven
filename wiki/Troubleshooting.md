# SoulBox Troubleshooting

This page provides comprehensive solutions to common issues encountered during building, deploying, and running SoulBox.

## Build-Time Issues

### Common Build Failures

#### e2ls Parsing Errors
**Symptoms**: Build fails during filesystem extraction with parsing errors
```
Error: Unable to parse e2ls output
Failed to extract directory listing
```

**Cause**: e2ls output format changed between e2fsprogs versions

**Solution**: Fixed in v0.2.1+ with space-separated output parsing
```bash
# Update to latest SoulBox version
git pull origin main
./build-soulbox-containerized.sh --clean
```

**Manual Fix** (for older versions):
```bash
# Edit build script to handle different e2ls formats
sed -i 's/e2ls -l/e2ls -a/g' build-soulbox-containerized.sh
```

#### Download Timeouts
**Symptoms**: Build fails during Pi OS image download
```
curl: (28) Operation timed out
Failed to download Pi OS image
```

**Solutions**:
```bash
# 1. Check network connectivity
ping downloads.raspberrypi.org

# 2. Use different mirror
export SOULBOX_PI_OS_URL="https://mirror.example.com/raspios/"

# 3. Download manually and use local file
wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/...
export SOULBOX_LOCAL_IMAGE="/path/to/downloaded.img.xz"
```

#### Disk Space Issues
**Symptoms**: Build fails with "No space left on device"
```
dd: error writing to 'image.img': No space left on device
Cannot create staging directory
```

**Solutions**:
```bash
# 1. Check available space (need 10GB+)
df -h

# 2. Clean Docker containers and images
docker system prune -a

# 3. Use custom work directory with more space
./build-soulbox-containerized.sh --work-dir "/tmp/soulbox-build"

# 4. Clean previous build artifacts
rm -rf build/ /tmp/soulbox-*
```

#### Missing Tools
**Symptoms**: Build fails with "command not found" errors
```
./build-soulbox-containerized.sh: line 123: populatefs: command not found
e2cp: command not found
```

**Solutions**:
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y e2fsprogs e2fsprogs-extra mtools parted dosfstools

# CentOS/RHEL/Fedora
sudo yum install -y e2fsprogs e2fsprogs-extra mtools parted dosfstools

# Alpine (for containers)
apk add --no-cache e2fsprogs e2fsprogs-extra mtools parted dosfstools

# Check tool availability
which populatefs || which e2cp
which mtools
which parted
```

### Container-Specific Issues

#### Privilege Errors
**Symptoms**: Build fails with permission denied errors
```
mount: permission denied
Cannot access /dev/loop0
```

**Solution**: SoulBox container-friendly design doesn't need privileges
```bash
# Ensure using container-friendly script
./build-soulbox-containerized.sh  # NOT build-image.sh

# Verify no loop device mounting
grep -i "loop\|mount" build-soulbox-containerized.sh || echo "Container-safe!"
```

#### Loop Device Unavailable
**Symptoms**: Traditional build methods fail in containers
```
losetup: cannot find an unused loop device
mount: /dev/loop0 does not exist
```

**Solution**: Use container-friendly build system
```bash
# Switch to container-friendly approach
./build-soulbox-containerized.sh  # Uses populatefs/e2tools, no loop devices

# NOT this (requires privileges):
./scripts/build-image.sh
```

#### Tool Availability in Containers
**Symptoms**: populatefs not available in minimal containers
```
populatefs: command not found
Falling back to e2tools method
```

**Solution**: Install additional packages or use e2tools fallback
```bash
# Install populatefs (preferred)
apt-get install -y e2fsprogs-extra

# Or verify e2tools fallback works
which e2cp e2ls e2mkdir || apt-get install -y e2fsprogs
```

### Advanced Build Issues

#### Extraction Failures
**Symptoms**: Build fails during filesystem extraction with staging issues
```
Failed to extract Pi OS content to staging directory
Staging directory validation failed
```

**Debug Steps**:
```bash
# Enable debug mode and keep temporary files
./build-soulbox-containerized.sh --debug --keep-temp --work-dir "/tmp/debug"

# Examine staging directory
ls -la /tmp/debug/staging/
find /tmp/debug/staging/ -type f | wc -l

# Check Pi OS extraction
ls -la /tmp/debug/pi-os/
file /tmp/debug/pi-os/*.img

# Verify tool functionality
e2ls /tmp/debug/pi-root.ext4 | head -20
```

#### Symlink Problems
**Symptoms**: e2tools build succeeds but runtime symlink errors
```
/lib/systemd/system/dbus.service: Too many levels of symbolic links
Failed to start systemd services
```

**Cause**: e2tools doesn't handle symlinks correctly during population

**Solutions**:
```bash
# 1. Use populatefs method (preferred)
apt-get install -y e2fsprogs-extra

# 2. Enable symlink restoration (automatic in v0.2.1+)
grep "restore-symlinks" /opt/soulbox/scripts/first-boot-setup.sh

# 3. Manual symlink fix (if needed)
find /lib /usr/lib -xtype l -exec rm {} \;  # Remove broken symlinks
systemctl daemon-reload
```

#### Version Detection Issues
**Symptoms**: Build fails with version detection errors
```
Cannot determine next version from Gitea API
Version manager script failed
```

**Solutions**:
```bash
# 1. Specify version manually
./build-soulbox-containerized.sh --version "v1.0.0-manual"

# 2. Use timestamp version
export VERSION="v$(date +%Y%m%d-%H%M%S)"
./build-soulbox-containerized.sh

# 3. Fix Gitea API access
curl -I https://gitea.osiris-adelie.ts.net/api/v1/repos/reaper/soulbox/releases
```

## Runtime Issues

### First Boot Problems

#### Package Installation Hangs
**Symptoms**: First boot setup hangs during package installation
```
Configuring kodi...
(hangs indefinitely)
```

**Solutions**:
```bash
# 1. Check network connectivity
ping 8.8.8.8
ping archive.ubuntu.com

# 2. Monitor setup progress via SSH
ssh pi@<raspberry-pi-ip>
tail -f /var/log/soulbox-setup.log

# 3. Check for interactive package prompts
ps aux | grep apt
sudo fuser /var/lib/dpkg/lock-frontend

# 4. Manual intervention
sudo killall apt apt-get
sudo dpkg --configure -a
sudo apt-get install -f
```

#### Kodi Won't Start
**Symptoms**: System boots but Kodi doesn't start automatically
```
Failed to start kodi-standalone.service
No display available
```

**Debug Steps**:
```bash
# Check service status
systemctl status kodi-standalone.service

# Check display configuration
ls /dev/dri/
vcgencmd display_power
tvservice -s

# Check user and permissions
id soulbox
groups soulbox | grep -E 'audio|video'

# Manual service start
sudo systemctl start kodi-standalone.service
journalctl -u kodi-standalone.service -f
```

**Solutions**:
```bash
# 1. Fix display driver
echo 'dtoverlay=vc4-kms-v3d' | sudo tee -a /boot/config.txt
sudo reboot

# 2. Fix user permissions
sudo usermod -a -G audio,video,plugdev soulbox

# 3. Manual Kodi start
sudo -u soulbox kodi-standalone

# 4. Check HDMI connection
tvservice -p  # Power on HDMI
tvservice -o  # Power off HDMI
```

#### SSH Connection Refused
**Symptoms**: Cannot SSH to SoulBox after deployment
```
ssh: connect to host <ip> port 22: Connection refused
```

**Solutions**:
```bash
# 1. Wait for first boot completion (can take 10+ minutes)
ping <raspberry-pi-ip>

# 2. Check SSH service status (via HDMI)
systemctl status ssh
sudo systemctl start ssh

# 3. Check network configuration
ip addr show
sudo dhclient eth0

# 4. Check firewall
sudo ufw status
sudo ufw allow ssh
```

### Network Problems

#### Ethernet Not Working
**Symptoms**: No network connectivity via Ethernet
```
No IP address assigned
Cannot reach internet
```

**Solutions**:
```bash
# 1. Check cable and switch
ethtool eth0
ip link show eth0

# 2. Check DHCP client
sudo dhclient eth0
systemctl status NetworkManager

# 3. Manual IP configuration
sudo ip addr add 192.168.1.100/24 dev eth0
sudo ip route add default via 192.168.1.1

# 4. Check interface status
ip addr show eth0
cat /etc/systemd/network/eth0.network
```

#### WiFi Connection Issues
**Symptoms**: Cannot connect to WiFi networks
```
WiFi adapter not found
Authentication failed
```

**Solutions**:
```bash
# 1. Check WiFi hardware
lsusb | grep -i wireless
dmesg | grep -i wifi

# 2. Scan for networks
sudo iwlist wlan0 scan | grep ESSID

# 3. Configure WiFi
sudo nmtui  # Network Manager TUI
# or
sudo nmcli device wifi connect "SSID" password "password"

# 4. Check WiFi service
systemctl status wpa_supplicant
systemctl status NetworkManager
```

#### Tailscale Problems
**Symptoms**: Tailscale VPN not working
```
tailscale: not logged in
Cannot connect to coordination server
```

**Solutions**:
```bash
# 1. Check Tailscale status
sudo tailscale status
sudo tailscale up

# 2. Re-authenticate
sudo tailscale login

# 3. Check service
systemctl status tailscaled
sudo systemctl restart tailscaled

# 4. Check firewall
sudo ufw allow 41641/udp  # Tailscale port
```

### Hardware Issues

#### Video Playback Problems
**Symptoms**: Video playback is choppy or fails
```
Kodi: Failed to initialize video codec
No hardware acceleration available
```

**Solutions**:
```bash
# 1. Check GPU configuration
vcgencmd get_mem gpu
ls /dev/dri/

# 2. Verify vc4 driver
lsmod | grep vc4
dmesg | grep vc4

# 3. Check config.txt
grep -E 'gpu|dtoverlay' /boot/config.txt

# 4. Update GPU memory split
echo 'gpu_mem=128' | sudo tee -a /boot/config.txt
sudo reboot
```

#### Audio Problems
**Symptoms**: No audio output from HDMI or analog
```
No audio devices available
Audio device busy
```

**Solutions**:
```bash
# 1. Check audio devices
aplay -l
amixer

# 2. Set audio output
raspi-config  # Advanced Options -> Audio
# or
amixer cset numid=3 2  # Force HDMI audio

# 3. Check ALSA configuration
cat /proc/asound/cards
alsamixer

# 4. Test audio
speaker-test -t wav
```

#### Display Resolution Issues
**Symptoms**: Wrong resolution or no display output
```
Display shows "No signal"
Resolution is incorrect
```

**Solutions**:
```bash
# 1. Check HDMI status
tvservice -s
vcgencmd display_power

# 2. Force HDMI mode
echo 'hdmi_force_hotplug=1' | sudo tee -a /boot/config.txt
echo 'hdmi_drive=2' | sudo tee -a /boot/config.txt

# 3. Set specific resolution
echo 'hdmi_mode=82' | sudo tee -a /boot/config.txt  # 1080p 60Hz
sudo reboot

# 4. Check cable and display
# Try different HDMI cable and port
```

## System Validation Commands

### Service Health Checks
```bash
# Core SoulBox services
systemctl status kodi-standalone.service
systemctl status soulbox-splash.service  
systemctl status tailscaled
systemctl status ssh

# System services
systemctl status NetworkManager
systemctl status systemd-resolved
systemctl status systemd-timesyncd
```

### Hardware Validation
```bash
# GPU and display
vcgencmd version
ls /dev/dri/
tvservice -s
vcgencmd display_power

# Audio
aplay -l
amixer | head -10

# Network
ip addr show
ping -c 3 8.8.8.8
```

### User and Permissions
```bash
# User accounts
id soulbox
id pi
groups soulbox

# Media directories
ls -la /home/soulbox/
ls -la /opt/soulbox/

# Log files
ls -la /var/log/soulbox*
tail /var/log/soulbox-setup.log
```

### System Information
```bash
# SoulBox version
cat /etc/soulbox-version 2>/dev/null || echo "Version file not found"

# System info
uname -a
cat /etc/os-release
vcgencmd bootloader_version

# Storage
df -h
lsblk
mount | grep -E 'boot|root'
```

## Performance Debugging

### Memory Issues
**Symptoms**: System runs slowly or out of memory
```bash
# Check memory usage
free -h
ps aux --sort=-%mem | head -10

# Check for memory leaks
sudo journalctl | grep -i "out of memory"
sudo dmesg | grep -i "killed process"

# Solutions
sudo systemctl restart kodi-standalone.service
echo 'gpu_mem=64' | sudo tee -a /boot/config.txt  # Reduce GPU memory if needed
```

### Storage Performance
**Symptoms**: Slow boot times or laggy interface
```bash
# Check SD card health
sudo badblocks -v /dev/mmcblk0
sudo fsck -f /dev/mmcblk0p2

# Check I/O performance
sudo iotop
iostat 1 5

# Solutions
# Use faster SD card (Class 10, A1/A2)
# Consider NVMe storage on Pi 5
```

### Network Performance
**Symptoms**: Slow media streaming or network access
```bash
# Test network speed
speedtest-cli  # Install with: pip3 install speedtest-cli
iperf3 -c <server>

# Check network interface stats
cat /proc/net/dev
ethtool eth0

# Monitor network usage
sudo nethogs
sudo iftop
```

## Logs and Debugging

### Important Log Locations
```bash
# SoulBox specific logs
/var/log/soulbox-setup.log      # First boot setup
/opt/soulbox/logs/              # Runtime logs
/var/log/soulbox/               # System logs

# System logs
/var/log/syslog                 # General system log
journalctl -u kodi-standalone   # Kodi service log
journalctl -u ssh               # SSH service log
journalctl -boot                # Current boot log
```

### Debug Mode Commands
```bash
# Enable debug logging
echo 'debug=1' | sudo tee -a /boot/cmdline.txt

# Kodi debug mode
sudo -u soulbox kodi-standalone --debug

# Verbose boot
sudo systemctl set-default multi-user.target  # Disable auto-login
# Edit /boot/cmdline.txt, remove 'quiet'
```

### Log Analysis
```bash
# Search for errors
sudo journalctl --priority=err
grep -i error /var/log/syslog

# Check service failures
systemctl list-units --failed
systemctl status <failed-service>

# Monitor real-time logs
sudo journalctl -f
tail -f /var/log/soulbox-setup.log
```

---

## Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide** for your specific issue
2. **Review logs** for error messages and details
3. **Try basic solutions** like rebooting or restarting services
4. **Note your environment**: SoulBox version, Pi model, SD card, network setup

### Reporting Issues

When reporting issues, please include:

**System Information**:
```bash
# Run these commands and include output
uname -a
cat /etc/os-release
vcgencmd version
cat /etc/soulbox-version 2>/dev/null || echo "Unknown version"
```

**Error Details**:
- Complete error messages
- Relevant log file sections
- Steps to reproduce the issue
- Expected vs actual behavior

**Environment**:
- Raspberry Pi model
- SD card brand/size/speed
- Network configuration
- Connected peripherals

### Community Support

- **Gitea Issues**: [Report bugs and feature requests](https://gitea.osiris-adelie.ts.net/reaper/soulbox/issues)
- **Wiki**: Check other wiki pages for detailed information
- **Logs**: Always include relevant log files with issue reports

---

*Most SoulBox issues can be resolved with the solutions in this guide. When in doubt, start with a clean build and fresh SD card! 🔥*

**← Back to [[Development]] | [[Home]] →**
