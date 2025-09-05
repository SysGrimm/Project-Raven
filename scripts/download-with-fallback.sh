#!/bin/bash

# LibreELEC custom download script with fallback mirrors
# This script provides alternative download sources for critical packages

PACKAGE_NAME="$1"
PACKAGE_URL="$2"
DESTINATION="$3"

echo "Custom downloader: Attempting to download $PACKAGE_NAME from $PACKAGE_URL to $DESTINATION"

# Define alternative mirrors for known problematic packages
case "$PACKAGE_NAME" in
    "gmp-"*)
        FALLBACK_URLS=(
            "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
            "https://mirrors.kernel.org/gnu/gmp/gmp-6.3.0.tar.xz"
            "https://ftpmirror.gnu.org/gmp/gmp-6.3.0.tar.xz"
            "https://mirror.dogado.de/gnu/gmp/gmp-6.3.0.tar.xz"
        )
        ;;
    "mpfr-"*)
        FALLBACK_URLS=(
            "https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
            "https://mirrors.kernel.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
            "https://ftpmirror.gnu.org/mpfr/mpfr-4.2.1.tar.xz"
        )
        ;;
    "mpc-"*)
        FALLBACK_URLS=(
            "https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz"
            "https://mirrors.kernel.org/gnu/mpc/mpc-1.3.1.tar.gz"
            "https://ftpmirror.gnu.org/mpc/mpc-1.3.1.tar.gz"
        )
        ;;
    *)
        FALLBACK_URLS=()
        ;;
esac

# Function to attempt download with timeout and retries
download_with_retry() {
    local url="$1"
    local dest="$2"
    local timeout=30
    local retries=3
    
    echo "Trying to download from: $url"
    wget --timeout=$timeout --tries=$retries -c -O "$dest" "$url"
    return $?
}

# Try original URL first
if download_with_retry "$PACKAGE_URL" "$DESTINATION"; then
    echo "Successfully downloaded $PACKAGE_NAME from original URL"
    exit 0
fi

# Try fallback URLs if original failed
for fallback_url in "${FALLBACK_URLS[@]}"; do
    echo "Original URL failed, trying fallback: $fallback_url"
    if download_with_retry "$fallback_url" "$DESTINATION"; then
        echo "Successfully downloaded $PACKAGE_NAME from fallback URL: $fallback_url"
        exit 0
    fi
done

echo "ERROR: Failed to download $PACKAGE_NAME from all available sources"
echo "Original URL: $PACKAGE_URL"
echo "Tried fallback URLs: ${FALLBACK_URLS[*]}"
exit 1
