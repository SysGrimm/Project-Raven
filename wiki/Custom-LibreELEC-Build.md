# Custom LibreELEC Build System

This page documents the complete process for creating custom LibreELEC images with pre-installed add-ons, themes, and configurations.

## Build System Overview

The custom build system extends LibreELEC's official build framework to create turnkey media center images with:
- **Universal Package Download System** for reliable builds
- **Tailscale VPN** pre-configured
- **Custom themes** and skins
- **Essential add-ons** pre-installed
- **Optimized settings** for your hardware

For comprehensive build reliability, see the **[Universal Package Download System](Universal-Package-Download-System.md)** documentation.

## [FOLDER] Build Directory Structure

```
libreelec-custom-build/
├── build-env/                 # LibreELEC source and build environment
├── packages/                  # Custom package definitions
│   └── addons/
│       └── service/
│           └── tailscale/     # Tailscale add-on package
├── projects/                  # Hardware-specific configurations
│   └── RPi/
│       └── devices/
│           └── RPi4/          # Raspberry Pi 4 specific
├── config/                    # Build configuration files
│   ├── addon-bundles.conf     # Pre-installed add-on lists
│   ├── theme-config.conf      # Theme customization settings
│   └── build-options.conf     # Build system options
├── themes/                    # Custom theme files
│   ├── raven-theme/           # Custom Project-Raven theme
│   └── modifications/         # Theme modifications
├── scripts/                   # Build automation scripts
│   ├── build-image.sh         # Main build script
│   ├── setup-environment.sh   # Environment setup
│   └── customize-image.sh     # Post-build customization
└── output/                    # Generated images and logs
    ├── images/                # Final bootable images
    └── logs/                  # Build logs and reports
```

## Environment Setup

### Prerequisites
```bash
# Required packages for macOS
brew install wget git rsync gawk coreutils

# Create build workspace
cd /Users/grimm/Desktop/dev/Project-Raven
mkdir -p libreelec-custom-build
cd libreelec-custom-build
```

### LibreELEC Source Setup
```bash
# Clone LibreELEC source
git clone https://github.com/LibreELEC/LibreELEC.tv.git build-env
cd build-env

# Switch to stable branch
git checkout libreelec-12.0

# Setup build dependencies
PROJECT=RPi DEVICE=RPi4 ARCH=arm ./scripts/install
```

## Package Configuration

### Tailscale Add-on Package
The Tailscale add-on is defined in `packages/addons/service/tailscale/package.mk`:

```bash
PKG_NAME="tailscale"
PKG_VERSION="1.82.1"
PKG_SITE="https://tailscale.com"
PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_${TARGET_ARCH}.tgz"
PKG_DEPENDS_TARGET="toolchain"
PKG_IS_ADDON="yes"
PKG_ADDON_TYPE="xbmc.service"
PKG_ADDON_PROVIDES=""
PKG_LONGDESC="Tailscale VPN service for LibreELEC"

# Architecture-specific binary selection
case $TARGET_ARCH in
  arm)
    PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_arm.tgz"
    ;;
  aarch64)
    PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_arm64.tgz"
    ;;
  x86_64)
    PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_amd64.tgz"
    ;;
esac

makeinstall_target() {
  mkdir -p $INSTALL/usr/share/kodi/addons/service.tailscale
  cp -r $PKG_BUILD/source/* $INSTALL/usr/share/kodi/addons/service.tailscale/
  
  mkdir -p $INSTALL/usr/share/kodi/addons/service.tailscale/bin
  cp $PKG_BUILD/tailscale $INSTALL/usr/share/kodi/addons/service.tailscale/bin/
  cp $PKG_BUILD/tailscaled $INSTALL/usr/share/kodi/addons/service.tailscale/bin/
}
```

### Essential Add-ons Bundle
Pre-install popular add-ons via `config/addon-bundles.conf`:

```ini
[essential-addons]
# Media sources
repository.kodinerds=https://repo.kodinerds.net/
plugin.video.youtube=official

# Network tools  
script.module.requests=official
service.tailscale=custom

# System utilities
script.module.pycryptodome=official

[media-addons]
# Streaming services
plugin.video.netflix=repository.castagnait
plugin.video.amazon-prime=repository.castagnait

# Local media tools
service.upnp=official
plugin.video.emby=repository.emby
```

## Theme Customization

