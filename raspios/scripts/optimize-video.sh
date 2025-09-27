#!/bin/bash
# Video optimization script based on LibreELEC optimizations
# Implements video playback enhancements for Raspberry Pi

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Check if we're on a Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    error "This script is designed for Raspberry Pi only"
    exit 1
fi
# Detect Raspberry Pi model
detect_pi_model() {
    local revision=$(grep "Revision" /proc/cpuinfo | awk '{print $3}')
    case ${revision} in
        *900021*|*900032*|*900092*|*900093*|*920092*|*920093*)
            echo "Pi Zero"
            ;;
        *a01040*|*a01041*|*a21041*|*a22042*)
            echo "Pi2"
            ;;
        *a02082*|*a020a0*|*a22082*|*a32082*)
            echo "Pi3"
            ;;
        *a03111*|*b03111*|*b03112*|*c03111*|*c03112*)
            echo "Pi4"
            ;;
        *c04170*)
            echo "Pi5"
            ;;
        *)
            echo "Pi4" # Default to Pi4 if unknown
            ;;
    esac
}

# Set device-specific memory configurations
configure_memory_split() {
    local pi_model="$1"
    local config_file="/boot/firmware/config.txt"
    
    log "Configuring GPU memory split for ${pi_model}"
    
    # Remove existing gpu_mem settings
    sed -i '/^gpu_mem/d' "$config_file"
    
    case "$pi_model" in
        "Pi Zero"|"Pi2")
            echo "gpu_mem=128" >> "$config_file"
            info "Set GPU memory to 128MB for ${pi_model}"
            ;;
        "Pi3")
            echo "gpu_mem=256" >> "$config_file"
            info "Set GPU memory to 256MB for ${pi_model}"
            ;;
        "Pi4"|"Pi5")
            echo "gpu_mem=320" >> "$config_file"
            info "Set GPU memory to 320MB for ${pi_model}"
            ;;
    esac
}

# Configure video codec optimizations
configure_video_codecs() {
    local pi_model="$1"
    local config_file="/boot/firmware/config.txt"
    
    log "Configuring video codec optimizations"
    
    # Remove existing codec settings
    sed -i '/^decode_/d' "$config_file"
    sed -i '/^hdmi_enable_4kp60/d' "$config_file"
    sed -i '/^max_framebuffers/d' "$config_file"
    
    # Enable hardware video decode
    cat >> "$config_file" << 'EOF'

# Video codec optimizations
decode_MPG2=0x12345678
decode_WVC1=0x12345678
EOF
    
    case "$pi_model" in
        "Pi4"|"Pi5")
            cat >> "$config_file" << 'EOF'
# Enable 4K@60fps on Pi4/Pi5
hdmi_enable_4kp60=1
max_framebuffers=2
EOF
            info "Enabled 4K@60fps support for ${pi_model}"
            ;;
    esac
}

# Configure LibreELEC-style CMA (Contiguous Memory Allocator)
configure_cma() {
    local pi_model="$1"
    local config_file="/boot/firmware/config.txt"
    
    log "Configuring CMA for video acceleration"
    
    # Remove existing dtoverlay lines
    sed -i '/^dtoverlay=vc4-kms-v3d/d' "$config_file"
    
    case "$pi_model" in
        "Pi Zero"|"Pi")
            echo "dtoverlay=vc4-kms-v3d,cma-128" >> "$config_file"
            info "Set CMA to 128MB for ${pi_model}"
            ;;
        "Pi2")
            echo "dtoverlay=vc4-kms-v3d,cma-384" >> "$config_file"
            info "Set CMA to 384MB for ${pi_model}"
            ;;
        "Pi3"|"Pi4"|"Pi5")
            echo "dtoverlay=vc4-kms-v3d,cma-512" >> "$config_file"
            info "Set CMA to 512MB for ${pi_model}"
            ;;
    esac
}

