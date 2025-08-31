# SoulBox Development

This page covers the development workflow, CI/CD integration, local development setup, and contributing guidelines for SoulBox.

## Development Workflow

### Getting Started

#### Prerequisites
- Docker installed and running
- Git for version control
- Text editor or IDE
- Basic shell/bash knowledge

#### Repository Setup
```bash
# Clone the repository
git clone https://192.168.176.113:3000/yourusername/soulbox.git
cd soulbox

# Check repository structure
tree -L 2
```

#### Development Environment
```bash
# Install development dependencies (Ubuntu/Debian)
sudo apt update
sudo apt install -y \
    e2fsprogs e2fsprogs-extra \
    mtools parted dosfstools \
    curl xz-utils git

# Verify Docker installation
docker --version
docker run hello-world
```

### Local Development Build

#### Quick Build
```bash
# Standard build with auto-version
./build-soulbox-containerized.sh

# Clean build with specific version
./build-soulbox-containerized.sh --version "v1.0.0-dev" --clean
```

#### Development Build Options
```bash
# Debug build with verbose output
./build-soulbox-containerized.sh --debug --keep-temp

# Custom work directory for inspection
./build-soulbox-containerized.sh --work-dir "/tmp/soulbox-dev"

# Custom output location
./build-soulbox-containerized.sh --output-dir "./dev-builds"
```

#### Build Environment Variables
```bash
# Development configuration
export SOULBOX_DEBUG="true"
export SOULBOX_KEEP_TEMP="true"
export SOULBOX_WORK_DIR="/tmp/soulbox-dev"

# Custom base image (for testing)
export SOULBOX_PI_OS_URL="https://custom-mirror.com/"
export SOULBOX_BASE_IMAGE="test-bookworm-arm64.img.xz"

# Build optimizations
export SOULBOX_PARALLEL_JOBS="4"
export SOULBOX_CACHE_DOWNLOADS="true"
```

### Code Organization

#### Repository Structure
```
soulbox/
├── .github/workflows/       # CI/CD automation
│   └── build-release.yml    # Gitea Actions workflow
├── build/                   # Build output directory
├── scripts/                 # Build and utility scripts
│   ├── build-image.sh       # Legacy build script
│   └── gitea-version-manager.sh # Version management
├── config/                  # System configuration files
├── assets/                  # Branding and media assets
│   └── logos/              # Logo files
├── wiki/                   # Documentation (this wiki)
├── build-soulbox-containerized.sh # Primary build script
├── TFM.md                  # Legacy technical documentation
└── README.md               # Project overview
```

#### Key Development Files

**Primary Build Script**: `build-soulbox-containerized.sh`
- Container-friendly build orchestration
- LibreELEC-inspired staging methodology
- Intelligent tool selection and fallbacks

**Version Management**: `scripts/gitea-version-manager.sh`
- Automatic version detection via Gitea API
- Semantic version increment logic
- Release tag management

**CI/CD Workflow**: `.github/workflows/build-release.yml`
- Gitea Actions automation
- Artifact generation and upload
- Release creation and publishing

### Development Process

#### Feature Development
1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Implement Changes**
   - Modify build scripts or configuration
   - Test locally with debug builds
   - Verify container compatibility

3. **Test Build**
   ```bash
   ./build-soulbox-containerized.sh --debug --version "test-$(date +%s)"
   ```

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/new-feature
   # Create pull request via Gitea web interface
   ```

#### Testing Strategy

**Local Testing**
```bash
# Test build process
./build-soulbox-containerized.sh --debug --keep-temp

# Verify image integrity
file build/soulbox-*.img
fdisk -l build/soulbox-*.img

# Check image contents (if tools available)
mkdir -p /tmp/test-mount
sudo mount -o loop,offset=... build/soulbox-*.img /tmp/test-mount
ls -la /tmp/test-mount/
sudo umount /tmp/test-mount
```

**Hardware Testing**
```bash
# Flash test image to SD card
sudo dd if=build/soulbox-test.img of=/dev/sdX bs=4M status=progress

# Monitor first boot (via HDMI or SSH)
ssh pi@<raspberry-pi-ip>
tail -f /var/log/soulbox-setup.log
```

**Container Testing**
```bash
# Test in various container environments
docker run -v "$(pwd):/workspace" -w /workspace ubuntu:22.04 \
    bash -c "apt update && apt install -y e2fsprogs mtools parted curl xz-utils && ./build-soulbox-containerized.sh"
