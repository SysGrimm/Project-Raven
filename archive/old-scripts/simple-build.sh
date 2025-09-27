#!/bin/bash

# Simple LibreELEC Configuration Package Builder
# Creates a config package and downloads the official LibreELEC image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configurations"
OUTPUT_DIR="$PROJECT_DIR/output"

# Configuration
TARGET_DEVICE="${TARGET_DEVICE:-RPi5}"
LIBREELEC_VERSION="${LIBREELEC_VERSION:-12.2.0}"
INCLUDE_TAILSCALE="${INCLUDE_TAILSCALE:-true}"  # Include Tailscale by default

# If version is "latest", fetch the actual version from GitHub API
if [ "$LIBREELEC_VERSION" = "latest" ]; then
    echo " Fetching latest LibreELEC version..."
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/LibreELEC/LibreELEC.tv/releases/latest" | grep '"tag_name":' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    if [ -n "$LATEST_VERSION" ]; then
        LIBREELEC_VERSION="$LATEST_VERSION"
        echo "[SUCCESS] Using LibreELEC version: $LIBREELEC_VERSION"
    else
        echo "[WARNING]  Could not fetch latest version, using default: 12.2.0"
        LIBREELEC_VERSION="12.2.0"
    fi
fi

echo "[LAUNCH] LibreELEC Configuration Package Builder"
echo "==========================================="
echo "Target Device: $TARGET_DEVICE"
echo "LibreELEC Version: $LIBREELEC_VERSION"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to get LibreELEC download URL
get_download_url() {
    local device="$1"
    local version="$2"
    local base_url="https://releases.libreelec.tv"
    
    case "$device" in
        "RPi4")
            echo "${base_url}/LibreELEC-RPi4.aarch64-${version}.img.gz"
            ;;
        "RPi5")
            echo "${base_url}/LibreELEC-RPi5.aarch64-${version}.img.gz"
            ;;
        "RPiZeroW2")
            echo "${base_url}/LibreELEC-RPi2.arm-${version}.img.gz"
            ;;
        "Generic")
            echo "${base_url}/LibreELEC-Generic.x86_64-${version}.img.gz"
            ;;
        *)
            echo "[ERROR] Unsupported device: $device"
            exit 1
            ;;
    esac
}

# Function to download LibreELEC image
download_libreelec() {
    local download_url="$1"
    local filename=$(basename "$download_url")
    local filepath="$OUTPUT_DIR/$filename"
    
    if [ -f "$filepath" ]; then
        echo "[FOLDER] LibreELEC image already exists: $filepath"
        echo "   $(ls -lh "$filepath" | awk '{print $5}')"
        return 0
    fi
    
    echo "  Downloading LibreELEC image..."
    echo "URL: $download_url"
    echo "Destination: $filepath"
    
    if curl -L -f --progress-bar -o "$filepath" "$download_url"; then
        echo "[SUCCESS] Download completed: $filepath"
        echo "   $(ls -lh "$filepath" | awk '{print $5}')"
    else
        echo "[ERROR] Download failed"
        exit 1
    fi
}

