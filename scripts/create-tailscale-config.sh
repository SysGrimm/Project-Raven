#!/bin/bash
# SoulBox Tailscale Configuration Generator
# Creates configuration files for first-boot Tailscale setup
#
# Usage: ./create-tailscale-config.sh [options]

set -euo pipefail

# Default values
OUTPUT_DIR="."
AUTH_KEY=""
HOSTNAME=""
EXIT_NODE=""
ADVERTISE_ROUTES=""
INTERACTIVE="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show usage information
show_usage() {
    cat << EOF
SoulBox Tailscale Configuration Generator

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -k, --auth-key KEY       Tailscale authentication key
    -h, --hostname NAME      Set hostname for the device
    -e, --exit-node NODE     Use specified exit node
    -r, --routes ROUTES      Advertise specified routes (comma-separated)
    -o, --output DIR         Output directory (default: current directory)
    -i, --interactive        Interactive configuration mode
    --help                   Show this help

EXAMPLES:
    # Interactive mode
    $0 --interactive

    # With auth key
    $0 --auth-key tskey-auth-ABC123...

    # Full configuration
    $0 --auth-key tskey-auth-ABC123... \\
       --hostname soulbox-living-room \\
       --exit-node 100.64.0.1 \\
       --routes 192.168.1.0/24,10.0.0.0/8

    # Generate for SD card
    $0 --auth-key tskey-auth-ABC123... \\
       --output /Volumes/SOULBOOT

FILES CREATED:
    tailscale-authkey.txt    - Authentication key (if provided)
    soulbox-config.txt       - Configuration file with settings

EOF
}

# Interactive configuration
interactive_config() {
    log_info "Starting interactive Tailscale configuration..."
    echo ""
    
    # Hostname
    read -p "Enter hostname for this SoulBox (optional): " HOSTNAME
    
    # Auth key
    echo ""
    echo "Tailscale Authentication Key:"
    echo "  1. Get from: https://login.tailscale.com/admin/settings/keys"
    echo "  2. Create a reusable key for device authentication"
    echo "  3. Leave empty for manual authentication during first boot"
    echo ""
    read -p "Enter Tailscale auth key (optional): " AUTH_KEY
    
    # Exit node
    echo ""
    echo "Exit Node (optional):"
    echo "  - IP address or hostname of a Tailscale exit node"
    echo "  - Routes all traffic through this node"
    echo ""
    read -p "Enter exit node (optional): " EXIT_NODE
    
    # Advertised routes
    echo ""
    echo "Advertise Routes (optional):"
    echo "  - Comma-separated list of networks to advertise"
    echo "  - Example: 192.168.1.0/24,10.0.0.0/8"
    echo ""
    read -p "Enter routes to advertise (optional): " ADVERTISE_ROUTES
    
    # Output directory
    echo ""
    read -p "Output directory [current directory]: " OUTPUT_DIR
    OUTPUT_DIR="${OUTPUT_DIR:-./}"
}

# Validate auth key format
validate_auth_key() {
    local key="$1"
    if [[ -n "${key}" ]] && [[ ! "${key}" =~ ^tskey-(auth-|reusable-)[a-zA-Z0-9]+ ]]; then
        log_warn "Auth key format may be incorrect"
        log_warn "Expected format: tskey-auth-... or tskey-reusable-..."
    fi
}

