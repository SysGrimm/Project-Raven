#!/bin/bash

echo "🧪 SoulBox Smart Build System Test"
echo "=================================="
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

# Test upstream checker
echo "2. Testing upstream checker:"
if [[ -f "scripts/check-pi-upstream.sh" ]]; then
    echo "   ✅ Upstream checker exists"
    echo "   Current Pi OS: $(./scripts/check-pi-upstream.sh current)"
    echo "   Testing update check..."
    ./scripts/check-pi-upstream.sh check && echo "   ✅ No updates" || echo "   🔄 Updates available"
else
    echo "   ❌ Upstream checker not found"
fi

echo ""

# Test smart build script
echo "3. Testing smart build script:"
if [[ -f "build-soulbox-smart.sh" ]]; then
    echo "   ✅ Smart build script exists"
    echo "   Help output:"
    ./build-soulbox-smart.sh --help | head -6
    echo ""
    echo "   Testing upstream check:"
    ./build-soulbox-smart.sh --check-upstream && echo "   ✅ No rebuild needed" || echo "   🔄 Full rebuild recommended"
else
    echo "   ❌ Smart build script not found"
fi

echo ""

# Check for build components
echo "4. Available build options:"
echo "   Full build: $(test -f "build-soulbox-with-splash.sh" && echo "✅ Available" || echo "❌ Missing")"
echo "   Fast build: $(test -f "build-soulbox-fast.sh" && echo "✅ Available" || echo "❌ Missing")"
echo "   Smart build: $(test -f "build-soulbox-smart.sh" && echo "✅ Available" || echo "❌ Missing")"

echo ""

# Check for potential base images
echo "5. Looking for base images:"
img_count=$(find . -name "*.img" -type f 2>/dev/null | wc -l)
if [[ $img_count -gt 0 ]]; then
    echo "   ✅ Found $img_count image file(s):"
    find . -name "*.img" -type f | while read img; do
        size=$(ls -lh "$img" | awk '{print $5}')
        echo "     $img ($size)"
    done
else
    echo "   ℹ️  No existing .img files found"
fi

echo ""
echo "🎯 System Status Summary:"

all_components=true
if [[ ! -f "scripts/version-manager.sh" ]]; then all_components=false; fi
if [[ ! -f "scripts/check-pi-upstream.sh" ]]; then all_components=false; fi
if [[ ! -f "build-soulbox-smart.sh" ]]; then all_components=false; fi

if [[ "$all_components" == "true" ]]; then
    echo "   ✅ Smart build system is fully operational!"
    echo ""
    echo "📋 Recommended workflow:"
    if [[ $img_count -gt 0 ]]; then
        echo "   • Test smart build: ./build-soulbox-smart.sh"
        echo "   • Force full rebuild: ./build-soulbox-smart.sh --force-full"
        echo "   • Check for updates: ./scripts/check-pi-upstream.sh check"
    else
        echo "   • First build (will be full): ./build-soulbox-smart.sh"
        echo "   • Subsequent builds will be fast unless updates detected"
    fi
    echo ""
    echo "🚀 The system will automatically:"
    echo "   • Detect when Raspberry Pi OS has updates"
    echo "   • Use full builds only when necessary"
    echo "   • Use lightning-fast builds for routine releases"
    echo "   • Maintain proper semantic versioning"
else
    echo "   ❌ Some components missing"
    echo "   Run setup again or check individual components"
fi
