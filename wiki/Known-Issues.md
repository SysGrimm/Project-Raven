# Known Issues and Limitations

This page documents current known issues, limitations, and workarounds for Project-Raven components.

## Critical Issues

### Issue #1: bcmstat Package GitHub Archive Filename Mismatch
**Status**: Under Active Investigation  
**Affects**: All LibreELEC builds  
**Symptoms**: Build fails at package 1/290 with "File bcmstat-HASH.tar.gz doesn't exist"

**Details**:
- bcmstat package downloads from GitHub as `HASH.tar.gz`
- LibreELEC extract script expects `bcmstat-HASH.tar.gz`
- Multiple fix approaches tested including LibreELEC get script patching
- Build progression improved from immediate failures to 2-3 minute consistent failures

**Current Status**: 
- [SUCCESS] Universal Package Download System implemented
- [SUCCESS] Build workflow optimization completed  
- [SUCCESS] Multiple workflow trigger conflicts resolved
- [UPDATE] **Active Work**: Direct filename resolution during download phase

**Tracking**: High priority - blocking all LibreELEC builds

### Issue #2: Raspberry Pi 5 CEC Intermittent Failures
**Status**: Under Investigation  
**Affects**: Raspberry Pi 5 with specific TV models  
**Symptoms**: CEC remote control works initially but stops responding after 30-60 minutes

**Workaround**:
```bash
# Add to /flash/config.txt
hdmi_force_hotplug=1
cec_osd_name=LibreELEC

# Restart CEC service periodically (temporary fix)
# Add to crontab: */30 * * * * systemctl restart cec-adapter@1
```

