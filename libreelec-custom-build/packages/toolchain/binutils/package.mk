# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2018-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="binutils"
PKG_VERSION="2.41"
PKG_SHA256="ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450"
PKG_LICENSE="GPL"
PKG_SITE="https://www.gnu.org/software/binutils/"
PKG_URL="https://mirrors.kernel.org/gnu/binutils/binutils-${PKG_VERSION}.tar.xz"
PKG_DEPENDS_HOST="ccache:host autotools:host flex:host gettext:host"
PKG_DEPENDS_TARGET="zlib"
PKG_LONGDESC="The GNU Binutils are a collection of binary tools."

PKG_CONFIGURE_OPTS_HOST="--target=${TARGET_NAME} \
                         --with-sysroot=${SYSROOT_PREFIX} \
                         --with-lib-path=${SYSROOT_PREFIX}/lib:${SYSROOT_PREFIX}/usr/lib \
                         --enable-poison-system-directories \
                         --disable-multilib \
                         --disable-sim \
                         --disable-gdb \
                         --disable-libdecnumber \
                         --disable-readline \
                         --with-mpc=${TOOLCHAIN}/lib \
                         --with-mpfr=${TOOLCHAIN}/lib \
                         --with-gmp=${TOOLCHAIN}/lib \
                         --with-cloog=${TOOLCHAIN}/lib \
                         --with-isl=${TOOLCHAIN}/lib \
                         --disable-static \
                         --enable-shared"

post_makeinstall_host() {
  # Create symlinks for tools
  (
    cd ${TOOLCHAIN}/bin
    for i in ${TARGET_NAME}-*; do
      ln -sf $i $(echo $i | sed "s/${TARGET_NAME}-//g")
    done
  )
}

PKG_CONFIGURE_OPTS_TARGET="--enable-shared \
                           --disable-static \
                           --disable-multilib \
                           --disable-sim \
                           --disable-gdb \
                           --disable-libdecnumber \
                           --disable-readline \
                           --with-mpc=${SYSROOT_PREFIX}/usr \
                           --with-mpfr=${SYSROOT_PREFIX}/usr \
                           --with-gmp=${SYSROOT_PREFIX}/usr \
                           --with-cloog=${SYSROOT_PREFIX}/usr \
                           --with-isl=${SYSROOT_PREFIX}/usr"
