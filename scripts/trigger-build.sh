#!/bin/bash

# Manual Build Trigger Script
# Helps trigger GitHub Actions builds manually

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
    cat << 'EOF'
Manual Build Trigger for Project Raven

This script helps you trigger GitHub Actions builds manually.

Usage:
    ./trigger-build.sh [options]

Options:
    --check          Check current Pi OS version
    --status         Show recent build status
    --help, -h       Show this help

To trigger a manual build:
1. Go to: https://github.com/SysGrimm/Project-Raven/actions
2. Select "Build Raspberry Pi OS with Tailscale & Kodi"
3. Click "Run workflow"
4. Configure options as needed

EOF
}

check_version() {
    echo -e "${BLUE}Checking latest Raspberry Pi OS version...${NC}"
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq not found. Install it for better output formatting.${NC}"
        "$SCRIPT_DIR/check-version.sh"
        return
    fi
    
    VERSION_INFO=$("$SCRIPT_DIR/check-version.sh" --json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        VERSION_DATE=$(echo "$VERSION_INFO" | jq -r '.version_date')
        DOWNLOAD_URL=$(echo "$VERSION_INFO" | jq -r '.download_url')
        
        echo -e "${GREEN}Latest Pi OS Version:${NC} $VERSION_DATE"
        echo -e "${GREEN}Download URL:${NC} $DOWNLOAD_URL"
        
        # Check if we have this version built
        echo ""
        echo -e "${BLUE}Checking if this version is already built...${NC}"
        
        if command -v gh &> /dev/null; then
            # Use GitHub CLI if available
            LATEST_RELEASE=$(gh release list --repo SysGrimm/Project-Raven --limit 1 | head -1 | cut -f3)
            if [ "v$VERSION_DATE" = "$LATEST_RELEASE" ]; then
                echo -e "${GREEN}[PASS] Version v$VERSION_DATE is already built and released${NC}"
            else
                echo -e "${YELLOW}[WARN] Version v$VERSION_DATE is not yet built${NC}"
                echo -e "   Latest release: $LATEST_RELEASE"
                echo -e "   Consider triggering a manual build!"
            fi
        else
            echo -e "${YELLOW}Install 'gh' CLI tool to check release status automatically${NC}"
        fi
    else
        echo -e "${YELLOW}Could not check version. Check your internet connection.${NC}"
    fi
}

show_status() {
    echo -e "${BLUE}Recent build status:${NC}"
    
    if command -v gh &> /dev/null; then
        echo ""
        echo "Recent workflow runs:"
        gh run list --repo SysGrimm/Project-Raven --limit 5
        
        echo ""
        echo "Recent releases:"
        gh release list --repo SysGrimm/Project-Raven --limit 5
    else
        echo -e "${YELLOW}Install 'gh' CLI tool for detailed status information${NC}"
        echo ""
        echo "Manual checks:"
        echo "- Actions: https://github.com/SysGrimm/Project-Raven/actions"
        echo "- Releases: https://github.com/SysGrimm/Project-Raven/releases"
    fi
}

open_actions() {
    ACTIONS_URL="https://github.com/SysGrimm/Project-Raven/actions/workflows/build-pios-tailscale.yml"
    
    echo -e "${BLUE}Opening GitHub Actions workflow...${NC}"
    
    if command -v open &> /dev/null; then
        # macOS
        open "$ACTIONS_URL"
    elif command -v xdg-open &> /dev/null; then
        # Linux
        xdg-open "$ACTIONS_URL"
    else
        echo "Open this URL to trigger a manual build:"
        echo "$ACTIONS_URL"
    fi
}

main() {
    case "${1:-}" in
        --check|-c)
            check_version
            ;;
        --status|-s)
            show_status
            ;;
        --open|-o)
            open_actions
            ;;
        --help|-h|"")
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

main "$@"
