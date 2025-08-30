#!/bin/bash
# SoulBox Configuration Deployment Script
# Updates existing SoulBox installations with new configurations
#
# Usage: ./deploy-config.sh [target-host]
#
# If no target host is specified, assumes local deployment

set -euo pipefail

# Configuration
PROJECT_DIR=$(dirname $(dirname $(realpath $0)))
TARGET_HOST="${1:-localhost}"
SERVICE_NAME="kodi-standalone"
REMOTE_USER="pi"
BACKUP_DIR="/home/${REMOTE_USER}/soulbox-backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Execute command locally or remotely
execute_cmd() {
    local cmd="$1"
    local use_sudo="${2:-false}"
    
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        if [[ "${use_sudo}" == "true" ]]; then
            sudo bash -c "${cmd}"
        else
            bash -c "${cmd}"
        fi
    else
        if [[ "${use_sudo}" == "true" ]]; then
            ssh "${REMOTE_USER}@${TARGET_HOST}" "sudo bash -c '${cmd}'"
        else
            ssh "${REMOTE_USER}@${TARGET_HOST}" "${cmd}"
        fi
    fi
}

# Copy file to target
copy_file() {
    local source="$1"
    local dest="$2"
    local use_sudo="${3:-false}"
    
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        if [[ "${use_sudo}" == "true" ]]; then
            sudo cp "${source}" "${dest}"
        else
            cp "${source}" "${dest}"
        fi
    else
        scp "${source}" "${REMOTE_USER}@${TARGET_HOST}:/tmp/$(basename ${source})"
        if [[ "${use_sudo}" == "true" ]]; then
            ssh "${REMOTE_USER}@${TARGET_HOST}" "sudo mv /tmp/$(basename ${source}) ${dest}"
        else
            ssh "${REMOTE_USER}@${TARGET_HOST}" "mv /tmp/$(basename ${source}) ${dest}"
        fi
    fi
}

# Check connectivity and prerequisites
check_target() {
    log_info "Checking target system: ${TARGET_HOST}"
    
    if [[ "${TARGET_HOST}" != "localhost" ]]; then
        if ! ssh -q "${REMOTE_USER}@${TARGET_HOST}" exit; then
            log_error "Cannot connect to ${TARGET_HOST}"
            log_error "Ensure SSH key authentication is set up"
            exit 1
        fi
    fi
    
    # Check if SoulBox is installed
    if ! execute_cmd "systemctl list-unit-files | grep -q ${SERVICE_NAME}" false 2>/dev/null; then
        log_error "SoulBox does not appear to be installed on target system"
        log_error "Run setup-system.sh first"
        exit 1
    fi
    
    log_info "Target system check passed"
}

# Create backup directory
create_backup_dir() {
    log_info "Creating backup directory..."
    
    execute_cmd "mkdir -p ${BACKUP_DIR}/$(date +%Y%m%d_%H%M%S)" false
    
    log_info "Backup directory created"
}

# Backup current configurations
backup_configs() {
    log_info "Backing up current configurations..."
    
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/${backup_timestamp}"
    
    # Backup boot config
    execute_cmd "cp /boot/firmware/config.txt ${backup_path}/config.txt.backup" true
    
    # Backup systemd service
    execute_cmd "cp /etc/systemd/system/${SERVICE_NAME}.service ${backup_path}/${SERVICE_NAME}.service.backup" true
    
    # Backup user configs if they exist
    execute_cmd "if [[ -d /home/reaper/.kodi ]]; then tar -czf ${backup_path}/kodi-config.tar.gz -C /home/reaper .kodi; fi" true
    
    log_info "Configuration backup completed: ${backup_path}"
}

# Deploy boot configuration
deploy_boot_config() {
    log_info "Deploying boot configuration..."
    
    if [[ ! -f "${PROJECT_DIR}/configs/boot/config.txt" ]]; then
        log_warn "Boot config not found, skipping"
        return
    fi
    
    # Validate config for duplicates
    if grep -q "dtoverlay=vc4-kms-v3d.*dtoverlay=vc4-kms-v3d" "${PROJECT_DIR}/configs/boot/config.txt"; then
        log_error "Duplicate dtoverlay entries detected in config.txt"
        exit 1
    fi
    
    copy_file "${PROJECT_DIR}/configs/boot/config.txt" "/boot/firmware/config.txt" true
    
    log_info "Boot configuration deployed"
}