**Root Cause**: Suspected timing issue in Pi 5 CEC implementation  
**Tracking**: [GitHub Issue #42](https://github.com/SysGrimm/Project-Raven/issues/42)

### Issue #3: Tailscale Authentication Timeout on Slow Networks
**Status**: [CONFIG] Known Limitation  
**Affects**: Networks with >500ms latency to Tailscale servers  
**Symptoms**: Add-on shows "Authentication failed" during initial setup

**Workaround**:
```bash
# Increase timeout in Tailscale add-on
# Edit default.py, line 156:
TAILSCALE_AUTH_TIMEOUT = 300  # Increase from 60 to 300 seconds

# Or authenticate manually via SSH
ssh root@libreelec-ip
cd /storage/.kodi/addons/service.tailscale
./bin/tailscale up --timeout=300s
```

**Root Cause**: Default timeout too aggressive for high-latency connections  
**Fix Status**: Will be addressed in v2.1 release

## Major Limitations

### Limitation #1: No HDR10+ Support on Generic x86_64 Builds
**Affects**: Generic PC builds, Intel/AMD graphics  
**Description**: HDR10+ metadata passthrough not supported on x86_64 builds

**Impact**: 
- HDR10 works correctly
- HDR10+ content falls back to standard HDR10
- Dolby Vision not affected (separate limitation)

**Planned Fix**: LibreELEC 13.x will include improved HDR support

### Limitation #2: Tailscale Subnet Routing Requires Manual Configuration
**Affects**: Users wanting to access entire local network through VPN  
**Description**: Automatic subnet advertisement not implemented

**Current Process**:
```bash
# Manual subnet routing setup required
1. Enable IP forwarding on router
2. Add static routes on router to Tailscale IP
3. Configure firewall rules for subnet access
4. Manually advertise routes in Tailscale settings
```

**Planned Enhancement**: Automatic subnet detection in future release

### Limitation #3: Custom Theme Modifications Lost on Updates
**Affects**: Users with heavily customized themes  
**Description**: LibreELEC updates overwrite custom theme files

**Mitigation Strategy**:
```bash
# Backup themes before updates
cp -r /storage/.kodi/addons/skin.* /storage/theme-backup/

# Use overlay directory for persistent customizations
mkdir -p /storage/.kodi/userdata/theme-overlay/
# Place custom files here - they survive updates
```

## 🐛 Minor Issues

### Issue #3: YouTube Add-on Occasional Playback Stutters
**Status**:  Workaround Available  
**Affects**: 4K YouTube content on Pi 4 (not Pi 5)  
**Symptoms**: Occasional frame drops during 4K playback

**Workaround**:
```bash
# Reduce YouTube quality for Pi 4
# In YouTube add-on settings:
# Video Quality: Set to 1080p instead of 4K
# Or adjust GPU memory split:
# Add to /flash/config.txt:
gpu_mem=256  # Increase from default 128
```

### Issue #4: SMB Share Discovery Slow on Some Networks
**Status**:  Configuration Issue  
**Affects**: Networks with multiple subnets or complex topologies  
**Symptoms**: SMB shares take 30+ seconds to appear in file browser

**Solution**:
```bash
# Add SMB shares manually instead of using discovery
# Settings → Media → Library → Videos → Add videos...
# Use direct paths: smb://ip-address/sharename
# Instead of browsing network neighborhood
```

### Issue #5: Tailscale Status Display Incorrect After Sleep/Resume
**Status**:  Cosmetic Issue  
**Affects**: All platforms  
**Symptoms**: Add-on status shows "Disconnected" even when VPN works

**Workaround**:
```bash
# Status display refresh needed after resume
# Use "Show status" button in add-on settings to refresh
# Or restart add-on: Settings → Add-ons → service.tailscale → Disable/Enable
```

## Build System Issues

### Issue #6: Build Fails on macOS with Xcode 15+
**Status**:  Under Investigation  
**Affects**: macOS users with latest Xcode  
**Symptoms**: LibreELEC build fails during cross-compilation

**Workaround**:
```bash
# Use Docker-based build instead
cd libreelec-custom-build
docker run -v $(pwd):/workspace \
  libreelec/libreelec-builder:latest \
  /workspace/scripts/build-image.sh

# Or downgrade to Xcode 14.x temporarily
```

### Issue #7: Incremental Builds Sometimes Corrupted
**Status**:  Workaround Available  
**Affects**: Development builds  
**Symptoms**: Build succeeds but resulting image doesn't boot

**Solution**:
```bash
# Always do clean build for production images
cd build-env
make clean
PROJECT=RPi DEVICE=RPi4 make image

# For development, clean specific packages:
make clean-package-kodi
make clean-package-tailscale
```

## [MOBILE] Mobile App Compatibility

### Kore Remote App Issues

#### Issue #8: Kore Connection Timeout via Tailscale
**Affects**: Android Kore app v2.5.x  
**Symptoms**: App can't connect to Kodi via Tailscale IP

**Workaround**:
```bash
# Use IP address instead of hostname in Kore
# Enter: 100.x.x.x:8080
# Instead of: libreelec-device:8080

# Or enable mDNS in Tailscale (if supported by network)
```

#### Issue #9: iOS Kore App Playlist Sync Issues
**Affects**: iOS Kore app with large playlists (>1000 items)  
**Symptoms**: Playlist sync never completes

**Solution**:
```bash
# Limit playlist size or use alternative remote apps
# Recommended alternatives: Sybu for Kodi, Yatse
```

## Hardware-Specific Issues

### Raspberry Pi 4 Specific

#### Issue #10: USB 3.0 Interference with 2.4GHz WiFi
**Status**:  Known Hardware Limitation  
**Affects**: Pi 4 with USB 3.0 devices and 2.4GHz WiFi  
**Symptoms**: WiFi performance degrades when USB 3.0 devices active

**Mitigation**:
```bash
# Use 5GHz WiFi when possible
# Or limit USB 3.0 to USB 2.0 speeds:
# Add to /flash/config.txt:
dwc_otg.speed=1

# Use shielded USB 3.0 cables to reduce interference
```

### Raspberry Pi 5 Specific

#### Issue #11: Power Management Incompatibility with Some USB Hubs
**Affects**: Pi 5 with older USB hubs  
**Symptoms**: Connected devices randomly disconnect

**Solution**:
```bash
# Disable USB power management
# Add to /flash/config.txt:
usb_max_current_enable=1

# Or use powered USB hub with Pi 5 compatible power management
```

## Network-Related Issues

### Issue #12: Double NAT Prevents Tailscale Direct Connections
**Status**:  Network Configuration Issue  
**Affects**: Networks with double NAT (ISP modem + router)  
**Symptoms**: All Tailscale traffic routes through DERP relays

**Solutions**:
```bash
# Option 1: Enable UPnP on both devices
# Option 2: Configure port forwarding for Tailscale
# Port 41641 UDP on both router and ISP modem

# Option 3: Use bridge mode on ISP modem
# Contact ISP for bridge mode configuration
```

### Issue #13: Corporate Firewall Blocks Tailscale
**Affects**: Users on corporate networks  
**Symptoms**: Tailscale can't establish any connections

**Workaround**:
```bash
# Configure Tailscale to use HTTPS fallback
# In Tailscale add-on advanced settings:
# Enable "Use HTTPS for control connections"
# This works through most corporate firewalls
```

## 🔮 Future Improvements

### Planned Fixes (v2.1 Release)
- [ ] Fix Tailscale authentication timeout issue
- [ ] Improve CEC reliability on Pi 5
- [ ] Add automatic subnet routing detection
- [ ] Enhance build system macOS compatibility

### Planned Features (v2.2 Release)
- [ ] HDR10+ support for x86_64 builds
- [ ] Advanced theme overlay system
- [ ] Improved mobile app compatibility
- [ ] Built-in backup/restore functionality

### Long-term Roadmap (v3.0)
- [ ] Container-based add-on system
- [ ] AI-powered media recommendations
- [ ] Advanced network monitoring
- [ ] Multi-room audio/video synchronization

## Issue Priority Matrix

| Issue | Severity | Frequency | Impact | Priority |
|-------|----------|-----------|---------|----------|
| Pi 5 CEC failures | High | Medium | High | 🔴 Critical |
| Tailscale auth timeout | Medium | Low | Medium | 🟡 High |
| YouTube 4K stutters | Low | Medium | Low | 🟢 Medium |
| SMB discovery slow | Low | High | Low | 🟢 Medium |
| Build system issues | Medium | Low | High | 🟡 High |

## 🤝 Contributing

### Reporting New Issues
When reporting issues, please include:

1. **Hardware**: Exact device model and revision
2. **Software**: LibreELEC version, add-on versions
3. **Network**: Network topology and ISP details
4. **Logs**: Relevant log excerpts (sanitized)
5. **Reproduction**: Step-by-step reproduction instructions

### Issue Templates
Use the provided GitHub issue templates:
- Bug Report Template
- Feature Request Template  
- Build System Issue Template
- Network Configuration Template

### Debug Information Collection
```bash
# Collect system information
cat /etc/os-release
cat /proc/cpuinfo | grep Model
df -h
free -h

# Collect relevant logs
tail -n 100 /storage/.kodi/temp/kodi.log
journalctl -u tailscaled --no-pager -n 50
dmesg | grep -i cec | tail -20

# Network diagnostics
tailscale status
ip route show
```

---

**Last Updated**: September 5, 2025  
**Next Review**: October 2025

For real-time issue tracking, see the [Project-Raven Issues page](https://github.com/SysGrimm/Project-Raven/issues) on GitHub.
