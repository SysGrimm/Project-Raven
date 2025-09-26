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
# Add addon installation logic here

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

log "First-boot customization completed!"

# Mark as completed
touch /storage/.first-boot-completed
