#!/usr/bin/env python3
"""
Project-Raven Setup Wizard
Configures Jellyfin, Tailscale, and other components on first boot
"""

import xbmc
import xbmcaddon
import xbmcgui
import xbmcvfs
import json
import subprocess
import socket
import os
import time

class RavenSetupWizard:
    def __init__(self):
        self.addon = xbmcaddon.Addon()
        self.addon_path = self.addon.getAddonInfo('path')
        self.setup_complete_file = '/storage/.config/raven-setup-complete'
        
        # Configuration storage
        self.config = {
            'jellyfin_server': '',
            'jellyfin_username': '',
            'jellyfin_password': '',
            'tailscale_authkey': '',
            'device_hostname': self.get_hostname()
        }
    
    def get_hostname(self):
        """Get current device hostname or generate one"""
        try:
            hostname = socket.gethostname()
            if hostname and hostname != 'localhost':
                return hostname
        except:
            pass
        
        # Generate hostname based on device info
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read()
                if 'Raspberry Pi 4' in cpuinfo:
                    return 'LibreELEC-Pi4'
                elif 'Raspberry Pi 5' in cpuinfo:
                    return 'LibreELEC-Pi5'
                else:
                    return 'LibreELEC-Media'
        except:
            return 'LibreELEC-Raven'
    
    def show_welcome_dialog(self):
        """Show welcome screen and check if user wants to run setup"""
        dialog = xbmcgui.Dialog()
        
        welcome_text = (
            "Welcome to Project-Raven!\n\n"
            "This wizard will help you configure:\n"
            "• Jellyfin media server connection\n"
            "• Tailscale VPN for remote access\n"
            "• Copacetic theme and interface\n"
            "• System hostname and settings\n\n"
            "Would you like to run the setup wizard now?\n"
            "(You can always run it later from Add-ons)"
        )
        
        return dialog.yesno(
            "Project-Raven Setup Wizard",
            welcome_text
        )
    
    def get_jellyfin_config(self):
        """Get Jellyfin server configuration from user"""
        dialog = xbmcgui.Dialog()
        
        # Jellyfin server address
        server = dialog.input(
            "Jellyfin Server Address",
            "Enter your Jellyfin server URL (e.g., http://192.168.1.100:8096)",
            defaultt=""
        )
        if not server:
            return False
        
        # Validate URL format
        if not (server.startswith('http://') or server.startswith('https://')):
            server = 'http://' + server
        
        self.config['jellyfin_server'] = server
        
        # Username
        username = dialog.input(
            "Jellyfin Username",
            "Enter your Jellyfin username",
            defaultt=""
        )
        if not username:
            return False
        
        self.config['jellyfin_username'] = username
        
        # Password
        password = dialog.input(
            "Jellyfin Password",
            "Enter your Jellyfin password",
            defaultt="",
            option=xbmcgui.ALPHANUM_HIDE_INPUT
        )
        if not password:
            return False
        
        self.config['jellyfin_password'] = password
        
        return True
    
    def get_tailscale_config(self):
        """Get Tailscale configuration from user"""
        dialog = xbmcgui.Dialog()
        
        # Explain auth key
        info_text = (
            "Tailscale Auth Key Setup\n\n"
            "To automatically connect to your Tailscale network,\n"
            "you'll need an auth key from your Tailscale admin console.\n\n"
            "1. Go to https://login.tailscale.com/admin/settings/keys\n"
            "2. Generate a new auth key\n"
            "3. Copy and paste it below\n\n"
            "Skip this step if you want to authenticate manually later."
        )
        
        dialog.ok("Tailscale Setup", info_text)
        
        # Auth key input
        authkey = dialog.input(
            "Tailscale Auth Key",
            "Paste your Tailscale auth key (or leave blank to skip)",
            defaultt=""
        )
        
        self.config['tailscale_authkey'] = authkey
        
        # Hostname configuration
        hostname = dialog.input(
            "Device Hostname",
            "Choose a name for this device on your Tailscale network",
            defaultt=self.config['device_hostname']
        )
        
        if hostname:
            self.config['device_hostname'] = hostname
        
        return True
    
    def configure_jellyfin(self):
        """Configure Jellyfin add-on with provided settings"""
        if not self.config['jellyfin_server']:
            return True
        
        xbmc.log("Configuring Jellyfin add-on...", xbmc.LOGINFO)
        
        try:
            # Configure main Jellyfin add-on
            jellyfin_addon = xbmcaddon.Addon('plugin.video.jellyfin')
            
            # Set server URL
            jellyfin_addon.setSetting('server_url', self.config['jellyfin_server'])
            jellyfin_addon.setSetting('username', self.config['jellyfin_username'])
            
            # Enable add-on
            xbmc.executebuiltin('EnableAddon(plugin.video.jellyfin)')
            
            # Configure Jellyfin service add-on
            service_addon = xbmcaddon.Addon('service.jellyfin')
            service_addon.setSetting('server_url', self.config['jellyfin_server'])
            service_addon.setSetting('auto_connect', 'true')
            
            xbmc.executebuiltin('EnableAddon(service.jellyfin)')
            
            return True
            
        except Exception as e:
            xbmc.log(f"Error configuring Jellyfin: {str(e)}", xbmc.LOGERROR)
            return False
    
    def configure_tailscale(self):
        """Configure Tailscale add-on with auth key"""
        xbmc.log("Configuring Tailscale add-on...", xbmc.LOGINFO)
        
        try:
            # Configure Tailscale add-on
            tailscale_addon = xbmcaddon.Addon('service.tailscale')
            
            # Set hostname
            tailscale_addon.setSetting('device_hostname', self.config['device_hostname'])
            
            # Set auth key if provided
            if self.config['tailscale_authkey']:
                tailscale_addon.setSetting('auth_key', self.config['tailscale_authkey'])
                tailscale_addon.setSetting('auto_login', 'true')
            
            # Enable add-on
            xbmc.executebuiltin('EnableAddon(service.tailscale)')
            
            # Set system hostname
            try:
                subprocess.run([
                    'hostnamectl', 'set-hostname', self.config['device_hostname']
                ], check=True)
            except:
                # Fallback for systems without hostnamectl
                with open('/storage/.config/hostname', 'w') as f:
                    f.write(self.config['device_hostname'])
            
            return True
            
        except Exception as e:
            xbmc.log(f"Error configuring Tailscale: {str(e)}", xbmc.LOGERROR)
            return False
    
    def configure_theme(self):
        """Set Copacetic as default theme"""
        xbmc.log("Configuring Copacetic theme...", xbmc.LOGINFO)
        
        try:
            # Enable Copacetic skin
            xbmc.executebuiltin('EnableAddon(skin.copacetic)')
            
            # Wait a moment for add-on to be available
            time.sleep(2)
            
            # Set as current skin
            xbmc.executebuiltin('SetSkin(skin.copacetic)')
            
            return True
            
        except Exception as e:
            xbmc.log(f"Error configuring theme: {str(e)}", xbmc.LOGERROR)
            return False
    
    def save_config(self):
        """Save configuration for future reference"""
        try:
            config_file = '/storage/.config/raven-config.json'
            
            # Don't save sensitive information in plain text
            safe_config = {
                'jellyfin_server': self.config['jellyfin_server'],
                'jellyfin_username': self.config['jellyfin_username'],
                'device_hostname': self.config['device_hostname'],
                'setup_completed': True,
                'setup_date': time.strftime('%Y-%m-%d %H:%M:%S')
            }
            
            with open(config_file, 'w') as f:
                json.dump(safe_config, f, indent=2)
            
            return True
            
        except Exception as e:
            xbmc.log(f"Error saving config: {str(e)}", xbmc.LOGERROR)
            return False
    
    def mark_setup_complete(self):
        """Mark setup as completed"""
        try:
            with open(self.setup_complete_file, 'w') as f:
                f.write(time.strftime('%Y-%m-%d %H:%M:%S'))
            return True
        except:
            return False
    
    def show_completion_dialog(self):
        """Show setup completion summary"""
        dialog = xbmcgui.Dialog()
        
        summary = [
            "Project-Raven setup completed successfully!",
            "",
            "Configured components:"
        ]
        
        if self.config['jellyfin_server']:
            summary.append(f"✓ Jellyfin: {self.config['jellyfin_server']}")
        
        if self.config['tailscale_authkey']:
            summary.append(f"✓ Tailscale: {self.config['device_hostname']}")
        
        summary.extend([
            "✓ Copacetic theme activated",
            "",
            "Your media center is ready to use!",
            "",
            "Kodi will now restart to apply all changes."
        ])
        
        dialog.ok("Setup Complete", "\n".join(summary))
    
    def run_setup(self):
        """Main setup wizard flow"""
        xbmc.log("Starting Project-Raven setup wizard", xbmc.LOGINFO)
        
        # Check if already completed
        if os.path.exists(self.setup_complete_file):
            xbmc.log("Setup already completed, skipping wizard", xbmc.LOGINFO)
            return
        
        # Show welcome dialog
        if not self.show_welcome_dialog():
            xbmc.log("User declined setup wizard", xbmc.LOGINFO)
            return
        
        dialog = xbmcgui.Dialog()
        progress = xbmcgui.DialogProgress()
        
        try:
            # Get configuration from user
            if not self.get_jellyfin_config():
                dialog.ok("Setup Cancelled", "Jellyfin configuration is required.")
                return
            
            if not self.get_tailscale_config():
                dialog.ok("Setup Cancelled", "Tailscale configuration cancelled.")
                return
            
            # Show progress dialog
            progress.create("Project-Raven Setup", "Configuring components...")
            
            # Configure components
            progress.update(25, "Configuring Jellyfin...")
            if not self.configure_jellyfin():
                dialog.ok("Setup Error", "Failed to configure Jellyfin. Check your settings.")
                return
            
            progress.update(50, "Configuring Tailscale VPN...")
            if not self.configure_tailscale():
                dialog.ok("Setup Error", "Failed to configure Tailscale. Check your auth key.")
                return
            
            progress.update(75, "Setting up Copacetic theme...")
            if not self.configure_theme():
                dialog.ok("Setup Warning", "Theme configuration failed, but setup will continue.")
            
            progress.update(90, "Saving configuration...")
            self.save_config()
            self.mark_setup_complete()
            
            progress.update(100, "Setup complete!")
            progress.close()
            
            # Show completion dialog
            self.show_completion_dialog()
            
            # Restart Kodi to apply changes
            xbmc.executebuiltin('RestartApp')
            
        except Exception as e:
            progress.close()
            xbmc.log(f"Setup wizard error: {str(e)}", xbmc.LOGERROR)
            dialog.ok("Setup Error", f"An error occurred during setup:\n{str(e)}")

def main():
    """Main entry point"""
    wizard = RavenSetupWizard()
    wizard.run_setup()

if __name__ == '__main__':
    main()
