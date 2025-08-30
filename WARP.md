# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Soulbox is a Debian-based Raspberry Pi 5 OS project designed as a media center solution. The system runs Kodi as a standalone media player service on Raspberry Pi 5 hardware with optimized GPU configurations.

**Key Components:**
- **Hardware**: Raspberry Pi 5 Model B Rev 1.0
- **OS**: Debian GNU/Linux 12 (bookworm)
- **Primary Service**: Kodi media center (kodi-standalone.service)
- **GPU**: BCM2712 with vc4/v3d drivers
- **User**: reaper (with video, render, audio group permissions)

## System Architecture

This project manages a headless media center with the following architecture:

- **Service Layer**: systemd-managed Kodi service running in standalone mode
- **Display Layer**: GBM (Generic Buffer Management) windowing with hardware-accelerated GPU
- **Hardware Layer**: Raspberry Pi 5 with optimized GPU memory allocation and frequency settings
- **Configuration Management**: Centralized in /boot/firmware/config.txt

## Common Development Commands

### Service Management
```bash
# Check Kodi service status
sudo systemctl status kodi-standalone.service

# Stop/start Kodi service
sudo systemctl stop kodi-standalone.service
sudo systemctl start kodi-standalone.service

# View service logs in real-time
journalctl -u kodi-standalone.service -f
```

### System Diagnostics
```bash
# Check GPU/DRM devices
ls /dev/dri/

# Verify GPU modules are loaded
lsmod | grep -E "(drm|v3d|vc4)"

# Test GPU communication
vcgencmd version

# Check user groups
groups reaper
```

### Configuration Management
```bash
# Validate GPU configuration for duplicates
grep -n "dtoverlay\|gpu_freq\|over_voltage" /boot/firmware/config.txt

# Create timestamped config backup before changes
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.backup.$(date +%Y%m%d)

# View current GPU settings
vcgencmd get_config int
```

## Critical Configuration Files

### /boot/firmware/config.txt
Contains GPU and hardware optimization settings. Key sections:

**GPU Settings (Pi 5)**:
```
dtoverlay=vc4-kms-v3d
max_framebuffers=2
gpu_mem=256
gpu_freq=700
over_voltage=2
```

**Video Optimization**:
```
hdmi_drive=2
hdmi_force_hotplug=1
hdmi_boost=7
h264_freq=600
hevc_freq=600
codec_enabled=ALL
```

### ~/TFM.md (The Fucking Manual)
System documentation containing:
- Hardware specifications and configurations
- Issue resolution history with root cause analysis  
- Service management procedures
- Troubleshooting commands and validation steps

## Known Issues and Solutions

### GPU Driver Compatibility (Pi 5 Specific)
- **Issue**: BCM2712 GPU requires different driver handling than Pi 4
- **Symptoms**: vc4-drm probe failures, missing /dev/dri/ devices
- **Resolution**: Ensure single dtoverlay=vc4-kms-v3d entry in config.txt

### Config File Corruption
- **Issue**: Duplicate entries in /boot/firmware/config.txt cause boot failures
- **Prevention**: Always validate for duplicates before modification
- **Detection**: Use grep commands to check for duplicate GPU settings

## Development Workflow

1. **Before Making Changes**: Always backup config.txt with timestamp
2. **System Changes**: Test GPU device creation after configuration updates
3. **Service Changes**: Verify service restart capability before deployment
4. **Documentation**: Update ~/TFM.md with all system modifications

## Security Considerations

- dmesg access requires sudo privileges
- UFW firewall is active
- User reaper has restricted group memberships for media access
- System hardening is implemented per security best practices

## Troubleshooting Priority

1. **GPU Issues**: Check /dev/dri/ devices first
2. **Service Issues**: Review journalctl logs for crash patterns
3. **Config Issues**: Validate /boot/firmware/config.txt for duplicates
4. **Hardware Issues**: Test GPU communication via vcgencmd

## Documentation Requirements

All system changes must be documented in ~/TFM.md with:
- Problem description and symptoms
- Root cause analysis
- Solution applied with exact commands
- Prevention measures for future occurrences
