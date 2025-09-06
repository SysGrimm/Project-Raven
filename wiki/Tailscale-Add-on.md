# Tailscale Add-on for LibreELEC

This page documents the complete Tailscale VPN service add-on that provides secure remote access to your LibreELEC media center.

## Overview

The Tailscale add-on integrates Tailscale's mesh VPN directly into LibreELEC, allowing you to:
- Access your media center from anywhere
- Securely stream content over the internet
- Connect multiple devices in a private network
- Use your LibreELEC device as a VPN exit node

## Add-on Components

### Core Files Structure
```
service.tailscale/
├── addon.xml              # Kodi add-on manifest
├── default.py             # Main Python service
├── settings.xml           # Configuration interface
├── bin/
│   ├── tailscale          # Tailscale CLI binary
│   ├── tailscaled         # Tailscale daemon binary
│   ├── reset_auth.py      # Authentication reset helper
│   ├── show_status.py     # Status display helper
│   └── tailscale.start    # Startup script
└── resources/
    └── language/
        └── resource.language.en_gb/
            └── strings.po # UI text strings
```

### Binary Architecture Support
- **ARM** (armv6l): Raspberry Pi 1, Pi Zero
- **ARM64** (aarch64): Raspberry Pi 2/3/4/5
- **x86_64**: Generic PC builds

## Installation Methods

### Method 1: Custom LibreELEC Build (Recommended)
Include the add-on in your custom build:

```bash
# Add to packages/addons/service/tailscale/package.mk
PKG_NAME="tailscale"
PKG_VERSION="1.82.1"
PKG_IS_ADDON="yes"
PKG_ADDON_TYPE="xbmc.service"
```

### Method 2: Manual Installation
1. Download appropriate Tailscale binaries
2. Create add-on structure
3. Install via Kodi add-on manager

### Method 3: Repository Installation
Add custom repository with pre-built add-on packages.

## Configuration Options

### Basic Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Auto-login | Authenticate automatically on startup | Enabled |
| Hostname | Device name on Tailscale network | LibreELEC-Kodi |
| Daemon Port | Tailscale daemon listening port | 41641 |

### Network Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Accept Subnet Routes | Accept routes from other nodes | Disabled |
| Accept DNS | Use Tailscale DNS configuration | Enabled |
| Shields Up | Block incoming connections | Disabled |

### Advanced Settings

| Setting | Description | Default |
|---------|-------------|---------|
| Exit Node | Route all traffic through specific node | None |
| Advertise Routes | Advertise local subnet routes | None |
| SNAT Routes | Use source NAT for advertised routes | Disabled |

## Service Architecture

### TailscaleService Class
The main service class handles:

```python
class TailscaleService:
    def __init__(self):
        self.addon = xbmcaddon.Addon()
        self.monitor = xbmc.Monitor()
        
    def start_tailscaled(self):
        # Start Tailscale daemon with LibreELEC-specific config
        
    def authenticate_if_needed(self):
        # Handle web-based authentication flow
        
    def monitor_status(self):
        # Monitor connection and update Kodi notifications
```

### Startup Process
1. **Service Initialization**: Load add-on settings and create state directory
2. **Daemon Launch**: Start `tailscaled` with LibreELEC-optimized parameters
3. **Authentication**: Handle initial device authentication
4. **Monitoring**: Continuous status monitoring and error handling

### State Management
- **State Directory**: `/storage/.kodi/userdata/addon_data/service.tailscale/`
- **Configuration**: `tailscaled.state` (encrypted device keys)
- **Logs**: Integrated with Kodi logging system

## 🔐 Authentication Flow

### Initial Setup
1. Add-on starts `tailscaled` daemon
2. If auto-login enabled, initiates authentication
3. Displays authentication URL in Kodi notification
4. User visits URL to approve device
5. Service completes authentication automatically

### Manual Authentication
```bash
# SSH into LibreELEC device
ssh root@libreelec-ip

# Navigate to add-on directory
cd /storage/.kodi/addons/service.tailscale

# Manual authentication
./bin/tailscale up --hostname=LibreELEC-Kodi
```

### Re-authentication
Use the "Reset authentication" button in settings to:
1. Stop Tailscale daemon
2. Clear stored authentication state
3. Restart daemon for fresh authentication

## Network Configuration

### Basic Connectivity
Once authenticated, your LibreELEC device gets:
- **Tailscale IP**: Unique IP in 100.x.x.x range
- **Device Name**: Resolvable hostname on Tailscale network
- **Encrypted Tunnels**: WireGuard-based peer-to-peer connections

### Access Methods

