# SoulBox

**A Debian-based Raspberry Pi 5 media center OS optimized for Kodi**

## Overview

SoulBox is a specialized Debian GNU/Linux 12 (bookworm) distribution designed specifically for Raspberry Pi 5 hardware to deliver a high-performance, headless media center experience. The system runs Kodi in standalone mode with hardware-accelerated GPU rendering for optimal 4K media playback.

## Key Features

- **Hardware-Optimized**: Specifically tuned for Raspberry Pi 5 BCM2712 SoC
- **GPU Acceleration**: Full vc4/v3d driver support with optimized frequencies
- **Headless Operation**: Standalone Kodi service without desktop overhead
- **Service Management**: systemd-managed with automatic restart capabilities
- **Performance Tuned**: Optimized GPU memory allocation and codec support

## Hardware Requirements

- Raspberry Pi 5 Model B (any RAM variant)
- MicroSD card (32GB+ recommended)
- HDMI display
- Power supply (official Pi 5 PSU recommended)

## Architecture

```
Kodi Media Center
    ↓
GBM Windowing System
    ↓
vc4/v3d GPU Drivers
    ↓
Raspberry Pi 5 BCM2712
```

## Quick Start

1. Flash the SoulBox image to your SD card
2. Insert into Raspberry Pi 5
3. Connect HDMI and power on
4. Kodi will start automatically

## Documentation

- **[TFM.md](TFM.md)**: Complete technical documentation and troubleshooting guide
- **[WARP.md](WARP.md)**: Development guidelines and project context

## System Specifications

- **OS**: Debian GNU/Linux 12 (bookworm)
- **Kernel**: Optimized for Pi 5 with vc4-kms-v3d overlay
- **Graphics**: Hardware-accelerated with 256MB GPU memory
- **Service**: kodi-standalone running as dedicated user
- **Codecs**: Full hardware codec support (H.264, HEVC, etc.)

## Support

For technical issues, configuration problems, or troubleshooting, please refer to the comprehensive [TFM.md](TFM.md) documentation.

## License

This project is licensed under the terms specified in [LICENSE](LICENSE).
