#!/bin/bash
# SoulBox Tailscale First-Boot Configuration
# Handles Tailscale setup and authentication on first boot
#
# This script runs once on first boot to configure Tailscale
# with authentication key or interactive setup

set -euo pipefail

# Configuration
AUTH_KEY_FILE="/boot/firmware/tailscale-authkey.txt"
CONFIG_FILE="/boot/firmware/soulbox-config.txt"
SETUP_COMPLETE_FILE="/var/lib/soulbox-tailscale-setup-complete"
LOCK_FILE="/var/lock/soulbox-tailscale-setup.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" | tee -a /var/log/soulbox-tailscale.log; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a /var/log/soulbox-tailscale.log; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a /var/log/soulbox-tailscale.log; }

# Check if setup already completed
check_setup_complete() {
    if [[ -f "${SETUP_COMPLETE_FILE}" ]]; then
        log_info "Tailscale first-boot setup already completed"
        exit 0
    fi
}

# Create lock file to prevent multiple runs
create_lock() {
    if ! (set -C; echo $$ > "${LOCK_FILE}") 2>/dev/null; then
        log_warn "Setup already running (lock file exists)"
        exit 1
    fi
    trap 'rm -f "${LOCK_FILE}"; exit' INT TERM EXIT
}

# Wait for network connectivity
wait_for_network() {
    log_info "Waiting for network connectivity..."
    local max_attempts=30
    local attempt=0
    
    while ! ping -c 1 1.1.1.1 >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [[ ${attempt} -ge ${max_attempts} ]]; then
            log_error "Network not available after ${max_attempts} attempts"
            return 1
        fi
        log_info "Network not ready, waiting... (${attempt}/${max_attempts})"
        sleep 10
    done
    
    log_info "Network connectivity confirmed"
}

# Read configuration from boot partition
read_config() {
    local hostname=""
    local auth_key=""
    local exit_node=""
    local advertise_routes=""
    
    # Check for Tailscale auth key
    if [[ -f "${AUTH_KEY_FILE}" ]]; then
        auth_key=$(cat "${AUTH_KEY_FILE}" | tr -d '[:space:]')
        log_info "Found Tailscale auth key in ${AUTH_KEY_FILE}"
    fi
    
    # Check for additional configuration
    if [[ -f "${CONFIG_FILE}" ]]; then
        log_info "Reading SoulBox configuration from ${CONFIG_FILE}"
        
        # Parse key-value pairs
        while IFS='=' read -r key value; do
            case "${key}" in
                "hostname")
                    hostname="${value}"
                    ;;
                "tailscale_auth_key")
                    auth_key="${value}"
                    ;;
                "tailscale_exit_node")
                    exit_node="${value}"
                    ;;
                "tailscale_advertise_routes")
                    advertise_routes="${value}"
                    ;;
            esac
        done < "${CONFIG_FILE}"
    fi
    
    # Export variables for use by other functions
    export SOULBOX_HOSTNAME="${hostname}"
    export SOULBOX_AUTH_KEY="${auth_key}"
    export SOULBOX_EXIT_NODE="${exit_node}"
    export SOULBOX_ADVERTISE_ROUTES="${advertise_routes}"
}

# Set hostname if provided
configure_hostname() {
    if [[ -n "${SOULBOX_HOSTNAME:-}" ]]; then
        log_info "Setting hostname to: ${SOULBOX_HOSTNAME}"
        hostnamectl set-hostname "${SOULBOX_HOSTNAME}"
        
        # Update /etc/hosts
        sed -i "s/127.0.1.1.*/127.0.1.1\t${SOULBOX_HOSTNAME}/" /etc/hosts
        log_info "Hostname configured"
    fi
}

# Start Tailscale daemon if not running
start_tailscale_daemon() {
    if ! systemctl is-active --quiet tailscaled; then
        log_info "Starting Tailscale daemon..."
        systemctl start tailscaled
        
        # Wait for daemon to be ready
        local max_attempts=10
        local attempt=0
        while ! tailscale status >/dev/null 2>&1; do
            attempt=$((attempt + 1))
            if [[ ${attempt} -ge ${max_attempts} ]]; then
                log_error "Tailscale daemon failed to start"
                return 1
            fi
            sleep 2
        done
        log_info "Tailscale daemon started"
    fi
}

