#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import xbmc
import xbmcaddon
import xbmcgui
import os
import subprocess
import time

class TailscaleConfigService:
    def __init__(self):
        self.addon = xbmcaddon.Addon()
        self.monitor = xbmc.Monitor()
        self.config_dir = "/storage/.config/tailscale"
        self.authkey_file = os.path.join(self.config_dir, "authkey")
        
        # Ensure config directory exists
        os.makedirs(self.config_dir, exist_ok=True)
        
    def log(self, message):
        xbmc.log(f"[Tailscale Config] {message}", xbmc.LOGINFO)
        
    def run_command(self, cmd):
        """Run a system command and return result"""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            return result.returncode == 0, result.stdout.strip(), result.stderr.strip()
        except Exception as e:
            self.log(f"Command failed: {cmd} - Error: {str(e)}")
            return False, "", str(e)
            
    def apply_settings(self):
        """Apply current addon settings"""
        enabled = self.addon.getSettingBool('enabled')
        authkey = self.addon.getSettingString('authkey').strip()
        accept_routes = self.addon.getSettingBool('accept_routes')
        exit_node = self.addon.getSettingString('exit_node').strip()
        hostname = self.addon.getSettingString('hostname').strip()
        advertise_routes = self.addon.getSettingString('advertise_routes').strip()
        ssh_enabled = self.addon.getSettingBool('ssh_enabled')
        
        self.log(f"Applying settings - Enabled: {enabled}, Has authkey: {bool(authkey)}")
        
        if not enabled or not authkey:
            # Disable Tailscale
            self.log("Disabling Tailscale service")
            self.run_command("systemctl stop tailscale")
            self.run_command("systemctl disable tailscale")
            
            # Remove authkey file
            if os.path.exists(self.authkey_file):
                os.remove(self.authkey_file)
            return
            
        # Save authkey to file
        with open(self.authkey_file, 'w') as f:
            f.write(authkey)
        os.chmod(self.authkey_file, 0o600)
        
        # Build tailscale up command
        cmd_parts = ["/storage/.kodi/addons/service.tailscale/bin/tailscale", "up"]
        cmd_parts.append(f"--authkey={authkey}")
        
        if accept_routes:
            cmd_parts.append("--accept-routes")
            
        if exit_node:
            cmd_parts.append(f"--exit-node={exit_node}")
            
        if hostname:
            cmd_parts.append(f"--hostname={hostname}")
            
        if advertise_routes:
            cmd_parts.append(f"--advertise-routes={advertise_routes}")
            
        if ssh_enabled:
            cmd_parts.append("--ssh")
            
        # Enable and start service
        self.log("Enabling Tailscale service")
        self.run_command("systemctl enable tailscale")
        self.run_command("systemctl start tailscale")
        
        # Wait a moment for service to start
        time.sleep(2)
        
        # Run tailscale up command
        cmd = " ".join(cmd_parts)
        self.log(f"Running: {cmd}")
        success, stdout, stderr = self.run_command(cmd)
        
        if success:
            self.log("Tailscale configured successfully")
            xbmcgui.Dialog().notification("Tailscale", "Configuration applied successfully", xbmcgui.NOTIFICATION_INFO, 5000)
        else:
            self.log(f"Tailscale configuration failed: {stderr}")
            xbmcgui.Dialog().notification("Tailscale", f"Configuration failed: {stderr[:50]}...", xbmcgui.NOTIFICATION_ERROR, 8000)
            
    def run(self):
        """Main service loop"""
        self.log("Tailscale Configuration Service started")
        
        # Apply settings on startup
        self.apply_settings()
        
        # Monitor for setting changes
        while not self.monitor.abortRequested():
            if self.monitor.waitForAbort(10):
                break
                
            # Check if settings have changed (simple implementation)
            # In a real addon, you'd want more sophisticated change detection
            
        self.log("Tailscale Configuration Service stopped")

if __name__ == '__main__':
    service = TailscaleConfigService()
    service.run()
