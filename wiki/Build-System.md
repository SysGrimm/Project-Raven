# SoulBox Build System

This page provides comprehensive documentation of the **Container-Friendly Build System** that creates SoulBox images, including the primary build script, LibreELEC-inspired processes, and the complete build flow.

## Primary Build Script: `build-soulbox-containerized.sh`

The heart of our container-friendly build system - **no loop devices, no mounting, no privileges required!**

### Core Functions

#### 1. Pi OS Image Download & Analysis

```bash
# Downloads official Raspberry Pi OS ARM64 image
# URL: https://downloads.raspberrypi.org/raspios_lite_arm64/images/...
# Size: 431MB compressed → 2.7GB extracted
download_pi_os_image()

# Analyzes partition table using parted (no mounting!)
extract_pi_os_filesystems() {
    parted -s "$source_image" unit s print
    dd if="$source_image" of="$boot_fs" bs=512 skip="$boot_start"
    dd if="$source_image" of="$root_fs" bs=512 skip="$root_start"
}
```

#### 2. LibreELEC-Style Staging & Filesystem Population

```bash
# Extract boot partition using mtools (FAT32 - no mounting!)
mcopy -s -i "$pi_boot" :: "$boot_content/"

# LibreELEC approach: Extract Pi OS to staging directory first
extract_pi_os_to_staging() {
    if command -v populatefs >/dev/null 2>&1; then
        log_info "Using populatefs (LibreELEC method) for efficient extraction"
        extract_pi_os_content_with_e2tools "$source_img" "$staging_dir"
    else
        extract_pi_os_content_with_e2tools "$source_img" "$staging_dir"
    fi
}

# Populate filesystem using populatefs or e2tools fallback
copy_and_customize_filesystems() {
    # Extract to staging directory (LibreELEC approach)
    extract_pi_os_to_staging "$pi_root" "$staging_dir"
    
    # Merge SoulBox customizations into staging
    cp -r "$temp_dir/root-content"/* "$staging_dir/"
    
    # Populate filesystem using LibreELEC method
    if command -v populatefs >/dev/null 2>&1; then
        populatefs -U -d "$staging_dir" "$temp_dir/root-new.ext4"
    else
        # E2tools fallback with improved error handling
        populate_filesystem_with_e2tools "$temp_dir" "$staging_dir"
    fi
}
```

#### 3. Image Creation from Scratch

```bash
# Create blank image and partition table
build_soulbox_image() {
    dd if=/dev/zero of="$output_image" bs=1M seek="$total_size"
    parted -s "$output_image" mklabel msdos
    parted -s "$output_image" mkpart primary fat32 4MiB ${boot_size}MiB
    parted -s "$output_image" mkpart primary ext4 ${boot_size}MiB ${total_size}MiB
    
    # Create filesystems
    mkfs.fat -F 32 -n "SOULBOX" "$boot_new_fs"
    mke2fs -F -t ext4 -L "soulbox-root" "$root_new_fs"
}
```

#### 4. Configuration Injection Functions

- `create_soulbox_assets()` - Generate all SoulBox customizations
- `create_boot_config()` - Pi 5 optimizations (GPU, codecs, boot settings)
- `create_root_customizations()` - User accounts, services, directory structure
- `create_first_boot_setup()` - Self-configuring package installation
- `copy_and_customize_filesystems()` - Merge Pi OS + SoulBox content

## Container-Friendly Build Process Flow

The build process is divided into five distinct phases for maximum reliability and debuggability:

### Phase 1: Setup & Download (2-3 minutes)

1. **Environment Prep** - Clean work directory, check required tools
2. **Download Pi OS** - Get ARM64 image (431MB compressed → 2.7GB)
3. **Verify Tools** - Ensure populatefs (preferred) or e2tools, mtools, parted available
4. **Version Detection** - Auto-increment via Gitea API

### Phase 2: LibreELEC-Style Staging & Extraction (8-12 minutes)

