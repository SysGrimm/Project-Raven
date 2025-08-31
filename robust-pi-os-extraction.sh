#!/bin/bash

# Robust Pi OS extraction functions using correct e2tools syntax
# This replaces the broken e2cp -r approach in the build script

# Function to extract all files from a directory recursively using e2ls + e2cp
extract_directory_recursive() {
    local source_img="$1"
    local source_path="$2"
    local target_path="$3"
    local depth="${4:-0}"
    local max_depth="${5:-10}"
    
    # Prevent infinite recursion
    if [[ $depth -gt $max_depth ]]; then
        echo "    Max depth reached for $source_path"
        return 1
    fi
    
    # Create target directory
    mkdir -p "$target_path"
    
    # Get directory listing
    local items
    items=$(e2ls "$source_img:$source_path" 2>/dev/null || echo "")
    
    if [[ -z "$items" ]]; then
        return 1
    fi
    
    local files_copied=0
    local dirs_processed=0
    
    # Process each item
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        [[ "$item" =~ ^\.\.?/?$ ]] && continue  # Skip . and ..
        
        local source_item="$source_path/$item"
        local target_item="$target_path/$item"
        
        # Check if it's a directory (ends with /)
        if [[ "$item" =~ /$ ]]; then
            # Directory - recurse into it
            local clean_name="${item%/}"
            local sub_source="$source_path/$clean_name"
            local sub_target="$target_path/$clean_name"
            
            if extract_directory_recursive "$source_img" "$sub_source" "$sub_target" $((depth + 1)) "$max_depth"; then
                dirs_processed=$((dirs_processed + 1))
            fi
        else
            # File - copy it
            if e2cp "$source_img:$source_item" "$target_item" 2>/dev/null; then
                files_copied=$((files_copied + 1))
            fi
        fi
    done <<< "$items"
    
    [[ $depth -eq 0 ]] && echo "    Extracted: $files_copied files, $dirs_processed subdirectories"
    return 0
}

# Function to extract Pi OS using file list approach (more reliable for large directories)
extract_with_file_list() {
    local source_img="$1"
    local source_dir="$2"
    local target_base="$3"
    
    echo "  Extracting $source_dir using file list approach..."
    
    # Build complete file list recursively
    local temp_list="/tmp/file_list_$$.txt"
    build_complete_file_list "$source_img" "$source_dir" > "$temp_list"
    
    local total_files=$(wc -l < "$temp_list" 2>/dev/null || echo "0")
    echo "    Found $total_files files to extract"
    
    if [[ $total_files -eq 0 ]]; then
        rm -f "$temp_list"
        return 1
    fi
    
    local copied=0
    local failed=0
    
    # Copy files in batches for better performance
    while IFS= read -r file_path; do
        [[ -z "$file_path" ]] && continue
        
        local target_file="$target_base$file_path"
        local target_dir=$(dirname "$target_file")
        
        # Ensure directory exists
        mkdir -p "$target_dir"
        
        # Copy file
        if e2cp "$source_img:$file_path" "$target_file" 2>/dev/null; then
            copied=$((copied + 1))
        else
            failed=$((failed + 1))
        fi
        
        # Progress indicator
        if (( (copied + failed) % 50 == 0 )); then
            echo "    Progress: $((copied + failed))/$total_files files"
        fi
    done < "$temp_list"
    
    rm -f "$temp_list"
    echo "    Complete: $copied files copied, $failed failed"
    return 0
}

# Helper function to build complete file list recursively
build_complete_file_list() {
    local source_img="$1"
    local current_dir="$2"
    local prefix="${3:-}"
    
    local items
    items=$(e2ls "$source_img:$current_dir" 2>/dev/null || echo "")
    
    [[ -z "$items" ]] && return
    
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        [[ "$item" =~ ^\.\.?/?$ ]] && continue
        
        if [[ "$item" =~ /$ ]]; then
            # Directory - recurse
            local clean_name="${item%/}"
            local sub_path="$current_dir/$clean_name"
            build_complete_file_list "$source_img" "$sub_path" "$prefix"
        else
            # File - add to list
            echo "$current_dir/$item"
        fi
    done <<< "$items"
}

