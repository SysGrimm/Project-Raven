# Architecture Overview

This page provides a comprehensive technical overview of Project-Raven's architecture, design decisions, and system integration approach.

## System Architecture

### High-Level Design
```
┌─────────────────────────────────────────────────────────────┐
│                    Project-Raven Stack                      │
├─────────────────────────────────────────────────────────────┤
│ User Interface Layer                                        │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Kodi UI     │ │ Web Remote  │ │ Mobile Apps (Kore)      │ │
│ │ (CEC/IR)    │ │ (HTTP API)  │ │ (JSON-RPC)              │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ Application Layer                                           │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Kodi Core   │ │ Add-ons     │ │ Theme Engine            │ │
│ │ (Media)     │ │ (Services)  │ │ (UI Framework)          │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ Service Layer                                               │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Tailscale   │ │ CEC Service │ │ System Services         │ │
│ │ (VPN Mesh)  │ │ (Remote)    │ │ (SSH, SMB, HTTP)        │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ Operating System Layer                                      │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ LibreELEC   │ │ Linux       │ │ Hardware Drivers        │ │
│ │ (Distro)    │ │ (Kernel)    │ │ (GPU, CEC, Network)     │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ Hardware Layer                                              │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│ │ Raspberry   │ │ Network     │ │ Storage & Peripherals   │ │
│ │ Pi 4/5      │ │ Interface   │ │ (SD, USB, HDMI)         │ │
│ └─────────────┘ └─────────────┘ └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Component Integration

### Core Components

#### 1. LibreELEC Foundation
**Purpose**: Purpose-built Linux distribution for media centers
- **Just Enough OS (JeOS)**: Minimal overhead, maximum performance
- **Read-only Root**: Immutable system partition for stability  
- **Kodi-centric**: Everything optimized for media center use
- **Hardware Integration**: Native GPU acceleration, CEC support
- **Universal Package System**: Advanced build reliability framework

#### 2. Universal Package Download System
**Purpose**: Comprehensive build reliability and package management
- **Proactive Analysis**: Pre-build scanning of all 951 LibreELEC packages
- **Intelligent Mirrors**: Auto-fallback system for all major package sources
- **Pattern Matching**: Smart filename conversion and URL correction
- **Build Optimization**: Sub-10 minute reliable builds vs 2h+ failures
- **Mirror Database**: Comprehensive coverage of GNU, Kernel.org, Python, GitHub, Mozilla, Debian

#### 2. Kodi Media Center
**Purpose**: Primary user interface and media management
- **Database Engine**: SQLite for metadata and library management
- **Playback Engine**: FFmpeg with hardware acceleration
- **Add-on Framework**: Python-based extensibility system
- **Remote APIs**: JSON-RPC, HTTP API, UPnP/DLNA

#### 3. Tailscale VPN Service
**Purpose**: Secure remote access and network mesh
- **WireGuard Protocol**: Modern, high-performance VPN
- **NAT Traversal**: Direct peer connections when possible
- **Zero-config**: Automatic network discovery and routing
- **Cross-platform**: Consistent across all device types

#### 4. CEC Integration
**Purpose**: TV remote control functionality
- **Kernel Framework**: Low-level CEC message handling
- **libcec Library**: High-level CEC API for applications
- **Arbitration**: Coordinated access between frameworks
- **Device Discovery**: Automatic TV and receiver detection

## Network Architecture

### Network Flow Design
```
Internet
    │
    ▼
┌─────────────────┐    Tailscale Mesh    ┌─────────────────┐
│ Remote Device   │◄─────────────────────►│ LibreELEC       │
│ (Phone/Laptop)  │     Encrypted P2P     │ Media Center    │
└─────────────────┘                       └─────────────────┘
                                               │
                                               ▼
                                        ┌─────────────────┐
                                        │ Local Network   │
                                        │ (Home LAN)      │
                                        └─────────────────┘
                                               │
                                               ▼
                                        ┌─────────────────┐
                                        │ Media Sources   │
                                        │ (NAS, Shares)   │
                                        └─────────────────┘
