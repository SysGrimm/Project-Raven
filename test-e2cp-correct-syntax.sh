#!/bin/bash

# Test script to verify correct e2cp syntax and develop proper Pi OS extraction

set -e

echo "=== E2CP Correct Syntax Test ==="
echo "Understanding proper e2tools usage for Pi OS extraction"
echo

# Create test environment
echo "1. Setting up test environment..."
dd if=/dev/zero of=test.ext4 bs=1M count=20 2>/dev/null
mke2fs -t ext4 -F test.ext4 >/dev/null 2>&1

# Create test content with directory structure
mkdir -p test-source/{bin,lib/{modules/6.6.31-v8+,firmware},etc}
echo "#!/bin/bash" > test-source/bin/bash
echo "#!/bin/bash" > test-source/bin/ls
echo "config" > test-source/etc/config
echo "firmware" > test-source/lib/firmware/test.bin
echo "module" > test-source/lib/modules/6.6.31-v8+/test.ko
chmod +x test-source/bin/*

echo "Test source structure:"
find test-source -type f

echo
echo "2. Testing correct e2cp syntax..."

# Test: Copy individual files (this should work)
echo "  Testing individual file copy..."
if e2cp test-source/bin/bash test.ext4:/bash; then
    echo "  ✓ Individual file copy works"
else
    echo "  ✗ Individual file copy failed"
fi

echo "  Testing file to specific directory..."
e2mkdir test.ext4:/bin 2>/dev/null
if e2cp test-source/bin/bash test.ext4:/bin/bash; then
    echo "  ✓ File to directory copy works"
else
    echo "  ✗ File to directory copy failed"
fi

echo
echo "3. Testing directory extraction approaches..."

# Approach 1: Use find + e2cp (this is what the manual suggests)
echo "  Approach 1: Using find + e2cp with -d flag..."
if find test-source -type f | e2cp -d test.ext4:/ 2>/dev/null; then
    echo "  ✓ Find + e2cp approach works"
else
    echo "  ✗ Find + e2cp approach failed"
fi

# Approach 2: Manual directory creation + file copying
echo "  Approach 2: Manual directory creation + individual file copying..."
e2mkdir test.ext4:/lib 2>/dev/null || true
e2mkdir test.ext4:/lib/modules 2>/dev/null || true
e2mkdir test.ext4:/lib/modules/6.6.31-v8+ 2>/dev/null || true

if e2cp test-source/lib/modules/6.6.31-v8+/test.ko test.ext4:/lib/modules/6.6.31-v8+/test.ko; then
    echo "  ✓ Manual approach works"
else
    echo "  ✗ Manual approach failed"
fi

echo
echo "4. Testing filesystem listing to verify..."
echo "Contents of test filesystem:"
e2ls test.ext4:/ 2>/dev/null || echo "Could not list root"
e2ls test.ext4:/bin 2>/dev/null || echo "Could not list /bin"
e2ls test.ext4:/lib 2>/dev/null || echo "Could not list /lib"

# Cleanup
rm -f test.ext4
rm -rf test-source

echo
echo "=== E2CP Test Complete ==="
echo "This shows us the correct way to extract Pi OS content"
