# SoulBox Will-o'-Wisp Media Center

Welcome to the **SoulBox Knowledge Base** - your comprehensive guide to building, deploying, and managing the SoulBox Will-o'-Wisp media center operating system.

## What is SoulBox?

SoulBox is a **turnkey media center solution** built specifically for ARM64 devices like the Raspberry Pi 5. It combines a lightweight Debian base with a fully configured Kodi media center, creating an appliance-like experience that just works.

**Perfect for:**
- Home media servers
- Living room entertainment centers  
- Digital signage displays
- Anyone wanting Kodi without the hassle

## Current Status

**Production Ready** ✅ - Works in GitHub Actions, Gitea Actions, Docker, and all CI/CD environments

- **Latest Version**: v0.2.1 
- **Build Date**: 2025-08-31
- **Image Size**: 1.1GB (56MB compressed)
- **Build System**: Container-Friendly with LibreELEC methodology

## Wiki Navigation

### 🏗️ **[[Architecture]]**
Learn about the revolutionary container-friendly build system, technology stack, and LibreELEC-inspired methodology that makes SoulBox possible.

### 🔧 **[[Build-System]]**  
Comprehensive documentation of the primary build script, container-friendly processes, and the build flow that creates SoulBox images.

### 🚀 **[[Deployment-Guide]]**
Step-by-step instructions for deploying SoulBox images, whether from pre-built releases or local builds.

### 🎯 **[[Features]]**
Complete overview of SoulBox features, system requirements, performance characteristics, and what you get out-of-the-box.

### 👨‍💻 **[[Development]]**
Development workflow, CI/CD integration, local development setup, and contributing guidelines.

### 🔧 **[[Troubleshooting]]**
Common issues, solutions, validation commands, and debugging techniques for both build-time and runtime problems.

---

## Quick Links

- **📥 [Download Latest Release](https://192.168.176.113:3000/yourusername/soulbox/releases/latest)** - Ready-to-flash SD card images
- **🔨 [Build from Source](Build-System)** - Container-friendly build instructions
- **📋 [System Requirements](Features#system-requirements)** - Hardware and software requirements
- **🚨 [Troubleshooting](Troubleshooting)** - Common issues and solutions

## Key Innovations

1. **Container-Friendly Design** - No loop devices, no mounting, no privileges required
2. **LibreELEC Methodology** - Battle-tested staging approach with populatefs
3. **Universal Compatibility** - Works in any CI/CD environment  
4. **First Boot Strategy** - Self-configuring package installation on target hardware
5. **Space Efficient** - Smart cleanup and compression for distribution

## Evolution Journey

We evolved through **three major architectural approaches** to achieve our current bulletproof system:

1. **Phase 1**: Docker + Debootstrap ❌ *(Failed - ARM64 emulation unreliable)*
2. **Phase 2**: Loop Device Mounting ⚠️ *(Privileged - Limited CI/CD compatibility)*  
3. **Phase 3**: Container-Friendly ✅ *(Current - LibreELEC approach, works everywhere)*

---

**The blue flame now burns bright, stable, and container-ready! 🔥**

*Last Updated: 2025-08-31 | Build System Version: LibreELEC-Style Container-Friendly v3.1*