```

### Network Layers

#### Physical Layer
- **Ethernet**: Primary connection (1Gbps recommended)
- **WiFi**: Backup connection (802.11ac minimum)
- **HDMI**: Display and CEC signaling

#### Network Layer  
- **IPv4/IPv6**: Standard IP networking
- **Tailscale Overlay**: 100.x.x.x private network
- **Local Subnet**: Standard home network integration

#### Application Layer
- **HTTP/HTTPS**: Web interface and API access
- **SMB/CIFS**: File sharing protocols
- **UPnP/DLNA**: Media streaming protocols

## Data Flow Patterns

### Media Playback Flow
```
┌─────────────┐    Request    ┌─────────────┐    Fetch    ┌─────────────┐
│ User Input  │─────────────►│ Kodi Core   │───────────►│ Media       │
│ (CEC/Web)   │               │ (Playback)  │             │ Source      │
└─────────────┘               └─────────────┘             └─────────────┘
                                      │                          │
                                      ▼                          ▼
                              ┌─────────────┐            ┌─────────────┐
                              │ Hardware    │◄───────────│ Network/    │
                              │ Decoder     │   Stream   │ Storage     │
                              └─────────────┘            └─────────────┘
                                      │
                                      ▼
                              ┌─────────────┐
                              │ HDMI Output │
                              │ (TV/AVR)    │
                              └─────────────┘
```

### VPN Connection Flow
```
┌─────────────┐    Auth      ┌─────────────┐   Control   ┌─────────────┐
│ Remote      │─────────────►│ Tailscale   │────────────►│ Tailscale   │
│ Device      │               │ Coord Server│             │ Control     │
└─────────────┘               └─────────────┘             └─────────────┘
       │                             │                           │
       │ P2P Tunnel                  │ NAT Traversal             │
       ▼                             ▼                           ▼
┌─────────────┐    Direct    ┌─────────────┐   Config    ┌─────────────┐
│ WireGuard   │◄────────────►│ LibreELEC   │◄───────────►│ Local       │
│ Client      │   Connection │ Tailscaled  │             │ Network     │
└─────────────┘              └─────────────┘             └─────────────┘
```

## Build System Architecture

### Package Dependencies
```
┌─────────────────────────────────────────────────────────────┐
│                    Build Dependency Tree                    │
├─────────────────────────────────────────────────────────────┤
│ Custom Image                                                │
│ ├── LibreELEC Base                                          │
│ │   ├── Linux Kernel (CEC patches)                          │
│ │   ├── Kodi (Media center)                                 │
│ │   ├── Graphics Drivers (Mesa/VC4)                         │
│ │   └── System Libraries (glibc, systemd)                   │
│ ├── Tailscale Add-on                                        │
│ │   ├── Tailscale Binaries (tailscale, tailscaled)          │
│ │   ├── Python Service (default.py)                         │
│ │   ├── Kodi Integration (addon.xml, settings.xml)          │
│ │   └── Helper Scripts (status, auth reset)                 │
│ ├── Custom Theme                                            │
│ │   ├── Estuary Base Theme                                  │
│ │   ├── Custom Graphics (backgrounds, icons)                │
│ │   ├── Layout Modifications (XML files)                    │
│ │   └── Color Schemes (CSS-like definitions)                │
│ └── Additional Add-ons                                      │
│     ├── YouTube Add-on                                      │
│     ├── Network Tools                                       │
│     └── System Utilities                                    │
└─────────────────────────────────────────────────────────────┘
```

### Build Process Flow
```
Source Code → Configure → Compile → Package → Customize → Image
     │            │          │         │          │         │
     ▼            ▼          ▼         ▼          ▼         ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│ Git     │ │ Build   │ │ Cross   │ │ Create  │ │ Install │ │ Final   │
│ Clone   │ │ Config  │ │ Compile │ │ Packages│ │ Addons  │ │ Image   │
└─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

## [SECURITY] Security Architecture

### Security Layers

#### 1. Hardware Security
- **Secure Boot**: Verified boot process (Pi 4+)
- **Hardware RNG**: Cryptographic random number generation
- **TPM Emulation**: Trusted Platform Module functionality

#### 2. Operating System Security
- **Read-only Root**: Immutable system partition
- **Minimal Attack Surface**: Only essential services running
- **Automatic Updates**: Security patches via image updates

#### 3. Network Security
- **WireGuard Encryption**: ChaCha20Poly1305 authenticated encryption
- **Key Management**: Automatic key rotation and exchange
- **Network Isolation**: VPN traffic separated from local network

#### 4. Application Security
- **Sandboxed Add-ons**: Limited permissions for third-party code
- **API Authentication**: Token-based access for remote APIs
- **Input Validation**: Sanitized user input processing

