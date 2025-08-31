# SoulBox Features

This page provides a comprehensive overview of SoulBox features, system requirements, performance characteristics, and what you get out-of-the-box with your Will-o'-Wisp media center.

## What You Get Out-of-the-Box

### 🎬 Media Center Features

#### Kodi Media Center
- **Version**: Latest stable Kodi from Debian repositories
- **Auto-Start**: Boots directly into Kodi after system initialization
- **Hardware Acceleration**: Full Pi 5 GPU optimization with vc4-kms-v3d driver
- **Video Codecs**: H.264/HEVC hardware decode support
- **Audio Support**: HDMI audio, analog audio, USB audio devices
- **4K Support**: Up to 4K@60Hz video playback on compatible displays

#### Pre-configured Media Directories
```bash
/home/soulbox/Videos/     # Video media library
/home/soulbox/Music/      # Audio media library
/home/soulbox/Pictures/   # Photo media library
/home/soulbox/Downloads/  # Download staging area
```

#### Supported Media Formats
- **Video**: H.264, H.265/HEVC, VP9, AV1, MPEG-2, MPEG-4
- **Audio**: MP3, FLAC, AAC, DTS, Dolby Digital, PCM
- **Images**: JPEG, PNG, GIF, BMP, TIFF, WebP
- **Subtitles**: SRT, ASS, SSA, VTT, embedded subtitles

### 🌐 Network Integration

#### Tailscale VPN
- **Mesh Networking**: Enterprise-grade VPN for secure remote access
- **Zero-Config**: Automatic peer discovery and NAT traversal
- **Cross-Platform**: Access from Windows, macOS, Linux, iOS, Android
- **Encrypted**: WireGuard-based encryption for all traffic
- **Remote Management**: SSH access from anywhere via Tailscale network

#### Network Services
- **SSH Server**: OpenSSH enabled by default with password authentication
- **DHCP Client**: Automatic network configuration via NetworkManager
- **WiFi Support**: 802.11ac wireless with WPA2/WPA3 support
- **Ethernet**: Gigabit Ethernet support on Pi 5, fast Ethernet on Pi 4

#### Network Media Access
- **SMB/CIFS**: Access network shares for media storage
- **NFS**: Network File System support for media libraries
- **FTP/SFTP**: File transfer protocol support
- **UPnP/DLNA**: Media server and renderer capabilities

### 🔥 Will-o'-Wisp Branding

#### Boot Experience
- **Custom Boot Splash**: Branded ASCII art during system initialization
- **Themed MOTD**: Will-o'-wisp message of the day on SSH login
- **Hostname**: Pre-configured as "soulbox" for easy network identification
- **User Experience**: Cohesive theming throughout the system

#### Visual Identity
- **SoulBox Logo**: Integrated branding assets in `/opt/soulbox/assets/`
- **Color Scheme**: Blue flame themed interface elements
- **Typography**: Consistent font choices across system components

### ⚙️ System Configuration

#### User Management
- **soulbox User**: Primary media center user with sudo privileges
- **pi User**: Traditional Raspberry Pi user account (compatibility)
- **root User**: System administration account
- **Audio/Video Groups**: Proper permissions for media device access

#### Service Management
- **systemd Integration**: Proper service management and dependencies
- **Auto-login**: Direct boot to Kodi without login prompt
- **Service Recovery**: Automatic restart of failed services
- **Boot Optimization**: Fast boot times with optimized service startup

#### System Directories
```bash
/opt/soulbox/
├── assets/           # Branding and logo assets
├── scripts/          # System setup and utility scripts
└── logs/             # System and setup logs

/etc/soulbox/         # Configuration files
/var/log/soulbox/     # Runtime logs
```

## System Requirements

### Build Host Requirements

For building SoulBox images from source:

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Any with Docker support | Ubuntu 22.04+ or equivalent |
| **CPU** | 2 cores | 4+ cores for faster builds |
| **RAM** | 4GB | 8GB+ for optimal performance |
| **Storage** | 20GB free | 50GB+ for multiple builds |
| **Docker** | 20.10+ | Latest stable version |
| **Network** | Broadband internet | Gigabit for faster downloads |

#### Required Software
```bash
# Core build tools
docker                    # Container runtime
e2fsprogs e2fsprogs-extra # Filesystem tools (populatefs preferred)
mtools                    # FAT32 filesystem tools
parted                    # Partition manipulation
dosfstools                # Additional FAT tools
curl                      # Download utilities
xz-utils                  # Compression tools
```

### Target Hardware Requirements

For running SoulBox on Raspberry Pi:

