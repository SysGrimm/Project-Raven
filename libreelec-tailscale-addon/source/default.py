#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025-present Team LibreELEC (https://libreelec.tv)

import os
import sys
import time
import subprocess
import threading
import xbmc
import xbmcaddon
import xbmcgui

class TailscaleService:
    def __init__(self):
        self.addon = xbmcaddon.Addon()
        self.addon_path = xbmc.translatePath(self.addon.getAddonInfo('path'))
        self.addon_data = xbmc.translatePath(self.addon.getAddonInfo('profile'))
        
        # Ensure addon data directory exists
        if not os.path.exists(self.addon_data):
            os.makedirs(self.addon_data)
        
        # Paths to Tailscale binaries
        self.tailscaled_bin = os.path.join(self.addon_path, 'bin', 'tailscaled')
        self.tailscale_bin = os.path.join(self.addon_path, 'bin', 'tailscale')
        
        # State directory for Tailscale
        self.state_dir = os.path.join(self.addon_data, 'tailscale-state')
        if not os.path.exists(self.state_dir):
            os.makedirs(self.state_dir)
        
        # Process handles
        self.tailscaled_process = None
        self.monitor = xbmc.Monitor()
        
        xbmc.log("[Tailscale] Service initialized", xbmc.LOGINFO)

    def start_tailscaled(self):
        """Start the Tailscale daemon"""
        try:
            # Check if already running
            if self.is_tailscaled_running():
                xbmc.log("[Tailscale] tailscaled already running", xbmc.LOGINFO)
                return True
            
            # Start tailscaled daemon
            cmd = [
                self.tailscaled_bin,
                '--state=' + os.path.join(self.state_dir, 'tailscaled.state'),
                '--socket=' + os.path.join(self.state_dir, 'tailscaled.sock'),
                '--port=' + self.addon.getSetting('daemon_port') or '41641'
            ]
            
            xbmc.log("[Tailscale] Starting tailscaled: " + ' '.join(cmd), xbmc.LOGDEBUG)
            
            self.tailscaled_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=dict(os.environ, HOME=self.addon_data)
            )
            
            # Wait a moment for daemon to start
            time.sleep(2)
            
            if self.tailscaled_process.poll() is None:
                xbmc.log("[Tailscale] tailscaled started successfully", xbmc.LOGINFO)
                return True
            else:
                xbmc.log("[Tailscale] tailscaled failed to start", xbmc.LOGERROR)
                return False
                
        except Exception as e:
            xbmc.log("[Tailscale] Error starting tailscaled: " + str(e), xbmc.LOGERROR)
            return False

    def is_tailscaled_running(self):
        """Check if tailscaled is running"""
        try:
            result = subprocess.run(['pgrep', '-f', 'tailscaled'], 
                                  capture_output=True, text=True)
            return result.returncode == 0
        except:
            return False

    def get_tailscale_status(self):
        """Get Tailscale connection status"""
        try:
            cmd = [self.tailscale_bin, '--socket=' + os.path.join(self.state_dir, 'tailscaled.sock'), 'status', '--json']
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                import json
                return json.loads(result.stdout)
            else:
                return None
        except Exception as e:
            xbmc.log("[Tailscale] Error getting status: " + str(e), xbmc.LOGDEBUG)
            return None

    def authenticate_if_needed(self):
        """Check if authentication is needed and handle it"""
        status = self.get_tailscale_status()
        
        if not status:
            xbmc.log("[Tailscale] Cannot get status, daemon may not be running", xbmc.LOGWARNING)
            return
        
        # Check if we need to authenticate
        if status.get('BackendState') == 'NeedsLogin':
            if self.addon.getSetting('auto_login') == 'true':
                self.login()
            else:
                xbmc.log("[Tailscale] Authentication needed but auto_login disabled", xbmc.LOGINFO)
                self.show_auth_notification()

    def login(self):
        """Authenticate with Tailscale"""
        try:
            cmd = [
                self.tailscale_bin,
                '--socket=' + os.path.join(self.state_dir, 'tailscaled.sock'),
                'up'
            ]
            
            # Add auth key if available
            auth_key = self.addon.getSetting('auth_key')
            if auth_key and auth_key.strip():
                cmd.extend(['--authkey', auth_key.strip()])
                xbmc.log("[Tailscale] Using auth key for authentication", xbmc.LOGINFO)
            
            # Add optional flags based on settings
            if self.addon.getSetting('accept_routes') == 'true':
                cmd.append('--accept-routes')
            
            if self.addon.getSetting('accept_dns') == 'true':
                cmd.append('--accept-dns')
            
            hostname = self.addon.getSetting('hostname')
            if hostname:
                cmd.extend(['--hostname', hostname])
            
            xbmc.log("[Tailscale] Logging in with command: " + ' '.join([c for c in cmd if not c.startswith('tskey-')]), xbmc.LOGDEBUG)
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                xbmc.log("[Tailscale] Login successful", xbmc.LOGINFO)
                self.show_notification("Tailscale", "Connected successfully")
                return True
            else:
                xbmc.log("[Tailscale] Login failed: " + result.stderr, xbmc.LOGERROR)
                if "visit the admin console" in result.stderr:
                    self.show_auth_notification()
                return False
                
        except Exception as e:
            xbmc.log("[Tailscale] Error during login: " + str(e), xbmc.LOGERROR)
            return False

    def show_auth_notification(self):
        """Show notification that manual authentication is needed"""
        self.show_notification(
            "Tailscale Authentication Required",
            "Please run 'tailscale up' manually or check addon settings",
            time=10000
        )

    def show_notification(self, title, message, time=5000):
        """Show a Kodi notification"""
        try:
            xbmcgui.Dialog().notification(title, message, xbmcgui.NOTIFICATION_INFO, time)
        except:
            pass

    def stop_tailscale(self):
        """Stop Tailscale services"""
        try:
            # Stop tailscaled daemon
            if self.tailscaled_process and self.tailscaled_process.poll() is None:
                self.tailscaled_process.terminate()
                self.tailscaled_process.wait(timeout=10)
                xbmc.log("[Tailscale] tailscaled stopped", xbmc.LOGINFO)
        except:
            pass

    def run(self):
        """Main service loop"""
        xbmc.log("[Tailscale] Service starting", xbmc.LOGINFO)
        
        # Start tailscaled daemon
        if not self.start_tailscaled():
            xbmc.log("[Tailscale] Failed to start daemon, exiting", xbmc.LOGERROR)
            return
        
        # Wait for daemon to initialize
        time.sleep(3)
        
        # Authenticate if needed and enabled
        self.authenticate_if_needed()
        
        # Main monitoring loop
        while not self.monitor.abortRequested():
            # Check if settings changed
            if self.monitor.waitForAbort(30):  # Check every 30 seconds
                break
            
            # Restart daemon if it died
            if not self.is_tailscaled_running():
                xbmc.log("[Tailscale] Daemon died, restarting", xbmc.LOGWARNING)
                self.start_tailscaled()
                time.sleep(3)
                self.authenticate_if_needed()
        
        # Cleanup on exit
        self.stop_tailscale()
        xbmc.log("[Tailscale] Service stopped", xbmc.LOGINFO)


class Monitor(xbmc.Monitor):
    def __init__(self, service):
        self.service = service
        xbmc.Monitor.__init__(self)

    def onSettingsChanged(self):
        """Called when addon settings are changed"""
        xbmc.log("[Tailscale] Settings changed, restarting service", xbmc.LOGINFO)
        # Settings changed, restart service
        self.service.stop_tailscale()
        time.sleep(2)
        self.service.start_tailscaled()
        time.sleep(3)
        self.service.authenticate_if_needed()


if __name__ == "__main__":
    try:
        service = TailscaleService()
        monitor = Monitor(service)
        service.run()
    except Exception as e:
        xbmc.log("[Tailscale] Service error: " + str(e), xbmc.LOGERROR)
