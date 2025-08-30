# The Fucking Manual (TFM.md) - SoulBox

## Project Overview

SoulBox is a Debian-based Raspberry Pi 5 OS project designed as a media center solution. The system runs Kodi as a standalone media player service on Raspberry Pi 5 hardware with optimized GPU configurations.

**Hardware Specifications:**
- **Device**: Raspberry Pi 5 Model B Rev 1.0
- **CPU**: BCM2712 (ARM Cortex-A76 quad-core)
- **GPU**: BCM2712 with vc4/v3d drivers
- **Memory**: GPU memory allocated at 256MB

**Software Stack:**
- **OS**: Debian GNU/Linux 12 (bookworm)
- **Primary Service**: Kodi media center (kodi-standalone.service)
- **Display System**: GBM (Generic Buffer Management) windowing
- **User Context**: reaper (with video, render, audio group permissions)

## System Architecture

```
┌─────────────────────────────────────────┐
│ Application Layer                       │
│ ┌─────────────────────────────────────┐ │
│ │ Kodi Media Center                   │ │
│ │ (kodi-standalone.service)           │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ Service Management Layer                │
│ ┌─────────────────────────────────────┐ │
│ │ systemd Service Manager             │ │
│ │ - Auto-start/restart                │ │
│ │ - Logging and monitoring            │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ Display and Graphics Layer              │
│ ┌─────────────────────────────────────┐ │
│ │ GBM Windowing System                │ │
│ │ - Hardware-accelerated rendering    │ │
│ │ - Direct GPU access                 │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ Hardware Layer                          │
│ ┌─────────────────────────────────────┐ │
│ │ Raspberry Pi 5 BCM2712 SoC          │ │
│ │ - vc4/v3d GPU drivers              │ │
│ │ - Optimized GPU frequencies         │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Critical Configuration Files

### /boot/firmware/config.txt
**Primary hardware configuration file for Raspberry Pi 5**

**GPU Settings (Pi 5 Specific):**
```ini
# Graphics drivers for Pi 5 BCM2712
dtoverlay=vc4-kms-v3d
max_framebuffers=2
gpu_mem=256
gpu_freq=700
over_voltage=2
```

**Video Optimization:**
```ini
# HDMI configuration
hdmi_drive=2
hdmi_force_hotplug=1
hdmi_boost=7

# Hardware codec frequencies
h264_freq=600
hevc_freq=600
codec_enabled=ALL
```

**CRITICAL WARNING**: This file is extremely sensitive. Duplicate entries will cause boot failures. Always validate before modification.

## Service Management

### Kodi Standalone Service
**Service Name**: `kodi-standalone.service`
**User Context**: `reaper`
**Auto-start**: Enabled

**Essential Commands:**
```bash
# Service status check
sudo systemctl status kodi-standalone.service

# Service control
sudo systemctl stop kodi-standalone.service
sudo systemctl start kodi-standalone.service
sudo systemctl restart kodi-standalone.service

# Real-time log monitoring
journalctl -u kodi-standalone.service -f

# Boot-time log analysis
journalctl -u kodi-standalone.service --since="1 hour ago"
```

## System Diagnostics and Validation

### GPU and DRM Device Verification
```bash
# Check DRM devices (CRITICAL - must show card0 and renderD128)
ls -la /dev/dri/
# Expected output: card0, controlD64, renderD128

# Verify GPU driver modules are loaded
lsmod | grep -E "(drm|v3d|vc4)"
# Expected: vc4, v3d_drm, drm, drm_kms_helper

# Test GPU firmware communication
vcgencmd version
vcgencmd get_config int

# Verify user permissions
groups reaper
# Expected: reaper video render audio
```

### Configuration Validation
```bash
# Check for duplicate GPU settings (CRITICAL)
grep -n "dtoverlay\|gpu_freq\|over_voltage" /boot/firmware/config.txt

# Create timestamped backup before changes
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup.$(date +%Y%m%d_%H%M%S)

# Validate config syntax
vcgencmd get_config int | grep -E "gpu_|over_voltage"
```

## Known Issues and Solutions

### Issue 1: GPU Driver Probe Failures (Pi 5 BCM2712)
**Symptoms:**
- Missing /dev/dri/ devices
- vc4-drm probe failures in dmesg
- Kodi fails to initialize graphics

**Root Cause:**
BCM2712 GPU in Pi 5 requires different driver handling than Pi 4. Multiple or conflicting dtoverlay entries cause initialization failures.

**Solution:**
1. Backup config.txt
2. Ensure single `dtoverlay=vc4-kms-v3d` entry
3. Remove any duplicate GPU-related lines
4. Reboot and verify /dev/dri/ devices

**Prevention:**
- Always grep for duplicates before config modifications
- Use timestamped backups for all config changes

### Issue 2: Boot Configuration Corruption
**Symptoms:**
- System fails to boot
- GPU initialization errors
- Multiple duplicate entries in config.txt

**Root Cause:**
Automated tools or manual edits create duplicate configuration entries, causing parsing conflicts.

**Detection Commands:**
```bash
# Find duplicate dtoverlay entries
grep -n "dtoverlay" /boot/firmware/config.txt

