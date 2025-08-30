#!/bin/bash

set -e

# Version Management Script for SoulBox
# Determines next version based on git tags and semantic versioning

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get the latest version tag
get_latest_version() {
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
    local latest_tag="$1"
    local commits
    
    if [[ "$latest_tag" == "v0.0.0" ]]; then
        # First release
        echo "minor"
        return
    fi
    
    # Get commits since last tag
    commits=$(git log --oneline "${latest_tag}..HEAD" 2>/dev/null || git log --oneline -10)
    
    # Check for breaking changes or major features
    if echo "$commits" | grep -qi "breaking\|major\|BREAKING"; then
        echo "major"
    elif echo "$commits" | grep -qi "feat\|feature\|add\|new"; then
        echo "minor"
    else
        echo "patch"
    fi
}

# Function to get next version
get_next_version() {
    local increment_type="$1"
    local latest_version
    
    latest_version=$(get_latest_version)
    log_info "Latest version: $latest_version"
    
    if [[ -z "$increment_type" ]]; then
        increment_type=$(determine_increment_type "$latest_version")
    fi
    
    local next_version
    next_version=$(increment_version "$latest_version" "$increment_type")
    
    log_info "Increment type: $increment_type"
    log_info "Next version: $next_version"
    
    echo "$next_version"
}

# Main function
main() {
    local action="$1"
    local increment_type="$2"
    
    case "$action" in
        "get-current")
            get_latest_version
            ;;
        "get-next")
            get_next_version "$increment_type"
            ;;
        "auto")
            local next_version
            next_version=$(get_next_version "$increment_type")
            echo "$next_version"
            ;;
        *)
            echo "Usage: $0 {get-current|get-next|auto} [increment_type]"
            echo "  get-current: Get the current latest version"
            echo "  get-next: Get the next version (auto-determined or specified type)"
            echo "  auto: Get next version for automated builds"
            echo ""
            echo "Increment types: major, minor, patch"
            exit 1
            ;;
    esac
}

main "$@"
