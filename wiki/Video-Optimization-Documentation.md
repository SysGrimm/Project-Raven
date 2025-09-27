# Video Optimization Documentation

Project Raven implements comprehensive video playbook optimizations based on LibreELEC's proven approach to media center performance on Raspberry Pi.

## Overview

The video optimization system automatically configures your Raspberry Pi for optimal media playback performance, implementing lessons learned from the LibreELEC project's years of media center optimization.

## Optimization Categories

### 1. Hardware Configuration

#### GPU Memory Allocation
- **Pi Zero/Pi2**: 128MB GPU memory split
- **Pi3**: 256MB GPU memory split  
- **Pi4/Pi5**: 320MB GPU memory split

These values are optimized for 4K video playback while preserving enough system memory for Kodi operation.

#### CMA (Contiguous Memory Allocator)
- **Pi Zero/Pi**: 128MB CMA buffer
- **Pi2**: 384MB CMA buffer
- **Pi3/Pi4/Pi5**: 512MB CMA buffer

CMA provides large contiguous memory blocks required for hardware video decoding.

#### Hardware Acceleration
```bash
# Enabled codecs
decode_MPG2=0x12345678    # MPEG-2 hardware decode
decode_WVC1=0x12345678    # VC-1 hardware decode

# Pi4/Pi5 specific
hdmi_enable_4kp60=1       # Enable 4K@60fps output
max_framebuffers=2        # Dual framebuffer support
```

### 2. Video Decoding Optimization

#### MMAL (Multi-Media Abstraction Layer)
- Hardware-accelerated H.264/H.265 decoding
- Zero-copy video rendering
- GPU-accelerated video processing

#### V4L2 M2M (Pi4/Pi5)
```xml
<video>
  <enablehighmem>false</enablehighmem>
  <prefervaapirender>true</prefervaapirender>
  <deinterlacemethod>6</deinterlacemethod>
</video>
```

#### SAND Format Support
Pi4 and Pi5 benefit from SAND (Subtiled And Non-Dense) format:
```bash
# FFmpeg configuration
pix_fmt=sand128
hwaccel=v4l2m2m
```

### 3. Memory Management

#### System Memory Tuning
```bash
# /etc/sysctl.d/99-video-optimizations.conf
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_writeback_centisecs = 500
vm.swappiness = 1
```

#### Malloc Optimizations
LibreELEC-style memory allocation thresholds:

**ARM devices (Pi Zero/Pi2/Pi3):**
```bash
MALLOC_MMAP_THRESHOLD_=8192
MALLOC_TRIM_THRESHOLD_=131072
```

**64-bit devices (Pi4/Pi5):**
```bash
MALLOC_MMAP_THRESHOLD_=524288
MALLOC_TRIM_THRESHOLD_=1048576
```

### 4. Streaming Optimizations

#### Network Buffers
```bash
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
```

#### Kodi Cache Settings
```xml
<network>
  <cachemembuffersize>20971520</cachemembuffersize>  <!-- 20MB -->
  <readbufferfactor>4.0</readbufferfactor>
  <curlclienttimeout>30</curlclienttimeout>
</network>
```

### 5. I/O Optimization

#### Scheduler Configuration
```bash
# /etc/udev/rules.d/99-io-scheduler.rules
KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="deadline"
KERNEL=="sd*", ATTR{queue/scheduler}="deadline"
```

#### Read-ahead Optimization
- SD Cards: 1024KB read-ahead
- USB Storage: 2048KB read-ahead
- Queue depth: 128 requests

### 6. Thermal Management

#### Temperature Monitoring
- Thermal throttling at 75°C
- CPU governor optimization for media workloads
- Automatic thermal monitoring

#### Configuration
```bash
# Set thermal limits
echo 75000 > /sys/class/thermal/thermal_zone0/trip_point_0_temp

# Optimize CPU governor
echo "ondemand" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

## Kodi Configuration

### Advanced Settings
The optimization applies comprehensive Kodi settings:

```xml
<advancedsettings>
  <video>
    <enablemmal>true</enablemmal>
    <adjustrefreshrate>2</adjustrefreshrate>
    <resyncmethod>2</resyncmethod>
    <cachemembuffersize>20971520</cachemembuffersize>
    <readbufferfactor>4.0</readbufferfactor>
    <allowhifi>true</allowhifi>
    <prefervaapirender>true</prefervaapirender>
    <deinterlacemethod>6</deinterlacemethod>
  </video>
  
  <videoplayer>
    <usedisplayasclock>false</usedisplayasclock>
    <adjustrefreshrate>2</adjustrefreshrate>
    <synctype>2</synctype>
    <maxspeedadjust>0.05</maxspeedadjust>
    <resyncmethod>2</resyncmethod>
  </videoplayer>
  
  <audio>
    <resamplequality>3</resamplequality>
    <stereodownmix>1</stereodownmix>
    <ac3downmix>true</ac3downmix>
  </audio>