#### Raspberry Pi 5 (Primary Target)
| Component | Specification |
|-----------|---------------|
| **CPU** | Broadcom BCM2712 (Cortex-A76 quad-core 2.4GHz) |
| **RAM** | 4GB LPDDR4X (minimum), 8GB recommended |
| **GPU** | VideoCore VII with hardware video decode |
| **Storage** | 8GB+ SD card (Class 10), 16GB+ recommended |
| **Power** | Official 27W USB-C power supply |
| **Display** | HDMI 2.0 (up to 4K@60Hz) |
| **Network** | Gigabit Ethernet + 802.11ac WiFi |

#### Raspberry Pi 4 (Compatible)
| Component | Specification |
|-----------|---------------|
| **CPU** | Broadcom BCM2711 (Cortex-A72 quad-core 1.8GHz) |
| **RAM** | 2GB LPDDR4 (minimum), 4GB+ recommended |
| **GPU** | VideoCore VI with hardware video decode |
| **Storage** | 8GB+ SD card (Class 10), 16GB+ recommended |
| **Power** | Official 15W USB-C or 3A micro-USB power supply |
| **Display** | HDMI 2.0 (up to 4K@60Hz) |
| **Network** | Gigabit Ethernet + 802.11ac WiFi |

### Storage Requirements

#### SD Card Recommendations
| Capacity | Use Case | Performance |
|----------|----------|-------------|
| **8GB** | Basic installation | Minimum viable |
| **16GB** | Recommended minimum | Good performance |
| **32GB+** | Optimal with local media | Best performance |
| **64GB+** | Large local media library | Excellent performance |

#### Performance Characteristics
- **Class 10**: Minimum recommended speed class
- **A1/A2**: Application Performance Class for better random I/O
- **V30**: Video Speed Class for smooth 4K recording/playback
- **UHS-I/UHS-II**: Ultra High Speed for maximum throughput

### Network Requirements

#### Build Environment
- **Internet Access**: Required for downloading Pi OS base images
- **Bandwidth**: 1Mbps+ for downloads (431MB base image)
- **Stability**: Reliable connection for 15-25 minute build process

#### Runtime Environment
- **DHCP**: Automatic network configuration (preferred)
- **Static IP**: Manual configuration supported
- **WiFi**: WPA2/WPA3 encrypted networks
- **Ethernet**: Direct connection or network switch

## Performance Characteristics

### Build Performance

#### Build Times (Typical)
| Phase | Duration | Description |
|-------|----------|-------------|
| **Setup & Download** | 2-3 minutes | Environment prep and Pi OS download |
| **Staging & Extraction** | 8-12 minutes | LibreELEC-style filesystem staging |
| **Asset Creation** | 1-2 minutes | SoulBox customization generation |
| **Image Assembly** | 3-5 minutes | Final image creation and population |
| **Output & Cleanup** | 1-2 minutes | Compression and artifact generation |
| **Total** | **15-25 minutes** | Complete build process |

#### Build Resources
- **Peak RAM Usage**: 2-4GB during extraction phase
- **Temporary Storage**: 8-10GB during build process  
- **Final Artifacts**: 1.1GB image, 56MB compressed
- **Network Transfer**: 431MB download + metadata

### Runtime Performance

#### Boot Performance
| Phase | Duration | Description |
|-------|----------|-------------|
| **Hardware Init** | 10-15 seconds | Pi firmware and kernel loading |
| **System Boot** | 15-20 seconds | systemd service initialization |
| **Kodi Startup** | 5-10 seconds | Media center application launch |
| **Total Cold Boot** | **30-45 seconds** | Power-on to usable Kodi |
| **First Boot Setup** | **+10 minutes** | One-time package installation |

#### Media Performance
- **4K Video**: Smooth playback with hardware decode
- **1080p Video**: Excellent performance with all codecs
- **Audio**: Low-latency HDMI and analog output
- **Navigation**: Responsive Kodi interface with GPU acceleration

#### Network Performance
- **Ethernet**: Up to 1Gbps on Pi 5, 100Mbps on Pi 4
- **WiFi**: 802.11ac speeds (300-866Mbps theoretical)
- **Tailscale**: WireGuard performance (100+ Mbps typical)
- **Media Streaming**: Smooth network media playback

### Resource Usage

#### Memory Usage
| Component | RAM Usage | Notes |
|-----------|-----------|-------|
| **Base System** | 200-300MB | Debian base + services |
| **Kodi** | 400-800MB | Depends on media library size |
| **GPU Memory** | 128MB | Allocated for hardware decode |
| **Available** | 3GB+ | On 4GB Pi, 7GB+ on 8GB Pi |

