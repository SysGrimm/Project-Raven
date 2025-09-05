PKG_NAME="skin-copacetic"
PKG_VERSION="2.1.8"
PKG_SITE="https://github.com/scarfa/Copacetic"
PKG_URL="https://github.com/scarfa/Copacetic/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_IS_ADDON="yes"
PKG_ADDON_TYPE="xbmc.gui.skin"
PKG_ADDON_PROVIDES=""
PKG_LONGDESC="Copacetic skin for Kodi - clean, modern interface optimized for media centers"

# Ensure compatibility with LibreELEC 12.x / Kodi 21.x
PKG_KODI_VERSION="21.0"

makeinstall_target() {
  # Install Copacetic skin
  mkdir -p $INSTALL/usr/share/kodi/addons/skin.copacetic
  cp -r $PKG_BUILD/Copacetic-${PKG_VERSION}/* $INSTALL/usr/share/kodi/addons/skin.copacetic/
  
  # Set proper permissions
  chmod -R 755 $INSTALL/usr/share/kodi/addons/skin.copacetic
  
  # Create skin configuration for default settings
  mkdir -p $INSTALL/usr/share/kodi/system/settings
  
  # Add default skin setting to settings template
  cat >> $INSTALL/usr/share/kodi/system/settings/settings.xml << EOF
  <setting id="lookandfeel.skin" value="skin.copacetic" />
EOF
}
