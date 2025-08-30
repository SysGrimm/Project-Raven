#!/bin/bash

echo "🧪 SoulBox Fast Build System Test"
echo "================================="
echo ""

# Test version manager
echo "1. Testing version management:"
if [[ -f "scripts/version-manager.sh" ]]; then
    echo "   ✅ Version manager exists"
    echo "   Current version: $(./scripts/version-manager.sh get-current)"
    echo "   Next version: $(./scripts/version-manager.sh auto)"
else
    echo "   ❌ Version manager not found"
fi

echo ""

# Test fast build script
echo "2. Testing fast build script:"
if [[ -f "build-soulbox-fast.sh" ]]; then
    echo "   ✅ Fast build script exists"
    echo "   Help output:"
    ./build-soulbox-fast.sh --help | head -5
else
    echo "   ❌ Fast build script not found"
fi

echo ""

# Check for potential base images
echo "3. Looking for potential base images:"
img_count=$(find . -name "*.img" -type f 2>/dev/null | wc -l)
if [[ $img_count -gt 0 ]]; then
    echo "   ✅ Found $img_count image file(s):"
    ./build-soulbox-fast.sh --list-images
else
    echo "   ℹ️  No existing .img files found"
    echo "   You'll need to create a base image first using:"
    echo "   ./build-soulbox-with-splash.sh"
fi

echo ""
echo "🎯 System Status:"
if [[ -f "scripts/version-manager.sh" ]] && [[ -f "build-soulbox-fast.sh" ]]; then
    echo "   ✅ Fast build system is ready!"
    echo ""
    echo "📋 Next steps:"
    if [[ $img_count -gt 0 ]]; then
        echo "   • Test fast build: ./build-soulbox-fast.sh"
        echo "   • Specific version: ./build-soulbox-fast.sh -v v1.0.0"
    else
        echo "   • Create base image: ./build-soulbox-with-splash.sh"
        echo "   • Then use fast builds: ./build-soulbox-fast.sh"
    fi
else
    echo "   ❌ Setup incomplete"
fi