# Function to create configuration package
create_config_package() {
    local version="$1"
    local device="$2"
    
    echo "[PACKAGE] Creating configuration package..."
    
    local package_name="LibreELEC-${device}-${version}-Raven-Config"
    local package_dir="$OUTPUT_DIR/$package_name"
    
    # Remove existing package directory
    rm -rf "$package_dir"
    
    # Create package directory structure
    mkdir -p "$package_dir/boot"
    mkdir -p "$package_dir/storage"
    mkdir -p "$package_dir/instructions"
    
    # Copy boot configuration files
    if [ -f "$CONFIG_DIR/config.txt" ]; then
        cp "$CONFIG_DIR/config.txt" "$package_dir/boot/"
        echo "[SUCCESS] Added config.txt"
    fi
    
    if [ -f "$CONFIG_DIR/cmdline.txt" ]; then
        cp "$CONFIG_DIR/cmdline.txt" "$package_dir/boot/"
        echo "[SUCCESS] Added cmdline.txt"
    fi
    
    if [ -f "$CONFIG_DIR/first-boot.sh" ]; then
        cp "$CONFIG_DIR/first-boot.sh" "$package_dir/boot/"
        chmod +x "$package_dir/boot/first-boot.sh"
        echo "[SUCCESS] Added first-boot.sh"
    fi
    
    # Copy Tailscale installation if enabled
    if [ "$INCLUDE_TAILSCALE" = "true" ] && [ -f "$CONFIG_DIR/tailscale/install-tailscale.sh" ]; then
        cp "$CONFIG_DIR/tailscale/install-tailscale.sh" "$package_dir/boot/tailscale-install.sh"
        chmod +x "$package_dir/boot/tailscale-install.sh"
        echo "[SUCCESS] Added Tailscale installer"
        
        # Copy Tailscale config template
        if [ -f "$CONFIG_DIR/tailscale/tailscale.conf" ]; then
            cp "$CONFIG_DIR/tailscale/tailscale.conf" "$package_dir/boot/tailscale.conf.template"
            echo "[SUCCESS] Added Tailscale configuration template"
        fi
    fi
    
    # Copy storage files (Kodi settings, etc.)
    if [ -d "$CONFIG_DIR/storage" ]; then
        cp -r "$CONFIG_DIR/storage/"* "$package_dir/storage/" 2>/dev/null || true
        echo "[SUCCESS] Added storage files"
    fi
    
    # Always include Tailscale addon and configuration
    echo " Adding Tailscale integration..."
    
    # Copy the existing tailscale addon
    if [ -d "$PROJECT_DIR/libreelec-tailscale-addon" ]; then
        mkdir -p "$package_dir/storage/.kodi/addons/service.tailscale"
        cp -r "$PROJECT_DIR/libreelec-tailscale-addon/source/"* "$package_dir/storage/.kodi/addons/service.tailscale/"
        
        # Copy addon metadata
        cp "$PROJECT_DIR/libreelec-tailscale-addon/source/addon.xml" "$package_dir/storage/.kodi/addons/service.tailscale/"
        echo "[SUCCESS] Added Tailscale VPN addon"
    fi
    
    # Copy Tailscale configuration addon
    if [ -d "$CONFIG_DIR/addons/service.tailscale-config" ]; then
        mkdir -p "$package_dir/storage/.kodi/addons/service.tailscale-config"
        cp -r "$CONFIG_DIR/addons/service.tailscale-config/"* "$package_dir/storage/.kodi/addons/service.tailscale-config/"
        echo "[SUCCESS] Added Tailscale configuration addon"
    fi
    
    # Create Tailscale service file for systemd
    mkdir -p "$package_dir/system/etc/systemd/system"
    cat > "$package_dir/system/etc/systemd/system/tailscale.service" << 'EOF'
[Unit]
Description=Tailscale VPN client
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target NetworkManager.service systemd-resolved.service

[Service]
Type=notify
ExecStart=/storage/.kodi/addons/service.tailscale/bin/tailscale.start
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
    echo "[SUCCESS] Added Tailscale systemd service"
    
    # Create installation instructions
    cat > "$package_dir/instructions/README.md" << EOF
# LibreELEC Raven Configuration Package

This package contains custom configurations for LibreELEC ${version} on ${device}.

## Quick Setup

1. **Flash LibreELEC**: Flash the included \`.img.gz\` file to your SD card
2. **Apply configs**: Before first boot, copy files from \`boot/\` to SD card boot partition
3. **Boot**: Start your device - first-boot script will apply remaining configurations

## What's Included

### Boot Configuration (\`config.txt\`)
- GPU memory: 256MB (optimized for 4K video)
- 4K 60fps support enabled
- Performance overclocking settings
- Audio and HDMI optimizations

### Kodi Settings (\`guisettings.xml\`)  
- Optimized video playback
- Audio passthrough enabled
- Web server enabled for remote control
- Media-friendly interface

### System Features
- SSH enabled by default
- Automated first-boot setup
- Custom directory structure
- Network optimizations

### [SECURITY] Tailscale VPN Integration
- **Built-in by default** - No extra downloads needed
- Configure via LibreELEC Settings > Services > Tailscale Configuration
- Secure remote access to your media center
- Access your home network from anywhere

## Tailscale Setup

### Getting Your Auth Key
1. Go to https://login.tailscale.com/admin/settings/keys
2. Generate a new auth key (reusable recommended)
3. Copy the key (starts with \`tskey-auth-...\`)

### Configure in LibreELEC
1. Navigate to **Settings > Add-ons > Services > Tailscale Configuration**
2. **Enable Tailscale**: Turn on the toggle
3. **Auth Key**: Paste your Tailscale auth key
4. **Accept Routes**: Enable to access other devices on your Tailscale network
5. Save settings - Tailscale will automatically connect!

### Verification
- Check connection: Settings > Services > Tailscale Configuration > Show Status
- Your device will appear in the Tailscale admin console
- You can now access your LibreELEC remotely via Tailscale IP

## Manual Installation

### Step 1: Flash Image
Use Raspberry Pi Imager or Balena Etcher to flash the LibreELEC image to your SD card.

### Step 2: Apply Boot Configuration
Copy these files to the SD card's boot partition (visible on any computer):
- \`boot/config.txt\` → \`config.txt\`
- \`boot/cmdline.txt\` → \`cmdline.txt\`  
- \`boot/first-boot.sh\` → \`first-boot.sh\`

### Step 3: First Boot
Insert SD card and boot your device. The first-boot script will:
- Enable SSH
- Apply Kodi settings
- Set up custom directories
- Configure system optimizations

Enjoy your customized LibreELEC system! [LAUNCH]
EOF

    # Create installation script
    cat > "$package_dir/install.sh" << 'EOF'
#!/bin/bash
# LibreELEC Raven Configuration Installer

echo "[LAUNCH] LibreELEC Raven Configuration Installer"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run as root (use sudo)"
    exit 1
fi

# Detect boot partition
BOOT_PART=""
if [ -d "/flash" ]; then
    BOOT_PART="/flash"
elif [ -d "/boot" ]; then
    BOOT_PART="/boot"
else
    echo "[ERROR] Could not find boot partition"
    exit 1
fi

echo "[FOLDER] Boot partition detected: $BOOT_PART"

# Copy boot files
echo " Installing boot configuration..."
cp boot/config.txt "$BOOT_PART/" 2>/dev/null && echo "[SUCCESS] config.txt installed"
cp boot/cmdline.txt "$BOOT_PART/" 2>/dev/null && echo "[SUCCESS] cmdline.txt installed"
cp boot/first-boot.sh "$BOOT_PART/" 2>/dev/null && echo "[SUCCESS] first-boot.sh installed"

# Copy Kodi settings
echo " Installing Kodi settings..."
if [ -d "storage" ]; then
    cp -r storage/* /storage/ 2>/dev/null && echo "[SUCCESS] Kodi settings installed"
fi

echo "[COMPLETE] Installation complete! Reboot to apply changes."
EOF
    chmod +x "$package_dir/install.sh"
    
    # Create a compressed package
    cd "$OUTPUT_DIR"
    tar -czf "${package_name}.tar.gz" "$package_name"
    
    echo "[SUCCESS] Configuration package created: ${package_name}.tar.gz"
}

# Main execution
main() {
    echo "🔗 Getting download URL..."
    local download_url
    download_url=$(get_download_url "$TARGET_DEVICE" "$LIBREELEC_VERSION")
    echo "[SUCCESS] Download URL: $download_url"
    
    echo "  Downloading LibreELEC..."
    download_libreelec "$download_url"
    
    echo "[PACKAGE] Creating configuration package..."
    create_config_package "$LIBREELEC_VERSION" "$TARGET_DEVICE"
    
    # Generate checksums
    echo "[SECURITY] Generating checksums..."
    cd "$OUTPUT_DIR"
    for file in *.img.gz *.tar.gz; do
        if [ -f "$file" ]; then
            sha256sum "$file" > "${file}.sha256" 2>/dev/null || shasum -a 256 "$file" > "${file}.sha256"
            echo "[SUCCESS] Checksum: ${file}.sha256"
        fi
    done
    
    echo ""
    echo "[COMPLETE] Build Complete!"
    echo "================="
    echo "[FOLDER] Output directory: $OUTPUT_DIR"
    echo "[PACKAGE] Files created:"
    ls -la "$OUTPUT_DIR"/*.img.gz "$OUTPUT_DIR"/*.tar.gz 2>/dev/null || echo "  (files will be shown after upload)"
    echo ""
    echo " Next Steps:"
    echo "1. Download the LibreELEC-${TARGET_DEVICE}-${LIBREELEC_VERSION}.img.gz"
    echo "2. Download the LibreELEC-${TARGET_DEVICE}-${LIBREELEC_VERSION}-Raven-Config.tar.gz"  
    echo "3. Flash the image and apply the configuration package"
    echo "4. Boot your customized LibreELEC system!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
