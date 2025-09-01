#!/bin/bash

# SoulBox Build Status and Capability Check
# Shows current build system status and available options

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🔥 SoulBox Will-o'-Wisp Build System Status"
echo "============================================"
echo

# Check available build scripts
log_info "Available build scripts:"
if [[ -x "build-soulbox-full.sh" ]]; then
    log_success "✅ build-soulbox-full.sh (Local development)"
    echo "   • Downloads real Pi firmware and OS"
    echo "   • Creates 2GB fully functional images"
    echo "   • Requires loop device support"
    echo "   • Best for local testing"
else
    log_error "❌ build-soulbox-full.sh not found"
fi

if [[ -x "build-soulbox-enhanced-container.sh" ]]; then
    log_success "✅ build-soulbox-enhanced-container.sh (CI/CD optimized)"
    echo "   • Container-friendly (no loop devices)"
    echo "   • Downloads real Pi firmware and OS"
    echo "   • Creates 1.5GB optimized images"
    echo "   • Perfect for GitHub Actions"
else
    log_error "❌ build-soulbox-enhanced-container.sh not found"
fi

if [[ -x "build-soulbox-containerized.sh" ]]; then
    log_warning "⚠️  build-soulbox-containerized.sh (Legacy)"
    echo "   • Original complex container approach"
    echo "   • LibreELEC-style staging"
    echo "   • Large complex codebase"
    echo "   • Maintained for compatibility"
else
    log_info "❌ build-soulbox-containerized.sh not found"
fi

echo

# Check documentation
log_info "Documentation status:"
if [[ -f "README-Enhanced-Build.md" ]]; then
    log_success "✅ Enhanced build documentation available"
else
    log_warning "⚠️  Enhanced build documentation missing"
fi

if [[ -f "README.md" ]]; then
    log_success "✅ Main project documentation available"
else
    log_warning "⚠️  Main project documentation missing"
fi

echo

# Check CI/CD integration
log_info "CI/CD integration status:"
if [[ -f ".github/workflows/build-release.yml" ]]; then
    log_success "✅ GitHub Actions workflow configured"
    if grep -q "build-soulbox-enhanced-container.sh" ".github/workflows/build-release.yml"; then
        log_success "✅ Workflow uses enhanced container build"
    else
        log_warning "⚠️  Workflow needs update to use enhanced build"
    fi
else
    log_warning "⚠️  GitHub Actions workflow missing"
fi

if [[ -f ".gitea/workflows/build-release.yml" ]]; then
    log_success "✅ Gitea Actions workflow configured"
else
    log_info "❌ Gitea Actions workflow not configured"
fi

echo

# System capability check
log_info "System build capabilities:"

# Check for required tools
required_tools=(curl wget xz parted mkfs.fat mke2fs mcopy e2fsck resize2fs tar sha256sum)
available_tools=()
missing_tools=()

for tool in "${required_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        available_tools+=("$tool")
    else
        missing_tools+=("$tool")
    fi
done

if [[ ${#available_tools[@]} -gt 0 ]]; then
    log_success "✅ Available tools (${#available_tools[@]}/${#required_tools[@]}): ${available_tools[*]}"
fi

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_warning "⚠️  Missing tools: ${missing_tools[*]}"
    echo "   Install with: apt-get install ${missing_tools[*]// / }"
fi

# Check disk space
available_space=$(df -h . | tail -1 | awk '{print $4}')
log_info "Available disk space: $available_space"

# Check loop device support
if [[ -e /dev/loop0 ]] || [[ -c /dev/loop-control ]]; then
    log_success "✅ Loop device support available"
    echo "   • Can use build-soulbox-full.sh for full local builds"
else
    log_warning "⚠️  No loop device support"
    echo "   • Use build-soulbox-enhanced-container.sh for container builds"
fi

echo

# Recommendations
log_info "Build recommendations:"

if [[ ${#missing_tools[@]} -eq 0 ]]; then
    if [[ -e /dev/loop0 ]] || [[ -c /dev/loop-control ]]; then
        log_success "🎯 Recommendation: Use build-soulbox-full.sh for complete local development"
        echo "   ./build-soulbox-full.sh --version v0.3.0 --clean"
    else
        log_success "🎯 Recommendation: Use build-soulbox-enhanced-container.sh for container builds"
        echo "   ./build-soulbox-enhanced-container.sh --version v0.3.0 --clean"
    fi
else
    log_warning "📋 Install missing tools first, then run enhanced container build"
    echo "   sudo apt-get install ${missing_tools[*]// / }"
    echo "   ./build-soulbox-enhanced-container.sh --version v0.3.0 --clean"
fi

echo

log_info "🔥 SoulBox: The blue flame burns bright and guides your build journey!"
