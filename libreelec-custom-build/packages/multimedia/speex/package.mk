# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2018-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="speex"
PKG_VERSION="1.2.1"
PKG_SHA256="4b44d4f2b38a370a2d98a78329fefc56a0cf93d1c1be70029217baae6628feea"
PKG_LICENSE="BSD"
PKG_SITE="https://www.speex.org/"
PKG_URL="https://ftp.osuosl.org/pub/xiph/releases/speex/speex-${PKG_VERSION}.tar.gz"
PKG_DEPENDS_TARGET="toolchain libogg"
PKG_LONGDESC="Speex is an Open Source/Free Software patent-free audio compression format designed for speech."
PKG_BUILD_FLAGS="+pic"

PKG_CONFIGURE_OPTS_TARGET="--enable-static \
                           --disable-shared \
                           --disable-oggtest \
                           --with-ogg=${SYSROOT_PREFIX}/usr"

post_makeinstall_target() {
  rm -rf ${INSTALL}/usr/bin
}