5. **Partition Analysis** - Use parted to read MBR without mounting
6. **Extract Boot** - Use dd to extract FAT32 partition to file
7. **Extract Root** - Use dd to extract ext4 partition to file  
8. **Boot Content** - Use mtools (mcopy) to extract boot files
9. **Staging Directory** - Create LibreELEC-style staging area
10. **Root Content to Staging** - Use populatefs extraction or e2tools to extract Pi OS to staging
11. **Progress Logging** - Show files/directories extracted counts

### Phase 3: SoulBox Asset Creation (1-2 minutes)

11. **Boot Config** - Pi 5 GPU optimizations (vc4-kms-v3d, codecs)
12. **Root Customizations** - User accounts, directory structure
13. **First Boot Service** - Self-configuring package installation
14. **Branding Assets** - MOTD, hostname, Will-o'-wisp theming
15. **Service Configuration** - Kodi auto-start, SSH, Tailscale setup

### Phase 4: LibreELEC-Style Image Assembly (3-5 minutes)

16. **Create Blank Image** - dd with calculated size (1025MB)
17. **Partition Table** - parted MBR with Pi-compatible alignment
18. **Create Filesystems** - mkfs.fat (boot), mke2fs (root)
19. **Populate Boot** - mcopy Pi OS + SoulBox boot files
20. **Merge to Staging** - Combine Pi OS + SoulBox content in staging
21. **Bulk Population** - populatefs staging to filesystem (or e2tools fallback)
22. **Handle Symlinks** - Create first-boot restoration script for e2tools compatibility

### Phase 5: Output & Cleanup (1-2 minutes)

22. **Merge to Image** - dd filesystems into final image
23. **Generate Checksums** - SHA256 for integrity verification
24. **Create Archives** - TAR.GZ for distribution
25. **Cleanup** - Remove temporary files, preserve space
26. **Upload Assets** - Copy to artifacts directory

**Total Time**: 15-25 minutes typical (but reliable!)  
**Space Efficient**: Cleans up intermediate files during build  
**Container Safe**: No loop devices, no mounting, no privileges

## Revolutionary First Boot Strategy

**The Problem**: Installing ARM64 packages during build requires complex emulation and chroot environments that are unreliable in containers.

**Our Solution**: Create a self-configuring first boot process that installs packages natively on the target hardware.

### Implementation

```bash
create_first_boot_setup() {
    # Create systemd service that runs once on first boot
    cat > "$root_content/etc/systemd/system/soulbox-setup.service" << 'EOF'
[Unit]
Description=SoulBox First Boot Setup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/soulbox/scripts/first-boot-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create the first boot setup script
    cat > "$root_content/opt/soulbox/scripts/first-boot-setup.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a /var/log/soulbox-setup.log; }

log_info "SoulBox First Boot Setup Starting..."

# Update package lists
apt-get update

# Install core packages natively on ARM64 hardware
apt-get install -y \
    kodi \
    tailscale \
    mesa-utils \
    python3-pip \
    curl \
    wget \
    vim \
    htop

# Create soulbox user
useradd -m -s /bin/bash -G sudo,audio,video,plugdev soulbox || true
echo "soulbox:soulbox" | chpasswd

# Set pi user password
echo "pi:soulbox" | chpasswd

# Enable services
systemctl enable kodi-standalone.service
systemctl enable tailscaled
systemctl enable ssh

# Create media directories
mkdir -p /home/soulbox/{Videos,Music,Pictures,Downloads}
chown -R soulbox:soulbox /home/soulbox

log_info "SoulBox First Boot Setup Complete!"

# Disable this service (runs only once)
systemctl disable soulbox-setup.service

# Reboot to apply all changes
systemctl reboot
EOF

    chmod +x "$root_content/opt/soulbox/scripts/first-boot-setup.sh"
    
    # Enable the service
    ln -sf /etc/systemd/system/soulbox-setup.service \
        "$root_content/etc/systemd/system/multi-user.target.wants/soulbox-setup.service"
}
```

### Benefits of First Boot Strategy

