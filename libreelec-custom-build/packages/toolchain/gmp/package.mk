# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2018-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="gmp"
PKG_VERSION="6.3.0"
PKG_SHA256="a3c2b80201b89e68616f4ad30bc66aee707d3aa15c4e6b613ca88be80c1fe700"
PKG_LICENSE="GPL"
PKG_SITE="https://gmplib.org/"
PKG_URL="https://mirrors.kernel.org/gnu/gmp/gmp-${PKG_VERSION}.tar.xz"
PKG_DEPENDS_HOST="ccache:host autotools:host"
PKG_LONGDESC="GNU Multiple Precision Arithmetic Library."

PKG_CONFIGURE_OPTS_HOST="--enable-cxx \
                         --enable-mpbsd \
                         --disable-shared \
                         --enable-static"

PKG_CONFIGURE_OPTS_TARGET="--enable-cxx \
                           --enable-mpbsd \
                           --enable-shared \
                           --disable-static"
