PKG_NAME="setup-wizard"
PKG_VERSION="1.0.0"
PKG_SITE="https://github.com/SysGrimm/Project-Raven"
PKG_DEPENDS_TARGET="toolchain"
PKG_IS_ADDON="yes"
PKG_ADDON_TYPE="xbmc.python.script"
PKG_ADDON_PROVIDES=""
PKG_LONGDESC="Project-Raven setup wizard for initial configuration"

makeinstall_target() {
  # Install setup wizard add-on
  mkdir -p $INSTALL/usr/share/kodi/addons/script.raven.setup
  cp -r $PKG_BUILD/source/* $INSTALL/usr/share/kodi/addons/script.raven.setup/
  
  # Set proper permissions
  chmod -R 755 $INSTALL/usr/share/kodi/addons/script.raven.setup
  
  # Create autostart entry for first boot
  mkdir -p $INSTALL/storage/.config/autostart.d
  cat > $INSTALL/storage/.config/autostart.d/setup-wizard.sh << 'EOF'
#!/bin/bash
# Run setup wizard on first boot
if [ ! -f /storage/.config/raven-setup-complete ]; then
    # Wait for Kodi to fully start
    sleep 30
    # Launch setup wizard
    kodi-send --action="RunScript(script.raven.setup)"
fi
EOF
  chmod +x $INSTALL/storage/.config/autostart.d/setup-wizard.sh
}
