#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025-present Team LibreELEC (https://libreelec.tv)

import os
import subprocess
import json
import xbmc
import xbmcaddon
import xbmcgui

def show_status():
    """Display Tailscale status information"""
    addon = xbmcaddon.Addon()
    addon_path = xbmc.translatePath(addon.getAddonInfo('path'))
    addon_data = xbmc.translatePath(addon.getAddonInfo('profile'))
    
    tailscale_bin = os.path.join(addon_path, 'bin', 'tailscale')
    socket_path = os.path.join(addon_data, 'tailscale-state', 'tailscaled.sock')
    
    try:
        # Get status
        result = subprocess.run([tailscale_bin, '--socket=' + socket_path, 'status', '--json'], 
                              capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0:
            status = json.loads(result.stdout)
            
            # Format status information
            backend_state = status.get('BackendState', 'Unknown')
            self_node = status.get('Self', {})
            tailscale_ips = self_node.get('TailscaleIPs', [])
            
            info_lines = [
                "Status: " + backend_state,
                "Device: " + self_node.get('HostName', 'Unknown'),
                "User: " + self_node.get('UserID', 'Unknown')
            ]
            
            if tailscale_ips:
                info_lines.append("IP: " + ', '.join(tailscale_ips))
            
            # Count peers
            peers = status.get('Peer', {})
            if peers:
                online_peers = sum(1 for peer in peers.values() if peer.get('Online', False))
                info_lines.append(f"Peers: {online_peers}/{len(peers)} online")
            
            info_text = '\n'.join(info_lines)
            
        else:
            info_text = "Error getting status:\n" + result.stderr
            
    except Exception as e:
        info_text = "Error: " + str(e)
    
    # Show dialog
    dialog = xbmcgui.Dialog()
    dialog.textviewer("Tailscale Status", info_text)

if __name__ == "__main__":
    show_status()
