#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import subprocess
import xbmcgui

def run_command(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout.strip(), result.stderr.strip()
    except Exception as e:
        return False, "", str(e)

def main():
    # Get Tailscale status
    success, stdout, stderr = run_command("/storage/.kodi/addons/service.tailscale/bin/tailscale status")
    
    if success:
        dialog = xbmcgui.Dialog()
        dialog.textviewer("Tailscale Status", stdout)
    else:
        dialog = xbmcgui.Dialog()
        dialog.ok("Tailscale Status", f"Failed to get status:\n{stderr}")

if __name__ == '__main__':
    main()