# Configure system-wide video optimizations
configure_system_optimizations() {
    log "Configuring system-wide video optimizations"
    
    # Create sysctl optimizations for video
    cat > /etc/sysctl.d/99-video-optimizations.conf << 'EOF'
# Video playback optimizations
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_writeback_centisecs = 500
vm.swappiness = 1

# Network buffer optimizations for streaming
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-video-optimizations.conf
    
    info "Applied system-wide video optimizations"
}

# Configure LibreELEC-style malloc optimizations
configure_malloc_optimizations() {
    local pi_model="$1"
    
    log "Configuring memory allocation optimizations"
    
    # Create environment file for Kodi
    mkdir -p /etc/systemd/system/kodi.service.d
    
    case "$pi_model" in
        "Pi Zero"|"Pi2"|"Pi3")
            cat > /etc/systemd/system/kodi.service.d/malloc.conf << 'EOF'
[Service]
Environment="MALLOC_MMAP_THRESHOLD_=8192"
Environment="MALLOC_TRIM_THRESHOLD_=131072"
EOF
            info "Set ARM malloc optimizations for ${pi_model}"
            ;;
        "Pi4"|"Pi5")
            cat > /etc/systemd/system/kodi.service.d/malloc.conf << 'EOF'
[Service]
Environment="MALLOC_MMAP_THRESHOLD_=524288"
Environment="MALLOC_TRIM_THRESHOLD_=1048576"
EOF
            info "Set enhanced malloc optimizations for ${pi_model}"
            ;;
    esac
}

# Configure FFmpeg video acceleration
configure_ffmpeg_optimizations() {
    local pi_model="$1"
    
    log "Configuring FFmpeg video acceleration"
    
    # Create FFmpeg configuration directory
    mkdir -p /etc/kodi
    
    cat > /etc/kodi/ffmpeg.conf << 'EOF'
# FFmpeg optimizations for Raspberry Pi
[video]
# Enable hardware acceleration
hwaccel=auto
hwaccel_device=auto

# Enable multi-threading
threads=auto

# Optimize for low latency
flags=+global_header+low_delay
fflags=+genpts+nobuffer

# Video filters
vf=format=yuv420p

[audio]
# Audio optimizations
ac=2
ar=48000
ab=192k
EOF

    # Pi4/Pi5 specific optimizations
    if [[ "$pi_model" == "Pi4" || "$pi_model" == "Pi5" ]]; then
        cat >> /etc/kodi/ffmpeg.conf << 'EOF'

# Pi4/Pi5 specific optimizations
[video_pi4]
# Enable SAND format (RPi specific)
pix_fmt=sand128
# Enable V4L2 hardware decode
hwaccel=v4l2m2m
EOF
    fi
    
    info "Configured FFmpeg optimizations for ${pi_model}"
}

