# Tailscale VPN Integration for LibreELEC

This integration provides secure remote access to your LibreELEC device using Tailscale VPN, based on the approach from [Dave King's blog post](https://www.davbo.uk/posts/connecting-home/).

## What is Tailscale?

Tailscale creates a secure mesh VPN network using WireGuard. Your LibreELEC device becomes accessible from anywhere without port forwarding or complex networking setup.

## Features

- ✅ **Automatic Installation** - Installs during first boot
- ✅ **Systemd Integration** - Proper service management
- ✅ **Architecture Detection** - Works on RPi4, RPi5, and x86
- ✅ **Easy Management** - Simple commands for status and control
- ✅ **Secure by Default** - No port forwarding required

## Quick Setup

### Option 1: Automated (Recommended)

1. **Get an auth key**: Visit https://login.tailscale.com/admin/settings/keys
2. **Configure**: Copy `tailscale.conf.template` to `tailscale.conf` on SD card boot partition
3. **Add your key**: Edit `tailscale.conf` and set your auth key:
   ```bash
   TAILSCALE_AUTH_KEY="tskey-auth-your-key-here"
   AUTO_CONNECT=true
   ```
4. **Boot**: Your device connects automatically!

### Option 2: Manual Setup

1. **Boot** your LibreELEC device
2. **SSH in**: Connect to your device
3. **Connect**: Run `/storage/tailscale-up`
4. **Authenticate**: Visit the provided URL to authorize the device

## Usage Commands

After installation, these commands are available:

```bash
# Check Tailscale status
/storage/tailscale-status

# Connect to Tailscale (interactive)
/storage/tailscale-up

# Connect with auth key
/storage/tailscale-up tskey-auth-your-key-here

# Direct tailscale commands
/storage/tailscale-cmd status
/storage/tailscale-cmd ip
/storage/tailscale-cmd down
```

## Configuration Options

Edit `/storage/tailscale/config` or use the template to set:

```bash
# Authentication key for automatic connection
TAILSCALE_AUTH_KEY="tskey-auth-your-key-here"

# Additional tailscale arguments
TAILSCALE_ARGS="--accept-routes"

# Auto-start on boot
AUTO_CONNECT=true

# Custom node name
NODE_NAME="my-libreelec-device"
```

## Advanced Features

### Accept Routes
To access other devices on your Tailscale network:
```bash
TAILSCALE_ARGS="--accept-routes"
```

### Advertise Routes
To share your local network through this device:
```bash
TAILSCALE_ARGS="--advertise-routes=192.168.1.0/24"
```

### Exit Node
To use this device as an exit node:
```bash
TAILSCALE_ARGS="--advertise-exit-node"
```

## Troubleshooting

### Check Service Status
```bash
systemctl status tailscaled
journalctl -u tailscaled
```

### Manual Service Control
```bash
# Start service
systemctl start tailscaled

# Restart service  
systemctl restart tailscaled

# Stop service
systemctl stop tailscaled
```

### Verify Installation
```bash
# Check if binaries exist
ls -la /storage/tailscale/

# Test direct command
/storage/tailscale/tailscale version
```

## Security Notes

- Tailscale uses WireGuard for encryption
- No ports need to be opened on your router
- Each device is authenticated through your Tailscale account
- Auth keys can be restricted and have expiration dates
- All traffic is end-to-end encrypted

## Benefits for LibreELEC

1. **Remote Media Access** - Stream from your home server while traveling
2. **Remote Administration** - SSH access without port forwarding
3. **Secure Kodi Web Interface** - Access Kodi remotely via Tailscale IP
4. **File Sharing** - Access `/storage` directory remotely
5. **Zero Configuration** - Works behind NAT/firewalls automatically

Your LibreELEC device will be accessible at its Tailscale IP address from any device on your Tailscale network! 🚀