#### Storage Usage
| Component | Space Used | Notes |
|-----------|------------|-------|
| **Base System** | 1.8GB | Debian + core packages |
| **Kodi** | 200MB | Media center application |
| **SoulBox Assets** | 50MB | Branding and scripts |
| **Free Space** | 6GB+ | On 8GB SD card |
| **Media Cache** | Variable | Thumbnails and metadata |

## Advanced Features

### Container-Friendly Build System

#### LibreELEC Methodology
- **Staging Directory**: Clean separation of build phases
- **populatefs**: Bulk filesystem population (preferred method)
- **e2tools Fallback**: Universal compatibility with traditional tools
- **No Privileges**: Runs in unprivileged containers
- **Universal**: Works on any Docker-capable system

#### Intelligent Tool Selection
```bash
# Automatic tool detection and fallback
if command -v populatefs >/dev/null 2>&1; then
    # Use LibreELEC method (preferred)
    populatefs -U -d "$staging_dir" "$filesystem_image"
else  
    # Fall back to e2tools method
    populate_filesystem_with_e2tools "$temp_dir" "$staging_dir"
fi
```

### CI/CD Integration

#### Gitea Actions
- **Automated Builds**: Every commit triggers image build
- **Artifact Management**: Automatic upload and release creation
- **Version Control**: Semantic versioning with auto-increment
- **Quality Gates**: Build verification and testing

#### Container Compatibility
- **GitHub Actions**: Works in standard GitHub runners
- **Docker**: Compatible with any Docker environment
- **Unraid**: Optimized for Unraid NAS systems
- **Local Development**: Cross-platform build support

### Security Features

#### Default Security
- **SSH Access**: Enabled with password authentication
- **User Accounts**: Standard sudo-enabled accounts
- **Firewall**: UFW available but disabled by default
- **Updates**: Latest Debian security patches included

#### Hardening Options
- **Password Changes**: Easy default password modification
- **SSH Keys**: Support for key-based authentication
- **Firewall Rules**: UFW configuration for network security
- **Automatic Updates**: Unattended security update support

## Comparison with Alternatives

### vs. Standard Raspberry Pi OS
| Feature | Pi OS | SoulBox |
|---------|--------|---------|
| **Installation** | Manual setup required | Plug-and-play image |
| **Media Center** | Manual Kodi installation | Pre-configured Kodi |
| **VPN** | Manual Tailscale setup | Pre-installed Tailscale |
| **Optimization** | Generic Pi settings | Pi 5 media optimized |
| **Updates** | Manual maintenance | Automated first boot |

### vs. LibreELEC
| Feature | LibreELEC | SoulBox |
|---------|-----------|---------|
| **Base System** | Custom minimal | Full Debian |
| **Package Manager** | Add-ons only | Full apt ecosystem |
| **SSH Access** | Limited shell | Full Linux environment |
| **Customization** | Restricted | Full system access |
| **Updates** | Appliance model | Traditional Linux |

### vs. OSMC
| Feature | OSMC | SoulBox |
|---------|------|---------|
| **Base System** | Custom Debian | Raspberry Pi OS |
| **Hardware Support** | Multi-platform | Pi 4/5 optimized |
| **Build System** | Traditional | Container-friendly |
| **VPN Integration** | Manual | Pre-configured Tailscale |
| **Remote Access** | SSH only | SSH + VPN mesh |

## Future Roadmap

### Planned Enhancements

#### Hardware Support
- **Pi Zero 2W**: Lightweight media player variant
- **Pi 400**: Integrated keyboard computer support
- **Compute Module**: Industrial/embedded deployment options
- **Pi Pico**: Companion device integration

#### Software Features
- **Web Interface**: Browser-based configuration and management
- **Mobile App**: Remote control and media management
- **Plugin System**: Extensible addon architecture  
- **Custom Skins**: User-configurable Kodi themes

#### Infrastructure
- **Multi-arch**: ARM32, x86_64 build support
- **Cloud Integration**: S3, Backblaze B2 media storage
- **Clustering**: Multi-device media server coordination
- **Edge Computing**: CDN and edge cache integration

### Next Generation Architecture

#### Container Variants
- **Docker Images**: Native containerized deployment
- **Kubernetes**: Orchestrated media center clusters
- **Edge Runtime**: Lightweight container variants
- **Serverless**: Function-based media processing

#### AI Integration
- **Content Recognition**: Automatic media tagging and organization
- **Smart Recommendations**: ML-based content suggestions
- **Voice Control**: Natural language media center interaction
- **Predictive Caching**: AI-driven content pre-loading

---

*SoulBox delivers a complete, optimized media center experience with the flexibility of a full Linux system and the simplicity of an appliance.*

**← Back to [[Deployment-Guide]] | Next: [[Development]] →**
