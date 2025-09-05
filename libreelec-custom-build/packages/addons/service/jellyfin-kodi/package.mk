PKG_NAME="jellyfin-kodi"
PKG_VERSION="0.7.11"
PKG_SITE="https://github.com/jellyfin/jellyfin-kodi"
PKG_URL="https://github.com/jellyfin/jellyfin-kodi/archive/v${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain"
PKG_IS_ADDON="yes"
PKG_ADDON_TYPE="xbmc.python.pluginsource"
PKG_ADDON_PROVIDES="video"
PKG_LONGDESC="Jellyfin for Kodi add-on - native integration with Jellyfin server"

# Repository dependencies
PKG_ADDON_REPO_URL="https://kodi.jellyfin.org"
PKG_ADDON_REPO_NAME="Jellyfin Repository"

pre_configure_target() {
  # Create addon directory structure
  mkdir -p $PKG_BUILD/addon
}

makeinstall_target() {
  # Install main Jellyfin add-on
  mkdir -p $INSTALL/usr/share/kodi/addons/plugin.video.jellyfin
  cp -r $PKG_BUILD/jellyfin-kodi-${PKG_VERSION}/* $INSTALL/usr/share/kodi/addons/plugin.video.jellyfin/
  
  # Install Jellyfin service add-on (background sync)
  mkdir -p $INSTALL/usr/share/kodi/addons/service.jellyfin
  cp -r $PKG_BUILD/jellyfin-kodi-${PKG_VERSION}/service.jellyfin/* $INSTALL/usr/share/kodi/addons/service.jellyfin/
  
  # Install JellyCon (lightweight alternative)
  mkdir -p $INSTALL/usr/share/kodi/addons/plugin.video.jellycon
  
  # Set proper permissions
  chmod -R 755 $INSTALL/usr/share/kodi/addons/plugin.video.jellyfin
  chmod -R 755 $INSTALL/usr/share/kodi/addons/service.jellyfin
}