### Custom Theme Structure
```
themes/raven-theme/
├── skin.estuary.raven/        # Modified Estuary skin
│   ├── addon.xml              # Theme manifest
│   ├── media/                 # Custom graphics
│   │   ├── backgrounds/       # Background images
│   │   ├── icons/            # Custom icons
│   │   └── logos/            # Branding elements
│   ├── xml/                   # Layout modifications
│   │   ├── Home.xml          # Home screen layout
│   │   └── DialogPVRInfo.xml # UI customizations
│   └── colors/               # Color schemes
│       └── raven.xml         # Project-Raven colors
```

### Theme Installation Process
```bash
# Theme gets installed during build process
addon_install_theme() {
  local theme_dir="$1"
  local install_dir="$INSTALL/usr/share/kodi/addons/"
  
  # Copy theme files
  cp -r "$theme_dir" "$install_dir"
  
  # Set as default theme in Kodi settings
  echo "lookandfeel.skin=skin.estuary.raven" >> \
    "$INSTALL/usr/share/kodi/system/settings/settings.xml"
}
```

## Build Process

### Main Build Script
The `scripts/build-image.sh` handles the complete build process:

```bash
#!/bin/bash
set -e

PROJECT="${PROJECT:-RPi}"
DEVICE="${DEVICE:-RPi4}" 
ARCH="${ARCH:-arm}"

echo "Building custom LibreELEC image for $PROJECT/$DEVICE..."

# 1. Setup environment
source scripts/setup-environment.sh

# 2. Configure build options
configure_build_options() {
  export LIBREELEC_OPTIONS="
    --with-ffmpeg-vaapi
    --enable-webserver
    --enable-cec
  "
}

# 3. Build base image
build_base_image() {
  cd build-env
  PROJECT=$PROJECT DEVICE=$DEVICE ARCH=$ARCH make image
}

# 4. Customize image
customize_image() {
  source ../scripts/customize-image.sh
}

# 5. Generate final image
finalize_image() {
  local image_name="LibreELEC-$PROJECT.$DEVICE-raven-$(date +%Y%m%d).img"
  mv build-env/target/*.img "output/images/$image_name"
  echo "Custom image created: $image_name"
}

# Execute build stages
configure_build_options
build_base_image
customize_image  
finalize_image
```

### Customization Script
The `scripts/customize-image.sh` applies post-build modifications:

```bash
#!/bin/bash

customize_kodi_settings() {
  local settings_file="$MOUNT_POINT/usr/share/kodi/system/settings/settings.xml"
  
  # Enable web interface
  xmlstarlet ed -u "//setting[@id='services.webserver']/@default" -v "true" "$settings_file"
  
  # Set default theme
  xmlstarlet ed -u "//setting[@id='lookandfeel.skin']/@default" -v "skin.estuary.raven" "$settings_file"
  
  # Configure CEC
  xmlstarlet ed -u "//setting[@id='input.enablecec']/@default" -v "true" "$settings_file"
}

install_custom_addons() {
  local addon_dir="$MOUNT_POINT/usr/share/kodi/addons"
  
  # Install Tailscale add-on
  cp -r ../packages/addons/service/tailscale/source/* "$addon_dir/service.tailscale/"
  
  # Install theme
  cp -r ../themes/raven-theme/skin.estuary.raven "$addon_dir/"
}

configure_networking() {
  # Pre-configure connman for VPN compatibility
  cat > "$MOUNT_POINT/storage/.config/connman.conf" << EOF
[General]
PreferredTechnologies=ethernet,wifi
AllowHostnameUpdates=false
AllowDomainnameUpdates=false
EOF
}
```

## Hardware-Specific Builds

### Raspberry Pi 4/5 Configuration
```bash
# projects/RPi/devices/RPi4/options
TARGET_KERNEL_ARCH=arm64
TARGET_ARCH=aarch64
TARGET_CPU=cortex-a72
TARGET_FLOAT=hard

# Enable hardware features
KODI_ARCH="aarch64"
KODI_EXTRA_OPTS="--enable-gles --enable-vdpau"

# CEC-specific options
EXTRA_CMDLINE="vc4.enable_cec_follower=1"
```

### x86_64 Generic PC Configuration  
```bash
# projects/Generic/devices/x86_64/options
TARGET_KERNEL_ARCH=x86_64
TARGET_ARCH=x86_64
TARGET_CPU=x86-64

# Enable Intel/AMD features
KODI_EXTRA_OPTS="--enable-vaapi --enable-vdpau --enable-gl"
KERNEL_OPTS="i915.enable_guc=2 i915.enable_fbc=1"
```