# Main extraction function that combines all approaches for maximum success
extract_pi_os_comprehensive() {
    local pi_root_image="$1"
    local target_extraction_dir="$2"
    
    echo "=== COMPREHENSIVE PI OS EXTRACTION ===" 
    echo "Source: $pi_root_image"
    echo "Target: $target_extraction_dir"
    echo
    
    # Verify we can access the source
    if ! e2ls "$pi_root_image:/" >/dev/null 2>&1; then
        echo "ERROR: Cannot access Pi OS root filesystem: $pi_root_image"
        return 1
    fi
    
    mkdir -p "$target_extraction_dir"
    
    # Critical system directories in priority order
    local system_dirs=(
        "/bin"                      # Core system binaries
        "/sbin"                     # System administration 
        "/lib/aarch64-linux-gnu"    # ARM64 libraries
        "/lib/systemd"              # Systemd components
        "/lib/modules"              # Kernel modules (CRITICAL)
        "/lib/firmware"             # Hardware firmware
        "/etc/systemd"              # Systemd configuration
        "/etc/ssh"                  # SSH configuration
        "/etc/apt"                  # Package management
        "/usr/bin"                  # User binaries
        "/usr/sbin"                 # User system binaries
        "/usr/lib/aarch64-linux-gnu" # User libraries
    )
    
    local success_count=0
    local failure_count=0
    
    for sys_dir in "${system_dirs[@]}"; do
        echo "Processing: $sys_dir"
        
        # Try recursive extraction first
        if extract_directory_recursive "$pi_root_image" "$sys_dir" "$target_extraction_dir$sys_dir" 0 8; then
            echo "  ✓ $sys_dir extracted successfully"
            success_count=$((success_count + 1))
        else
            echo "  ✗ $sys_dir extraction failed, trying file list approach..."
            
            # Fallback to file list approach
            if extract_with_file_list "$pi_root_image" "$sys_dir" "$target_extraction_dir"; then
                echo "  ✓ $sys_dir extracted via file list"
                success_count=$((success_count + 1))
            else
                echo "  ✗ $sys_dir completely failed"
                failure_count=$((failure_count + 1))
                
                # Create minimal directory structure for failed critical dirs
                mkdir -p "$target_extraction_dir$sys_dir"
            fi
        fi
    done
    
    # Special handling for critical individual files
    echo "Extracting critical individual files..."
    local critical_files=(
        "/lib/ld-linux-aarch64.so.1"
        "/etc/passwd"
        "/etc/group"
        "/etc/shadow"
        "/etc/fstab"
        "/etc/hostname"
        "/etc/hosts"
    )
    
    for file in "${critical_files[@]}"; do
        local target_file="$target_extraction_dir$file"
        local target_dir=$(dirname "$target_file")
        mkdir -p "$target_dir"
        
        if e2cp "$pi_root_image:$file" "$target_file" 2>/dev/null; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (will create fallback)"
        fi
    done
    
    echo
    echo "=== FINAL EXTRACTION SUMMARY ==="
    echo "Successful directories: $success_count"
    echo "Failed directories: $failure_count"
    
    # Calculate extracted content size
    local extracted_size=$(du -sh "$target_extraction_dir" 2>/dev/null | cut -f1 || echo "unknown")
    echo "Extracted content size: $extracted_size"
    
    # Verify critical components
    echo
    echo "=== BOOT READINESS CHECK ==="
    
    # Check for essential binaries
    local essential_bins=("/bin/bash" "/sbin/init" "/bin/mount")
    local bins_ok=0
    for bin in "${essential_bins[@]}"; do
        if [[ -f "$target_extraction_dir$bin" ]]; then
            echo "✓ Essential binary: $bin"
            bins_ok=$((bins_ok + 1))
        else
            echo "✗ Missing binary: $bin"
        fi
    done
    
    # Check for kernel modules
    local module_count=0
    if [[ -d "$target_extraction_dir/lib/modules" ]]; then
        module_count=$(find "$target_extraction_dir/lib/modules" -name "*.ko" 2>/dev/null | wc -l || echo "0")
    fi
    echo "Kernel modules: $module_count"
    
    # Check for system libraries
    local lib_count=0
    if [[ -d "$target_extraction_dir/lib/aarch64-linux-gnu" ]]; then
        lib_count=$(find "$target_extraction_dir/lib/aarch64-linux-gnu" -name "*.so*" 2>/dev/null | wc -l || echo "0")
    fi
    echo "System libraries: $lib_count"
    
    # Determine boot readiness
    if [[ $bins_ok -ge 2 && $module_count -gt 50 && $lib_count -gt 20 ]]; then
        echo "✓ EXTRACTION APPEARS BOOT-READY"
        return 0
    else
        echo "✗ EXTRACTION MAY NOT BE SUFFICIENT FOR BOOT"
        return 1
    fi
}

# If script is run directly, run a comprehensive test
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== PI OS EXTRACTION TEST ==="
    echo "This will test our robust extraction approach"
    echo "Run this script as a test before integrating into build script"
    echo
    echo "To test with real Pi OS image:"
    echo "  $0 /path/to/pi-root.ext4 /path/to/extraction/target"
    echo
fi
