#!/bin/bash

# Apply patches to LibreELEC build system for better download reliability

LIBREELEC_DIR="$1"

if [ ! -d "$LIBREELEC_DIR" ]; then
    echo "Error: LibreELEC directory not found: $LIBREELEC_DIR"
    exit 1
fi

echo "Applying download reliability patches to $LIBREELEC_DIR"

# Create a custom get script with fallback mirrors
cat > "$LIBREELEC_DIR/scripts/get-with-fallback" << 'EOF'
#!/bin/bash

# Enhanced get script with fallback mirrors for critical packages
source $SCRIPTS/get

# Override the original get function for specific packages
original_get_pkg() {
  $SCRIPTS/get "$@"
}

get_pkg_with_fallback() {
  local pkg_name="$1"
  
  # Define GNU mirror alternatives
  GNU_MIRRORS=(
    "https://ftp.gnu.org/gnu"
    "https://mirrors.kernel.org/gnu"
    "https://ftpmirror.gnu.org"
    "https://mirror.dogado.de/gnu"
  )
  
  # Try original download first
  if original_get_pkg "$pkg_name"; then
    return 0
  fi
  
  # For GNU packages, try alternative mirrors
  case "$pkg_name" in
    gmp|mpfr|mpc|gcc|binutils|gdb)
      echo "Trying alternative GNU mirrors for $pkg_name..."
      for mirror in "${GNU_MIRRORS[@]}"; do
        if [ -f "packages/$pkg_name/package.mk" ]; then
          # Temporarily modify PKG_URL to use alternative mirror
          original_url=$(grep "PKG_URL=" "packages/$pkg_name/package.mk" | cut -d'"' -f2)
          if [[ "$original_url" == *"gnu.org"* ]]; then
            # Extract the path part after the domain
            url_path=${original_url#*gnu.org}
            new_url="$mirror$url_path"
            echo "Trying mirror: $new_url"
            
            # Temporarily replace URL and try download
            sed -i.bak "s|PKG_URL=.*|PKG_URL=\"$new_url\"|" "packages/$pkg_name/package.mk"
            if original_get_pkg "$pkg_name"; then
              echo "Successfully downloaded $pkg_name from $mirror"
              return 0
            fi
            # Restore original URL
            mv "packages/$pkg_name/package.mk.bak" "packages/$pkg_name/package.mk"
          fi
        fi
      done
      ;;
  esac
  
  echo "Failed to download $pkg_name from all sources"
  return 1
}

# Replace the get function
get_pkg_with_fallback "$@"
EOF

chmod +x "$LIBREELEC_DIR/scripts/get-with-fallback"

echo "Download reliability patches applied successfully"
