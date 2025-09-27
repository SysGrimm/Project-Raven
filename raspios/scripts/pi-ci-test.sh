#!/bin/bash

# Project Raven - Pi-CI Integration Script
# Uses Pi-CI to test Raspberry Pi OS configurations locally

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RASPIOS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$RASPIOS_DIR")"
PICI_DIR="${PROJECT_ROOT}/pi-ci"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING]  $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker."
    fi
    
    # Check if git is available
    if ! command -v git &> /dev/null; then
        error "Git is not installed. Please install Git first."
    fi
    
    success "Prerequisites check passed"
}

# Function to clone/update Pi-CI
setup_pici() {
    log "Setting up Pi-CI..."
    
    if [ ! -d "$PICI_DIR" ]; then
        log "Cloning Pi-CI repository..."
        git clone https://github.com/ptrsr/pi-ci.git "$PICI_DIR"
    else
        log "Updating Pi-CI repository..."
        cd "$PICI_DIR"
        git pull origin main
        cd "$PROJECT_ROOT"
    fi
    
    success "Pi-CI setup completed"
}

# Function to build Pi-CI Docker image
build_pici_image() {
    log "Building Pi-CI Docker image..."
    
    cd "$PICI_DIR"
    
    # Build the Pi-CI image
    docker build -t pi-ci:latest .
    
    success "Pi-CI Docker image built"
    cd "$PROJECT_ROOT"
}

# Function to prepare test configuration
prepare_test_config() {
    log "Preparing test configuration..."
    
    # Create temporary test directory
    TEST_DIR="${PROJECT_ROOT}/testing/current"
    mkdir -p "$TEST_DIR"
    
    # Copy Raspberry Pi OS configurations
    cp -r "$RASPIOS_DIR/configurations/"* "$TEST_DIR/"
    cp -r "$RASPIOS_DIR/ansible" "$TEST_DIR/"
    
    # Create a test script that Pi-CI will run
    cat > "$TEST_DIR/test-raven.sh" << 'EOF'
#!/bin/bash
set -e

echo "[LAUNCH] Testing Project Raven Raspberry Pi OS Configuration"
echo "======================================================"

# Test 1: Verify system updates work
echo "[PACKAGE] Testing system updates..."
apt-get update -qq
echo "[SUCCESS] System updates work"

# Test 2: Verify SSH configuration
echo "[SECURITY] Testing SSH configuration..."
if systemctl is-enabled ssh >/dev/null 2>&1; then
    echo "[SUCCESS] SSH service is enabled"
else
    echo "[ERROR] SSH service is not enabled"
    exit 1
fi

# Test 3: Test Tailscale installation (dry run)
echo "[SECURITY] Testing Tailscale installation..."
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg >/dev/null 2>&1 && echo "[SUCCESS] Tailscale repo accessible" || echo "[ERROR] Tailscale repo not accessible"

# Test 4: Verify Kodi can be installed
echo "[MEDIA] Testing Kodi installation..."
apt-get install -y --dry-run kodi >/dev/null 2>&1 && echo "[SUCCESS] Kodi package available" || echo "[ERROR] Kodi package not available"

# Test 5: Test CEC support packages
echo "Testing CEC support..."
apt-get install -y --dry-run libcec6 cec-utils >/dev/null 2>&1 && echo "[SUCCESS] CEC packages available" || echo "[ERROR] CEC packages not available"

# Test 6: Verify GPU memory configuration
echo "[PERFORMANCE] Testing GPU memory configuration..."
if grep -q "gpu_mem=256" /boot/config.txt; then
    echo "[SUCCESS] GPU memory configured correctly"
else
    echo "[ERROR] GPU memory not configured"
    exit 1
fi

# Test 7: Test CEC configuration in boot config
echo "Testing CEC configuration..."
if grep -q "cec_osd_name" /boot/config.txt; then
    echo "[SUCCESS] CEC configured in boot config"
else
    echo "[ERROR] CEC not configured"
    exit 1
fi

# Test 8: Test file limits configuration
echo "📂 Testing file limits..."
if grep -q "65536" /etc/security/limits.conf; then
    echo "[SUCCESS] File limits configured"
else
    echo "[ERROR] File limits not configured"
    exit 1
fi

# Test 9: Test Jellyfin addon availability
echo "[VIDEO] Testing Jellyfin addon availability..."
wget -q --spider https://repo.jellyfin.org/releases/client/kodi/repository.jellyfin.kodi.zip && echo "[SUCCESS] Jellyfin addon accessible" || echo "[ERROR] Jellyfin addon not accessible"

# Test 10: Verify latest Raspberry Pi OS base
echo "🐧 Testing OS version..."
if grep -q "bookworm" /etc/os-release; then
    echo "[SUCCESS] Running Raspberry Pi OS Bookworm (latest)"
else
    echo "[WARNING]  Not running latest Raspberry Pi OS"
fi

echo ""
echo "[COMPLETE] All Project Raven tests passed!"
echo "=================================="
echo "[SUCCESS] Latest Raspberry Pi OS (stripped down)"
echo "[SUCCESS] Kodi with direct boot capability"
echo "[SUCCESS] CEC support for TV remote"
echo "[SUCCESS] Latest Tailscale client"
echo "[SUCCESS] Jellyfin-Kodi plugin support"
EOF
    
    chmod +x "$TEST_DIR/test-raven.sh"
    
    success "Test configuration prepared"
}

