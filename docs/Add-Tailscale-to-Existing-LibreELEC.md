# Adding Project Raven's Tailscale to Existing LibreELEC

This guide shows you how to add the Tailscale VPN integration from Project Raven to your existing LibreELEC installation.

## 🚀 Quick Install Methods

### Method 1: Manual Add-on Installation (Recommended)

1. **Download the Tailscale Add-on**
   ```bash
   # SSH into your LibreELEC box
   ssh root@YOUR_LIBREELEC_IP
   
   # Download the add-on
   cd /storage/downloads
   wget https://github.com/SysGrimm/Project-Raven/archive/refs/heads/main.zip
   unzip main.zip
   ```

2. **Install via Kodi Interface**
   - Open Kodi → Settings → Add-ons
   - Click "Install from zip file" 
   - Navigate to `/storage/downloads/Project-Raven-main/libreelec-tailscale-addon`
   - Select the folder and install

3. **Configure Tailscale**
   - Go to Add-ons → Services → Tailscale VPN
   - Enable the service
   - Follow the authentication prompts

### Method 2: Direct Copy Installation

```bash
# SSH into LibreELEC
ssh root@YOUR_LIBREELEC_IP

# Create addon directory
mkdir -p /storage/.kodi/addons/service.tailscale

# Download and extract
cd /tmp
wget https://github.com/SysGrimm/Project-Raven/archive/refs/heads/main.zip
unzip main.zip

# Copy addon files
cp -r Project-Raven-main/libreelec-tailscale-addon/source/* /storage/.kodi/addons/service.tailscale/

# Download appropriate Tailscale binary for your architecture
# For Raspberry Pi 4/5 (64-bit):
mkdir -p /storage/.kodi/addons/service.tailscale/bin
cd /storage/.kodi/addons/service.tailscale/bin
wget https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_arm64.tgz
tar -xzf tailscale_1.82.1_linux_arm64.tgz --strip-components=1
rm tailscale_1.82.1_linux_arm64.tgz

# For Raspberry Pi 2/3 (32-bit):
# wget https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_arm.tgz
# tar -xzf tailscale_1.82.1_linux_arm.tgz --strip-components=1

# For x86_64 systems:
# wget https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_amd64.tgz
# tar -xzf tailscale_1.82.1_linux_amd64.tgz --strip-components=1

# Make binaries executable
chmod +x tailscale tailscaled

# Restart Kodi to detect the new addon
systemctl restart kodi
```

### Method 3: Git Clone (For Developers)

```bash
# SSH into LibreELEC
ssh root@YOUR_LIBREELEC_IP

# Install git if not available (may need to add packages)
# or download via wget as shown above

# Clone the repository
cd /storage
git clone https://github.com/SysGrimm/Project-Raven.git

# Create symlink to addon
ln -s /storage/Project-Raven/libreelec-tailscale-addon/source /storage/.kodi/addons/service.tailscale

# Download binaries (same as Method 2)
mkdir -p /storage/.kodi/addons/service.tailscale/bin
# ... follow binary download steps from Method 2 ...

# Restart Kodi
systemctl restart kodi
```

## 🔧 Configuration Files

### Add-on Settings (Optional Customization)

Create `/storage/.kodi/userdata/addon_data/service.tailscale/settings.xml`:

```xml
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<settings version="2">
    <setting id="auto_login" value="true" />
    <setting id="hostname" value="LibreELEC-Custom" />
    <setting id="accept_routes" value="true" />
    <setting id="accept_dns" value="true" />
    <setting id="daemon_port" value="41641" />
    <setting id="enable_ssh_over_tailscale" value="true" />
</settings>
```

### Startup Script (Optional - Auto-enable)

Create `/storage/.config/autostart.sh` to automatically start Tailscale:

```bash
#!/bin/bash
# Auto-enable Tailscale addon on boot

# Wait for Kodi to start
sleep 30

# Enable Tailscale addon
kodi-send --action="RunScript(service.tailscale)"
```

Make it executable:
```bash
chmod +x /storage/.config/autostart.sh
```

## 🎯 Platform-Specific Binary Downloads

### Detect Your Architecture
```bash
# Check your LibreELEC architecture
uname -m
# armv7l = 32-bit ARM (Pi 2/3)
# aarch64 = 64-bit ARM (Pi 4/5 with 64-bit OS)
# x86_64 = Intel/AMD 64-bit
```

### Download Correct Binaries

**Raspberry Pi 4/5 (64-bit):**
```bash
wget https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_arm64.tgz
```

