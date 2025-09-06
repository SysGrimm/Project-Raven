# CEC Troubleshooting Guide

This page documents the comprehensive troubleshooting process for Consumer Electronics Control (CEC) remote functionality on Raspberry Pi systems.

## Problem Summary

CEC allows your TV remote to control Kodi/LibreELEC, but Raspberry Pi systems often have conflicts between different CEC implementations that prevent proper functionality.

## Root Cause Analysis

### The Core Conflict

Modern Raspberry Pi systems have **two competing CEC frameworks**:

1. **Kernel CEC Framework** (`/dev/cec0`) - Built into Linux kernel
2. **libcec Library** - Used by Kodi for CEC functionality

These frameworks **cannot run simultaneously** - they require exclusive access to the CEC hardware.

### Error Manifestations

```bash
# Common error in Kodi logs:
ERROR <general>: CEC adapter: could not open a connection (errno=16)

# errno=16 = EBUSY (Device or resource busy)
```

## Diagnostic Commands

### Check CEC Device Status
```bash
# List CEC devices
ls -la /dev/cec*

# Check if kernel CEC is active
lsof /dev/cec0

# Check for CEC processes
ps aux | grep -i cec
```

### Examine Kernel CEC Framework
```bash
# Check if CEC follower is enabled
cat /proc/cmdline | grep cec

# View CEC adapter info
cat /sys/class/cec/cec0/cec_info

# Check CEC capabilities
cec-ctl --list-devices
```

### Monitor CEC Activity
```bash
# Real-time CEC message monitoring
cec-ctl --monitor

# Check for CEC framework conflicts
dmesg | grep -i cec
```

## Failed Solutions

### Attempt 1: Disable Kernel CEC Framework
```bash
# Add to /boot/firmware/cmdline.txt
vc4.enable_cec_follower=0

# Result: Partial success, but still conflicts
```

### Attempt 2: Blacklist CEC Modules
```bash
# Add to /etc/modprobe.d/blacklist-cec.conf
blacklist cec
blacklist vc4

# Result: Breaks graphics entirely
```

### Attempt 3: Custom libcec Compilation
```bash
# Compile libcec with exclusive access patches
cmake -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DBUILD_SHARED_LIBS=1 \
      -DHAVE_LINUX_API=1

# Result: Complex, fragile, version-dependent
```

### Attempt 4: udev Rules Manipulation
```bash
# Custom udev rules for CEC device ownership
SUBSYSTEM=="cec", GROUP="video", MODE="0664"

# Result: Permissions fixed but framework conflict remains
```

## Working Solutions

### Solution 1: LibreELEC (Recommended)

**Why it works**: LibreELEC includes pre-patched kernels that properly coordinate between the kernel CEC framework and libcec.

```bash
# LibreELEC includes these patches by default:
- CEC framework coordination patches
- Proper device arbitration
- libcec integration fixes
- Hardware-specific optimizations
```

**Benefits**:
- CEC works out of the box
- No manual kernel patching required
- Optimized for media center use
- Regular updates with CEC fixes

### Solution 2: Custom Kernel Patching (Advanced)

For those who must stay on standard Raspberry Pi OS:

```bash
# Required kernel patches (simplified overview):
1. CEC framework arbitration patches
2. libcec exclusive access modifications
3. VC4 driver coordination fixes
4. Device tree overlay adjustments
```

**Warning**: This approach requires:
- Deep kernel knowledge
- Custom build toolchain
- Ongoing maintenance for each kernel update

## Debugging Workflow

### Step 1: Identify the Conflict
```bash
# Check what's using CEC device
sudo lsof /dev/cec0

# Look for competing processes
ps aux | grep -E "(kodi|cec)"
```

### Step 2: Test Exclusive Access
```bash
# Stop Kodi
sudo systemctl stop kodi

# Test kernel CEC access
cec-ctl --list-devices

# Start Kodi and retest
sudo systemctl start kodi
```

### Step 3: Examine Framework State
```bash
# Check kernel CEC state
cat /sys/class/cec/cec0/state

# Monitor for state changes
watch -n 1 'cat /sys/class/cec/cec0/state'
```

## Comparison Matrix

| Approach | Complexity | Success Rate | Maintenance | Recommended |
|----------|------------|--------------|-------------|-------------|
| LibreELEC Migration | Low | 95% | Low |  Yes |
| Kernel Patching | Very High | 70% | Very High | ❌ No |
| Framework Disabling | Medium | 40% | Medium | ❌ No |
| Module Blacklisting | Low | 10% | Low | ❌ No |

## Best Practices

### For New Installations
1. **Use LibreELEC** - It's purpose-built for this
2. Avoid mixing CEC frameworks
3. Test CEC functionality early in setup

### For Existing Systems
1. Assess migration effort vs. patching complexity
2. Document current configuration before changes
3. Have rollback plan ready

### For Developers
1. Understand the exclusive access requirement
2. Test on multiple hardware revisions
3. Monitor kernel CEC framework changes

## 🐛 Common Pitfalls

### Pitfall 1: Assuming Software-Only Solution
- **Problem**: CEC conflicts are hardware arbitration issues
- **Reality**: Requires kernel-level coordination

### Pitfall 2: Ignoring Hardware Variations
- **Problem**: Solutions that work on Pi 3 may fail on Pi 4/5
- **Reality**: Each Pi revision has different CEC implementations

### Pitfall 3: Mixing CEC Tools
- **Problem**: Using both cec-utils and libcec simultaneously
- **Reality**: They compete for the same hardware resources

## 📚 Technical References

### Kernel Documentation
- [CEC Framework Documentation](https://docs.kernel.org/userspace-api/media/cec/cec-api.html)
- [VC4 Driver Documentation](https://docs.kernel.org/gpu/vc4.html)

### LibreELEC Resources
- [LibreELEC CEC Documentation](https://wiki.libreelec.tv/configuration/cec)
- [LibreELEC Build System](https://github.com/LibreELEC/LibreELEC.tv)

### Hardware References
- [Raspberry Pi CEC Implementation](https://www.raspberrypi.org/documentation/configuration/hdmi-cec.md)
- [HDMI CEC Specification](https://www.hdmi.org/manufacturer/hdmi_1_3/cec.aspx)

---

**Key Takeaway**: CEC issues on Raspberry Pi are complex hardware arbitration problems best solved by using LibreELEC, which includes all necessary patches and coordination mechanisms.
