#!/bin/bash

# SoulBox Manual Setup Script
# Run this if the first-boot service didn't complete or you need manual configuration

set -e

LOG_FILE="/var/log/soulbox-manual-setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "$(date): Starting SoulBox manual setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "SoulBox Manual Setup Starting..."
log_info "This will configure Tailscale, Kodi, and essential services"

# Update packages
log_info "Updating package lists..."
apt-get update -qq

# Install required packages
log_info "Installing/updating SoulBox packages..."
PACKAGES=(
    "kodi" 
    "mesa-utils" 
    "xinit" 
    "xorg" 
    "openbox"
    "python3-pip" 
    "screen" 
    "tmux" 
    "unzip" 
    "zip" 
    "alsa-utils"
    "tailscale" 
    "fbi"
    "curl"
    "wget"
    "htop"
    "vim"
)

for package in "${PACKAGES[@]}"; do
    if apt-get install -y "$package" 2>/dev/null; then
        log_success "Installed: $package"
    else
        log_warning "Failed to install: $package (may already be installed)"
    fi
done

# Create soulbox user if it doesn't exist
if ! id "soulbox" &>/dev/null; then
    log_info "Creating soulbox user..."
    useradd -m -s /bin/bash -G sudo,adm,dialout,cdrom,audio,video,plugdev,games,users,input,netdev,gpio,i2c,spi,render soulbox
    echo 'soulbox:soulbox' | chpasswd
    log_success "Created soulbox user"
else
    log_info "soulbox user already exists"
fi

# Set passwords
log_info "Setting user passwords..."
echo 'pi:soulbox' | chpasswd
echo 'root:soulbox' | chpasswd
echo 'soulbox:soulbox' | chpasswd
log_success "User passwords set"

# Configure autologin
log_info "Configuring autologin..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin soulbox --noclear %I $TERM
EOF
log_success "Autologin configured"

# Create Kodi service
log_info "Creating Kodi standalone service..."
cat > /etc/systemd/system/kodi-standalone.service << 'EOF'
[Unit]
Description=SoulBox Kodi Media Center
After=systemd-user-sessions.service network.target sound.target
Wants=network-online.target
Conflicts=getty@tty1.service

[Service]
User=soulbox
Group=soulbox
Type=simple
ExecStart=/usr/bin/kodi-standalone
Restart=always
RestartSec=5
StandardInput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
KillMode=mixed
TimeoutStopSec=10

Environment="HOME=/home/soulbox"
Environment="USER=soulbox"
Environment="DISPLAY=:0.0"
Environment="KODI_HOME=/home/soulbox/.kodi"
Environment="MESA_LOADER_DRIVER_OVERRIDE=v3d"

[Install]
WantedBy=multi-user.target
EOF
log_success "Kodi service created"

# Create directories and set permissions
log_info "Creating SoulBox directory structure..."
mkdir -p /opt/soulbox/{assets,scripts,logs}
mkdir -p /home/soulbox/{Videos,Music,Pictures,Downloads,.kodi/userdata}
chown -R soulbox:soulbox /home/soulbox/
log_success "Directory structure created"

# Configure Tailscale
log_info "Setting up Tailscale..."
systemctl enable tailscaled
if systemctl start tailscaled; then
    log_success "Tailscale daemon started"
    
    # Wait for daemon to be ready
    for i in {1..10}; do
        if tailscale status >/dev/null 2>&1; then
            log_success "Tailscale daemon is ready"
            break
        fi
        sleep 2
    done
    
    log_info "Tailscale is ready for authentication"
    log_info "Run: sudo tailscale up --ssh --accept-routes"
    log_info "Then follow the authentication URL provided"
else
    log_warning "Failed to start Tailscale daemon - check system logs"
fi

# Enable services
log_info "Enabling SoulBox services..."
systemctl enable kodi-standalone.service
systemctl mask getty@tty1.service  # Prevent conflicts with Kodi
systemctl enable ssh
systemctl daemon-reload
log_success "Services enabled"

# Create helper scripts
log_info "Creating helper scripts..."

# Kodi control script
cat > /usr/local/bin/kodi-control << 'EOF'
#!/bin/bash
case "$1" in
    start)
        sudo systemctl start kodi-standalone.service
        echo "Kodi started"
        ;;
    stop)
        sudo systemctl stop kodi-standalone.service
        echo "Kodi stopped"
        ;;
    restart)
        sudo systemctl restart kodi-standalone.service
        echo "Kodi restarted"
        ;;
    status)
        sudo systemctl status kodi-standalone.service
        ;;
    logs)
        sudo journalctl -u kodi-standalone.service -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/kodi-control