## Build Performance

### Build Times (Approximate)
| Hardware | Clean Build | Incremental | Custom Image |
|----------|-------------|-------------|--------------|
| MacBook Pro M1 | 45 min | 5 min | 55 min |
| MacBook Pro Intel | 75 min | 8 min | 90 min |
| Linux Workstation | 35 min | 4 min | 45 min |

### Optimization Tips
```bash
# Use ccache for faster rebuilds
export USE_CCACHE=yes
export CCACHE_DIR="$HOME/.ccache"

# Parallel build jobs
export MAKEFLAGS="-j$(nproc)"

# Skip unnecessary packages
export BUILD_MINIMAL=yes
```

## Automated Builds

### GitHub Actions Integration
Create `.github/workflows/build-image.yml`:

```yaml
name: Build Custom LibreELEC Image

on:
  push:
    branches: [ main ]
    paths: 
      - 'libreelec-custom-build/**'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        device: [RPi4, RPi5, Generic]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Build Environment
      run: |
        sudo apt-get update
        sudo apt-get install -y build-essential git wget
        
    - name: Build LibreELEC Image
      run: |
        cd libreelec-custom-build
        DEVICE=${{ matrix.device }} bash scripts/build-image.sh
        
    - name: Upload Image Artifacts
      uses: actions/upload-artifact@v3
      with:
        name: libreelec-${{ matrix.device }}-image
        path: libreelec-custom-build/output/images/*.img
```

### Local Development Builds
```bash
# Quick development build
DEVICE=RPi4 QUICK_BUILD=yes ./scripts/build-image.sh

# Clean build with full customization
DEVICE=RPi4 CLEAN_BUILD=yes ./scripts/build-image.sh

# Build for multiple devices
for device in RPi4 RPi5 Generic; do
  DEVICE=$device ./scripts/build-image.sh &
done
wait
```

## Testing and Validation

### Image Testing Process
```bash
# Automated testing script
test_image() {
  local image="$1"
  
  # Mount image for inspection
  mkdir -p /tmp/test-mount
  sudo mount -o loop,offset=1048576 "$image" /tmp/test-mount
  
  # Verify add-ons are installed
  test -d "/tmp/test-mount/usr/share/kodi/addons/service.tailscale" || exit 1
  test -d "/tmp/test-mount/usr/share/kodi/addons/skin.estuary.raven" || exit 1
  
  # Check configurations
  grep -q "services.webserver.*true" "/tmp/test-mount/usr/share/kodi/system/settings/settings.xml" || exit 1
  
  sudo umount /tmp/test-mount
  echo "Image validation passed: $image"
}
```

### Hardware Testing
- **Boot Test**: Verify image boots successfully
- **CEC Test**: Confirm remote control functionality
- **Network Test**: Validate Tailscale connectivity
- **Performance Test**: Check media playback performance

## Troubleshooting Build Issues

### Common Build Problems

#### Missing Dependencies
```bash
# Install missing build dependencies
sudo apt-get install -y \
  build-essential git mercurial wget cpio gzip unzip \
  gcc g++ xsltproc java-common default-jre-headless
```

#### Disk Space Issues
```bash
# Clean build cache
cd build-env
make clean

# Monitor disk usage during build
df -h . | grep -v Filesystem
```

#### Network/Download Failures
```bash
# Retry failed downloads
make download

# Use local mirror for packages
export PKG_MIRROR="http://local-mirror.example.com/packages"
```

### Debug Build Process
```bash
# Enable verbose build output
export VERBOSE=yes

# Build specific package for debugging
PROJECT=RPi DEVICE=RPi4 ./scripts/build package-name

# Check build logs
tail -f target/build.log
```

## Advanced Customizations

### Custom Kernel Patches
```bash
# Add kernel patches
mkdir -p projects/RPi/patches/linux
cp custom-cec.patch projects/RPi/patches/linux/

# Patches applied automatically during kernel build
```

### Additional Services
```bash
# Add custom systemd services
mkdir -p packages/custom/services/my-service
# Define service package similar to Tailscale add-on
```

### Bootloader Customization
```bash
# Custom boot splash
cp custom-splash.png projects/RPi/splash/

# Boot configuration
echo "disable_splash=0" >> projects/RPi/filesystem/boot/config.txt
```

---

**Next**: See [[Add-on-Development]] for creating additional custom add-ons for your LibreELEC build.
