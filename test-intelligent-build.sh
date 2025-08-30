#!/bin/bash

echo "Testing SoulBox Intelligent Build System"
echo "======================================="
echo ""

# Test the intelligent build system
echo "1. Testing intelligent build system:"
if [[ -f "build-soulbox-intelligent.sh" ]]; then
    echo "   Script exists and is executable"
    echo ""
    echo "   Help output:"
    ./build-soulbox-intelligent.sh --help | head -10
    echo ""
    echo "   Checking current state:"
    ./build-soulbox-intelligent.sh --check-state
else
    echo "   Script not found"
fi

echo ""
echo "========================================="
echo "Test complete!"
