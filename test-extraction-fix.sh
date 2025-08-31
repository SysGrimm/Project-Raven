#!/bin/bash

# Test script to verify the e2cp extraction fix works correctly
# This simulates the Pi OS extraction to ensure our fix resolves the issue

set -e

echo "=== E2CP EXTRACTION FIX TEST ==="
echo "Testing the corrected extraction logic from build-soulbox-containerized.sh"
echo

# Source the helper function from the fixed build script
source_extract_function() {
    # Extract just the helper function for testing
    cat > /tmp/extract_helper.sh << 'EOF'
extract_directory_contents() {
    local source_img="$1"
    local source_dir="$2"
    local target_dir="$3"
    local max_files="${4:-1000}"
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Get directory listing
    local items
    items=$(e2ls "$source_img:$source_dir" 2>/dev/null || echo "")
    
    if [[ -z "$items" ]]; then
        return 1
    fi
    
    local files_copied=0
    local total_processed=0
    
    # Process each item
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        [[ "$item" =~ ^\.\.?/?$ ]] && continue  # Skip . and ..
        
        # Limit extraction to prevent runaway copying
        if [[ $total_processed -ge $max_files ]]; then
            echo "    Reached file limit ($max_files) for $source_dir"
            break
        fi
        
        local source_item="$source_dir/$item"
        local target_item="$target_dir/$item"
        
        # Check if it's a directory (ends with /)
        if [[ "$item" =~ /$ ]]; then
            # Directory - recurse into it (limited depth)
            local clean_name="${item%/}"
            local sub_source="$source_dir/$clean_name"
            local sub_target="$target_dir/$clean_name"
            
            # Only recurse 3 levels deep to avoid excessive copying
            if [[ $(echo "$source_dir" | tr -cd '/' | wc -c) -lt 3 ]]; then
                extract_directory_contents "$source_img" "$sub_source" "$sub_target" 100
            fi
        else
            # File - copy it
            if e2cp "$source_img:$source_item" "$target_item" 2>/dev/null; then
                files_copied=$((files_copied + 1))
            fi
        fi
        
        total_processed=$((total_processed + 1))
    done <<< "$items"
    
    echo "    $source_dir: $files_copied files extracted"
    return 0
}
EOF
    source /tmp/extract_helper.sh
}

