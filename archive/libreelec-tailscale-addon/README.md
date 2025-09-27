# Tailscale VPN Add-on for LibreELEC

This add-on provides Tailscale VPN functionality for LibreELEC, allowing you to securely access your media center from anywhere and integrate it into your Tailscale network.

## Features

- **Zero-config VPN**: Connect your LibreELEC device to your Tailscale network
- **Automatic startup**: Service starts automatically with LibreELEC
- **Web authentication**: Easy setup through Tailscale's web interface
- **Exit node support**: Route all traffic through your LibreELEC device or another node
- **Subnet routing**: Advertise local network routes to other Tailscale devices
- **DNS integration**: Use Tailscale DNS for name resolution
- **Status monitoring**: View connection status and peer information

## Installation

### Method 1: Install on LibreELEC Device

1. Copy the entire `libreelec-tailscale-addon` folder to your LibreELEC device
2. Place it in the LibreELEC packages directory structure:
   ```
   packages/addons/service/tailscale/
   ```
3. Build the add-on using LibreELEC's build system
4. Install the resulting add-on package

### Method 2: Manual Installation

1. Download the appropriate Tailscale binaries for your architecture:
   - ARM: `tailscale_1.82.1_linux_arm.tgz`
   - ARM64: `tailscale_1.82.1_linux_arm64.tgz` 
   - x86_64: `tailscale_1.82.1_linux_amd64.tgz`

2. Extract and place the binaries in the add-on structure
3. Install via Kodi's add-on manager

## Configuration

1. Go to **Settings** → **Add-ons** → **My add-ons** → **Services** → **Tailscale VPN**
2. Click **Configure**

### Basic Settings

- **Auto-login on startup**: Automatically authenticate when the service starts
- **Device hostname**: Hostname for this device on the Tailscale network (default: LibreELEC-Kodi)
- **Daemon port**: Port for the Tailscale daemon (default: 41641)

### Network Settings

- **Accept subnet routes**: Accept routes advertised by other Tailscale nodes
- **Accept DNS configuration**: Use DNS servers provided by Tailscale
- **Shields up mode**: Block incoming connections from other Tailscale users

### Advanced Settings

- **Exit node**: Route all traffic through a specific Tailscale node
- **Advertise routes**: Advertise local subnet routes (e.g., 192.168.1.0/24)
- **SNAT subnet routes**: Use source NAT for advertised routes

## First Time Setup

1. Enable the add-on in Kodi
2. The service will start automatically
3. If auto-login is enabled, you'll need to authenticate:
   - Check the Kodi notification for authentication instructions
   - Visit the Tailscale admin console to approve the device
   - Or manually run: `tailscale up` via SSH

## Usage

### Checking Status
- Use the "Show status" button in add-on settings
- Or via SSH: `tailscale status`

### Manual Authentication
If you need to authenticate manually:
```bash
# SSH into your LibreELEC device
ssh root@your-libreelec-ip

# Navigate to add-on directory
cd /storage/.kodi/addons/service.tailscale

# Authenticate
./bin/tailscale up --hostname=LibreELEC-Kodi
```

### Reset Authentication
Use the "Reset authentication" button in add-on settings to log out and start fresh.

## Accessing Your LibreELEC Device

Once connected to Tailscale:

1. **Kodi Web Interface**: `http://tailscale-ip:8080`
2. **SSH Access**: `ssh root@tailscale-ip`
3. **SMB Shares**: `\\tailscale-ip` or `smb://tailscale-ip`
4. **HTTP/Media Shares**: `http://tailscale-ip:port`

## Exit Node Configuration

To use your LibreELEC device as an exit node:

1. Enable "Advertise routes" with value: `0.0.0.0/0`
2. Enable IP forwarding on the device
3. Approve the exit node in Tailscale admin console
4. Other devices can then route traffic through your LibreELEC device

## Troubleshooting

### Service Won't Start
- Check Kodi logs: **Settings** → **System** → **Logging** → **Component-specific logging** → **Enable**
- Verify binary permissions: `chmod +x /storage/.kodi/addons/service.tailscale/bin/*`

### Authentication Issues
- Use "Reset authentication" in add-on settings
- Check Tailscale admin console for pending device approvals
- Verify network connectivity

### Network Connectivity
- Ensure your router allows the daemon port (default: 41641)
- Check if UFW or other firewalls are blocking connections
- Verify Tailscale service is running: `ps | grep tailscaled`

## Architecture Support

This add-on supports:
- **Raspberry Pi** (ARM): Pi 1, Pi Zero
- **Raspberry Pi** (ARM64): Pi 2, Pi 3, Pi 4, Pi 5
- **x86_64**: Generic PC builds

## Security Notes

- Tailscale uses WireGuard for encryption
- All connections are peer-to-peer when possible
- The Tailscale daemon runs with minimal privileges
- State files are stored in `/storage/.kodi/userdata/addon_data/service.tailscale/`

## Contributing

This add-on is part of the Project-Raven repository. Contributions welcome!

## License

This add-on is licensed under GPL-2.0. Tailscale binaries are licensed under BSD-3-Clause.

## Support

- LibreELEC Forum: https://forum.libreelec.tv
- Tailscale Documentation: https://tailscale.com/kb/
- Project Repository: https://github.com/SysGrimm/Project-Raven
