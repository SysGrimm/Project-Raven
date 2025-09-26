#!/bin/bash

# Tailscale Installation Script for LibreELEC
# Based on the approach from https://www.davbo.uk/posts/connecting-home/
# This script downloads and sets up Tailscale on LibreELEC systems

set -e

TAILSCALE_VERSION="1.70.0"  # Update this to latest stable version
ARCH="arm64"  # Default for RPi4/5, will be detected
STORAGE_DIR="/storage/tailscale"
CONFIG_DIR="/storage/.config"
SYSTEMD_DIR="$CONFIG_DIR/system.d"

echo "🔗 Tailscale Installation for LibreELEC"
echo "======================================="

# Detect architecture
detect_architecture() {
    case "$(uname -m)" in
        "aarch64"|"arm64")
            ARCH="arm64"
            ;;
        "armv7l"|"armhf")
            ARCH="arm"
            ;;
        "x86_64"|"amd64")
            ARCH="amd64"
            ;;
        *)
            echo "❌ Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    echo "✅ Detected architecture: $ARCH"
}

# Download Tailscale binaries
download_tailscale() {
    echo "📥 Downloading Tailscale $TAILSCALE_VERSION for $ARCH..."
    
    # Create storage directory
    mkdir -p "$STORAGE_DIR"
    cd "$STORAGE_DIR"
    
    # Download and extract
    local download_url="https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_linux_${ARCH}.tgz"
    echo "   URL: $download_url"
    
    if curl -L -f -o "tailscale_${TAILSCALE_VERSION}_linux_${ARCH}.tgz" "$download_url"; then
        echo "✅ Download completed"
        
        # Extract binaries
        tar -xzf "tailscale_${TAILSCALE_VERSION}_linux_${ARCH}.tgz"
        
        # Move binaries to storage directory
        mv "tailscale_${TAILSCALE_VERSION}_linux_${ARCH}/tailscale" .
        mv "tailscale_${TAILSCALE_VERSION}_linux_${ARCH}/tailscaled" .
        
        # Make executable
        chmod +x tailscale tailscaled
        
        # Clean up
        rm -rf "tailscale_${TAILSCALE_VERSION}_linux_${ARCH}"*
        
        echo "✅ Tailscale binaries installed to $STORAGE_DIR"
    else
        echo "❌ Failed to download Tailscale"
        exit 1
    fi
}

# Create systemd service
create_systemd_service() {
    echo "🔧 Creating systemd service..."
    
    # Create systemd directory
    mkdir -p "$SYSTEMD_DIR"
    
    # Create the service file
    cat > "$SYSTEMD_DIR/tailscaled.service" << 'EOF'
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target
StartLimitIntervalSec=0
StartLimitBurst=0

[Service]
EnvironmentFile=-/storage/tailscale/tailscaled.defaults
ExecStart=/storage/tailscale/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port ${PORT:-41641} $FLAGS
Restart=on-failure
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
StateDirectory=tailscale
StateDirectoryMode=0750

[Install]
WantedBy=multi-user.target
EOF

    echo "✅ Systemd service created: $SYSTEMD_DIR/tailscaled.service"
}

