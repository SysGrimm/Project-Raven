#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import xbmcaddon

def run_command(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout.strip(), result.stderr.strip()
    except Exception as e:
        return False, "", str(e)

def main():
    # Restart Tailscale service
    addon = xbmcaddon.Addon()
    
    # Apply current settings by restarting service
    success1, _, _ = run_command("systemctl restart tailscale")
    
    # Wait and try to connect
    import time
    time.sleep(3)
    
    # Re-run tailscale up with current settings
    from service import TailscaleConfigService
    service = TailscaleConfigService()
    service.apply_settings()

if __name__ == '__main__':
    main()