# Find duplicate GPU settings
grep -n "gpu_" /boot/firmware/config.txt
```

**Recovery Process:**
1. Mount SD card on another system
2. Edit /boot/firmware/config.txt
3. Remove duplicate entries
4. Validate with known-good configuration
5. Test boot process

## Development Workflow

### Pre-Change Checklist
1. **Backup Creation**: Always create timestamped config backups
2. **Service Status**: Check current Kodi service state
3. **GPU Validation**: Confirm /dev/dri/ devices exist
4. **Documentation**: Update this TFM.md with planned changes

### Post-Change Validation
1. **Boot Test**: Verify system boots successfully
2. **GPU Test**: Confirm /dev/dri/ devices still exist
3. **Service Test**: Verify Kodi service starts correctly
4. **Documentation**: Document changes, issues, and solutions

### Change Documentation Template
```markdown
## Change: [Brief Description]
**Date**: [YYYY-MM-DD HH:MM]
**Issue**: [Problem description]
**Root Cause**: [Analysis of why the issue occurred]
**Solution**: [Exact commands and changes made]
**Validation**: [How the fix was verified]
**Prevention**: [Steps to avoid recurrence]
```

## Security Considerations

- **Privilege Escalation**: dmesg access requires sudo
- **Firewall**: UFW is active and configured
- **User Restrictions**: reaper user has minimal necessary group memberships
- **Service Isolation**: Kodi runs as dedicated user, not root
- **Configuration Protection**: Critical config files have restricted permissions

## Troubleshooting Priority Framework

### Level 1: GPU and Graphics
1. Check /dev/dri/ device existence
2. Verify vc4/v3d driver loading
3. Test GPU firmware communication
4. Validate config.txt for duplicates

### Level 2: Service Management
1. Check systemd service status
2. Review journalctl logs for patterns
3. Verify user permissions and groups
4. Test service restart capability

### Level 3: Hardware Validation
1. Test GPU frequency settings
2. Verify voltage and thermal status
3. Check HDMI connectivity
4. Validate hardware codec availability

### Level 4: System Integration
1. Review boot process timing
2. Check dependency service status
3. Validate network connectivity
4. Test storage accessibility

## Emergency Recovery Procedures

### Boot Failure Recovery
1. **Physical Access**: Connect keyboard to Pi
2. **Emergency Boot**: Use recovery mode if available
3. **Config Restore**: Mount SD card externally and restore config backup
4. **Minimal Boot**: Start with basic config.txt to isolate issues

### Service Failure Recovery
```bash
# Emergency service restart
sudo systemctl daemon-reload
sudo systemctl reset-failed kodi-standalone.service
sudo systemctl start kodi-standalone.service

# Log analysis for root cause
journalctl -u kodi-standalone.service --since="10 minutes ago" -p err
```

## Performance Optimization Settings

### GPU Configuration
- **gpu_freq=700**: Optimal balance of performance and stability
- **over_voltage=2**: Required for stable high-frequency GPU operation
- **gpu_mem=256**: Sufficient memory allocation for 4K media

### Service Configuration
- **Standalone Mode**: Direct GPU access without desktop environment overhead
- **Hardware Acceleration**: Full codec support for efficient playback
- **Auto-restart**: Service resilience against crashes

## Maintenance Schedule

### Daily (Automated)
- Service health monitoring
- Log rotation and cleanup
- Basic connectivity checks

### Weekly
- Configuration backup verification
- Service log analysis
- Performance metrics review

### Monthly
- Full system backup
- Security update application
- Configuration optimization review

## Project Structure

### Repository Layout
```
soulbox/
├── README.md                    # Project overview and quick start
├── TFM.md                      # Technical manual (this file)
├── WARP.md                     # Development guidelines for WARP
├── LICENSE                     # Project license
├── configs/                    # Configuration templates
│   ├── boot/
│   │   └── config.txt         # Raspberry Pi boot configuration
│   └── systemd/
│       └── kodi-standalone.service  # Kodi systemd service
├── scripts/                    # Automation and deployment scripts
│   ├── setup-system.sh       # Initial system setup (run on Pi)
│   ├── build-image.sh         # Create custom OS image
│   └── deploy-config.sh       # Deploy updates to existing systems
└── build/                      # Build artifacts (generated)
    ├── image/
    ├── rootfs/
    └── *.img
```

### Script Usage

**Initial System Setup:**
```bash
# On a fresh Debian Pi 5 installation
sudo ./scripts/setup-system.sh
```

**Build Custom Image:**
```bash
# Requires debootstrap, qemu-user-static, parted
sudo ./scripts/build-image.sh [output-directory]
```

**Deploy Configuration Updates:**
```bash
# Local deployment
./scripts/deploy-config.sh

# Remote deployment
./scripts/deploy-config.sh pi@192.168.1.100

# Interactive mode
./scripts/deploy-config.sh -i soulbox.local
```

## Change Log

### Version 1.0.0 - 2025-08-30
**Initial Project Setup**
- Created comprehensive project structure
- Implemented systemd service configuration with proper security
- Developed optimized Pi 5 boot configuration
- Created automated setup script with user management
- Built image creation pipeline with debootstrap
- Implemented deployment system for configuration updates
- Established backup procedures for safe updates
- Added comprehensive documentation and troubleshooting guides

**Key Features Implemented:**
- Headless Kodi operation with GBM windowing
- Hardware-accelerated GPU with vc4/v3d drivers
- Optimized performance settings (700MHz GPU, 256MB memory)
- Service resilience with automatic restart
- Security hardening with restricted user permissions
- Comprehensive validation and diagnostic tools

## Contact and Support

**Project Repository**: https://github.com/[username]/soulbox
**Documentation**: This TFM.md file (keep updated)
**Issue Tracking**: GitHub Issues

---

**Last Updated**: 2025-08-30
**Next Review**: 2025-09-30
**Version**: 1.0.0
