#!/bin/bash

# Project Raven - LibreELEC Video Optimizations
# Applies LibreELEC-inspired system optimizations for video playback

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Function to optimize kernel parameters for video playback
optimize_kernel_params() {
    log "Applying LibreELEC kernel parameter optimizations..."
    
    # Create sysctl configuration for video optimization
    cat > /etc/sysctl.d/99-libreelec-video.conf << 'EOF'
# LibreELEC-inspired video optimizations for Raspberry Pi

# Memory management optimizations
vm.swappiness = 1
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.vfs_cache_pressure = 50

# Network optimizations for streaming
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# File system optimizations
fs.file-max = 2097152

# Video buffer optimizations
vm.min_free_kbytes = 16384
EOF

    success "Kernel parameters optimized"
}

# Function to create kodi.conf with LibreELEC memory optimizations
create_kodi_conf() {
    log "Creating LibreELEC-style Kodi environment configuration..."
    
    mkdir -p /etc/systemd/system/kodi.service.d
    
    cat > /etc/systemd/system/kodi.service.d/libreelec-optimizations.conf << 'EOF'
[Service]
# LibreELEC memory allocation optimizations for ARM
Environment=MALLOC_MMAP_THRESHOLD_=8192
Environment=MALLOC_TRIM_THRESHOLD_=131072
Environment=MALLOC_TOP_PAD_=131072

# Video acceleration environment
Environment=V4L2_DISABLE_SANDBOX=1
Environment=LIBVA_DRIVER_NAME=v4l2_request

# Kodi-specific optimizations
Environment=KODI_AE_SINK=ALSA
Environment=KODI_DISABLE_ADDON_CACHING=1
EOF

    success "Kodi environment optimizations created"
}

# Function to optimize GPU memory split based on LibreELEC
optimize_gpu_memory() {
    log "Optimizing GPU memory configuration..."
    
    # Check total system memory
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    
    if [ "$TOTAL_MEM" -gt 3000 ]; then
        # 4GB+ Pi - Use LibreELEC's 76MB default
        GPU_MEM=76
        warn "4GB+ Pi detected - Using LibreELEC's optimized 76MB GPU split"
    elif [ "$TOTAL_MEM" -gt 1500 ]; then
        # 2GB Pi - Slightly higher for stability
        GPU_MEM=128
        warn "2GB Pi detected - Using 128MB GPU split"
    else
        # 1GB Pi - Conservative
        GPU_MEM=128
        warn "1GB Pi detected - Using 128MB GPU split"
    fi
    
    # Update the GPU memory in config.txt if different from current setting
    if ! grep -q "^gpu_mem=$GPU_MEM$" /boot/config.txt; then
        sed -i "s/^gpu_mem=.*/gpu_mem=$GPU_MEM/" /boot/config.txt
        success "GPU memory optimized to ${GPU_MEM}MB"
    else
        success "GPU memory already optimized"
    fi
}

# Function to create LibreELEC-style video acceleration setup
setup_video_acceleration() {
    log "Setting up LibreELEC video acceleration configuration..."
    
    # Ensure required modules are loaded
    cat > /etc/modules-load.d/libreelec-video.conf << 'EOF'
# LibreELEC video acceleration modules
bcm2835-v4l2
bcm2835-codec
EOF

    # Create modprobe configuration for video optimization
    cat > /etc/modprobe.d/libreelec-video.conf << 'EOF'
# LibreELEC video driver optimizations

# V4L2 optimizations for RPi
options bcm2835-v4l2 gst_v4l2src_is_broken=1

# Enable hardware video acceleration
options bcm2835-codec decode=1
options vc4 hdmi_cec=1
EOF

    success "Video acceleration configured"
}

# Function to optimize systemd for media center use
optimize_systemd() {
    log "Applying LibreELEC systemd optimizations..."
    
    # Optimize systemd for faster boot and media center operation
    mkdir -p /etc/systemd/system.conf.d
    
    cat > /etc/systemd/system.conf.d/libreelec.conf << 'EOF'
[Manager]
# LibreELEC systemd optimizations
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=10s
DefaultRestartSec=100ms
DefaultLimitNOFILE=65536

# Memory optimization
DefaultMemoryAccounting=yes
DefaultLimitMEMLOCK=64M
EOF

    success "Systemd optimized for media center"
}

# Function to create temperature monitoring (LibreELEC-style)
setup_temperature_monitoring() {
    log "Setting up LibreELEC-style temperature monitoring..."
    
    cat > /usr/local/bin/cputemp << 'EOF'
#!/bin/sh
# LibreELEC-style temperature monitoring for RPi

TEMP="$(cat /sys/class/thermal/thermal_zone0/temp)"
echo "$(($TEMP / 1000)) C"
EOF

    chmod +x /usr/local/bin/cputemp
    
    success "Temperature monitoring configured"
}

# Function to create LibreELEC-style boot optimization
optimize_boot() {
    log "Applying LibreELEC boot optimizations..."
    
    # Add boot optimization parameters to cmdline.txt
    CMDLINE_FILE="/boot/cmdline.txt"
    CMDLINE_OPTS="quiet loglevel=0 logo.nologo vt.global_cursor_default=0"
    
    # Check if optimizations are already applied
    if ! grep -q "quiet loglevel=0" "$CMDLINE_FILE"; then
        # Backup original
        cp "$CMDLINE_FILE" "$CMDLINE_FILE.backup"
        
        # Add optimizations
        sed -i "s/$/ $CMDLINE_OPTS/" "$CMDLINE_FILE"
        success "Boot optimizations applied"
    else
        success "Boot optimizations already present"
    fi
}

# Function to create LibreELEC-style memory optimization
setup_memory_optimization() {
    log "Setting up LibreELEC memory optimizations..."
    
    # Create memory optimization service
    cat > /etc/systemd/system/memory-optimize.service << 'EOF'
[Unit]
Description=LibreELEC Memory Optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 1 > /proc/sys/vm/drop_caches'
ExecStart=/bin/sh -c 'echo 0 > /proc/sys/vm/zone_reclaim_mode'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable memory-optimize.service
    success "Memory optimization service created"
}

# Function to apply all LibreELEC optimizations
apply_all_optimizations() {
    log "Applying all LibreELEC-inspired optimizations..."
    
    optimize_kernel_params
    create_kodi_conf
    optimize_gpu_memory
    setup_video_acceleration
    optimize_systemd
    setup_temperature_monitoring
    optimize_boot
    setup_memory_optimization
    
    # Reload systemd
    systemctl daemon-reload
    
    # Apply sysctl changes
    sysctl -p /etc/sysctl.d/99-libreelec-video.conf
    
    success "All LibreELEC optimizations applied successfully!"
    warn "A reboot is recommended to ensure all optimizations take effect"
}

# Main execution
main() {
    log "Starting LibreELEC Video Optimization Process..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root"
        exit 1
    fi
    
    apply_all_optimizations
    
    success "LibreELEC optimization complete!"
    echo ""
    echo "Next steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. Verify optimizations with: vcgencmd get_mem gpu"
    echo "3. Check temperature: /usr/local/bin/cputemp"
    echo "4. Monitor performance during video playback"
}

# Execute main function
main "$@"