# Generate configuration files
generate_config_files() {
    log_info "Generating configuration files in: ${OUTPUT_DIR}"
    
    # Create output directory if it doesn't exist
    mkdir -p "${OUTPUT_DIR}"
    
    # Generate auth key file if provided
    if [[ -n "${AUTH_KEY}" ]]; then
        echo "${AUTH_KEY}" > "${OUTPUT_DIR}/tailscale-authkey.txt"
        chmod 600 "${OUTPUT_DIR}/tailscale-authkey.txt"
        log_info "Created: ${OUTPUT_DIR}/tailscale-authkey.txt"
    fi
    
    # Generate main configuration file
    local config_file="${OUTPUT_DIR}/soulbox-config.txt"
    cat > "${config_file}" << EOF
# SoulBox Configuration File
# Generated on $(date)
#
# This file is read by the SoulBox first-boot configuration script
# Place this file in /boot/firmware/ on your SD card

EOF
    
    # Add hostname if specified
    if [[ -n "${HOSTNAME}" ]]; then
        echo "hostname=${HOSTNAME}" >> "${config_file}"
    fi
    
    # Add Tailscale auth key if specified (alternative to separate file)
    if [[ -n "${AUTH_KEY}" ]]; then
        echo "# tailscale_auth_key=${AUTH_KEY}" >> "${config_file}"
        echo "# (Auth key is in separate tailscale-authkey.txt file)" >> "${config_file}"
    fi
    
    # Add exit node if specified
    if [[ -n "${EXIT_NODE}" ]]; then
        echo "tailscale_exit_node=${EXIT_NODE}" >> "${config_file}"
    fi
    
    # Add advertised routes if specified
    if [[ -n "${ADVERTISE_ROUTES}" ]]; then
        echo "tailscale_advertise_routes=${ADVERTISE_ROUTES}" >> "${config_file}"
    fi
    
    # Add configuration notes
    cat >> "${config_file}" << 'EOF'

# Additional configuration options:
# hostname=my-soulbox               # Set device hostname
# tailscale_auth_key=tskey-auth-... # Tailscale authentication key
# tailscale_exit_node=100.64.0.1    # Use specific exit node
# tailscale_advertise_routes=192.168.1.0/24,10.0.0.0/8  # Advertise routes

# Network configuration will be handled automatically
# SSH access will be enabled via Tailscale
# Kodi will be accessible via local network and Tailscale

EOF
    
    log_info "Created: ${config_file}"
}

# Show deployment instructions
show_instructions() {
    log_info "Configuration files generated successfully!"
    echo ""
    echo "=== Deployment Instructions ==="
    echo ""
    echo "1. Copy the generated files to your SD card's boot partition:"
    if [[ -n "${AUTH_KEY}" ]]; then
        echo "   - tailscale-authkey.txt"
    fi
    echo "   - soulbox-config.txt"
    echo ""
    echo "2. Insert SD card into Raspberry Pi and boot SoulBox"
    echo ""
    echo "3. First-boot process will:"
    echo "   - Configure hostname (if specified)"
    echo "   - Install and configure Tailscale"
    if [[ -n "${AUTH_KEY}" ]]; then
        echo "   - Automatically authenticate with provided key"
    else
        echo "   - Show QR code for manual authentication"
    fi
    if [[ -n "${EXIT_NODE}" ]]; then
        echo "   - Configure exit node: ${EXIT_NODE}"
    fi
    if [[ -n "${ADVERTISE_ROUTES}" ]]; then
        echo "   - Advertise routes: ${ADVERTISE_ROUTES}"
    fi
    echo "   - Enable SSH access via Tailscale"
    echo "   - Start Kodi media center"
    echo ""
    echo "4. Access your SoulBox:"
    echo "   - SSH: ssh reaper@<tailscale-hostname>"
    echo "   - Kodi: http://<tailscale-ip>:8080 (if web interface enabled)"
    echo ""
    echo "=== Security Notes ==="
    echo "- Auth key file will be deleted after first use"
    echo "- SSH is enabled and accessible via Tailscale"
    echo "- Firewall is configured for security"
    echo ""
    
    if [[ -z "${AUTH_KEY}" ]]; then
        echo "=== Manual Authentication Required ==="
        echo "Since no auth key was provided:"
        echo "1. Connect a monitor/TV to see the QR code"
        echo "2. Scan QR code with Tailscale mobile app, or"
        echo "3. Visit the displayed URL to authenticate"
        echo "4. Device will appear in your Tailscale admin panel"
        echo ""
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--auth-key)
                AUTH_KEY="$2"
                shift 2
                ;;
            -h|--hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            -e|--exit-node)
                EXIT_NODE="$2"
                shift 2
                ;;
            -r|--routes)
                ADVERTISE_ROUTES="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -i|--interactive)
                INTERACTIVE="true"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    log_info "SoulBox Tailscale Configuration Generator"
    
    # Parse arguments
    parse_args "$@"
    
    # Run interactive mode if requested
    if [[ "${INTERACTIVE}" == "true" ]]; then
        interactive_config
    fi
    
    # Validate inputs
    if [[ -n "${AUTH_KEY}" ]]; then
        validate_auth_key "${AUTH_KEY}"
    fi
    
    # Generate configuration files
    generate_config_files
    
    # Show deployment instructions
    show_instructions
    
    log_info "Configuration generation completed!"
}

# Execute main function
main "$@"