**Raspberry Pi 2/3 (32-bit):**
```bash
wget https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_arm.tgz
```

**Generic x86_64:**
```bash
wget https://pkgs.tailscale.com/stable/tailscale_1.82.1_linux_amd64.tgz
```

## 🚀 First Time Setup

1. **Enable the Add-on**
   - Kodi → Settings → Add-ons → My add-ons → Services
   - Find "Tailscale VPN" and enable it

2. **Initial Authentication**
   - The add-on will show a notification with an authentication URL
   - Visit the URL on another device to authenticate
   - Or check Kodi logs for the auth URL: Settings → System → Logging

3. **Verify Connection**
   - Check Tailscale status in the add-on settings
   - Your LibreELEC device should appear in your Tailscale admin panel
   - Test connectivity from another Tailscale device

## 🔧 Integration Features

### What You Get

- ✅ **Automatic Startup**: Tailscale starts with LibreELEC
- ✅ **Web Interface Access**: Access Kodi web interface via Tailscale IP
- ✅ **SSH Access**: SSH to your LibreELEC via Tailscale IP  
- ✅ **File Sharing**: Access Samba shares over Tailscale
- ✅ **Remote Streaming**: Stream media securely from anywhere
- ✅ **No Port Forwarding**: No router configuration needed

### Access Methods After Setup

```bash
# SSH via Tailscale (no local network needed)
ssh root@100.x.x.x

# Web interface via Tailscale
http://100.x.x.x:8080

# Samba shares via Tailscale
smb://100.x.x.x
```

## 🔍 Troubleshooting

### Check Service Status
```bash
# Check if Tailscale processes are running
ps aux | grep tailscale

# Check Kodi logs
tail -f /storage/.kodi/temp/kodi.log | grep -i tailscale

# Check addon files
ls -la /storage/.kodi/addons/service.tailscale/
```

### Common Issues

1. **Binary Architecture Mismatch**
   - Ensure you downloaded the correct binary for your platform
   - Check with `uname -m`

2. **Permissions**
   - Ensure binaries are executable: `chmod +x tailscale tailscaled`
   - Check addon directory permissions

3. **Authentication Failed**
   - Check internet connectivity
   - Look for auth URL in Kodi notifications or logs
   - Ensure Tailscale account is set up

### Reset Tailscale
```bash
# Stop the service
systemctl stop kodi

# Remove state
rm -rf /storage/.kodi/userdata/addon_data/service.tailscale/

# Restart Kodi
systemctl start kodi
```

## 🎨 Customization Options

### Custom Hostname
Edit the addon settings to change your device name in Tailscale.

### Route Configuration
- Accept routes: Allow access to other networks via Tailscale
- Advertise routes: Share your local network with other Tailscale devices

### DNS Settings
- Use Tailscale DNS: Routes DNS queries through Tailscale
- Custom nameservers: Set specific DNS servers

## 🔄 Updates

### Update Tailscale Binary
```bash
# Download new version
cd /storage/.kodi/addons/service.tailscale/bin
wget https://pkgs.tailscale.com/stable/tailscale_NEWVERSION_linux_arm64.tgz
tar -xzf tailscale_NEWVERSION_linux_arm64.tgz --strip-components=1
chmod +x tailscale tailscaled
systemctl restart kodi
```

### Update Add-on Code
```bash
# Re-download the latest addon
cd /tmp
wget https://github.com/SysGrimm/Project-Raven/archive/refs/heads/main.zip
unzip main.zip
cp -r Project-Raven-main/libreelec-tailscale-addon/source/* /storage/.kodi/addons/service.tailscale/
systemctl restart kodi
```

## 🎁 Bonus: Other Project Raven Features

While you're at it, you can also grab other Project Raven optimizations:

### Boot Optimizations
Copy our config.txt optimizations:
```bash
# Backup current config
cp /flash/config.txt /flash/config.txt.backup

# Apply Raven optimizations
wget -O /tmp/raven-config.txt https://raw.githubusercontent.com/SysGrimm/Project-Raven/main/libreelec-custom-build/customizations/config.txt
cat /tmp/raven-config.txt >> /flash/config.txt
```

### Kodi Settings
Apply our optimized Kodi configuration:
```bash
wget -O /storage/.kodi/userdata/guisettings.xml https://raw.githubusercontent.com/SysGrimm/Project-Raven/main/libreelec-custom-build/customizations/settings/guisettings.xml
```

---

That's it! Your existing LibreELEC installation now has the same Tailscale integration as Project Raven. The add-on will automatically handle connection, authentication, and provide secure remote access to your media center.