# Create configuration files
create_config_files() {
    echo "📝 Creating configuration files..."
    
    # Create defaults file
    cat > "$STORAGE_DIR/tailscaled.defaults" << 'EOF'
# Tailscale daemon configuration
# Port for the daemon to listen on
PORT=41641

# Additional flags for tailscaled
# FLAGS="--accept-routes"
FLAGS=""
EOF

    # Create helper scripts
    cat > "$STORAGE_DIR/tailscale-up.sh" << 'EOF'
#!/bin/bash
# Tailscale connection helper script

echo "🔗 Connecting to Tailscale..."
echo "   To authenticate, visit the URL that appears below"
echo "   or use an auth key if you have one."
echo ""

if [ -n "$1" ]; then
    # Use provided auth key
    echo "   Using provided auth key..."
    /storage/tailscale/tailscale up --authkey="$1"
else
    # Interactive authentication
    echo "   Starting interactive authentication..."
    /storage/tailscale/tailscale up
fi

echo ""
echo "✅ Tailscale connection complete!"
echo "   Your LibreELEC device should now be accessible on your Tailscale network."
echo ""
echo "📋 Useful commands:"
echo "   Check status: /storage/tailscale/tailscale status"
echo "   Get IP:       /storage/tailscale/tailscale ip"
echo "   Disconnect:   /storage/tailscale/tailscale down"
EOF

    chmod +x "$STORAGE_DIR/tailscale-up.sh"

    # Create status script
    cat > "$STORAGE_DIR/tailscale-status.sh" << 'EOF'
#!/bin/bash
# Tailscale status checker

echo "🔗 Tailscale Status"
echo "=================="
echo ""

# Check if tailscaled is running
if systemctl is-active --quiet tailscaled; then
    echo "✅ Tailscaled service: Running"
else
    echo "❌ Tailscaled service: Not running"
    echo "   Start with: systemctl start tailscaled"
    exit 1
fi

echo ""
echo "📊 Network Status:"
/storage/tailscale/tailscale status

echo ""
echo "🌐 Tailscale IP:"
/storage/tailscale/tailscale ip -4 2>/dev/null || echo "   Not connected"

echo ""
echo "⚙️  Service Status:"
systemctl status tailscaled --no-pager -l
EOF

    chmod +x "$STORAGE_DIR/tailscale-status.sh"

    echo "✅ Configuration files created"
}

# Enable and start service
enable_service() {
    echo "🚀 Enabling Tailscale service..."
    
    # Enable the service
    systemctl enable tailscaled.service
    
    # Start the service
    systemctl start tailscaled.service
    
    # Wait a moment for the service to start
    sleep 2
    
    # Check if it's running
    if systemctl is-active --quiet tailscaled; then
        echo "✅ Tailscale service is running"
    else
        echo "⚠️  Tailscale service may not have started properly"
        echo "   Check logs with: journalctl -u tailscaled"
    fi
}

# Create easy access aliases
create_aliases() {
    echo "🔗 Creating convenient access scripts..."
    
    # Create symlinks in /storage for easy access
    ln -sf "$STORAGE_DIR/tailscale" /storage/tailscale-cmd 2>/dev/null || true
    ln -sf "$STORAGE_DIR/tailscale-up.sh" /storage/tailscale-up 2>/dev/null || true
    ln -sf "$STORAGE_DIR/tailscale-status.sh" /storage/tailscale-status 2>/dev/null || true
    
    echo "✅ Quick access commands created:"
    echo "   /storage/tailscale-up [auth-key]  # Connect to Tailscale"
    echo "   /storage/tailscale-status         # Check status"
    echo "   /storage/tailscale-cmd status     # Direct tailscale command"
}

# Main installation
main() {
    # Check if running on LibreELEC
    if [ ! -f /etc/libreelec-release ]; then
        echo "⚠️  This script is designed for LibreELEC"
        echo "   It may work on other systems but is not tested"
    fi
    
    # Check if already installed
    if [ -f "$STORAGE_DIR/tailscale" ] && [ -f "$SYSTEMD_DIR/tailscaled.service" ]; then
        echo "✅ Tailscale appears to already be installed"
        echo "   Run /storage/tailscale-status to check"
        echo "   Or run /storage/tailscale-up to connect"
        exit 0
    fi
    
    detect_architecture
    download_tailscale
    create_systemd_service
    create_config_files
    enable_service
    create_aliases
    
    echo ""
    echo "🎉 Tailscale Installation Complete!"
    echo "=================================="
    echo ""
    echo "📋 Next Steps:"
    echo "1. Connect to Tailscale network:"
    echo "   /storage/tailscale-up"
    echo ""
    echo "2. Or use an auth key (recommended for automation):"
    echo "   /storage/tailscale-up YOUR_AUTH_KEY_HERE"
    echo ""
    echo "3. Check status anytime:"
    echo "   /storage/tailscale-status"
    echo ""
    echo "🔗 Your LibreELEC device will be accessible on your Tailscale network!"
    echo "   No port forwarding needed - secure WireGuard VPN connection."
}

# Run installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