# Configure Kodi video settings
configure_kodi_video_settings() {
    local pi_model="$1"
    
    log "Configuring Kodi video settings"
    
    # Create Kodi configuration directory
    mkdir -p /opt/kodi-config
    
    cat > /opt/kodi-config/advancedsettings.xml << 'EOF'
<advancedsettings>
  <video>
    <!-- Video acceleration settings -->
    <enablemmal>true</enablemmal>
    <enablehighmem>false</enablehighmem>
    <adjustrefreshrate>2</adjustrefreshrate>
    <resyncmethod>2</resyncmethod>
    
    <!-- Buffer settings for smooth playback -->
    <cachemembuffersize>20971520</cachemembuffersize> <!-- 20MB -->
    <readbufferfactor>4.0</readbufferfactor>
    
    <!-- Display settings -->
    <allowhifi>true</allowhifi>
    <prefervaapirender>true</prefervaapirender>
    
    <!-- Deinterlacing -->
    <deinterlacemethod>6</deinterlacemethod> <!-- Auto -->
  </video>
  
  <network>
    <!-- Network cache for streaming -->
    <cachemembuffersize>20971520</cachemembuffersize>
    <readbufferfactor>4.0</readbufferfactor>
    <curlclienttimeout>30</curlclienttimeout>
    <curllowspeedtime>20</curllowspeedtime>
    <curlretries>2</curlretries>
  </network>
  
  <audio>
    <!-- Audio settings -->
    <resamplequality>3</resamplequality>
    <stereodownmix>1</stereodownmix>
    <ac3downmix>true</ac3downmix>
  </audio>
EOF

    # Pi4/Pi5 specific settings
    if [[ "$pi_model" == "Pi4" || "$pi_model" == "Pi5" ]]; then
        cat >> /opt/kodi-config/advancedsettings.xml << 'EOF'
  
  <!-- Pi4/Pi5 specific optimizations -->
  <videoplayer>
    <usedisplayasclock>false</usedisplayasclock>
    <adjustrefreshrate>2</adjustrefreshrate>
    <synctype>2</synctype> <!-- Video clock -->
    <maxspeedadjust>0.05</maxspeedadjust>
    <resyncmethod>2</resyncmethod>
  </videoplayer>
EOF
    fi
    
    cat >> /opt/kodi-config/advancedsettings.xml << 'EOF'
</advancedsettings>
EOF

    info "Created Kodi advanced settings for ${pi_model}"
}

# Configure LibreELEC-style boot optimizations
configure_boot_optimizations() {
    local config_file="/boot/firmware/config.txt"
    
    log "Configuring boot optimizations"
    
    # Remove existing settings
    sed -i '/^disable_overscan/d' "$config_file"
    sed -i '/^disable_fw_kms_setup/d' "$config_file"
    sed -i '/^display_auto_detect/d' "$config_file"
    sed -i '/^arm_boost/d' "$config_file"
    
    # Add LibreELEC-style optimizations
    cat >> "$config_file" << 'EOF'

# Boot and display optimizations
disable_overscan=1
disable_fw_kms_setup=1
display_auto_detect=1
arm_boost=1
EOF

    info "Applied boot optimizations"
}

# Configure thermal management
configure_thermal_management() {
    local pi_model="$1"
    
    log "Configuring thermal management"
    
    # Create thermal configuration
    mkdir -p /etc/systemd/system
    
    cat > /etc/systemd/system/thermal-management.service << 'EOF'
[Unit]
Description=Thermal Management for Video Playback
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-thermal.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create thermal setup script
    cat > /usr/local/bin/setup-thermal.sh << 'EOF'
#!/bin/bash
# Set thermal limits for sustained video playback

# Enable thermal throttling at higher temperatures
echo 75000 > /sys/class/thermal/thermal_zone0/trip_point_0_temp 2>/dev/null || true

# Optimize CPU governor for media playback
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo "ondemand" > "$cpu"
done

# Set up nice thermal monitoring
echo "Thermal management configured"
EOF

    chmod +x /usr/local/bin/setup-thermal.sh
    systemctl enable thermal-management.service
    
    info "Configured thermal management"
}

# Configure I/O scheduler optimizations
configure_io_optimizations() {
    log "Configuring I/O optimizations"
    
    # Create I/O optimization rules
    cat > /etc/udev/rules.d/99-io-scheduler.rules << 'EOF'
# Set I/O scheduler for different device types
# Use deadline for SD cards and USB storage
KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="deadline"
KERNEL=="sd*", ATTR{queue/scheduler}="deadline"

# Optimize read-ahead for media files
KERNEL=="mmcblk[0-9]*", ATTR{queue/read_ahead_kb}="1024"
KERNEL=="sd*", ATTR{queue/read_ahead_kb}="2048"

# Set queue depth
KERNEL=="mmcblk[0-9]*", ATTR{queue/nr_requests}="128"
KERNEL=="sd*", ATTR{queue/nr_requests}="128"
EOF

    info "Configured I/O optimizations"
}