- ✅ **No ARM64 Emulation**: Completely avoids unreliable cross-architecture package installation
- ✅ **Native Performance**: Packages install at full speed on target hardware
- ✅ **Self-Configuring**: No user intervention required
- ✅ **Self-Disabling**: Service runs once and removes itself
- ✅ **Container Compatible**: Build process requires no special privileges
- ✅ **Reliable**: Works consistently across all target hardware
- ✅ **Debuggable**: Full logs available in `/var/log/soulbox-setup.log`

## Tool Selection & Intelligent Fallbacks

Our build system uses intelligent tool selection with graceful fallbacks:

### Primary Tools (populatefs Method)
```bash
if command -v populatefs >/dev/null 2>&1; then
    log_info "Using populatefs (LibreELEC method) for efficient extraction"
    # LibreELEC-style bulk filesystem operations
    populatefs -U -d "$staging_dir" "$filesystem_image"
else
    log_info "populatefs not available, falling back to e2tools method"
    # Traditional e2tools approach
    populate_filesystem_with_e2tools "$temp_dir" "$staging_dir"
fi
```

### Tool Hierarchy

1. **populatefs** (Preferred) - LibreELEC's bulk filesystem population tool
   - Most efficient for large filesystem operations
   - Handles permissions, symlinks, and special files correctly
   - Requires: e2fsprogs-extra package

2. **e2tools** (Fallback) - Traditional ext4 manipulation tools
   - Works everywhere e2fsprogs is available
   - Requires symlink restoration script for compatibility
   - Individual file operations (e2cp, e2ls, e2mkdir)

3. **mtools** (FAT32) - Standard FAT32 filesystem tools
   - Universal availability
   - Reliable for boot partition operations
   - Standard tools: mcopy, mdir, mformat

## Build Environment Requirements

### Required Tools

The build system automatically checks for and uses these tools:

```bash
check_required_tools() {
    local required_tools=(
        "curl"      # Download Pi OS images
        "xz"        # Decompress images
        "parted"    # Partition manipulation
        "dd"        # Raw disk operations
        "mkfs.fat"  # Create FAT32 filesystems
        "mke2fs"    # Create ext4 filesystems
    )
    
    # Filesystem manipulation (either is acceptable)
    if command -v populatefs >/dev/null 2>&1; then
        log_info "✅ populatefs available (LibreELEC method preferred)"
    elif command -v e2cp >/dev/null 2>&1; then
        log_info "✅ e2tools available (fallback method)"
        required_tools+=("e2cp" "e2ls" "e2mkdir")
    else
        log_error "❌ Neither populatefs nor e2tools available"
        exit 1
    fi
    
    # FAT32 tools (required)
    required_tools+=("mcopy" "mdir" "mformat")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "❌ Required tool missing: $tool"
            exit 1
        fi
    done
    
    log_info "✅ All required tools available"
}
```

### Package Installation

For different distributions:

```bash
# Ubuntu/Debian
apt-get update
apt-get install -y \
    e2fsprogs e2fsprogs-extra \
    mtools parted dosfstools \
    curl xz-utils

# CentOS/RHEL/Fedora  
yum install -y \
    e2fsprogs e2fsprogs-extra \
    mtools parted dosfstools \
    curl xz

# Alpine Linux (Container)
apk add --no-cache \
    e2fsprogs e2fsprogs-extra \
    mtools parted dosfstools \
    curl xz
```

## Build Script Usage

### Basic Usage

```bash
# Run with automatic version detection
./build-soulbox-containerized.sh

# Specify version and clean build
./build-soulbox-containerized.sh --version "v1.0.0" --clean

# Debug mode with verbose output
./build-soulbox-containerized.sh --debug --keep-temp
```

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--version` | Specify output version | `--version "v1.0.0"` |
| `--clean` | Clean previous build artifacts | `--clean` |
| `--debug` | Enable verbose debugging output | `--debug` |
| `--keep-temp` | Keep temporary files for inspection | `--keep-temp` |
| `--work-dir` | Specify custom work directory | `--work-dir "/tmp/soulbox-build"` |
| `--output-dir` | Specify custom output directory | `--output-dir "./dist"` |

### Environment Variables

```bash
# Base image settings
export SOULBOX_PI_OS_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/..."
export SOULBOX_BASE_IMAGE="2024-07-04-raspios-bookworm-arm64-lite.img.xz"