### Threat Model
```
┌─────────────────────────────────────────────────────────────┐
│                      Threat Landscape                       │
├─────────────────────────────────────────────────────────────┤
│ External Threats                                            │
│ ├── Network Attackers (Internet-based)                      │
│ │   └── Mitigation: Tailscale VPN, No open ports           │
│ ├── Local Network Attackers                                 │
│ │   └── Mitigation: Service isolation, minimal exposure     │
│ └── Physical Access                                         │
│     └── Mitigation: Encrypted storage, secure boot         │
├─────────────────────────────────────────────────────────────┤
│ Internal Threats                                            │
│ ├── Malicious Add-ons                                       │
│ │   └── Mitigation: Curated repositories, sandboxing       │
│ ├── Privilege Escalation                                    │
│ │   └── Mitigation: Minimal privileges, read-only system   │
│ └── Data Exfiltration                                       │
│     └── Mitigation: Network monitoring, access controls    │
└─────────────────────────────────────────────────────────────┘
```

## Performance Architecture

### Resource Management

#### CPU Utilization
```
┌─────────────────────────────────────────────────────────────┐
│                    CPU Core Allocation                      │
├─────────────────────────────────────────────────────────────┤
│ Core 0: System Services (kernel, drivers)                   │
│ Core 1: Kodi Main Thread (UI, library)                     │
│ Core 2: Media Decode (hardware accelerated)                │
│ Core 3: Network Services (Tailscale, file sharing)         │
└─────────────────────────────────────────────────────────────┘
```

#### Memory Layout
```
┌─────────────────────────────────────────────────────────────┐
│                    Memory Allocation                        │
├─────────────────────────────────────────────────────────────┤
│ System/Kernel:     512MB  (OS, drivers, buffers)           │
│ GPU Memory:        256MB  (hardware decode, display)       │
│ Kodi Application:  1GB    (UI, database, cache)            │
│ Add-on Services:   256MB  (Tailscale, other services)      │
│ Buffer/Cache:      2GB    (network, media buffering)       │
│ Available:         Remaining (system-dependent)            │
└─────────────────────────────────────────────────────────────┘
```

### I/O Performance

#### Storage Hierarchy
1. **SD Card**: System partition (read-only, optimized)
2. **USB 3.0**: Media storage (high-capacity, moderate speed)
3. **Network Storage**: NAS/SMB shares (variable speed)
4. **RAM Cache**: Active media buffering (fastest access)

#### Network Performance
- **Local Network**: 1Gbps Ethernet / 300Mbps WiFi
- **Tailscale VPN**: ~200Mbps peer-to-peer / ~50Mbps relay
- **Media Streaming**: Adaptive bitrate based on connection

## State Management

### System State
```
┌─────────────────────────────────────────────────────────────┐
│                     State Persistence                       │
├─────────────────────────────────────────────────────────────┤
│ /flash (Boot Partition)                                     │
│ ├── bootloader configuration                                │
│ ├── kernel and device tree                                  │
│ └── system configuration                                    │
├─────────────────────────────────────────────────────────────┤
│ /storage (User Partition)                                   │
│ ├── .kodi/ (Kodi configuration and data)                   │
│ │   ├── userdata/ (settings, database)                     │
│ │   ├── addons/ (user-installed add-ons)                   │
│ │   └── temp/ (cache and temporary files)                  │
│ ├── .config/ (system service configuration)                │
│ │   ├── tailscale/ (VPN state and keys)                    │
│ │   └── connman/ (network configuration)                   │
│ └── media/ (user media files)                              │
└─────────────────────────────────────────────────────────────┘
```

### Configuration Management
- **Kodi Settings**: XML-based configuration with GUI
- **Add-on Settings**: Per-add-on configuration storage  
- **System Settings**: LibreELEC-specific configuration files
- **Network Settings**: ConnMan-based network management

## Integration Points

### External System Integration

#### Media Sources
- **NAS Integration**: SMB, NFS, FTP protocols
- **Streaming Services**: Add-on based integration
- **Local Storage**: USB, external drives
- **Cloud Storage**: WebDAV, cloud add-ons

#### Control Systems  
- **Home Automation**: HTTP API integration
- **Voice Control**: Google Assistant, Alexa compatibility
- **Mobile Apps**: Official and third-party remote apps
- **Physical Remotes**: CEC, IR, RF remotes

#### Monitoring and Management
- **System Monitoring**: Built-in system information
- **Log Management**: Centralized logging with rotation
- **Update Management**: Automatic and manual update systems
- **Backup/Restore**: Configuration and media library backup

---

This architecture provides a robust, scalable foundation for a modern media center with secure remote access capabilities. The modular design allows for easy customization while maintaining system stability and performance.