# Install additional video optimization packages
install_optimization_packages() {
    log "Installing video optimization packages"
    
    # Update package list
    apt-get update
    
    # Install video optimization packages
    apt-get install -y \
        vainfo \
        mesa-va-drivers \
        mesa-utils \
        v4l-utils \
        media-types \
        i965-va-driver \
        libva2 \
        libva-drm2 \
        libvdpau-va-gl1
    
    info "Installed video optimization packages"
}

# Create optimization status check
create_optimization_check() {
    log "Creating optimization status check"
    
    cat > /usr/local/bin/video-status.sh << 'EOF'
#!/bin/bash
# Video optimization status checker

echo "=== Video Optimization Status ==="
echo

# Check GPU memory
echo "GPU Memory Split:"
vcgencmd get_mem gpu || echo "vcgencmd not available"
echo

# Check thermal status
echo "Thermal Status:"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    temp=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
    echo "CPU Temperature: ${temp}°C"
else
    echo "Temperature monitoring not available"
fi
echo

# Check video acceleration
echo "Video Acceleration Status:"
if command -v vainfo >/dev/null 2>&1; then
    vainfo 2>/dev/null | grep -E "(Driver|VAProfile)" || echo "VA-API not available"
else
    echo "vainfo not installed"
fi
echo

# Check memory usage
echo "Memory Usage:"
free -h
echo

# Check Kodi process
echo "Kodi Status:"
if pgrep -x "kodi" > /dev/null; then
    echo "Kodi is running"
    ps aux | grep kodi | grep -v grep | awk '{print "PID: " $2 ", CPU: " $3 "%, MEM: " $4 "%"}'
else
    echo "Kodi is not running"
fi
echo

echo "=== End Status ==="
EOF

    chmod +x /usr/local/bin/video-status.sh
    
    info "Created video status checker at /usr/local/bin/video-status.sh"
}

# Main execution function
main() {
    log "Starting LibreELEC-style video optimizations for Raspberry Pi"
    
    # Detect Pi model
    local pi_model
    pi_model=$(detect_pi_model)
    info "Detected Raspberry Pi model: ${pi_model}"
    
    # Check if config.txt exists
    if [[ ! -f "/boot/firmware/config.txt" ]]; then
        error "/boot/firmware/config.txt not found. Is this a proper Raspberry Pi OS installation?"
        exit 1
    fi
    
    # Backup config.txt
    cp /boot/firmware/config.txt /boot/firmware/config.txt.backup.$(date +%Y%m%d-%H%M%S)
    log "Backed up config.txt"
    
    # Apply optimizations
    configure_memory_split "$pi_model"
    configure_video_codecs "$pi_model"
    configure_cma "$pi_model"
    configure_boot_optimizations
    configure_system_optimizations
    configure_malloc_optimizations "$pi_model"
    configure_ffmpeg_optimizations "$pi_model"
    configure_kodi_video_settings "$pi_model"
    configure_thermal_management "$pi_model"
    configure_io_optimizations
    install_optimization_packages
    create_optimization_check
    
    log "Video optimizations completed successfully!"
    info "Reboot required to apply all changes."
    info "After reboot, run: /usr/local/bin/video-status.sh to check status"
    
    # Show what changed
    echo
    echo "=== Summary of Changes ==="
    echo "• GPU memory split optimized for $pi_model"
    echo "• Video codec acceleration enabled"
    echo "• CMA (Contiguous Memory Allocator) configured"
    echo "• System memory management optimized"
    echo "• FFmpeg hardware acceleration configured"
    echo "• Kodi advanced video settings created"
    echo "• Thermal management optimized"
    echo "• I/O scheduler optimized for media playback"
    echo "• Video acceleration packages installed"
    echo "• Status monitoring tools created"
    echo
    
    warn "Please reboot the system to apply all optimizations!"
}

# Execute main function
main "$@"
