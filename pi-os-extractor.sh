#!/bin/bash

# Robust Pi OS extraction function using correct e2tools syntax
# This solves the e2cp -r issue that was causing extraction failures

# Function to recursively extract directory contents from ext4 filesystem
extract_pi_os_directory() {
    local pi_root_image="$1"
    local source_dir="$2"
    local target_dir="$3"
    local verbose="${4:-false}"
    
    [[ "$verbose" == "true" ]] && echo "  Extracting $source_dir -> $target_dir"
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # List contents of source directory
    local contents
    contents=$(e2ls "$pi_root_image:$source_dir" 2>/dev/null || echo "")
    
    if [[ -z "$contents" ]]; then
        [[ "$verbose" == "true" ]] && echo "    WARNING: Directory $source_dir is empty or inaccessible"
        return 1
    fi
    
    local extracted_count=0
    local failed_count=0
    
    # Process each item in the directory
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        
        # Skip . and .. entries
        [[ "$item" =~ ^\.\.?$ ]] && continue
        
        local source_path="$source_dir/$item"
        local target_path="$target_dir/$item"
        
        # Check if item is a directory (e2ls shows directories with trailing /)
        if [[ "$item" =~ /$ ]]; then
            # It's a directory - remove trailing / and recurse
            local clean_item="${item%/}"
            local sub_source="$source_dir/$clean_item"
            local sub_target="$target_dir/$clean_item"
            
            mkdir -p "$sub_target"
            if extract_pi_os_directory "$pi_root_image" "$sub_source" "$sub_target" "$verbose"; then
                extracted_count=$((extracted_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        else
            # It's a file - copy it
            if e2cp "$pi_root_image:$source_path" "$target_path" 2>/dev/null; then
                extracted_count=$((extracted_count + 1))
                [[ "$verbose" == "true" ]] && echo "    ✓ $item"
            else
                failed_count=$((failed_count + 1))
                [[ "$verbose" == "true" ]] && echo "    ✗ $item"
            fi
        fi
    done <<< "$contents"
    
    [[ "$verbose" == "true" ]] && echo "    Extracted: $extracted_count, Failed: $failed_count"
    
    return 0
}

# Function to extract essential Pi OS components using find + e2cp approach
extract_pi_os_with_find() {
    local pi_root_image="$1"
    local target_base_dir="$2"
    local source_dir="$3"
    
    echo "  Using find-based extraction for $source_dir"
    
    # Create target directory
    mkdir -p "$target_base_dir$source_dir"
    
    # Get file list using e2find (if available) or e2ls recursively
    local file_list
    if command -v e2find >/dev/null 2>&1; then
        file_list=$(e2find "$pi_root_image:$source_dir" -type f 2>/dev/null || echo "")
    else
        # Use our recursive function to build file list
        file_list=$(build_file_list "$pi_root_image" "$source_dir")
    fi
    
    if [[ -z "$file_list" ]]; then
        echo "    No files found in $source_dir"
        return 1
    fi
    
    local extracted=0
    local failed=0
    
    # Copy each file
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        
        local target_path="$target_base_dir$file_path"
        local target_dir=$(dirname "$target_path")
        
        # Ensure target directory exists
        mkdir -p "$target_dir"
        
        # Copy the file
        if e2cp "$pi_root_image:$file_path" "$target_path" 2>/dev/null; then
            extracted=$((extracted + 1))
        else
            failed=$((failed + 1))
        fi
        
        # Progress indicator for large directories
        if (( (extracted + failed) % 100 == 0 )); then
            echo "    Progress: $((extracted + failed)) files processed"
        fi
    done <<< "$file_list"
    
    echo "    Extraction complete: $extracted files extracted, $failed failed"
    return 0
}

# Optimized function for mass Pi OS extraction using correct e2tools syntax
extract_critical_pi_os_components() {
    local pi_root_image="$1"
    local target_root="$2"
    local verbose="${3:-true}"
    
    echo "=== ROBUST PI OS EXTRACTION ==="
    echo "Source image: $pi_root_image"
    echo "Target root: $target_root"
    echo
    
    # Verify source image is accessible
    if ! e2ls "$pi_root_image:/" >/dev/null 2>&1; then
        echo "ERROR: Cannot access Pi OS root image: $pi_root_image"
        return 1
    fi
    
    # Create target structure
    mkdir -p "$target_root"
    
    # Critical directories for Pi boot - in order of importance
    local critical_dirs=(
        "/bin"                  # Essential system binaries
        "/sbin"                 # System administration binaries  
        "/lib/aarch64-linux-gnu" # Architecture-specific libraries
        "/lib/ld-linux-aarch64.so.1" # Dynamic linker (special case)
        "/lib/systemd"          # Systemd components
        "/lib/modules"          # Kernel modules (CRITICAL for Pi 5)
        "/lib/firmware"         # Hardware firmware
        "/etc"                  # System configuration
        "/usr/bin"              # User binaries
        "/usr/sbin"             # User system binaries
        "/usr/lib"              # User libraries
    )
    
    local total_success=0
    local total_failed=0
    
    for dir in "${critical_dirs[@]}"; do
        echo "Extracting critical directory: $dir"
        
        # Special handling for the dynamic linker (it's a file, not directory)
        if [[ "$dir" == "/lib/ld-linux-aarch64.so.1" ]]; then
            mkdir -p "$target_root/lib"
            if e2cp "$pi_root_image:$dir" "$target_root$dir" 2>/dev/null; then
                echo "  ✓ Dynamic linker extracted"
                total_success=$((total_success + 1))
            else
                echo "  ✗ Dynamic linker extraction failed"
                total_failed=$((total_failed + 1))
            fi
            continue
        fi
        
        # For directories, use our robust extraction method
        if extract_pi_os_directory "$pi_root_image" "$dir" "$target_root$dir" "$verbose"; then
            echo "  ✓ $dir extraction completed"
            total_success=$((total_success + 1))
        else
            echo "  ✗ $dir extraction failed"
            total_failed=$((total_failed + 1))
            
            # For critical directories like /lib/modules, try alternative approach
            if [[ "$dir" == "/lib/modules" ]]; then
                echo "    Attempting kernel module extraction fallback..."
                mkdir -p "$target_root/lib/modules"
                
                # Try to find kernel versions
                local kernel_dirs
                kernel_dirs=$(e2ls "$pi_root_image:/lib/modules" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' || echo "")
                
                if [[ -n "$kernel_dirs" ]]; then
                    while IFS= read -r kernel_ver; do
                        [[ -z "$kernel_ver" ]] && continue
                        echo "    Extracting kernel modules for: $kernel_ver"
                        
                        if extract_pi_os_directory "$pi_root_image" "/lib/modules/$kernel_ver" "$target_root/lib/modules/$kernel_ver" false; then
                            echo "    ✓ Kernel modules for $kernel_ver extracted"
                        else
                            echo "    ✗ Kernel modules for $kernel_ver failed"
                        fi
                    done <<< "$kernel_dirs"
                fi
            fi
        fi
    done
    
    echo
    echo "=== EXTRACTION SUMMARY ==="
    echo "Successful: $total_success directories"
    echo "Failed: $total_failed directories"
    echo "Target size: $(du -sh "$target_root" 2>/dev/null | cut -f1 || echo "unknown")"
    
    # Verify critical files exist
    echo
    echo "=== CRITICAL FILE VERIFICATION ==="
    local critical_files=(
        "/bin/bash"
        "/bin/sh" 
        "/lib/ld-linux-aarch64.so.1"
        "/sbin/init"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$target_root$file" ]]; then
            echo "✓ $file"
        else
            echo "✗ $file (MISSING)"
        fi
    done
    
    # Check for kernel modules
    local modules_count=$(find "$target_root/lib/modules" -name "*.ko" 2>/dev/null | wc -l || echo "0")
    echo "Kernel modules found: $modules_count"
    
    if [[ $modules_count -gt 0 ]]; then
        echo "✓ Kernel modules present"
    else
        echo "✗ No kernel modules found (CRITICAL)"
    fi
    
    return 0
}

# Test function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== TESTING ROBUST PI OS EXTRACTION ==="
    
    # For testing, we'll use a simple test case first
    echo "Creating test ext4 filesystem..."
    dd if=/dev/zero of=test-extract.ext4 bs=1M count=50 2>/dev/null
    /opt/homebrew/Cellar/e2fsprogs/1.47.3/sbin/mke2fs -t ext4 -F test-extract.ext4 >/dev/null 2>&1
    
    # Create test source structure
    mkdir -p test-extract-source/{bin,lib/{modules/6.6.31-v8+,firmware},etc}
    echo "#!/bin/bash" > test-extract-source/bin/bash
    echo "#!/bin/bash" > test-extract-source/bin/sh
    echo "config" > test-extract-source/etc/passwd
    echo "firmware" > test-extract-source/lib/firmware/test.bin
    echo "module" > test-extract-source/lib/modules/6.6.31-v8+/test.ko
    
    # Populate test filesystem
    echo "Populating test filesystem..."
    (cd test-extract-source && find . -type f | while read file; do
        dir=$(dirname "$file")
        if [[ "$dir" != "." ]]; then
            e2mkdir "test-extract.ext4:$dir" 2>/dev/null || true
        fi
        e2cp "$file" "test-extract.ext4:$file" 2>/dev/null || echo "Failed to copy $file"
    done)
    
    echo "Testing extraction..."
    extract_critical_pi_os_components "test-extract.ext4" "test-output" true
    
    echo "Cleanup..."
    rm -f test-extract.ext4
    rm -rf test-extract-source test-output
    
    echo "Test complete!"
fi
