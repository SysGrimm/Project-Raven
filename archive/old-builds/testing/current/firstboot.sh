#!/bin/bash

# Project Raven - Raspberry Pi OS First Boot Setup
# This script runs on first boot to configure the system

set -e

LOG_FILE="/var/log/raven-setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "[LAUNCH] Project Raven - First Boot Setup Starting..."
echo "=================================================="
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo ""

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[ERROR] This script must be run as root"
        exit 1
    fi
}

# Function to update system
update_system() {
    echo "[PACKAGE] Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
    apt-get install -y curl wget git htop nano vim sudo unzip
    echo "[SUCCESS] System updated"
}

# Function to strip down OS
strip_system() {
    echo "[CLEANUP]  Stripping unnecessary components..."
    if [ -f "/opt/raven/strip-os.sh" ]; then
        /opt/raven/strip-os.sh
    else
        echo "[WARNING]  OS stripping script not found, skipping..."
    fi
    echo "[SUCCESS] System stripped"
}

# Function to configure SSH
setup_ssh() {
    echo "[SECURITY] Configuring SSH..."
    systemctl enable ssh
    systemctl start ssh
    
    # Secure SSH configuration
    cat > /etc/ssh/sshd_config.d/raven.conf << 'EOF'
# Project Raven SSH Configuration
Port 22
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    
    systemctl reload ssh
    echo "[SUCCESS] SSH configured"
}

# Function to install and configure Kodi
setup_kodi() {
    echo "[MEDIA] Installing latest Kodi media center..."
    
    # Install Kodi and CEC support
    apt-get install -y kodi kodi-addon-peripheral-joystick libcec6 cec-utils
    
    # Create kodi user
    useradd -m -s /bin/bash kodi || true
    usermod -a -G audio,video,input,dialout,plugdev,tty,cdrom kodi
    
    # Install Jellyfin for Kodi plugin
    echo "[PACKAGE] Installing Jellyfin for Kodi plugin..."
    mkdir -p /tmp/jellyfin-kodi
    cd /tmp/jellyfin-kodi
    
    # Download latest Jellyfin for Kodi addon
    wget -q https://repo.jellyfin.org/releases/client/kodi/repository.jellyfin.kodi.zip
    
    # Extract and install to Kodi addons directory
    mkdir -p /home/kodi/.kodi/addons
    unzip -q repository.jellyfin.kodi.zip -d /home/kodi/.kodi/addons/
    chown -R kodi:kodi /home/kodi/.kodi
    
    # Configure Kodi to start directly (no desktop environment)
    cat > /etc/systemd/system/kodi.service << 'EOF'
[Unit]
Description=Kodi Media Center
After=remote-fs.target sound.target network-online.target
Wants=network-online.target
Conflicts=getty@tty1.service

[Service]
Type=simple
User=kodi
Group=kodi
PAMName=login
TTYPath=/dev/tty1
ExecStart=/usr/bin/kodi-standalone
Restart=always
RestartSec=15
KillMode=process
StandardInput=tty
StandardOutput=inherit
StandardError=inherit

[Install]
WantedBy=multi-user.target
EOF
    
    # Disable desktop manager to boot directly to Kodi
    systemctl set-default multi-user.target
    systemctl disable lightdm || true
    systemctl disable gdm3 || true
    systemctl disable sddm || true
    
    systemctl daemon-reload
    systemctl enable kodi.service
    
    # Configure CEC for TV remote control
    echo " Configuring CEC for TV remote control..."
    cat > /home/kodi/.kodi/userdata/advancedsettings.xml << 'EOF'
<advancedsettings>
    <cec>
        <enabled>true</enabled>
        <ceclogaddresses>true</ceclogaddresses>
        <poweroffshutdown>true</poweroffshutdown>
        <poweroninit>true</poweroninit>
        <usececcec>true</usececcec>
        <cecactivatesource>true</cecactivatesource>
        <cecstandbydeactivate>true</cecstandbydeactivate>
    </cec>
</advancedsettings>
EOF
    
    chown -R kodi:kodi /home/kodi/.kodi
    
    echo "[SUCCESS] Kodi installed and configured for direct boot"
}

