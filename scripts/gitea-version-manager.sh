#!/bin/bash

# SoulBox Gitea Release Version Manager
# Queries Gitea API for latest releases and manages smart versioning

set -e

# Configuration
GITEA_SERVER="https://gitea.osiris-adelie.ts.net"
GITEA_OWNER="reaper"
GITEA_REPO="soulbox"
GITEA_API_URL="${GITEA_SERVER}/api/v1/repos/${GITEA_OWNER}/${GITEA_REPO}"
GITEA_TOKEN="${GITOKEN:-}"  # Set via environment variable (GITOKEN secret)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to query Gitea releases API
query_gitea_releases() {
    local releases_url="${GITEA_API_URL}/releases"
    # Only log when not in auto mode to avoid version output contamination
    if [[ "${1:-}" != "silent" ]]; then
        log_info "Querying Gitea releases: $releases_url" >&2
    fi
    
    # Try to get releases from Gitea API
    if command -v curl >/dev/null 2>&1; then
        curl -s "$releases_url" 2>/dev/null || echo "[]"
    else
        echo "[]"
    fi
}

# Function to get latest released version from Gitea
get_latest_gitea_version() {
    local silent_mode="$1"
    local releases_json
    releases_json=$(query_gitea_releases "$silent_mode")
    
    # Parse latest version from JSON response
    local latest_version
    if command -v jq >/dev/null 2>&1; then
        # Use jq if available for proper JSON parsing
        latest_version=$(echo "$releases_json" | jq -r '.[0].tag_name // empty' 2>/dev/null)
    else
        # Fallback: simple grep parsing (less reliable but works without jq)
        latest_version=$(echo "$releases_json" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "")
    fi
    
    # Validate version format and return
    if [[ "$latest_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$latest_version"
    else
        # Fallback to git tags silently for clean version output
        get_latest_git_version
    fi
}

# Function to get latest version from git tags (fallback)
get_latest_git_version() {
    local latest_tag
    latest_tag=$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 2>/dev/null || echo "")
    
    if [[ -z "$latest_tag" ]]; then
        echo "v0.0.0"
    else
        echo "$latest_tag"
    fi
}

# Function to increment version
increment_version() {
    local version="$1"
    local increment_type="$2"
    
    # Remove 'v' prefix if present
    version=${version#v}
    
    # Split version into components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    
    case "$increment_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch"|*)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "v${major}.${minor}.${patch}"
}

# Function to determine increment type based on commit messages
determine_increment_type() {
    local latest_version="$1"
    local commits
    
    if [[ "$latest_version" == "v0.0.0" ]]; then
        # First release
        echo "minor"
        return
    fi
    
    # Get commits since last version (try both Gitea releases and git tags)
    if git rev-parse --verify "${latest_version}" >/dev/null 2>&1; then
        commits=$(git log --oneline "${latest_version}..HEAD" 2>/dev/null)
    else
        # If tag doesn't exist locally, use recent commits
        commits=$(git log --oneline -10)
    fi
    
    # Check for breaking changes or major features
    if echo "$commits" | grep -qi "breaking\|major\|BREAKING\|MAJOR"; then
        echo "major"
    elif echo "$commits" | grep -qi "feat\|feature\|add\|new\|FEAT\|FEATURE"; then
        echo "minor"
    else
        echo "patch"
    fi
}

# Function to get next version based on Gitea releases
get_next_version() {
    local increment_type="$1"
    local silent_mode="$2"
    local latest_version
    
    # Get latest version from Gitea first, fallback to git tags
    latest_version=$(get_latest_gitea_version "$silent_mode")
    
    # Only log if not in silent mode
    if [[ "$silent_mode" != "silent" ]]; then
        log_info "Current version: $latest_version" >&2
    fi
    
    # Auto-determine increment type if not specified
    if [[ -z "$increment_type" ]]; then
        increment_type=$(determine_increment_type "$latest_version")
    fi
    
    local next_version
    next_version=$(increment_version "$latest_version" "$increment_type")
    
    # Only log if not in silent mode
    if [[ "$silent_mode" != "silent" ]]; then
        log_info "Increment type: $increment_type" >&2
        log_info "Next version: $next_version" >&2
    fi
    
    # Only output the version to stdout (clean single line)
    echo "$next_version"
}

# Function to create Gitea release
create_gitea_release() {
    local version="$1"
    local image_file="$2"
    local checksum_file="$3"
    local release_notes="$4"
    
    log_info "Creating Gitea release: $version"
    
    # Prepare release data
    local release_data
    release_data=$(cat <<EOF
{
    "tag_name": "$version",
    "name": "SoulBox Will-o'-Wisp $version",
    "body": "$release_notes",
    "draft": false,
    "prerelease": false
}
EOF
)
    
    # Create the release
    local releases_url="${GITEA_API_URL}/releases"
    if command -v curl >/dev/null 2>&1; then
        log_info "Creating release via Gitea API..."
        local response
        if [[ -n "$GITEA_TOKEN" ]]; then
            response=$(curl -s -X POST "$releases_url" \
                -H "Authorization: token $GITEA_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$release_data" 2>/dev/null || echo '{"message":"API call failed"}')
        else
            response=$(curl -s -X POST "$releases_url" \
                -H "Content-Type: application/json" \
                -d "$release_data" 2>/dev/null || echo '{"message":"API call failed"}')
        fi
        
        # Check if release was created successfully
        local release_id
        if command -v jq >/dev/null 2>&1; then
            release_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)
        else
            release_id=$(echo "$response" | grep -o '"id":[0-9]*' | cut -d':' -f2 | head -1 2>/dev/null || echo "")
        fi
        
        if [[ -n "$release_id" && "$release_id" != "null" ]]; then
            log_success "Release created with ID: $release_id"
            
            # Upload image file as release asset
            if [[ -f "$image_file" ]]; then
                upload_release_asset "$release_id" "$image_file"
            fi
            
            # Upload checksum file as release asset
            if [[ -f "$checksum_file" ]]; then
                upload_release_asset "$release_id" "$checksum_file"
            fi
            
            log_success "Release $version created successfully: ${GITEA_SERVER}/${GITEA_OWNER}/${GITEA_REPO}/releases/tag/$version"
            return 0
        else
            log_warning "Failed to create Gitea release via API"
            log_info "Response: $response"
            return 1
        fi
    else
        log_error "curl not available for API calls"
        return 1
    fi
}