# Configure Tailscale with authentication
configure_tailscale() {
    local auth_args=""
    
    # Build authentication arguments
    if [[ -n "${SOULBOX_AUTH_KEY:-}" ]]; then
        log_info "Configuring Tailscale with pre-shared auth key"
        auth_args="--auth-key=${SOULBOX_AUTH_KEY}"
    else
        log_info "No auth key provided - manual authentication required"
        auth_args="--qr"  # Show QR code for mobile auth
    fi
    
    # Add additional configuration options
    if [[ -n "${SOULBOX_ADVERTISE_ROUTES:-}" ]]; then
        auth_args="${auth_args} --advertise-routes=${SOULBOX_ADVERTISE_ROUTES}"
        log_info "Advertising routes: ${SOULBOX_ADVERTISE_ROUTES}"
    fi
    
    # Accept routes and enable SSH
    auth_args="${auth_args} --accept-routes --ssh"
    
    # Run tailscale up
    log_info "Bringing up Tailscale..."
    if tailscale up ${auth_args}; then
        log_info "Tailscale successfully configured"
        
        # Configure exit node if specified
        if [[ -n "${SOULBOX_EXIT_NODE:-}" ]]; then
            log_info "Configuring exit node: ${SOULBOX_EXIT_NODE}"
            tailscale set --exit-node="${SOULBOX_EXIT_NODE}"
        fi
        
    else
        log_error "Failed to configure Tailscale"
        return 1
    fi
}

# Display connection information
show_connection_info() {
    log_info "Tailscale Configuration Complete!"
    echo ""
    echo "=== SoulBox Network Information ==="
    
    # Tailscale status
    if tailscale status >/dev/null 2>&1; then
        echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'Not available')"
        echo "Tailscale Status:"
        tailscale status --json | jq -r '.Self | "  Name: \(.DNSName // "Unknown")\n  Online: \(.Online // false)\n  LastSeen: \(.LastSeen // "Unknown")"' 2>/dev/null || echo "  Status details not available"
    else
        echo "Tailscale: Not connected"
    fi
    
    # Local network info
    echo ""
    echo "Local Network:"
    ip route | grep default | awk '{print "  Gateway: " $3 " via " $5}' || echo "  Gateway: Not available"
    hostname -I | awk '{print "  Local IP: " $1}' || echo "  Local IP: Not available"
    
    echo ""
    echo "SSH Access:"
    echo "  Local: ssh reaper@$(hostname -I | awk '{print $1}')"
    if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
        local tailscale_name=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' 2>/dev/null | sed 's/\\.$//' || echo "")
        if [[ -n "${tailscale_name}" ]]; then
            echo "  Tailscale: ssh reaper@${tailscale_name}"
        fi
    fi
    
    echo ""
    echo "Media Center: http://$(hostname -I | awk '{print $1}'):8080 (when Kodi web interface is enabled)"
    echo "=============================================="
}

# Clean up configuration files
cleanup_config_files() {
    log_info "Cleaning up configuration files..."
    
    # Remove auth key file for security
    if [[ -f "${AUTH_KEY_FILE}" ]]; then
        rm -f "${AUTH_KEY_FILE}"
        log_info "Removed auth key file"
    fi
    
    # Keep config file but mark as processed
    if [[ -f "${CONFIG_FILE}" ]]; then
        echo "# Configuration processed on $(date)" >> "${CONFIG_FILE}"
        log_info "Marked config file as processed"
    fi
}

# Mark setup as complete
mark_complete() {
    echo "Tailscale first-boot setup completed on $(date)" > "${SETUP_COMPLETE_FILE}"
    log_info "First-boot setup marked as complete"
}

# Main execution
main() {
    log_info "Starting SoulBox Tailscale first-boot configuration..."
    
    # Initial checks
    check_setup_complete
    create_lock
    
    # Core setup process
    wait_for_network
    read_config
    configure_hostname
    start_tailscale_daemon
    configure_tailscale
    
    # Finalization
    show_connection_info
    cleanup_config_files
    mark_complete
    
    log_info "SoulBox Tailscale first-boot configuration completed successfully!"
    
    # If no auth key was provided, show instructions
    if [[ -z "${SOULBOX_AUTH_KEY:-}" ]]; then
        echo ""
        echo "MANUAL AUTHENTICATION REQUIRED:"
        echo "1. Use the Tailscale mobile app to scan the QR code above, or"
        echo "2. Visit the URL shown above to authenticate this device"
        echo "3. Once authenticated, your SoulBox will be accessible via Tailscale"
    fi
}

# Execute main function if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