| Service | Access Method | Default Port |
|---------|---------------|--------------|
| Kodi Web Interface | `http://tailscale-ip:8080` | 8080 |
| SSH Access | `ssh root@tailscale-ip` | 22 |
| SMB Shares | `smb://tailscale-ip` | 445 |
| HTTP Shares | `http://tailscale-ip:8181` | 8181 |

### Subnet Routing
Enable your LibreELEC device to route local network traffic:

```bash
# Advertise local subnet (e.g., 192.168.1.0/24)
Advertise Routes: 192.168.1.0/24

# Enable IP forwarding (automatic in add-on)
echo 1 > /proc/sys/net/ipv4/ip_forward
```

### Exit Node Setup
Use LibreELEC as internet gateway for other Tailscale devices:

```bash
# Advertise as exit node
Advertise Routes: 0.0.0.0/0

# Approve in Tailscale admin console
# Other devices can then route all traffic through LibreELEC
```

## Monitoring and Status

### Status Display
The add-on provides real-time status information:

```python
def show_status():
    # Display current Tailscale status in Kodi dialog
    # Shows: Connection state, peer count, exit node, routes
```

### Health Checks
Continuous monitoring includes:
- **Daemon Health**: Verify `tailscaled` process is running
- **Network Connectivity**: Test connection to Tailscale control server
- **Peer Connectivity**: Monitor peer-to-peer connection status
- **Authentication State**: Check for authentication expiration

### Logging Integration
- **Kodi Logs**: Service events logged to Kodi log system
- **Debug Mode**: Verbose logging for troubleshooting
- **Error Notifications**: User-friendly error messages in Kodi UI

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check binary permissions
ls -la /storage/.kodi/addons/service.tailscale/bin/
# Should show: -rwxr-xr-x

# Fix permissions if needed
chmod +x /storage/.kodi/addons/service.tailscale/bin/*
```

#### Authentication Fails
- Verify internet connectivity
- Check Tailscale admin console for pending approvals
- Use "Reset authentication" in add-on settings
- Manually authenticate via SSH if needed

#### Network Connectivity Issues
- Ensure daemon port (41641) is not blocked
- Check router/firewall configuration
- Verify LibreELEC network settings
- Test with different Tailscale exit nodes

### Debug Commands

```bash
# Check service status
systemctl --user status service.tailscale

# View Tailscale status
/storage/.kodi/addons/service.tailscale/bin/tailscale status

# Monitor daemon logs
tail -f /storage/.kodi/temp/kodi.log | grep -i tailscale

# Test network connectivity
/storage/.kodi/addons/service.tailscale/bin/tailscale ping peer-hostname
```

## 🔒 Security Considerations

### Encryption
- **WireGuard Protocol**: All traffic encrypted with modern cryptography
- **Key Management**: Device keys stored securely in encrypted state file
- **Peer Authentication**: Cryptographic device identity verification

### Access Control
- **Device Approval**: New devices require admin approval
- **ACL Policies**: Fine-grained access control via Tailscale admin console
- **Shields Up Mode**: Block unwanted incoming connections

### Best Practices
1. **Regular Updates**: Keep Tailscale binaries updated
2. **Key Rotation**: Periodically re-authenticate devices
3. **Access Review**: Regularly audit device access in admin console
4. **Network Segmentation**: Use ACLs to limit device access scope

## Performance Optimization

### Bandwidth Considerations
- **Direct Connections**: Peer-to-peer when possible (no relay)
- **DERP Relays**: Automatic fallback for NAT traversal
- **Exit Node Selection**: Choose geographically close exit nodes

### Resource Usage
- **Memory**: ~20MB for daemon + ~5MB for CLI tools
- **CPU**: Minimal impact during steady-state operation
- **Storage**: ~50MB for binaries + minimal state files

### LibreELEC Optimizations
- **Minimal Dependencies**: No additional system libraries required
- **Startup Integration**: Starts with LibreELEC, stops cleanly on shutdown
- **Resource Management**: Respects LibreELEC memory constraints

## Updates and Maintenance

### Binary Updates
Update Tailscale binaries in custom builds:

```bash
# Update version in package.mk
PKG_VERSION="1.84.0"  # New version

# Rebuild add-on with updated binaries
```

### Configuration Migration
The add-on handles configuration updates automatically:
- Settings schema updates
- State file format changes
- Binary compatibility checks

### Backup and Restore
Important files to backup:
- `/storage/.kodi/userdata/addon_data/service.tailscale/tailscaled.state`
- Add-on settings and configuration

---

**Next**: See [[Custom-LibreELEC-Build]] for information on building custom images with the Tailscale add-on pre-installed.
