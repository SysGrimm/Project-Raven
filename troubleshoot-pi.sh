#!/bin/bash

# Project Raven - Live Troubleshooting Script
# Run this on the Pi to diagnose Kodi auto-launch issues

echo "=== Project Raven Troubleshooting ==="
echo

echo "1. Checking if Kodi user exists..."
id kodi 2>/dev/null && echo "✓ kodi user exists" || echo "✗ kodi user missing"

echo
echo "2. Checking Kodi installation..."
which kodi 2>/dev/null && echo "✓ Kodi installed at $(which kodi)" || echo "✗ Kodi not found"

echo
echo "3. Checking Kodi service..."
sudo systemctl status kodi --no-pager || echo "✗ Kodi service not found/configured"

echo
echo "4. Checking auto-login configuration..."
sudo systemctl status getty@tty1 --no-pager | head -10

echo
echo "5. Checking for custom services..."
sudo systemctl list-units --type=service | grep -E "(kodi|raven|firstboot)"

echo
echo "6. Checking boot scripts..."
ls -la /boot/raven* 2>/dev/null || echo "No raven boot scripts found"

echo
echo "7. Checking if firstboot service ran..."
sudo journalctl -u raven-firstboot --no-pager | tail -10 || echo "No firstboot service logs"

echo
echo "8. Checking current user and groups..."
whoami
groups

echo
echo "9. Checking display environment..."
echo "DISPLAY: $DISPLAY"
echo "XDG_SESSION_TYPE: $XDG_SESSION_TYPE"

echo
echo "10. Testing manual Kodi launch..."
echo "Try running: kodi-standalone"