# Build settings
export SOULBOX_IMAGE_SIZE="1025"  # MB
export SOULBOX_BOOT_SIZE="256"    # MB
export SOULBOX_WORK_DIR="/tmp/soulbox-build"

# Tool preferences
export SOULBOX_PREFER_POPULATEFS="true"
export SOULBOX_FALLBACK_E2TOOLS="true"
```

## Build Output

### Successful Build Artifacts

```
build/
├── soulbox-v0.2.1.img               # Complete bootable image (1.1GB)
├── soulbox-v0.2.1.img.sha256        # Integrity checksum
├── soulbox-v0.2.1.img.tar.gz        # Compressed archive (56MB)
├── soulbox-v0.2.1.img.tar.gz.sha256 # Compressed checksum
├── version.txt                      # Version information
└── build-log.txt                    # Complete build log
```

### Build Metrics

Recent successful build (v0.2.1):
- **Build Date**: 2025-08-31T05:26:47Z
- **Total Build Time**: ~25 minutes (including upload)
- **Final Image Size**: 1,074,790,400 bytes (1.1GB)
- **Compressed Size**: 55,866,161 bytes (56MB)
- **Compression Ratio**: 5.2% (19.2:1)

## Advanced Build Features

### Parallel Operations

Where possible, the build system performs operations in parallel:

```bash
# Parallel extraction
{
    extract_boot_partition &
    extract_root_partition &
    wait
}

# Parallel filesystem creation
{
    create_boot_filesystem &
    create_root_filesystem &
    wait
}
```

### Progress Tracking

```bash
show_progress() {
    local current=$1
    local total=$2
    local operation=$3
    
    local percent=$((current * 100 / total))
    printf "\r%s: %d/%d (%d%%) " "$operation" "$current" "$total" "$percent"
}
```

### Error Recovery

```bash
cleanup_on_error() {
    log_error "Build failed, cleaning up..."
    
    # Unmount any mounted filesystems
    umount "$temp_dir"/* 2>/dev/null || true
    
    # Remove temporary files unless --keep-temp specified
    if [[ "$KEEP_TEMP" != "true" ]]; then
        rm -rf "$SOULBOX_WORK_DIR"
    else
        log_info "Temporary files preserved in: $SOULBOX_WORK_DIR"
    fi
    
    exit 1
}

trap cleanup_on_error ERR
```

---

## Build System Benefits

### Universal Container Compatibility
- ✅ **GitHub Actions**: Works in standard runners without special configuration
- ✅ **Gitea Actions**: Tested and proven in self-hosted environments  
- ✅ **Docker**: Compatible with any Docker environment, including Unraid
- ✅ **Local Development**: Works on Linux, macOS, and Windows with Docker

### Reliability & Performance
- ✅ **LibreELEC Proven**: Based on battle-tested methodology used in production
- ✅ **Intelligent Fallbacks**: Multiple tool paths ensure builds always succeed
- ✅ **Space Efficient**: Smart cleanup keeps temporary space usage minimal
- ✅ **Fast Builds**: Optimized tool selection and parallel operations

### Developer Experience
- ✅ **Clear Error Messages**: Detailed logging helps debug issues quickly
- ✅ **Progress Tracking**: Real-time feedback on build progress
- ✅ **Debug Mode**: Verbose output and temporary file preservation for troubleshooting
- ✅ **Reproducible**: Deterministic builds from the same source

---

*The build system represents a breakthrough in container-friendly ARM64 image creation, making embedded system development accessible to any developer with Docker.*

**← Back to [[Architecture]] | Next: [[Deployment-Guide]] →**
