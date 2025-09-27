# Project Raven Video Optimization Context

## LibreELEC Integration Patterns
Project Raven implements video optimizations based on LibreELEC research:

### GPU Memory Management
- Dynamic GPU memory allocation based on detected Raspberry Pi model
- Pi 4: 128MB-256MB depending on RAM configuration  
- Pi 5: 128MB-512MB with intelligent scaling
- CMA (Contiguous Memory Allocator) optimization for video buffers

### Hardware Acceleration Stack
- **V4L2 M2M**: Memory-to-memory video processing
- **SAND Format**: Broadcom's tiled memory format for efficiency
- **MMAL**: Multimedia Abstraction Layer (legacy support)
- **FFmpeg Integration**: Hardware-accelerated codec paths

### Performance Critical Areas
1. **Memory Bandwidth**: Optimize for ARM64 memory subsystem
2. **Thermal Management**: Balance performance vs. heat generation
3. **I/O Scheduling**: Prioritize video data streams
4. **CPU Governor**: Dynamic frequency scaling for media workloads

### Configuration Files Managed
- `/boot/config.txt`: Hardware configuration and GPU memory
- `/boot/cmdline.txt`: Kernel parameters for video optimization
- `/etc/systemd/system/`: Performance-related services
- Device tree overlays for hardware-specific optimizations

### Testing Approach  
- **Pi-CI Integration**: Hardware-less testing environment
- **Thermal Monitoring**: Ensure optimizations don't cause overheating
- **Performance Metrics**: Video decode performance benchmarking
- **Compatibility Testing**: Ensure broad codec support

### Critical Dependencies
- `optimize-video.sh`: 555-line comprehensive optimization script
- `configure-kodi.sh`: Media center application configuration  
- `firstboot.sh`: Automated system setup and optimization application
- Boot splash system: Mandatory branding during system initialization