# Deploy systemd service
deploy_service() {
    log_info "Deploying systemd service configuration..."
    
    if [[ ! -f "${PROJECT_DIR}/configs/systemd/${SERVICE_NAME}.service" ]]; then
        log_error "Service file not found"
        exit 1
    fi
    
    # Stop service before updating
    execute_cmd "systemctl stop ${SERVICE_NAME}" true
    
    copy_file "${PROJECT_DIR}/configs/systemd/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service" true
    
    # Reload and restart service
    execute_cmd "systemctl daemon-reload" true
    execute_cmd "systemctl start ${SERVICE_NAME}" true
    
    log_info "Service configuration deployed and restarted"
}

# Update system packages
update_packages() {
    log_info "Updating system packages..."
    
    execute_cmd "apt-get update -qq" true
    execute_cmd "apt-get upgrade -y -qq" true
    
    log_info "System packages updated"
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment..."
    
    # Check service status
    if execute_cmd "systemctl is-active ${SERVICE_NAME}" true >/dev/null 2>&1; then
        log_info "Service ${SERVICE_NAME} is running"
    else
        log_error "Service ${SERVICE_NAME} is not running"
        execute_cmd "journalctl -u ${SERVICE_NAME} --no-pager -n 20" true
        exit 1
    fi
    
    # Check GPU devices
    if execute_cmd "test -c /dev/dri/card0" true >/dev/null 2>&1; then
        log_info "GPU device /dev/dri/card0 is available"
    else
        log_warn "GPU device not found - reboot may be required"
    fi
    
    # Check configuration files
    execute_cmd "grep -q 'dtoverlay=vc4-kms-v3d' /boot/firmware/config.txt" true
    log_info "Boot configuration validated"
    
    log_info "Deployment validation completed"
}

# Display post-deployment information
show_status() {
    log_info "Deployment Status Report"
    echo "=========================="
    
    # Service status
    log_info "Service Status:"
    execute_cmd "systemctl status ${SERVICE_NAME} --no-pager -l" true
    
    # System information
    log_info "System Information:"
    execute_cmd "vcgencmd version || echo 'vcgencmd not available'" false
    execute_cmd "vcgencmd get_config int | head -10 || echo 'GPU config not available'" false
    
    # Disk usage
    log_info "Disk Usage:"
    execute_cmd "df -h / /boot/firmware" false
    
    # Recent logs
    log_info "Recent Service Logs (last 10 lines):"
    execute_cmd "journalctl -u ${SERVICE_NAME} --no-pager -n 10" true
}

# Interactive deployment mode
interactive_deploy() {
    log_info "Starting interactive deployment to ${TARGET_HOST}"
    
    echo "Available deployment options:"
    echo "1. Full deployment (config + service + packages)"
    echo "2. Configuration only (boot config + service)"  
    echo "3. Service only"
    echo "4. Boot config only"
    echo "5. Package update only"
    
    read -p "Select option [1-5]: " option
    
    case $option in
        1)
            deploy_boot_config
            deploy_service
            update_packages
            ;;
        2)
            deploy_boot_config
            deploy_service
            ;;
        3)
            deploy_service
            ;;
        4)
            deploy_boot_config
            ;;
        5)
            update_packages
            ;;
        *)
            log_error "Invalid option selected"
            exit 1
            ;;
    esac
}

# Main deployment process
main() {
    local interactive_mode="${INTERACTIVE:-false}"
    
    log_info "Starting SoulBox configuration deployment..."
    log_info "Target: ${TARGET_HOST}"
    
    check_target
    create_backup_dir
    backup_configs
    
    if [[ "${interactive_mode}" == "true" ]]; then
        interactive_deploy
    else
        # Full deployment by default
        deploy_boot_config
        deploy_service
        update_packages
    fi
    
    validate_deployment
    show_status
    
    log_info "SoulBox deployment completed successfully!"
    
    if [[ "${TARGET_HOST}" != "localhost" ]]; then
        log_info "You may need to reboot the target system for all changes to take effect"
    else
        log_info "Reboot may be required for boot configuration changes"
    fi
}

# Handle script arguments
case "${1:-}" in
    --interactive|-i)
        export INTERACTIVE=true
        TARGET_HOST="${2:-localhost}"
        ;;
    --help|-h)
        echo "Usage: $0 [options] [target-host]"
        echo ""
        echo "Options:"
        echo "  -i, --interactive    Interactive deployment mode"
        echo "  -h, --help          Show this help"
        echo ""
        echo "Examples:"
        echo "  $0                   Deploy to localhost"
        echo "  $0 192.168.1.100     Deploy to remote host"
        echo "  $0 -i soulbox.local  Interactive deployment to remote host"
        exit 0
        ;;
esac

main "$@"