# Function to configure Kodi settings
configure_kodi_settings() {
    echo "  Configuring Kodi settings..."
    if [ -f "/opt/raven/configure-kodi.sh" ]; then
        /opt/raven/configure-kodi.sh
    else
        echo "[WARNING]  Kodi configuration script not found, using basic config..."
        # Ensure directories exist
        mkdir -p /home/kodi/.kodi/userdata
        chown -R kodi:kodi /home/kodi/.kodi
    fi
    echo "[SUCCESS] Kodi configured"
}

# Function to install and configure Tailscale
setup_tailscale() {
    echo "[SECURITY] Installing latest Tailscale VPN..."
    
    # Add Tailscale repository
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
    
    apt-get update -y
    apt-get install -y tailscale
    
    # Enable IP forwarding for subnet routing
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
    sysctl -p
    
    # Enable Tailscale service
    systemctl enable tailscaled
    systemctl start tailscaled
    
    echo "[SUCCESS] Tailscale installed and ready"
    echo "[INFO]  To connect: sudo tailscale up"
}

# Function to optimize system for media center
optimize_system() {
    echo "[PERFORMANCE] Optimizing system for media center use..."
    
    # Disable swap for better performance
    dphys-swapfile swapoff || true
    dphys-swapfile uninstall || true
    update-rc.d dphys-swapfile remove || true
    systemctl disable dphys-swapfile || true
    
    # Set I/O scheduler to deadline for better media performance
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/scheduler}="deadline"' > /etc/udev/rules.d/60-scheduler.rules
    
    # Apply LibreELEC video optimizations
    echo "[VIDEO] Applying LibreELEC video optimizations..."
    if [ -f "/opt/raven/libreelec-optimizations.sh" ]; then
        /opt/raven/libreelec-optimizations.sh
        echo "[SUCCESS] LibreELEC optimizations applied"
    else
        echo "[WARNING]  LibreELEC optimization script not found, skipping..."
    fi
    
    # Increase file limits for media streaming
    cat >> /etc/security/limits.conf << 'EOF'
# Project Raven optimizations
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    
    # GPU memory split optimization
    echo "gpu_mem=128" >> /boot/config.txt
    
    echo "[SUCCESS] System optimized"
}

# Function to create welcome message
setup_motd() {
    echo "[SETUP] Setting up welcome message..."
    
    cat > /etc/motd << 'EOF'
    ____            _           _     ____                         
   |  _ \ _ __ ___ (_) ___  ___| |_  |  _ \ __ ___   _____ _ __    
   | |_) | '__/ _ \| |/ _ \/ __| __| | |_) / _` \ \ / / _ \ '_ \   
   |  __/| | | (_) | |  __/ (__| |_  |  _ < (_| |\ V /  __/ | | |  
   |_|   |_|  \___// |\___|\___|\__| |_| \_\__,_| \_/ \___|_| |_|  
                 |__/                                            
   
   [LAUNCH] Raspberry Pi OS Edition with Tailscale VPN
   
   🔗 Network Status:
   [MEDIA] Kodi Media Center: systemctl status kodi
   [SECURITY] Tailscale VPN: sudo tailscale status
   🌐 SSH Access: ssh pi@$(hostname -I | awk '{print $1}')
   
   📚 Documentation: https://github.com/SysGrimm/Project-Raven/wiki
   🐛 Issues: https://github.com/SysGrimm/Project-Raven/issues
   
EOF
    
    echo "[SUCCESS] Welcome message configured"
}

# Function to cleanup
cleanup() {
    echo "🧹 Cleaning up..."
    apt-get autoremove -y
    apt-get autoclean
    
    # Clear logs
    journalctl --vacuum-time=1d
    
    # Remove this script
    rm -f /boot/firstboot.sh
    
    echo "[SUCCESS] Cleanup completed"
}

# Main execution
main() {
    echo "[LAUNCH] Starting Project Raven setup..."
    
    check_root
    update_system
    strip_system
    setup_ssh
    setup_kodi
    configure_kodi_settings
    setup_tailscale
    optimize_system
    setup_motd
    cleanup
    
    echo ""
    echo "[COMPLETE] Project Raven setup completed successfully!"
    echo "============================================="
    echo "[MEDIA] Kodi will start automatically on next boot"
    echo " Use your TV remote via CEC"
    echo "[SECURITY] Connect to Tailscale: sudo tailscale up"
    echo "[UPDATE] Rebooting in 10 seconds..."
    
    sleep 10
    reboot
}

# Run main function
main "$@"
