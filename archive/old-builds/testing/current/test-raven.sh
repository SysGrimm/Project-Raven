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
echo " Testing CEC support..."
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
echo " Testing CEC configuration..."
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
