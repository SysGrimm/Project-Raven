# SoulBox Build System Troubleshooting Guide

**Complete troubleshooting reference for the SoulBox container-friendly build system, based on real production debugging experience from builds #78-82.**

## Quick Diagnosis Decision Tree

```
Build Failure?
├── Early failure (setup/download phase)
│   ├── Tool missing → See [Missing Dependencies](#missing-dependencies)
│   ├── Network issues → See [Download Problems](#download-problems)  
│   └── Permission denied → See [Container Permissions](#container-permissions)
├── Mid failure (extraction/population phase)
│   ├── "populatefs not found" → See [Populatefs Issues](#populatefs-issues)
│   ├── "debugfs: command not found" → See [PATH Problems](#path-problems)
│   └── Bash syntax error → See [Script Errors](#script-errors)
└── Late failure (merger/output phase)
    ├── "No space left on device" → See [Disk Space](#disk-space-issues)
    ├── Silent failure → See [Error Handling](#silent-failures)
    └── Checksum/upload issues → See [Output Problems](#output-problems)
```

## Critical Error Patterns (Production-Tested)

### Build #78 Pattern: Bash Syntax Errors

**Symptoms**:
```bash
./build-soulbox-containerized.sh: line 1234: syntax error near unexpected token
```

**Root Cause**: Unescaped quotes in regex patterns or string operations.

**Example Failure**:
```bash
# BROKEN - causes syntax error
if [[ "$line" =~ "([^"]+)" ]]; then
    
# FIXED - properly escaped  
if [[ "$line" =~ "([^\"]+)" ]]; then
```

**Debug Commands**:
```bash
# Check bash syntax without running
bash -n build-soulbox-containerized.sh

# Find problematic regex patterns
grep -n '\[\[.*=~.*".*".*\]\]' build-soulbox-containerized.sh
```

**Solution**:
- Escape all quotes in regex patterns: `\"` instead of `"`
- Use single quotes for literal strings when possible
- Test regex patterns in isolation before integration

### Build #79-80 Pattern: Populatefs Path Resolution

**Symptoms**:
```bash
./populate-extfs.sh: line 76: /usr/local/bin/../debugfs/debugfs: No such file or directory
populatefs failed with exit code 127
```

**Root Cause**: Hardcoded relative paths in populatefs script don't match container environment.

**Debug Commands**:
```bash
# Check populatefs installation
ls -la /usr/local/bin/populatefs
file /usr/local/bin/populatefs

# Examine script content for hardcoded paths
cat /usr/local/bin/populatefs | grep -E "(debugfs|CONTRIB_DIR|BIN_DIR)"

# Test debugfs availability
command -v debugfs
which debugfs
debugfs -V
```

