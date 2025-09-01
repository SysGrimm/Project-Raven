# YAML Heredoc Escaping Patterns Guide

**Complete reference for shell variable escaping in YAML heredoc blocks, with real examples from SoulBox CI/CD troubleshooting.**

## The Problem

YAML workflows with embedded shell scripts face a complex escaping challenge:
1. YAML parser interprets the heredoc
2. Shell interprets the script content
3. Variables need correct escaping at both levels

This creates opportunities for multiple types of escaping failures.

## Common Error Patterns

### Pattern 1: Unexpected EOF Errors

**Symptoms**:
```bash
Error: Unexpected EOF while looking for matching `"`
./script.sh: line 15: unexpected EOF while looking for matching `"`
```

**Root Cause**: Unmatched quotes due to improper variable expansion in JSON strings or complex shell expressions.

**Example Failure**:
```yaml
# ❌ BROKEN: Mixed quote types cause parsing errors
cat > script.sh << 'EOF'
RELEASE_DATA='{\"tag_name\":\"'$VERSION'\",\"name\":\"App '$VERSION'\"}'
EOF
```

### Pattern 2: Invalid Arithmetic Base Errors

**Symptoms**:
```bash
./script.sh: line 12: invalid arithmetic base (error token is "VERSION")
```

**Root Cause**: Variable expansion happening at YAML parsing time instead of shell execution time.

**Example Failure**:
```yaml
# ❌ BROKEN: YAML expands variables before shell sees them
cat > script.sh << EOF
VERSION=$VERSION
if [[ $# -gt 0 ]]; then
    echo "Processing $VERSION"
fi
EOF
```

### Pattern 3: Process ID Instead of Variable

**Symptoms**:
```bash
# Script shows process ID instead of intended variable
Version: 12345  # Should be: Version: v1.0.0
```

**Root Cause**: Double dollar signs `$$` are interpreted as process ID in shell.

**Example Failure**:
```yaml
# ❌ BROKEN: Double dollar becomes process ID
cat > script.sh << 'EOF'
VERSION=$$VERSION
echo "Version: $$VERSION"
EOF
```

## Correct Escaping Patterns

### Basic Shell Variable Escaping

**✅ CORRECT Pattern**:
```yaml
- name: Create shell script with variables
  run: |
    cat > script.sh << 'SCRIPT'
#!/bin/bash
# Single backslash dollar for literal $ in shell script
VERSION="\$1"
BUILD_DIR="\$2"

if [[ \$# -eq 0 ]]; then
    echo "Usage: \$0 VERSION BUILD_DIR"
    exit 1
fi

echo "Building version: \$VERSION"
echo "Output directory: \$BUILD_DIR"
SCRIPT
    
    chmod +x script.sh
```

**Key Points**:
- Use `\$` to create literal `$` in the shell script
- Quote the heredoc delimiter with single quotes: `<< 'SCRIPT'`
- All shell variables should be escaped with `\$`

### Complex JSON String Construction

**❌ WRONG Approaches**:
```yaml
# Method 1: Mixed quotes (causes EOF errors)
RELEASE_DATA='{\"tag_name\":\"'\$VERSION'\",\"name\":\"App \$VERSION\"}'

# Method 2: Inconsistent escaping
RELEASE_DATA="{\"tag_name\":\"$VERSION\",\"name\":\"App $VERSION\"}"

# Method 3: Over-escaping
RELEASE_DATA="{\\\\"tag_name\\\\":\\\\"\\\\$VERSION\\\\",\\\\"name\\\\":\\\\"App \\\\$VERSION\\\\"}"
```

**✅ CORRECT Approaches**:

**Method 1: Consistent Double-Quote Escaping**:
```yaml
cat > api-script.sh << 'APISCRIPT'
#!/bin/bash
VERSION="\$1"
IMAGE_FILE="\$2"

# Build JSON with consistent escaping
RELEASE_DATA="{\\\"tag_name\\\":\\\"\\$VERSION\\\",\\\"name\\\":\\\"SoulBox \\$VERSION\\\",\\\"body\\\":\\\"Automated release\\\"}"

# Use the JSON in API call
curl -s -X POST "\${API_URL}/releases" \
    -H "Authorization: token \$TOKEN" \
    -H "Content-Type: application/json" \
    -d "\$RELEASE_DATA"
APISCRIPT
```

**Method 2: Template Substitution**:
```yaml
cat > api-script.sh << 'APISCRIPT'
#!/bin/bash
VERSION="\$1"

# Create JSON template
JSON_TEMPLATE='{"tag_name":"VERSION_PLACEHOLDER","name":"SoulBox VERSION_PLACEHOLDER","body":"Automated release"}'

# Substitute variables
RELEASE_DATA=\$(echo "\$JSON_TEMPLATE" | sed "s/VERSION_PLACEHOLDER/\$VERSION/g")

# Use in API call
curl -s -X POST "\${API_URL}/releases" \
    -H "Authorization: token \$TOKEN" \
    -H "Content-Type: application/json" \
    -d "\$RELEASE_DATA"
APISCRIPT
```

**Method 3: Heredoc within Heredoc**:
```yaml
cat > api-script.sh << 'APISCRIPT'
#!/bin/bash
VERSION="\$1"

# Create JSON using internal heredoc
RELEASE_DATA=\$(cat << JSONDATA
{
  "tag_name": "\$VERSION",
  "name": "SoulBox \$VERSION", 
  "body": "Automated release"
}
JSONDATA
)

# Remove newlines for API call
RELEASE_DATA=\$(echo "\$RELEASE_DATA" | tr -d '\\n')
APISCRIPT
```

### Advanced Shell Constructs

**Conditional Logic**:
```yaml
cat > build-script.sh << 'BUILDSCRIPT'
#!/bin/bash

# Argument parsing with proper escaping
while [[ \$# -gt 0 ]]; do
    case \$1 in
        --version)
            VERSION="\$2"
            shift 2
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        *)
            echo "Unknown option: \$1"
            exit 1
            ;;
    esac
done

# Conditional execution
if [[ -n "\$VERSION" ]]; then
    echo "Building version: \$VERSION"
else
    echo "No version specified"
    exit 1
fi

# Array handling
FILES=("file1.txt" "file2.txt" "file3.txt")
for file in "\${FILES[@]}"; do
    echo "Processing: \$file"
done
BUILDSCRIPT
```

**Function Definitions**:
```yaml
cat > functions-script.sh << 'FUNCSCRIPT'
#!/bin/bash

# Function with parameters
log_message() {
    local level="\$1"
    local message="\$2"
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] [\$level] \$message"
}

# Function with complex logic
process_file() {
    local input_file="\$1"
    local output_file="\$2"
    
    if [[ ! -f "\$input_file" ]]; then
        log_message "ERROR" "Input file not found: \$input_file"
        return 1
    fi
    
    # File processing
    sed 's/old/new/g' "\$input_file" > "\$output_file"
    log_message "INFO" "Processed \$input_file -> \$output_file"
}

# Usage
process_file "input.txt" "output.txt"
FUNCSCRIPT
```

## Special Cases and Edge Cases

### Environment Variable Pass-through

**Problem**: Need to pass environment variables from YAML to shell script.

**✅ SOLUTION**:
```yaml
- name: Create script with environment variables
  env:
    CUSTOM_VAR: "production"
    API_KEY: ${{ secrets.API_KEY }}
  run: |
    cat > env-script.sh << 'ENVSCRIPT'
#!/bin/bash

# Access environment variables passed from YAML
echo "Environment: \${CUSTOM_VAR:-development}"
echo "API Key length: \${#API_KEY}"

# Set script-local variables
SCRIPT_VAR="local-value"
echo "Script variable: \$SCRIPT_VAR"

# Combine environment and script variables  
COMBINED="\${CUSTOM_VAR}-\${SCRIPT_VAR}"
echo "Combined: \$COMBINED"
ENVSCRIPT
    
    chmod +x env-script.sh
    ./env-script.sh
```

### Multi-line String Values

**Problem**: Need to embed multi-line strings in shell variables.

**✅ SOLUTION**:
```yaml
cat > multiline-script.sh << 'MULTILINE'
#!/bin/bash

# Multi-line variable using internal heredoc
MESSAGE=\$(cat << ENDMSG
This is a multi-line
message that spans
several lines
ENDMSG
)

echo "Message: \$MESSAGE"

# Multi-line with variable substitution
VERSION="\$1"
DESCRIPTION=\$(cat << ENDDESC
SoulBox Media Center \$VERSION

Features:
- Kodi integration
- Tailscale VPN
- Raspberry Pi optimization
ENDDESC
)

echo "\$DESCRIPTION"
MULTILINE
```

### Regular Expression Patterns

**Problem**: Regex patterns with special characters need careful escaping.

**✅ SOLUTION**:
```yaml
cat > regex-script.sh << 'REGEXSCRIPT'
#!/bin/bash

INPUT_FILE="\$1"

# Simple regex patterns
if [[ "\$INPUT_FILE" =~ \\.txt\$ ]]; then
    echo "Text file detected"
fi

# Complex regex with escaped quotes
if [[ "\$line" =~ Fast[[:space:]]+link[[:space:]]+dest:[[:space:]]*\\\"([^\\\"]+)\\\" ]]; then
    TARGET="\${BASH_REMATCH[1]}"
    echo "Link target: \$TARGET"
fi

# Regex replacement with sed
sed 's/\\([0-9]\\+\\)/Version \\1/g' "\$INPUT_FILE"
REGEXSCRIPT
```

## Debugging Techniques

### Heredoc Content Verification

**Add debugging output**:
```yaml
- name: Create and verify script
  run: |
    cat > debug-script.sh << 'DEBUGSCRIPT'
#!/bin/bash
echo "Script arguments: \$*"
echo "Argument count: \$#"
echo "First argument: \$1"
DEBUGSCRIPT
    
    echo "=== SCRIPT CONTENT VERIFICATION ==="
    cat debug-script.sh
    echo "=== END SCRIPT CONTENT ==="
    
    chmod +x debug-script.sh
    ./debug-script.sh "test-arg" "second-arg"
```

### Variable Expansion Testing

**Test variable handling**:
```yaml
- name: Test variable expansion
  run: |
    TEST_VAR="example-value"
    
    cat > test-script.sh << 'TESTSCRIPT'
#!/bin/bash
# This should show the literal string "\$TEST_VAR"
echo "Script variable: \$TEST_VAR"

# This will be empty unless TEST_VAR is set when script runs
echo "Environment variable: \${TEST_VAR:-not-set}"
TESTSCRIPT
    
    echo "=== TESTING VARIABLE EXPANSION ==="
    cat test-script.sh
    echo "=== RUNNING SCRIPT ==="
    chmod +x test-script.sh
    TEST_VAR="runtime-value" ./test-script.sh
```

### YAML Parsing Validation

**Validate YAML syntax**:
```yaml
- name: Validate YAML parsing
  run: |
    # Create a temporary YAML file to test parsing
    cat > test-workflow.yml << 'YAMLTEST'
name: Test Parsing
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - name: Test heredoc
      run: |
        cat > script.sh << 'EOF'
#!/bin/bash
VERSION="\$1"
echo "Version: \$VERSION"
EOF
YAMLTEST
    
    # Use a YAML parser to validate syntax
    python3 -c "import yaml; yaml.safe_load(open('test-workflow.yml'))" && \
        echo "✅ YAML syntax is valid" || \
        echo "❌ YAML syntax error"
```

## Real-World Examples from SoulBox

### Version Manager Script (Build #123 Fix)

**Before (Broken)**:
```yaml
# ❌ This caused "unexpected EOF" errors
cat > version-manager.sh << 'VERSIONSCRIPT'
VERSION="$2"
RELEASE_DATA='{\"tag_name\":\"'$VERSION'\",\"name\":\"SoulBox '$VERSION'\"}'
VERSIONSCRIPT
```

**After (Fixed)**:
```yaml
# ✅ This works correctly
cat > gitea-version-manager.sh << 'VERSIONSCRIPT'
#!/bin/bash
case "\$1" in
    "auto")
        echo "v0.2.\$(date +%s)"
        ;;
    "create-release")
        VERSION="\$2"
        IMAGE_FILE="\$3"
        CHECKSUM_FILE="\$4"
        
        RELEASE_DATA="{\\\"tag_name\\\":\\\"\\$VERSION\\\",\\\"name\\\":\\\"SoulBox Will-o'-Wisp \\$VERSION\\\",\\\"body\\\":\\\"Automated release\\\"}"
        
        if [[ -n "\$GITEA_TOKEN" ]]; then
            RESPONSE=\$(curl -s -X POST "\${GITEA_API_URL}/releases" \\
                -H "Authorization: token \$GITEA_TOKEN" \\
                -H "Content-Type: application/json" \\
                -d "\$RELEASE_DATA")
        fi
        ;;
esac
VERSIONSCRIPT
```

### Build Script with Arguments (Production Pattern)

```yaml
- name: Create containerized build script
  run: |
    cat > build-soulbox-containerized.sh << 'BUILDSCRIPT'
#!/bin/bash
echo 'SoulBox containerized build script'

# Parse command line arguments
VERSION='v0.1.0'
CLEAN_BUILD=false

while [[ \$# -gt 0 ]]; do
  case \$1 in
    --version)
      VERSION="\$2"
      shift 2
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    *)
      echo "Unknown option: \$1"
      exit 1
      ;;
  esac
done

echo "Building SoulBox version: \$VERSION"
echo "Clean build: \$CLEAN_BUILD"

# Create build artifacts
mkdir -p build
echo "SoulBox image content - Build \$(date)" > "soulbox-\$VERSION.img"
sha256sum "soulbox-\$VERSION.img" > "soulbox-\$VERSION.img.sha256"

echo 'Build artifacts created:'
ls -la soulbox-*
BUILDSCRIPT
    
    chmod +x build-soulbox-containerized.sh
```

## Best Practices Summary

### DO's ✅

1. **Always quote heredoc delimiters**: `<< 'SCRIPT'`
2. **Use consistent escaping**: `\$VARIABLE` for all shell variables
3. **Test script content**: Echo the script before executing
4. **Use meaningful delimiter names**: `'BUILDSCRIPT'`, `'APICALL'`, etc.
5. **Validate YAML syntax**: Use tools to check parsing
6. **Document complex escaping**: Add comments explaining escaping choices

### DON'Ts ❌

1. **Don't mix escaping styles** in the same script
2. **Don't use unquoted delimiters** unless you want variable expansion
3. **Don't over-escape**: `\\\\$` is usually wrong
4. **Don't use `$$` for variables** (it's process ID)
5. **Don't embed quotes carelessly** in JSON strings
6. **Don't assume escaping works**: Always test

### Quick Reference Card

| Want in Shell Script | YAML Heredoc | Notes |
|---------------------|--------------|-------|
| `$VERSION` | `\$VERSION` | Basic variable |
| `$#` | `\$#` | Argument count |
| `$*` | `\$*` | All arguments |
| `${VAR:-default}` | `\${VAR:-default}` | Parameter expansion |
| `"$VAR"` | `"\$VAR"` | Quoted variable |
| `'literal text'` | `'literal text'` | No escaping needed |
| `\"quoted\"` | `\\\"quoted\\\"` | Escaped quotes |
| `$(command)` | `\$(command)` | Command substitution |
| `${array[@]}` | `\${array[@]}` | Array expansion |

---

**This guide is based on real debugging from SoulBox builds #117-123 where YAML heredoc escaping caused multiple CI/CD failures. Every pattern has been tested and verified.**

**← Back to [[CI-CD-Troubleshooting]] | Next: [[Build-System]] →**