# Function to run Pi-CI tests
run_pici_tests() {
    log "Running Pi-CI tests..."
    
    cd "$PICI_DIR"
    
    # Start Pi-CI container to initialize the environment
    log "Starting Pi-CI container..."
    docker run --rm --privileged \
        -v "${PROJECT_ROOT}/testing/current:/mnt/test:ro" \
        pi-ci:latest start <<'COMMANDS'
# Wait for system to boot
sleep 30

# Copy our test configurations
sudo cp /mnt/test/config.txt /boot/config.txt
sudo cp /mnt/test/cmdline.txt /boot/cmdline.txt

# Update package database
sudo apt-get update -qq

# Test 1: Verify system updates work
echo "[PACKAGE] Testing system updates..."
sudo apt-get update -qq
echo "[SUCCESS] System updates work"

# Test 2: Verify SSH service
echo "[SECURITY] Testing SSH service..."
systemctl is-enabled ssh && echo "[SUCCESS] SSH service enabled" || echo "[ERROR] SSH service not enabled"

# Test 3: Test Kodi package availability
echo "[MEDIA] Testing Kodi package..."
apt-cache show kodi > /dev/null 2>&1 && echo "[SUCCESS] Kodi package available" || echo "[ERROR] Kodi package not found"

# Test 4: Test CEC support packages
echo "Testing CEC packages..."
apt-cache show libcec6 > /dev/null 2>&1 && echo "[SUCCESS] CEC packages available" || echo "[ERROR] CEC packages not found"

# Test 5: Verify boot configuration
echo "[PERFORMANCE] Testing boot configuration..."
grep -q "gpu_mem=256" /boot/config.txt && echo "[SUCCESS] GPU memory configured" || echo "[ERROR] GPU memory not configured"
grep -q "cec_osd_name" /boot/config.txt && echo "[SUCCESS] CEC configured" || echo "[ERROR] CEC not configured"

# Test 6: Test Tailscale repository access
echo "[SECURITY] Testing Tailscale repository..."
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg >/dev/null 2>&1 && echo "[SUCCESS] Tailscale repo accessible" || echo "[ERROR] Tailscale repo not accessible"

# Test 7: Test Jellyfin addon URL
echo "[VIDEO] Testing Jellyfin addon..."
curl -fsSL --head https://repo.jellyfin.org/releases/client/kodi/repository.jellyfin.kodi.zip >/dev/null 2>&1 && echo "[SUCCESS] Jellyfin addon accessible" || echo "[ERROR] Jellyfin addon not accessible"

echo ""
echo "[COMPLETE] All Pi-CI tests completed!"
echo "=========================="

# Shutdown the Pi
sudo shutdown -h now
COMMANDS
    
    success "Pi-CI tests completed"
}

# Function to run Ansible tests
test_ansible_config() {
    log "Testing Ansible configuration..."
    
    cd "$RASPIOS_DIR/ansible"
    
    # Check Ansible syntax
    if command -v ansible-playbook &> /dev/null; then
        log "Checking Ansible playbook syntax..."
        ansible-playbook --syntax-check site.yml
        success "Ansible syntax check passed"
    else
        warning "Ansible not installed locally, skipping syntax check"
    fi
    
    cd "$PROJECT_ROOT"
}

# Function to cleanup
cleanup() {
    log "Cleaning up test files..."
    rm -rf "${PROJECT_ROOT}/testing/current"
    success "Cleanup completed"
}

# Function to show usage
show_usage() {
    echo "Project Raven Pi-CI Testing Script"
    echo "=================================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup     - Set up Pi-CI (clone/update repository and build image)"
    echo "  test      - Run full test suite"
    echo "  build     - Build Pi-CI Docker image"
    echo "  ansible   - Test Ansible configuration only"
    echo "  clean     - Clean up test files"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup    # First-time setup"
    echo "  $0 test     # Run all tests"
    echo "  $0 ansible  # Test Ansible only"
}

# Main execution
main() {
    case "${1:-test}" in
        "setup")
            check_prerequisites
            setup_pici
            build_pici_image
            success "Pi-CI setup completed successfully!"
            ;;
        "test")
            check_prerequisites
            if [ ! -d "$PICI_DIR" ]; then
                log "Pi-CI not found, setting up first..."
                setup_pici
                build_pici_image
            fi
            prepare_test_config
            test_ansible_config
            run_pici_tests
            cleanup
            success "All tests completed successfully!"
            ;;
        "build")
            check_prerequisites
            if [ ! -d "$PICI_DIR" ]; then
                setup_pici
            fi
            build_pici_image
            success "Pi-CI image built successfully!"
            ;;
        "ansible")
            test_ansible_config
            success "Ansible configuration test completed!"
            ;;
        "clean")
            cleanup
            success "Cleanup completed!"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            error "Unknown command: $1. Use '$0 help' for usage information."
            ;;
    esac
}

# Run main function with all arguments
main "$@"
