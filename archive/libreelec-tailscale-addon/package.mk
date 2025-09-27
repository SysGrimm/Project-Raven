# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2025-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="tailscale"
PKG_VERSION="1.82.1"
PKG_SHA256="b5b0062d4ad7b79e4be67e66b2b11ed08e4fd9a02dfe6bf7a3e66a0dd5ac8b6c"
PKG_REV="1"
PKG_ARCH="any"
PKG_LICENSE="BSD-3-Clause"
PKG_SITE="https://tailscale.com"
PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_arm64.tgz"
PKG_DEPENDS_TARGET="toolchain"
PKG_SECTION="service"
PKG_SHORTDESC="Tailscale VPN service for LibreELEC"
PKG_LONGDESC="Tailscale (${PKG_VERSION}): A secure network that just works. Zero config VPN. Installs on any device in minutes."
PKG_TOOLCHAIN="manual"

PKG_IS_ADDON="yes"
PKG_ADDON_NAME="Tailscale VPN"
PKG_ADDON_TYPE="xbmc.service"
PKG_ADDON_PROVIDES=""
PKG_ADDON_REQUIRES=""
PKG_ADDON_PROJECTS="RPi RPi2 RPi3 RPi4 RPi5"

# Download appropriate binary based on architecture
pre_unpack() {
  case "${TARGET_ARCH}" in
    "arm")
      PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_arm.tgz"
      ;;
    "aarch64")
      PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_arm64.tgz"
      ;;
    "x86_64")
      PKG_URL="https://pkgs.tailscale.com/stable/tailscale_${PKG_VERSION}_linux_amd64.tgz"
      ;;
    *)
      echo "Unsupported architecture: ${TARGET_ARCH}"
      exit 1
      ;;
  esac
}

unpack() {
  mkdir -p ${PKG_BUILD}
  tar --strip-components=1 -xf ${SOURCES}/${PKG_NAME}/${PKG_NAME}_${PKG_VERSION}_linux_*.tgz -C ${PKG_BUILD}
}

make_target() {
  # No compilation needed, using pre-built binaries
  :
}

makeinstall_target() {
  # Binaries will be installed in addon() function
  :
}

addon() {
  mkdir -p ${ADDON_BUILD}/${PKG_ADDON_ID}/bin
  
  # Copy Tailscale binaries
  cp ${PKG_BUILD}/tailscale ${ADDON_BUILD}/${PKG_ADDON_ID}/bin/
  cp ${PKG_BUILD}/tailscaled ${ADDON_BUILD}/${PKG_ADDON_ID}/bin/
  
  # Make binaries executable
  chmod +x ${ADDON_BUILD}/${PKG_ADDON_ID}/bin/*
}
