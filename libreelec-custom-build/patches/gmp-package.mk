# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2016-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="gmp"
PKG_VERSION="6.3.0"
PKG_SHA256="a3c2b80201b89e68616f4ad30bc66aee707d3aa15c67e2c5a48e7b37f7b7b8e9"
PKG_LICENSE="LGPL"
PKG_SITE="https://gmplib.org/"
# Primary URL with fallbacks in scripts
PKG_URL="https://gmplib.org/download/gmp/gmp-$PKG_VERSION.tar.xz"
PKG_DEPENDS_HOST="gcc:host"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="The GNU Multiple Precision Arithmetic Library."

# Alternative URLs for download fallback
PKG_URL_FALLBACK=(
  "https://ftp.gnu.org/gnu/gmp/gmp-$PKG_VERSION.tar.xz"
  "https://mirrors.kernel.org/gnu/gmp/gmp-$PKG_VERSION.tar.xz"
  "https://ftpmirror.gnu.org/gmp/gmp-$PKG_VERSION.tar.xz"
  "https://mirror.dogado.de/gnu/gmp/gmp-$PKG_VERSION.tar.xz"
)

PKG_CONFIGURE_OPTS_HOST="--enable-cxx --enable-static --disable-shared"

PKG_CONFIGURE_OPTS_TARGET="--enable-cxx --enable-static --disable-shared"
