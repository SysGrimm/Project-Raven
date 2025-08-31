#!/bin/bash

# Quick test of the corrected extraction function

# Copy the corrected function
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
    
    echo "DEBUG: Items found in $source_dir: '$items'"
    
    if [[ -z "$items" ]]; then
        echo "DEBUG: No items found in $source_dir"
        return 1
    fi
    
    local files_copied=0
    local dirs_processed=0
    local total_processed=0
    
    # Process each item in the directory listing
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        # Skip . and .. entries
        [[ "$item" == "." || "$item" == ".." ]] && continue
        [[ "$item" == "lost+found" ]] && continue
        
        echo "DEBUG: Processing item: '$item'"
        
        # Limit extraction to prevent runaway copying
        if [[ $total_processed -ge $max_files ]]; then
            echo "    Reached file limit ($max_files) for $source_dir"
            break
        fi
        
        local source_item="$source_dir/$item"
        local target_item="$target_dir/$item"
        
        echo "DEBUG: Testing if $source_item is a directory..."
        # Test if this item is a directory by trying to list it
        if e2ls "$source_img:$source_item" >/dev/null 2>&1; then
            echo "DEBUG: $item is a directory - recursing"
            # It's a directory - recurse into it (limited depth)
            mkdir -p "$target_item"
            # Only recurse 3 levels deep to avoid excessive copying
            local depth=$(echo "$source_dir" | tr -cd '/' | wc -c)
            if [[ $depth -lt 3 ]]; then
                if extract_directory_contents "$source_img" "$source_item" "$target_item" 100; then
                    dirs_processed=$((dirs_processed + 1))
                fi
            fi
        else
            echo "DEBUG: $item is a file - copying"
            # It's a file - copy it
            if e2cp "$source_img:$source_item" "$target_item" 2>/dev/null; then
                files_copied=$((files_copied + 1))
                echo "DEBUG: Successfully copied $item"
            else
                echo "DEBUG: Failed to copy $item"
            fi
        fi
        
        total_processed=$((total_processed + 1))
    done <<< "$items"
    
    echo "    $source_dir: $files_copied files, $dirs_processed subdirs extracted"
    return 0
}

# Test the function
echo "=== TESTING CORRECTED EXTRACTION ==="

# Test with our prepared filesystem
echo "Testing extraction of /bin directory..."
if extract_directory_contents "test-corrected.ext4" "/bin" "test-extract-target/bin" 100; then
    echo "✓ Extraction succeeded"
    echo "Files extracted:"
    find test-extract-target -type f | while read f; do
        echo "  $f: $(cat "$f")"
    done
else
    echo "✗ Extraction failed"
fi

# Cleanup
rm -f test-corrected.ext4 test.txt
rm -rf test-extract-target

echo "Test complete!"
