#!/bin/bash

# First Boot Customization Script
# This script runs on the first boot to apply custom configurations

LOG_FILE="/var/log/first-boot-custom.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting first-boot customization..."

# Wait for system to be ready
sleep 10

# Create custom directories
log "Creating custom directories..."
mkdir -p /storage/.kodi/userdata
mkdir -p /storage/.kodi/addons
mkdir -p /storage/downloads
mkdir -p /storage/media

# Set up Kodi configuration if not exists
if [ ! -f /storage/.kodi/userdata/guisettings.xml ]; then
    log "Setting up initial Kodi configuration..."
    # Copy any custom Kodi settings here
fi

# Install custom addons
log "Installing custom addons..."

# Install Tailscale if configuration is provided
if [ -f /flash/tailscale-install.sh ]; then
    log "Installing Tailscale VPN..."
    chmod +x /flash/tailscale-install.sh
    if /flash/tailscale-install.sh; then
        log "Tailscale installation completed successfully"
        
        # Auto-connect if auth key is provided
        if [ -f /storage/tailscale/config ]; then
            . /storage/tailscale/config
            if [ -n "$TAILSCALE_AUTH_KEY" ] && [ "$AUTO_CONNECT" = "true" ]; then
                log "Auto-connecting to Tailscale network..."
                /storage/tailscale-up "$TAILSCALE_AUTH_KEY" >> "$LOG_FILE" 2>&1 || log "Tailscale auto-connect failed (manual setup required)"
            fi
        fi
    else
        log "Tailscale installation failed"
    fi
fi

# Set permissions
log "Setting permissions..."
chown -R kodi:kodi /storage/.kodi
chmod -R 755 /storage/downloads
chmod -R 755 /storage/media

# Network configuration
log "Applying network settings..."
# Add any network customizations here

# System tweaks
log "Applying system tweaks..."
# Enable SSH if needed
systemctl enable sshd
systemctl start sshd

# Install Tailscale addon (always installed, but only activated if configured)
log "Installing Tailscale addon..."
if [ -d /storage/.kodi/addons/service.tailscale ]; then
    log "Tailscale addon already installed"
else
    # Install Tailscale addon
    mkdir -p /storage/.kodi/addons/service.tailscale
    
    # Copy addon files if they exist in our package
    if [ -f /flash/tailscale-addon.tar.gz ]; then
        cd /storage/.kodi/addons/
        tar -xzf /flash/tailscale-addon.tar.gz
        log "Tailscale addon extracted from package"
    fi
fi

# Create Tailscale configuration directory
mkdir -p /storage/.config/tailscale

# Check if Tailscale auth key is configured
TAILSCALE_KEY_FILE="/storage/.config/tailscale/authkey"
if [ -f "$TAILSCALE_KEY_FILE" ] && [ -s "$TAILSCALE_KEY_FILE" ]; then
    log "Tailscale auth key found, enabling service..."
    systemctl enable tailscale
    systemctl start tailscale
    
    # Attempt authentication
    /storage/.kodi/addons/service.tailscale/bin/tailscale up --authkey="$(cat $TAILSCALE_KEY_FILE)" --accept-routes
    log "Tailscale authentication attempted"
else
    log "No Tailscale auth key found - service will remain disabled"
    log "Configure via LibreELEC Settings > Services > Tailscale"
    # Create placeholder file with instructions
    cat > /storage/.config/tailscale/README.txt << 'EOF'
Tailscale Configuration:

To enable Tailscale VPN:
1. Get an auth key from https://login.tailscale.com/admin/settings/keys
2. Add it via LibreELEC Settings > Services > Tailscale
   OR
3. Place the key in: /storage/.config/tailscale/authkey
4. Restart LibreELEC or run: systemctl restart tailscale

The Tailscale addon is installed but disabled until configured.
EOF
fi

log "First-boot customization completed!"

# Mark as completed
touch /storage/.first-boot-completed