```

## CI/CD Integration

### Gitea Actions Workflow

#### Workflow Configuration
File: `.github/workflows/build-release.yml`

```yaml
name: Build SoulBox SD Card Image
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: ubuntu:22.04
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
    
    - name: Install dependencies
      run: |
        apt-get update
        apt-get install -y \
          e2fsprogs e2fsprogs-extra \
          mtools parted dosfstools \
          curl xz-utils git
    
    - name: Build SoulBox image
      run: |
        chmod +x build-soulbox-containerized.sh
        ./build-soulbox-containerized.sh --clean
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v4
      with:
        name: soulbox-image
        path: build/
```

#### Workflow Features
- **Automatic Triggers**: Push to main/develop, PRs, manual dispatch
- **Container Environment**: Ubuntu 22.04 with required tools
- **Dependency Installation**: Automatic setup of build tools
- **Artifact Upload**: Build outputs automatically preserved
- **Release Creation**: Automatic release for main branch pushes

#### Build Artifacts
Every successful CI build produces:
```
soulbox-v0.2.1.img               # Bootable SD card image (1.1GB)
soulbox-v0.2.1.img.sha256        # SHA256 checksum
soulbox-v0.2.1.img.tar.gz        # Compressed image (56MB)
soulbox-v0.2.1.img.tar.gz.sha256 # Compressed checksum
version.txt                      # Build version information
build-log.txt                    # Complete build log
```

### Version Management

#### Automatic Versioning
The `scripts/gitea-version-manager.sh` script provides:
- **API Integration**: Queries Gitea API for latest release
- **Semantic Versioning**: Automatic patch increment (v1.0.0 → v1.0.1)
- **Manual Override**: Support for custom version specification
- **Tag Management**: Automatic git tag creation on release

#### Version Detection Logic
```bash
# Automatic version detection
if [ -z "$VERSION" ]; then
    if [ -f "scripts/gitea-version-manager.sh" ]; then
        VERSION=$(./scripts/gitea-version-manager.sh --get-next)
    else
        VERSION="v$(date +%Y%m%d-%H%M%S)"
    fi
fi
```

#### Manual Version Override
```bash
# Specify custom version
./build-soulbox-containerized.sh --version "v2.0.0-beta1"

# Environment variable
export SOULBOX_VERSION="v2.0.0-rc1"
./build-soulbox-containerized.sh
```

### Release Process

#### Automated Release (Main Branch)
1. **Commit to Main**: Push changes to main branch
2. **CI Trigger**: Gitea Actions automatically starts build
3. **Build Process**: Complete image build with artifacts
4. **Version Detection**: Auto-increment from latest release
5. **Release Creation**: New Gitea release with downloadable assets
6. **Artifact Upload**: Image, checksums, and logs attached

#### Manual Release
```bash
# Create release tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Or use Gitea API
curl -X POST "https://192.168.176.113:3000/api/v1/repos/yourusername/soulbox/releases" \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tag_name": "v1.0.0",
    "name": "SoulBox v1.0.0",
    "body": "Release description"
  }'
```

## Advanced Development

### Build System Customization

#### Custom Base Images
```bash
# Use different Pi OS version
export SOULBOX_PI_OS_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-03-15/"
export SOULBOX_BASE_IMAGE="2024-03-12-raspios-bookworm-arm64-lite.img.xz"

# Test with custom image
./build-soulbox-containerized.sh --version "custom-test"
```

#### Build Script Modifications
Key functions to customize in `build-soulbox-containerized.sh`:

```bash
# Customize boot configuration
create_boot_config() {
    # Add custom config.txt settings
    echo "gpu_mem=128" >> "$boot_content/config.txt"
    echo "dtoverlay=vc4-kms-v3d" >> "$boot_content/config.txt"
    # Custom Pi 5 optimizations...
}

# Customize root filesystem
create_root_customizations() {
    # Add custom packages to first boot
    cat >> "$first_boot_script" << 'EOF'
apt-get install -y custom-package
EOF
    # Custom user configurations...
}

# Customize branding
create_soulbox_assets() {
    # Custom MOTD, logos, themes
    # Replace default branding assets
}
```

### Container Development

#### Docker Build Environment
```dockerfile
# Dockerfile for development environment
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    e2fsprogs e2fsprogs-extra \
    mtools parted dosfstools \
    curl xz-utils git \
    vim nano \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["/bin/bash"]
