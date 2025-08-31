# SoulBox Setup Guide 🎯

Quick guide to get Tailscale and Kodi running on your SoulBox Pi 5.

## Step 1: Complete Boot Process

**On your Pi 5 (in the initramfs shell):**
```bash
exit
```

Wait for the system to complete booting. You should see the SoulBox ASCII logo and login prompt.

## Step 2: Login

**Default credentials:**
- Username: `soulbox`
- Password: `soulbox`

(Alternative: `pi:soulbox` or `root:soulbox`)

## Step 3: Check First-Boot Status

```bash
# Check if first-boot setup completed
ls -la /opt/soulbox/setup-complete

# If it exists, setup completed automatically
# If not, run manual setup (see Step 4)

# Check setup logs
sudo tail -20 /var/log/soulbox-setup.log
```

## Step 4: Manual Setup (if needed)

If the first-boot setup didn't complete, copy and run the manual setup:

**On your local machine:**
```bash
# Copy manual setup script to Pi
scp manual-setup.sh soulbox@PI_IP_ADDRESS:~/
```

**On the Pi:**
```bash
chmod +x ~/manual-setup.sh
sudo ./manual-setup.sh
```

## Step 5: Configure Tailscale

### Method A: Interactive Setup
```bash
# Start Tailscale authentication
sudo tailscale up --ssh --accept-routes

# Follow the URL provided to authenticate
# This will open a browser link for you to approve
```

### Method B: With Auth Key
```bash
# Get auth key from https://login.tailscale.com/admin/settings/keys
sudo tailscale up --ssh --accept-routes --auth-key=YOUR_AUTH_KEY_HERE

# Check status
tailscale status
```

### Method C: Use Helper Script
```bash
tailscale-setup
# or
ts
```

## Step 6: Start Kodi

### Method A: Service Control
```bash
# Start Kodi service
sudo systemctl start kodi-standalone.service

# Check status
sudo systemctl status kodi-standalone.service

# Enable for boot (if not already)
sudo systemctl enable kodi-standalone.service
```

### Method B: Use Helper Script
```bash
# Start Kodi
kodi-control start
# or
kodi start

# Check status
kodi status

# View logs
kodi logs
```

## Step 7: Verify Everything

```bash
# Check overall system status
soulbox-status
# or
status

# Check specific services
sudo systemctl status kodi-standalone.service tailscaled ssh

# Check network connectivity
ping google.com
tailscale status
```

## Step 8: Reboot (Recommended)

```bash
sudo reboot
```

After reboot, Kodi should auto-start on the main display, and Tailscale should be connected.

---

## 🎮 Using SoulBox

### Accessing Kodi
- **Local**: Kodi should auto-start on the display after boot
- **Via Tailscale**: Access via Tailscale IP on port 8080 (if web interface enabled)
- **SSH**: Connect via `ssh soulbox@TAILSCALE_IP`

### Helper Commands
- `status` - Check system status
- `kodi start/stop/restart` - Control Kodi
- `ts` - Tailscale setup helper
- `logs` - View system logs

### File Locations
- **Media**: `/home/soulbox/Videos/`, `/home/soulbox/Music/`, `/home/soulbox/Pictures/`
- **Config**: `/home/soulbox/.kodi/`
- **Logs**: `/var/log/soulbox-*.log`

---

## 🔧 Troubleshooting

### Kodi Won't Start
```bash
# Check service status
sudo systemctl status kodi-standalone.service

# Check logs
sudo journalctl -u kodi-standalone.service -f

# Restart X server
sudo systemctl restart kodi-standalone.service
```

### Tailscale Issues
```bash
# Restart Tailscale
sudo systemctl restart tailscaled
sudo tailscale up --ssh --accept-routes

# Check logs
sudo journalctl -u tailscaled -f

# Reset Tailscale
sudo tailscale logout
sudo tailscale up --ssh --accept-routes
```

### SSH Access
```bash
# Enable SSH if disabled
sudo systemctl enable ssh
sudo systemctl start ssh

# Check SSH status
sudo systemctl status ssh
```

### Network Issues
```bash
# Check network interfaces
ip addr show

# Check routes
ip route show

# Restart networking
sudo systemctl restart networking
```

---

## 📱 Remote Access

Once Tailscale is configured:

1. **SSH Access**: `ssh soulbox@TAILSCALE_IP`
2. **File Transfer**: `scp file.txt soulbox@TAILSCALE_IP:~/`
3. **Kodi Web Interface**: `http://TAILSCALE_IP:8080` (if enabled)
4. **VNC/Remote Desktop**: Configure if needed

---

## 🎯 Quick Reference

| Command | Purpose |
|---------|---------|
| `status` | System overview |
| `kodi start` | Start Kodi |
| `kodi stop` | Stop Kodi |
| `ts` | Tailscale setup |
| `tailscale status` | Check Tailscale |
| `sudo reboot` | Restart system |
| `logs` | View system logs |

**Default Passwords**: `soulbox` for all users

🎉 **Enjoy your SoulBox media center!**
