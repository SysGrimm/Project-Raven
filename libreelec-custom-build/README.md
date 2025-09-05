# LibreELEC Custom Build - Project Raven

This directory contains the build configuration for creating a custom LibreELEC image with:

- 🔐 **Tailscale VPN** - Pre-installed and configured
- 🎨 **Custom Kodi Theme** - Your personalized interface
- 📦 **Additional Add-ons** - Pre-selected useful add-ons
- ⚙️ **Optimized Settings** - Pre-configured for best experience

## Build Process Overview

1. **Clone LibreELEC source** - Get the official build system
2. **Add custom packages** - Include Tailscale and other add-ons
3. **Configure theme** - Set up custom Kodi skin/theme
4. **Build image** - Create the final `.img` file
5. **Flash & deploy** - Install on Raspberry Pi or other device

## Directory Structure

```
libreelec-custom-build/
├── README.md                    # This file
├── build-setup.sh              # Initial build environment setup
├── packages/                   # Custom add-on packages
│   └── addons/
│       └── service/
│           └── tailscale/      # Our Tailscale add-on
├── config/                     # Build configuration
│   ├── options.conf           # Build options
│   └── project.conf           # Project-specific settings
├── customizations/             # Image customizations
│   ├── themes/                # Custom Kodi themes/skins
│   ├── addons/                # Additional add-ons to include
│   └── settings/              # Pre-configured Kodi settings
└── scripts/                   # Build automation scripts
    ├── build-image.sh         # Main build script
    └── post-build.sh          # Post-build customizations
```

## Next Steps

Run `./build-setup.sh` to initialize the LibreELEC build environment and begin customization.