```

```bash
# Build and use development container
docker build -t soulbox-dev .
docker run -it --rm -v "$(pwd):/workspace" soulbox-dev

# Inside container
./build-soulbox-containerized.sh --debug
```

#### Multi-Platform Development
```bash
# Test on different architectures
docker run --platform linux/amd64 -v "$(pwd):/workspace" -w /workspace ubuntu:22.04 bash
docker run --platform linux/arm64 -v "$(pwd):/workspace" -w /workspace ubuntu:22.04 bash

# Cross-platform build verification
docker buildx build --platform linux/amd64,linux/arm64 -t soulbox-builder .
```

### Debugging and Troubleshooting

#### Debug Build Analysis
```bash
# Enable comprehensive debugging
./build-soulbox-containerized.sh \
    --debug \
    --keep-temp \
    --work-dir "/tmp/soulbox-debug"

# Analyze temporary files
ls -la /tmp/soulbox-debug/
tree /tmp/soulbox-debug/

# Examine staging directory
ls -la /tmp/soulbox-debug/staging/
find /tmp/soulbox-debug/staging/ -type f | wc -l

# Check filesystem extraction
ls -la /tmp/soulbox-debug/boot-content/
ls -la /tmp/soulbox-debug/root-content/
```

#### Build Log Analysis
```bash
# Review build logs
tail -f build-log.txt

# Search for specific issues
grep -i error build-log.txt
grep -i warning build-log.txt

# Check tool availability
grep "tool available" build-log.txt
grep "populatefs\|e2tools" build-log.txt
```

#### Image Verification
```bash
# Check image structure
fdisk -l build/soulbox-*.img

# Verify checksums
sha256sum -c build/soulbox-*.img.sha256

# Check file system integrity
fsck.fat -v build/soulbox-boot.part
fsck.ext4 -f build/soulbox-root.part
```

## Contributing Guidelines

### Code Style

#### Shell Script Standards
- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use meaningful variable names
- Quote all variables: `"$variable"`
- Use functions for repeated code
- Add logging with `log_info`, `log_error`

#### Documentation Standards
- Document all functions and major sections
- Include usage examples
- Update README.md for user-facing changes
- Update wiki for technical details

### Pull Request Process

1. **Fork Repository**: Create personal fork of main repository
2. **Create Branch**: Use descriptive branch names (`feature/xyz`, `fix/abc`)
3. **Implement Changes**: Follow code style and test thoroughly
4. **Test Builds**: Verify local builds work correctly
5. **Update Documentation**: Update relevant documentation
6. **Submit PR**: Create pull request with detailed description
7. **Address Reviews**: Respond to feedback and make necessary changes
8. **Merge**: Maintainer will merge after approval

### Issue Reporting

#### Bug Reports
Include in bug reports:
- SoulBox version
- Build environment (OS, Docker version)
- Complete error logs
- Steps to reproduce
- Expected vs actual behavior

#### Feature Requests
Include in feature requests:
- Use case description
- Proposed implementation approach
- Impact on existing functionality
- Compatibility considerations

### Development Environment Setup

#### IDE Configuration

**VS Code Extensions**:
- ShellCheck (shell script linting)
- Docker (container development)
- Git Graph (version control visualization)
- Markdown All in One (documentation)

**Vim Configuration**:
```vim
" .vimrc additions for shell development
syntax on
set tabstop=4
set shiftwidth=4
set expandtab
set number
```

#### Git Configuration
```bash
# Set up Git for development
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Useful Git aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
```

---

## Development Roadmap

### Current Sprint
- **Container Optimization**: Improve build speed and resource usage
- **Tool Enhancement**: Better populatefs integration and fallback logic
- **Documentation**: Complete wiki migration from TFM.md

### Next Release (v0.3.0)
- **Pi 4 Support**: Extend compatibility to Raspberry Pi 4
- **Custom Branding**: User-configurable themes and assets  
- **Web Interface**: Basic configuration web UI
- **Build Caching**: Speed up repeated builds

### Future Features
- **Multi-arch Support**: ARM32 and x86_64 builds
- **Plugin System**: Extensible addon architecture
- **Cloud Integration**: S3/B2 storage backends
- **Cluster Management**: Multi-device coordination

---

*Join the SoulBox development community and help build the future of turnkey media center systems! 🔥*

**← Back to [[Features]] | Next: [[Troubleshooting]] →**