# Function to upload file as release asset
upload_release_asset() {
    local release_id="$1"
    local file_path="$2"
    local filename="$(basename "$file_path")"
    
    log_info "Uploading release asset: $filename ($(du -h "$file_path" | cut -f1))"
    log_info "File path: $file_path"
    log_info "File exists: $(test -f "$file_path" && echo "YES" || echo "NO")"
    
    local upload_url="${GITEA_API_URL}/releases/${release_id}/assets"
    if [[ -n "$GITEA_TOKEN" ]]; then
        log_info "Uploading to: $upload_url"
        local response
        # Use proper multipart form data without conflicting Content-Type header
        response=$(curl -s -X POST "$upload_url" \
            -H "Authorization: token $GITEA_TOKEN" \
            -F "attachment=@${file_path}" \
            -F "name=${filename}" 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "Uploaded: $filename"
            log_info "Upload response: $response"
        else
            log_warning "Failed to upload: $filename (exit code: $exit_code)"
            log_warning "Upload response: $response"
        fi
    else
        log_warning "No Gitea token provided - skipping asset upload: $filename"
    fi
}

# Function to generate release notes
generate_release_notes() {
    local version="$1"
    local latest_version="$2"
    
    local commit_log
    if [[ "$latest_version" != "v0.0.0" ]] && git rev-parse --verify "${latest_version}" >/dev/null 2>&1; then
        commit_log=$(git log --oneline "${latest_version}..HEAD" | head -10)
    else
        commit_log=$(git log --oneline -5)
    fi
    
    cat <<EOF
# SoulBox Will-o'-Wisp Media Center $version

🔥 **Container-Friendly Build System** - Built without privileged containers using LibreELEC-inspired approach

## What's New

$(echo "$commit_log" | sed 's/^/- /')

## Features

- **Kodi Media Center** with Raspberry Pi 5 optimizations
- **Tailscale VPN Integration** for secure remote access  
- **Automatic Setup** - first boot completes configuration
- **Will-o'-Wisp Branding** with custom boot splash
- **SSH Access** with default credentials
- **Container-Built** using mtools and e2tools (no loop devices!)

## Installation

1. Download the \`.img\` file from this release
2. Flash to SD card (2GB+ required, 8GB+ recommended)
3. Boot on Raspberry Pi 5
4. First boot will complete setup automatically

## Default Credentials

- **soulbox:soulbox** (media center user)
- **pi:soulbox** (compatibility)  
- **root:soulbox** (admin access)

## Verification

Use the provided \`.sha256\` file to verify image integrity:
\`\`\`bash
sha256sum -c soulbox-v${version#v}.img.sha256
\`\`\`

🌟 *The blue flame guides you home...*
EOF
}

# Main function
main() {
    local action="$1"
    local increment_type="$2"
    local image_file="$3"
    local checksum_file="$4"
    
    case "$action" in
        "get-current")
            get_latest_gitea_version
            ;;
        "get-next")
            get_next_version "$increment_type"
            ;;
        "auto")
            get_next_version "$increment_type" "silent"
            ;;
        "create-release")
            local version="$increment_type"  # version passed as second arg
            local latest_version=$(get_latest_gitea_version)
            local release_notes=$(generate_release_notes "$version" "$latest_version")
            create_gitea_release "$version" "$image_file" "$checksum_file" "$release_notes"
            ;;
        *)
            echo "SoulBox Gitea Release Version Manager"
            echo "Usage: $0 {get-current|get-next|auto|create-release} [options]"
            echo ""
            echo "Commands:"
            echo "  get-current                     Get current latest released version from Gitea"
            echo "  get-next [increment_type]       Get next version (auto-determined or specified)"
            echo "  auto [increment_type]           Get next version for automated builds"
            echo "  create-release VERSION IMG SHA  Create Gitea release with image files"
            echo ""
            echo "Increment types: major, minor, patch"
            echo ""
            echo "Examples:"
            echo "  $0 get-current"
            echo "  $0 get-next patch"
            echo "  $0 auto"
            echo "  $0 create-release v1.2.3 soulbox-v1.2.3.img soulbox-v1.2.3.img.sha256"
            exit 1
            ;;
    esac
}

main "$@"