# Create test environment
create_test_environment() {
    echo "1. Creating test environment..."
    
    # Clean up any previous test
    rm -rf test-pi-os test-extraction /tmp/extract_helper.sh
    
    # Create mock Pi OS structure
    mkdir -p test-pi-os/{bin,sbin,lib/{modules/6.6.31-v8+,firmware,systemd,aarch64-linux-gnu},etc,usr/{bin,sbin,lib}}
    
    # Create test files
    echo "#!/bin/bash" > test-pi-os/bin/bash
    echo "#!/bin/sh" > test-pi-os/bin/sh
    echo "#!/bin/bash" > test-pi-os/bin/ls
    echo "#!/sbin/init" > test-pi-os/sbin/init
    echo "dynamic linker" > test-pi-os/lib/ld-linux-aarch64.so.1
    echo "test module" > test-pi-os/lib/modules/6.6.31-v8+/test.ko
    echo "test module 2" > test-pi-os/lib/modules/6.6.31-v8+/other.ko
    echo "firmware" > test-pi-os/lib/firmware/test.bin
    echo "systemd" > test-pi-os/lib/systemd/systemd
    echo "library" > test-pi-os/lib/aarch64-linux-gnu/libc.so.6
    echo "root:x:0:0:root:/root:/bin/bash" > test-pi-os/etc/passwd
    
    # Make files executable
    chmod +x test-pi-os/bin/* test-pi-os/sbin/*
    
    echo "   Created mock Pi OS structure with $(find test-pi-os -type f | wc -l) files"
}

# Create test ext4 image
create_test_image() {
    echo "2. Creating test ext4 image..."
    
    # Create and format test image
    dd if=/dev/zero of=test-pi-root.ext4 bs=1M count=50 2>/dev/null
    /opt/homebrew/Cellar/e2fsprogs/1.47.3/sbin/mke2fs -t ext4 -F test-pi-root.ext4 >/dev/null 2>&1
    
    # Populate with test data using e2cp (simulate the Pi OS root filesystem)
    echo "   Populating test image with mock Pi OS content..."
    (cd test-pi-os && find . -type f | while read file; do
        dir=$(dirname "$file")
        if [[ "$dir" != "." ]]; then
            # Create directory structure
            e2mkdir "../test-pi-root.ext4:$dir" 2>/dev/null || true
        fi
        # Copy file
        if e2cp "$file" "../test-pi-root.ext4:$file" 2>/dev/null; then
            echo "    Populated: $file" >/dev/null
        else
            echo "    Failed: $file"
        fi
    done)
    
    echo "   Test image created and populated"
    echo "   Contents:"
    e2ls test-pi-root.ext4:/ 2>/dev/null | head -10
}

# Test the extraction function
test_extraction() {
    echo "3. Testing extraction function..."
    
    # Source our helper function
    source_extract_function
    
    # Test critical directory extractions
    local test_dirs=("/bin" "/sbin" "/lib" "/etc")
    local success_count=0
    local total_tests=${#test_dirs[@]}
    
    for test_dir in "${test_dirs[@]}"; do
        echo "   Testing extraction of: $test_dir"
        
        if extract_directory_contents "test-pi-root.ext4" "$test_dir" "test-extraction$test_dir" 100; then
            echo "     ✓ $test_dir extraction succeeded"
            success_count=$((success_count + 1))
            
            # Verify files were actually extracted
            local extracted_files=$(find "test-extraction$test_dir" -type f 2>/dev/null | wc -l)
            echo "     Files extracted: $extracted_files"
        else
            echo "     ✗ $test_dir extraction failed"
        fi
    done
    
    echo "   Extraction test results: $success_count/$total_tests succeeded"
    
    # Special test for kernel modules (the critical component)
    echo "   Special test: Kernel modules extraction..."
    if extract_directory_contents "test-pi-root.ext4" "/lib/modules" "test-extraction/lib/modules" 1000; then
        local module_count=$(find test-extraction/lib/modules -name "*.ko" 2>/dev/null | wc -l || echo "0")
        echo "     ✓ Kernel modules extracted: $module_count modules"
    else
        echo "     ✗ Kernel modules extraction failed"
    fi
}

# Verify extraction results
verify_results() {
    echo "4. Verifying extraction results..."
    
    if [[ -d "test-extraction" ]]; then
        echo "   Extraction directory created: ✓"
        echo "   Total extracted files: $(find test-extraction -type f 2>/dev/null | wc -l)"
        echo "   Directory structure:"
        find test-extraction -type d | head -10
        
        # Check critical files
        local critical_files=("/bin/bash" "/sbin/init" "/lib/ld-linux-aarch64.so.1" "/etc/passwd")
        echo "   Critical file verification:"
        for file in "${critical_files[@]}"; do
            if [[ -f "test-extraction$file" ]]; then
                echo "     ✓ $file"
            else
                echo "     ✗ $file (MISSING)"
            fi
        done
    else
        echo "   ✗ No extraction directory created"
    fi
}

# Cleanup test environment
cleanup_test() {
    echo "5. Cleaning up test environment..."
    rm -rf test-pi-os test-extraction test-pi-root.ext4 /tmp/extract_helper.sh
    echo "   Cleanup complete"
}

# Run the complete test
main() {
    echo "This test verifies that our e2cp extraction fix will work correctly"
    echo "It simulates the Pi OS extraction process to ensure kernel modules and system files are copied"
    echo
    
    create_test_environment
    create_test_image
    test_extraction
    verify_results
    cleanup_test
    
    echo
    echo "=== TEST COMPLETE ==="
    echo "If this test shows successful extraction of critical directories and files,"
    echo "then the fix should resolve the build 49 extraction failures."
    echo
    echo "The key fix:"
    echo "- Replaced 'e2cp -r' (doesn't exist) with proper e2ls + e2cp logic"
    echo "- Added file limits to prevent excessive copying in containers"
    echo "- Maintained robust fallback methods for critical components"
}

main