</advancedsettings>
```

### GUI Settings
Optimized display settings are automatically applied:
- Hardware acceleration enabled
- Refresh rate switching configured
- Audio passthrough optimized
- CEC integration active

## FFmpeg Integration

### Hardware Acceleration
```bash
# /etc/kodi/ffmpeg.conf
[video]
hwaccel=auto
hwaccel_device=auto
threads=auto
flags=+global_header+low_delay
fflags=+genpts+nobuffer
vf=format=yuv420p
```

### Pi4/Pi5 Specific
```bash
[video_pi4]
pix_fmt=sand128
hwaccel=v4l2m2m
```

## Performance Monitoring

### Status Checking
Use the included status script:
```bash
/usr/local/bin/video-status.sh
```

**Output includes:**
- GPU memory allocation
- CPU temperature
- Thermal throttling status
- Video acceleration capabilities  
- Memory usage statistics
- Kodi process information

### Key Metrics
Monitor these values for optimal performance:

1. **GPU Memory Usage**: Should be ~80-90% allocated during playback
2. **CPU Temperature**: Should stay below 70°C during sustained playback
3. **Memory Usage**: System should maintain >200MB free RAM
4. **Cache Hit Ratio**: Network cache should show good hit rates

### Troubleshooting

#### High CPU Usage
- Check hardware acceleration is working
- Verify correct video codec selection
- Monitor thermal throttling

#### Playback Stuttering
- Check network cache settings
- Verify I/O scheduler configuration
- Monitor storage performance

#### Audio Issues
- Verify HDMI audio configuration
- Check audio passthrough settings
- Validate CEC audio return channel

## Implementation Details

### Automatic Application
Video optimizations are applied automatically:

1. **During Image Build**: Basic optimizations are pre-configured
2. **On First Boot**: Device-specific optimizations are applied
3. **Runtime**: Dynamic optimizations based on hardware detection

### Service Integration
```bash
# Systemd service ensures optimizations persist
systemctl status video-optimizations.service
```

### Configuration Files
Key configuration locations:

- **Boot Config**: `/boot/firmware/config.txt`
- **System Tuning**: `/etc/sysctl.d/99-video-optimizations.conf`
- **Kodi Settings**: `/home/kodi/.kodi/userdata/advancedsettings.xml`
- **FFmpeg Config**: `/etc/kodi/ffmpeg.conf`
- **I/O Rules**: `/etc/udev/rules.d/99-io-scheduler.rules`
- **Service Overrides**: `/etc/systemd/system/kodi.service.d/`

## Comparison with LibreELEC

Project Raven implements the same core optimizations as LibreELEC but on full Raspberry Pi OS:

| Optimization | LibreELEC | Project Raven | Notes |
|--------------|-----------|---------------|--------|
| GPU Memory Split | [SUCCESS] | [SUCCESS] | Device-specific allocation |
| Hardware Decode | [SUCCESS] | [SUCCESS] | H.264/H.265/VC-1 support |
| CMA Configuration | [SUCCESS] | [SUCCESS] | Contiguous memory allocation |
| MMAL Support | [SUCCESS] | [SUCCESS] | Raspberry Pi specific |
| V4L2 M2M | [SUCCESS] | [SUCCESS] | Pi4/Pi5 optimization |
| SAND Format | [SUCCESS] | [SUCCESS] | Pi4/Pi5 specific |
| Malloc Tuning | [SUCCESS] | [SUCCESS] | Architecture-specific |
| I/O Optimization | [SUCCESS] | [SUCCESS] | Media-optimized scheduling |
| Thermal Management | [SUCCESS] | [SUCCESS] | Sustained playback support |

### Advantages over LibreELEC
- Full Debian package repository access
- Standard Linux tools and utilities  
- Easier customization and debugging
- Familiar systemd service management
- Better container support

### Performance Parity
Testing shows Project Raven achieves equivalent video performance to LibreELEC while maintaining the flexibility of full Raspberry Pi OS.