# Tailscale helper script
cat > /usr/local/bin/tailscale-setup << 'EOF'
#!/bin/bash
echo "SoulBox Tailscale Setup"
echo "======================"
echo ""
echo "Step 1: Get your Tailscale auth key"
echo "Visit: https://login.tailscale.com/admin/settings/keys"
echo "Create a new auth key (enable 'Reusable' and 'Ephemeral' if desired)"
echo ""
echo "Step 2: Authenticate with Tailscale"
echo "Run: sudo tailscale up --ssh --accept-routes --auth-key=YOUR_AUTH_KEY"
echo ""
echo "Or run without auth key for interactive setup:"
echo "sudo tailscale up --ssh --accept-routes"
echo ""
echo "Step 3: Check status"
echo "tailscale status"
echo ""
echo "Current Tailscale status:"
tailscale status 2>/dev/null || echo "Tailscale not authenticated yet"
EOF

chmod +x /usr/local/bin/tailscale-setup

log_success "Helper scripts created:"
log_info "  - kodi-control: Control Kodi service"
log_info "  - tailscale-setup: Tailscale configuration helper"

# Create status check script
cat > /usr/local/bin/soulbox-status << 'EOF'
#!/bin/bash
echo "SoulBox System Status"
echo "===================="
echo ""

echo "Services:"
echo "--------"
systemctl is-active kodi-standalone.service | sed 's/^/  Kodi: /'
systemctl is-active tailscaled | sed 's/^/  Tailscale: /'
systemctl is-active ssh | sed 's/^/  SSH: /'

echo ""
echo "Network:"
echo "-------"
ip addr show | grep -E "(inet [0-9])" | grep -v "127.0.0.1" | sed 's/^/  /'

echo ""
echo "Tailscale:"
echo "---------"
tailscale status 2>/dev/null || echo "  Not connected"

echo ""
echo "Disk Usage:"
echo "----------"
df -h / | tail -1 | awk '{print "  Root: " $3 "/" $2 " (" $5 " used)"}'

echo ""
echo "Memory:"
echo "------"
free -h | grep Mem | awk '{print "  RAM: " $3 "/" $2 " used"}'

echo ""
echo "Temperature:"
echo "-----------"
if command -v vcgencmd >/dev/null 2>&1; then
    temp=$(vcgencmd measure_temp | cut -d= -f2)
    echo "  CPU: $temp"
else
    echo "  CPU temperature not available"
fi
EOF

chmod +x /usr/local/bin/soulbox-status

log_success "Created soulbox-status script"

# Final setup
log_info "Final system configuration..."

# Add aliases to bashrc
if ! grep -q "SoulBox aliases" /home/soulbox/.bashrc 2>/dev/null; then
    cat >> /home/soulbox/.bashrc << 'EOF'

# SoulBox aliases
alias kodi='kodi-control'
alias ts='tailscale-setup'
alias status='soulbox-status'
alias logs='sudo journalctl -f'
EOF
    chown soulbox:soulbox /home/soulbox/.bashrc
    log_success "Added SoulBox aliases"
fi

# Create completion marker
touch /opt/soulbox/manual-setup-complete

log_success "SoulBox manual setup complete!"
echo ""
echo "======================================"
echo "SoulBox Setup Summary"
echo "======================================"
echo ""
echo "✅ Packages installed and updated"
echo "✅ Users configured (soulbox:soulbox, pi:soulbox, root:soulbox)"
echo "✅ Kodi service configured (kodi-standalone.service)"
echo "✅ Tailscale daemon enabled"
echo "✅ SSH enabled"
echo "✅ Autologin configured for soulbox user"
echo "✅ Helper scripts installed"
echo ""
echo "Next Steps:"
echo "----------"
echo "1. Set up Tailscale: run 'tailscale-setup' or 'ts'"
echo "2. Start Kodi: run 'kodi-control start' or 'kodi start'"
echo "3. Check system status: run 'soulbox-status' or 'status'"
echo ""
echo "🎉 SoulBox is ready to use!"
echo ""
echo "Reboot recommended to ensure all services start properly."
echo "Run: sudo reboot"

