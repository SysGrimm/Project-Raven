#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025-present Team LibreELEC (https://libreelec.tv)

import os
import subprocess
import xbmc
import xbmcaddon
import xbmcgui

def reset_auth():
    """Reset Tailscale authentication"""
    addon = xbmcaddon.Addon()
    addon_data = xbmc.translatePath(addon.getAddonInfo('profile'))
    state_dir = os.path.join(addon_data, 'tailscale-state')
    
    # Confirm action
    dialog = xbmcgui.Dialog()
    if not dialog.yesno("Reset Authentication", 
                       "This will log out from Tailscale and reset all authentication.",
                       "Do you want to continue?"):
        return
    
    try:
        # Run tailscale logout
        tailscale_bin = os.path.join(xbmc.translatePath(addon.getAddonInfo('path')), 'bin', 'tailscale')
        socket_path = os.path.join(state_dir, 'tailscaled.sock')
        
        subprocess.run([tailscale_bin, '--socket=' + socket_path, 'logout'], 
                      capture_output=True, timeout=10)
        
        # Remove state files
        state_file = os.path.join(state_dir, 'tailscaled.state')
        if os.path.exists(state_file):
            os.remove(state_file)
        
        dialog.notification("Tailscale", "Authentication reset successfully", 
                          xbmcgui.NOTIFICATION_INFO, 3000)
        
        # Restart service
        xbmc.executebuiltin('StopScript(service.tailscale)')
        xbmc.sleep(2000)
        xbmc.executebuiltin('RunScript(service.tailscale)')
        
    except Exception as e:
        xbmc.log("[Tailscale] Error resetting auth: " + str(e), xbmc.LOGERROR)
        dialog.notification("Tailscale", "Error resetting authentication", 
                          xbmcgui.NOTIFICATION_ERROR, 3000)

if __name__ == "__main__":
    reset_auth()
