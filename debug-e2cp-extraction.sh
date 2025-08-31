#!/bin/bash

# Debug script to test e2cp functionality and identify extraction issues
# This will help us understand why the Pi OS extraction is failing

set -e

echo "=== E2CP Debug Script ==="
echo "Testing e2cp functionality to diagnose extraction failures"
echo

# Check if e2tools is available
if ! command -v e2cp >/dev/null 2>&1; then
    echo "ERROR: e2cp not found - installing e2tools"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install e2tools
    else
        sudo apt-get update && sudo apt-get install -y e2tools
    fi
fi

# Test basic e2cp functionality
echo "1. Testing e2cp basic functionality..."
e2cp --help 2>&1 | head -10 || echo "e2cp help not available"

echo
echo "2. Testing e2ls functionality..."
e2ls --help 2>&1 | head -10 || echo "e2ls help not available"

echo
echo "3. Creating test ext4 filesystem..."
dd if=/dev/zero of=test.ext4 bs=1M count=10 2>/dev/null
mke2fs -t ext4 -F test.ext4 >/dev/null 2>&1

echo "4. Testing basic e2cp operations..."
# Create test content
mkdir -p test-content/subdir
echo "test file" > test-content/test.txt
echo "nested file" > test-content/subdir/nested.txt

# Test individual file copy
echo "  Testing single file copy..."
if e2cp test-content/test.txt test.ext4:/test.txt 2>/dev/null; then
    echo "  ✓ Single file copy works"
else
    echo "  ✗ Single file copy failed"
fi

# Test directory listing
echo "  Testing directory listing..."
if e2ls test.ext4:/ 2>/dev/null; then
    echo "  ✓ Directory listing works"
else
    echo "  ✗ Directory listing failed"
fi

# Test recursive copy - this is where our issue likely is
echo "  Testing recursive directory copy..."
if e2cp -r test-content test.ext4:/ 2>/dev/null; then
    echo "  ✓ Recursive copy works"
else
    echo "  ✗ Recursive copy failed - this is our problem!"
    
    # Try alternative syntax
    echo "  Trying alternative syntax: e2cp -r test-content/ test.ext4:/"
    if e2cp -r test-content/ test.ext4:/ 2>/dev/null; then
        echo "  ✓ Alternative syntax works"
    else
        echo "  ✗ Alternative syntax also failed"
        
        # Try without recursive flag
        echo "  Trying manual directory creation + file copy..."
        if e2mkdir test.ext4:/test-content 2>/dev/null; then
            echo "    ✓ Manual directory creation works"
            if e2cp test-content/test.txt test.ext4:/test-content/ 2>/dev/null; then
                echo "    ✓ File copy into created directory works"
            else
                echo "    ✗ File copy into created directory failed"
            fi
        else
            echo "    ✗ Manual directory creation failed"
        fi
    fi
fi

echo
echo "5. Final filesystem verification..."
echo "Contents of test filesystem:"
e2ls test.ext4:/ 2>/dev/null || echo "Could not list filesystem contents"

# Cleanup
rm -f test.ext4
rm -rf test-content

echo
echo "=== E2CP Debug Complete ==="
echo "This should help identify the correct syntax for Pi OS extraction"