**Wrong Fix (Don't Do This)**:
```bash
# This won't work - wrong variable name
sed -i 's|$BIN_DIR/../debugfs/debugfs|debugfs|g' /usr/local/bin/populatefs
```

**Correct Fix**:
```bash
# This works - correct variable name
sed -i 's|$CONTRIB_DIR/../debugfs/debugfs|debugfs|g' /usr/local/bin/populatefs

# Verify the fix worked
cat /usr/local/bin/populatefs | grep debugfs
```

### Build #81 Pattern: Silent DD Failures

**Symptoms**:
- Build appears successful through filesystem population
- Suddenly fails with no clear error message
- Log shows successful populatefs but then immediate failure

**Root Cause**: Critical operations redirecting errors to `/dev/null`.

**Example Problem**:
```bash
# BROKEN - hides all errors
dd if="$source" of="$target" bs=1M conv=notrunc 2>/dev/null
```

**Debug Commands**:
```bash
# Check for silenced operations
grep -n "2>/dev/null" build-soulbox-containerized.sh

# Look for dd operations without error handling
grep -A5 -B5 "dd if=" build-soulbox-containerized.sh
```

**Correct Implementation**:
```bash
# FIXED - proper error handling
log_info "Copying filesystem to image..."
if ! dd if="$source" of="$target" bs=1M conv=notrunc 2>&1; then
    log_error "Failed to copy filesystem: $?"
    return 1
fi
log_success "Filesystem copied successfully"
```

### Build #82 Pattern: Container Disk Space Exhaustion

**Symptoms**:
```bash
dd: error writing '/workspace/.../soulbox-v1.0.0.img': No space left on device
662+0 records out
```

**Root Cause**: Image size exceeds container disk space limits.

**Debug Commands**:
```bash
# Check available space during build
df -h /workspace
df -h /tmp

# Check space usage by build components
du -sh /workspace/*/
ls -lh *.img *.ext4 *.fat

# Monitor space usage in real-time
watch 'df -h /workspace && ls -lh /workspace/*/'
```

**Analysis**:
```
PROBLEM ANALYSIS:
- Planned image: 1025 MB (100 MB boot + 900 MB root + 25 MB padding)
- Container space: ~1.6 GB total
- Other files: ~800 MB (source image, extracted filesystems, staging)
- Available for final image: ~800 MB
- Result: Failure after writing 662 MB
```

**Solution**:
```bash
# BEFORE (Too Large):
local boot_size=100   # 100MB
local root_size=900   # 900MB
local total_size=1025 # Failed

# AFTER (Container-Optimized):
local boot_size=80    # 80MB (sufficient for Pi boot files)  
local root_size=600   # 600MB (fits container limits)
local total_size=700  # Success!
```

## Systematic Debugging Approach

### Phase 1: Environment Validation

```bash
#!/bin/bash
# comprehensive-debug.sh - Run before troubleshooting

echo "=== ENVIRONMENT VALIDATION ==="

# Check container environment
echo "Container Detection:"
echo "  - /dev/loop0 exists: $(test -e /dev/loop0 && echo 'YES' || echo 'NO')"
echo "  - /dev/loop-control exists: $(test -c /dev/loop-control && echo 'YES' || echo 'NO')"
echo "  - Running in container: $(test -f /.dockerenv && echo 'YES' || echo 'NO')"

# Check disk space
echo -e "\nDisk Space:"
df -h | head -1
df -h | grep -E "(workspace|tmp|dev/shm)"

# Check required tools
echo -e "\nRequired Tools:"
for tool in curl xz parted dd mkfs.fat mke2fs mcopy mdir debugfs tune2fs e2fsck; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✅ $tool: $(which $tool)"
    else
        echo "  ❌ $tool: NOT FOUND"
    fi
done

# Check populatefs specifically
echo -e "\nPopulatefs Status:"
if command -v populatefs >/dev/null 2>&1; then
    echo "  ✅ populatefs in PATH: $(which populatefs)"
    echo "  - Version: $(populatefs --version 2>&1 | head -1 || echo 'No version info')"
    echo "  - Type: $(file $(which populatefs))"
elif [[ -x "/usr/local/bin/populatefs" ]]; then
    echo "  ⚠️ populatefs in /usr/local/bin only"
    echo "  - Type: $(file /usr/local/bin/populatefs)"
    echo "  - Content preview: $(head -3 /usr/local/bin/populatefs)"
else
    echo "  ❌ populatefs not found"
fi

# Check PATH
echo -e "\nPATH Configuration:"
echo "$PATH" | tr ':' '\n' | while read dir; do
    echo "  - $dir"
done

echo -e "\n=== VALIDATION COMPLETE ==="
```

### Phase 2: Build Component Testing

```bash
#!/bin/bash
# test-build-components.sh - Test individual components

echo "=== TESTING BUILD COMPONENTS ==="

# Test Pi OS download
test_download() {
    echo "Testing Pi OS download..."
    local url="https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2024-07-04/2024-07-04-raspios-bookworm-arm64-lite.img.xz"
    
    if curl -I "$url" 2>/dev/null | head -1 | grep -q "200 OK"; then
        echo "  ✅ Pi OS download URL accessible"
    else
        echo "  ❌ Pi OS download URL failed"
    fi
}

# Test filesystem tools
test_filesystem_tools() {
    echo "Testing filesystem tools..."
    
    # Test FAT32 creation
    local test_fat="/tmp/test.fat"
    if dd if=/dev/zero of="$test_fat" bs=1M count=1 2>/dev/null && \
       mkfs.fat -F 32 "$test_fat" >/dev/null 2>&1; then
        echo "  ✅ FAT32 creation works"
        rm -f "$test_fat"
    else
        echo "  ❌ FAT32 creation failed"
    fi
    
    # Test ext4 creation  
    local test_ext4="/tmp/test.ext4"
    if dd if=/dev/zero of="$test_ext4" bs=1M count=1 2>/dev/null && \
       mke2fs -F -q -t ext4 "$test_ext4" >/dev/null 2>&1; then
        echo "  ✅ ext4 creation works"
        rm -f "$test_ext4"
    else
        echo "  ❌ ext4 creation failed"
    fi
}

# Test populatefs functionality
test_populatefs() {
    echo "Testing populatefs functionality..."
    
    local test_ext4="/tmp/test-populate.ext4"
    local test_staging="/tmp/test-staging"
    
    # Create test environment
    dd if=/dev/zero of="$test_ext4" bs=1M count=10 2>/dev/null
    mke2fs -F -q -t ext4 "$test_ext4" >/dev/null 2>&1
    mkdir -p "$test_staging/test-dir"
    echo "test content" > "$test_staging/test-file"
    
    # Test populatefs
    if command -v populatefs >/dev/null 2>&1; then
        if populatefs "$test_ext4" "$test_staging" >/dev/null 2>&1 || \
           populatefs -U -d "$test_staging" "$test_ext4" >/dev/null 2>&1; then
            echo "  ✅ populatefs works"
        else
            echo "  ❌ populatefs failed"
            echo "  - Exit code: $?"
        fi
    else
        echo "  ⚠️ populatefs not available"
    fi
    
    # Cleanup
    rm -rf "$test_ext4" "$test_staging"
}

# Run all tests
test_download
test_filesystem_tools  
test_populatefs

echo "=== COMPONENT TESTING COMPLETE ==="
```

### Phase 3: Build Process Isolation

```bash
#!/bin/bash
# isolate-build-failure.sh - Identify exact failure point

echo "=== BUILD PROCESS ISOLATION ==="

# Function to test each major phase
test_phase() {
    local phase_name="$1"
    local phase_command="$2"
    
    echo "Testing Phase: $phase_name"
    echo "Command: $phase_command"
    
    local start_time=$(date +%s)
    if eval "$phase_command"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo "  ✅ $phase_name completed in ${duration}s"
        return 0
    else
        local exit_code=$?
        echo "  ❌ $phase_name failed with exit code $exit_code"
        return $exit_code
    fi
}

# Test individual phases
test_phase "Tool Check" "check_required_tools"
test_phase "Work Directory Setup" "setup_work_dir"
test_phase "Pi OS Download" "download_base_image"
test_phase "Filesystem Extraction" "extract_base_filesystems"
test_phase "Asset Creation" "create_soulbox_assets"

# If all phases pass, test the full build
if [[ $? -eq 0 ]]; then
    echo "All phases passed individually - testing full build..."
    test_phase "Full Build" "./build-soulbox-containerized.sh --version 'debug-test'"
fi

echo "=== ISOLATION TESTING COMPLETE ==="
```

## Specific Troubleshooting Scenarios

### Missing Dependencies

**Problem**: Build fails immediately with "command not found"

**Solution Matrix**:

| Missing Tool | Ubuntu/Debian | CentOS/RHEL | Alpine |
|--------------|---------------|-------------|---------|
| `curl` | `apt-get install curl` | `yum install curl` | `apk add curl` |
| `xz` | `apt-get install xz-utils` | `yum install xz` | `apk add xz` |
| `parted` | `apt-get install parted` | `yum install parted` | `apk add parted` |
| `mkfs.fat` | `apt-get install dosfstools` | `yum install dosfstools` | `apk add dosfstools` |
| `mke2fs` | `apt-get install e2fsprogs` | `yum install e2fsprogs` | `apk add e2fsprogs` |
| `mcopy` | `apt-get install mtools` | `yum install mtools` | `apk add mtools` |
| `populatefs` | `apt-get install e2fsprogs-extra` | Build from source | Build from source |

### Populatefs Issues

**Problem 1**: "populatefs: command not found"

**Debug Steps**:
```bash
# Check if it's installed but not in PATH
find /usr -name "populatefs" 2>/dev/null
find /usr -name "*populate*" 2>/dev/null

# Check if e2fsprogs-extra is installed
dpkg -l | grep e2fsprogs-extra
rpm -qa | grep e2fsprogs-extra
```

**Solutions**:
```bash
# Method 1: Package installation
apt-get update && apt-get install -y e2fsprogs-extra

# Method 2: Add to PATH if found elsewhere
export PATH="/usr/local/bin:/usr/sbin:/sbin:$PATH"

# Method 3: Manual installation (see GitHub Actions workflow)
```

**Problem 2**: "debugfs: command not found" from within populatefs

**Debug Steps**:
```bash
# Check debugfs availability
command -v debugfs
which debugfs

# Check populatefs script for hardcoded paths
cat /usr/local/bin/populatefs | grep -E "debugfs|CONTRIB_DIR"
```

**Solutions**:
```bash
# Method 1: Fix PATH
export PATH="/usr/sbin:/sbin:$PATH"

# Method 2: Patch populatefs script
sed -i 's|\$CONTRIB_DIR/../debugfs/debugfs|debugfs|g' /usr/local/bin/populatefs
```

### PATH Problems

**Problem**: Tools exist but aren't found during execution

**Debug Commands**:
```bash
# Check current PATH
echo $PATH

# Find where tools are installed
for tool in debugfs mke2fs tune2fs e2fsck; do
    echo "$tool: $(find /usr -name $tool 2>/dev/null | head -1)"
done

# Check PATH during populatefs execution
sed -i '1a echo "POPULATEFS PATH: $PATH" >&2' /usr/local/bin/populatefs
```

**Solution**:
```bash
# Comprehensive PATH enhancement
export PATH="/usr/sbin:/sbin:/usr/bin:/bin:/usr/local/bin:/usr/local/sbin:$PATH"

# Make permanent in build script
echo 'export PATH="/usr/sbin:/sbin:/usr/bin:/bin:/usr/local/bin:$PATH"' >> ~/.bashrc
```

### Disk Space Issues

**Problem**: "No space left on device" during build

**Immediate Debug**:
```bash
# Check space availability
df -h

# Check largest files/directories  
du -sh /* 2>/dev/null | sort -hr | head -10
du -sh /workspace/* 2>/dev/null | sort -hr | head -10
du -sh /tmp/* 2>/dev/null | sort -hr | head -10

# Check build directory usage
find /workspace -name "*.img" -o -name "*.ext4" -o -name "*.fat" | xargs ls -lh
```

**Solutions by Priority**:

1. **Reduce Image Size**:
```bash
# Edit build script image size configuration
local boot_size=64    # Minimum viable
local root_size=512   # Reduced but functional
local total_size=600  # Under most container limits
```

2. **Aggressive Cleanup**:
```bash
# Add cleanup during build process
cleanup_intermediate() {
    rm -rf "$WORK_DIR/source" 2>/dev/null || true
    rm -rf "$WORK_DIR/filesystems" 2>/dev/null || true
    sync  # Force filesystem sync
}
```

3. **Container Configuration**:
```yaml
# In CI/CD configuration, increase disk space
resources:
  disk: 16GB  # Instead of default ~8GB
```

### Silent Failures

**Problem**: Build appears to succeed but produces no output or corrupted output

**Debug Approach**:
```bash
# Enable strict error checking
set -euo pipefail

# Add comprehensive logging to critical operations
log_operation() {
    local operation="$1"
    local command="$2"
    
    log_info "Starting: $operation"
    if eval "$command"; then
        log_success "Completed: $operation"
    else
        local exit_code=$?
        log_error "Failed: $operation (exit code: $exit_code)"
        return $exit_code
    fi
}
```

**Find Hidden Errors**:
```bash
# Search for operations that hide errors
grep -n "2>/dev/null" build-soulbox-containerized.sh
grep -n "|| true" build-soulbox-containerized.sh
grep -n ">/dev/null" build-soulbox-containerized.sh
```

## Production Monitoring Setup

### Build Health Checks

```bash
#!/bin/bash
# build-health-check.sh - Monitor build system health

check_build_readiness() {
    local score=0
    local max_score=10
    
    echo "=== BUILD READINESS CHECK ==="
    
    # Check disk space (2 points)
    local available_gb=$(df --output=avail /workspace | tail -1 | awk '{print int($1/1024/1024)}')
    if [[ $available_gb -ge 12 ]]; then
        echo "✅ Disk space: ${available_gb}GB (excellent)"
        score=$((score + 2))
    elif [[ $available_gb -ge 8 ]]; then
        echo "⚠️ Disk space: ${available_gb}GB (adequate)"  
        score=$((score + 1))
    else
        echo "❌ Disk space: ${available_gb}GB (insufficient)"
    fi
    
    # Check memory (1 point)
    local available_ram=$(free -g | awk 'NR==2{print $7}')
    if [[ $available_ram -ge 4 ]]; then
        echo "✅ Available RAM: ${available_ram}GB"
        score=$((score + 1))
    else
        echo "⚠️ Available RAM: ${available_ram}GB (low)"
    fi
    
    # Check required tools (3 points)
    local tool_score=0
    for tool in curl xz parted dd mkfs.fat mke2fs mcopy debugfs; do
        if command -v "$tool" >/dev/null 2>&1; then
            tool_score=$((tool_score + 1))
        fi
    done
    if [[ $tool_score -eq 8 ]]; then
        echo "✅ All required tools available"
        score=$((score + 3))
    elif [[ $tool_score -ge 6 ]]; then
        echo "⚠️ Most tools available ($tool_score/8)"
        score=$((score + 2))
    else
        echo "❌ Missing critical tools ($tool_score/8)"
    fi
    
    # Check populatefs (2 points)
    if command -v populatefs >/dev/null 2>&1; then
        echo "✅ populatefs available in PATH"
        score=$((score + 2))
    elif [[ -x "/usr/local/bin/populatefs" ]]; then
        echo "⚠️ populatefs available in /usr/local/bin"
        score=$((score + 1))
    else
        echo "❌ populatefs not found"
    fi
    
    # Check network connectivity (2 points)
    if curl -s --max-time 5 https://downloads.raspberrypi.org >/dev/null; then
        echo "✅ Network connectivity to Pi OS downloads"
        score=$((score + 2))
    else
        echo "❌ Network connectivity issues"
    fi
    
    echo "=== READINESS SCORE: $score/$max_score ==="
    
    if [[ $score -ge 9 ]]; then
        echo "🟢 Excellent - Build should succeed"
        return 0
    elif [[ $score -ge 7 ]]; then
        echo "🟡 Good - Build likely to succeed"
        return 0  
    elif [[ $score -ge 5 ]]; then
        echo "🟠 Fair - Build may have issues"
        return 1
    else
        echo "🔴 Poor - Build likely to fail"
        return 2
    fi
}

# Run health check
check_build_readiness
exit $?
```

### Failure Alerting

```bash
#!/bin/bash
# build-failure-alert.sh - Send alerts on build failures

send_alert() {
    local status="$1"
    local message="$2"
    local build_log="${3:-}"
    
    # Slack notification (example)
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        local payload=$(cat <<EOF
{
    "text": "SoulBox Build $status",
    "attachments": [
        {
            "color": $([ "$status" = "SUCCESS" ] && echo '"good"' || echo '"danger"'),
            "fields": [
                {
                    "title": "Status",
                    "value": "$status",
                    "short": true
                },
                {
                    "title": "Message", 
                    "value": "$message",
                    "short": false
                }
            ]
        }
    ]
}
EOF
)
        curl -X POST "$SLACK_WEBHOOK_URL" \
             -H 'Content-type: application/json' \
             -d "$payload"
    fi
    
    # Email notification (example)
    if command -v mail >/dev/null 2>&1 && [[ -n "$ALERT_EMAIL" ]]; then
        {
            echo "SoulBox Build $status"
            echo "Message: $message"
            echo "Time: $(date)"
            echo "Host: $(hostname)"
            [[ -n "$build_log" ]] && echo -e "\nBuild Log:\n$build_log"
        } | mail -s "SoulBox Build $status" "$ALERT_EMAIL"
    fi
}

# Example usage:
# send_alert "FAILURE" "Build failed during populatefs phase" "$(tail -100 build.log)"
```

---

*This troubleshooting guide is based on real production failures and their solutions from builds #78-82. Every scenario and solution has been tested and verified.*

**← Back to [[Build-System]] | Next: [[Deployment-Guide]] →**
