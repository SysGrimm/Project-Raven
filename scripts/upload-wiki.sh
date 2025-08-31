#!/bin/bash
set -euo pipefail

# SoulBox Wiki Upload Script
# Uploads local wiki pages to Gitea wiki repository

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WIKI_DIR="$PROJECT_ROOT/wiki"

# Configuration
GITEA_HOST="${GITEA_HOST:-https://192.168.176.113:3000}"
REPO_OWNER="${REPO_OWNER:-yourusername}"
REPO_NAME="${REPO_NAME:-soulbox}"
WIKI_REPO_URL="$GITEA_HOST/$REPO_OWNER/$REPO_NAME.wiki.git"
TEMP_WIKI_DIR="/tmp/soulbox-wiki-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Help function
show_help() {
    cat << EOF
SoulBox Wiki Upload Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Show what would be uploaded without actually doing it
    -f, --force         Force upload even if wiki exists
    -c, --clean         Clean up temporary files after upload
    --gitea-host URL    Gitea instance URL (default: $GITEA_HOST)
    --repo-owner NAME   Repository owner (default: $REPO_OWNER)  
    --repo-name NAME    Repository name (default: $REPO_NAME)

EXAMPLES:
    # Basic upload
    $0
    
    # Dry run to see what would be uploaded
    $0 --dry-run
    
    # Upload to different Gitea instance
    $0 --gitea-host "https://git.example.com"
    
    # Upload with custom repository
    $0 --repo-owner "myuser" --repo-name "myrepo"

ENVIRONMENT VARIABLES:
    GITEA_HOST      Gitea instance URL
    REPO_OWNER      Repository owner username
    REPO_NAME       Repository name
    GITEA_TOKEN     Gitea API token (for authentication)

SETUP:
    1. Ensure you have git configured with credentials for Gitea
    2. Make sure the repository exists and has wiki enabled
    3. Run: $0

The script will:
    - Clone the wiki repository (or create if it doesn't exist)
    - Copy local wiki pages to the wiki repository
    - Commit and push changes to Gitea
    - Clean up temporary files
EOF
}

# Parse command line arguments
DRY_RUN=false
FORCE=false
CLEAN=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        --no-clean)
            CLEAN=false
            shift
            ;;
        --gitea-host)
            GITEA_HOST="$2"
            WIKI_REPO_URL="$GITEA_HOST/$REPO_OWNER/$REPO_NAME.wiki.git"
            shift 2
            ;;
        --repo-owner)
            REPO_OWNER="$2"
            WIKI_REPO_URL="$GITEA_HOST/$REPO_OWNER/$REPO_NAME.wiki.git"
            shift 2
            ;;
        --repo-name)
            REPO_NAME="$2"
            WIKI_REPO_URL="$GITEA_HOST/$REPO_OWNER/$REPO_NAME.wiki.git"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            echo
            show_help
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_error "git is not installed or not in PATH"
        exit 1
    fi
    
    # Check if wiki directory exists
    if [[ ! -d "$WIKI_DIR" ]]; then
        log_error "Wiki directory not found: $WIKI_DIR"
        exit 1
    fi
    
    # Check if there are any .md files in wiki directory
    if ! find "$WIKI_DIR" -name "*.md" -type f | grep -q .; then
        log_error "No .md files found in wiki directory: $WIKI_DIR"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# List wiki pages to be uploaded
list_wiki_pages() {
    log_info "Wiki pages to be uploaded:"
    find "$WIKI_DIR" -name "*.md" -type f | while read -r file; do
        local basename=$(basename "$file")
        local size=$(du -h "$file" | cut -f1)
        echo "  - $basename ($size)"
    done
}

# Clone or create wiki repository
setup_wiki_repo() {
    log_info "Setting up wiki repository..."
    
    # Clean up any existing temp directory
    if [[ -d "$TEMP_WIKI_DIR" ]]; then
        rm -rf "$TEMP_WIKI_DIR"
    fi
    
    # Try to clone existing wiki
    if git clone "$WIKI_REPO_URL" "$TEMP_WIKI_DIR" 2>/dev/null; then
        log_success "Cloned existing wiki repository"
    else
        # Create new wiki repository
        log_warning "Wiki repository doesn't exist, creating new one"
        mkdir -p "$TEMP_WIKI_DIR"
        cd "$TEMP_WIKI_DIR"
        git init
        git remote add origin "$WIKI_REPO_URL"
        
        # Create initial commit
        echo "# SoulBox Wiki" > README.md
        git add README.md
        git commit -m "Initial wiki setup"
        
        # Try to push (this will create the wiki repository)
        if ! git push -u origin main 2>/dev/null; then
            log_error "Failed to create wiki repository. Make sure:"
            log_error "  1. The main repository exists"
            log_error "  2. Wiki is enabled in repository settings"
            log_error "  3. You have write access to the repository"
            exit 1
        fi
        
        log_success "Created new wiki repository"
    fi
}

# Copy wiki pages to repository
copy_wiki_pages() {
    log_info "Copying wiki pages..."
    
    cd "$TEMP_WIKI_DIR"
    
    # Remove existing .md files (except README.md)
    find . -name "*.md" -not -name "README.md" -delete 2>/dev/null || true
    
    # Copy all .md files from wiki directory
    find "$WIKI_DIR" -name "*.md" -type f | while read -r file; do
        local basename=$(basename "$file")
        cp "$file" "$basename"
        log_info "  Copied $basename"
    done
    
    # Count files
    local file_count=$(find . -name "*.md" -not -name "README.md" | wc -l)
    log_success "Copied $file_count wiki pages"
}

# Commit and push changes
upload_changes() {
    log_info "Uploading changes to Gitea..."
    
    cd "$TEMP_WIKI_DIR"
    
    # Check if there are any changes
    if git diff --quiet && git diff --cached --quiet; then
        log_info "No changes detected, wiki is up to date"
        return 0
    fi
    
    # Add all files
    git add .
    
    # Create commit with timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local commit_message="Update SoulBox wiki - $timestamp

Migrated from TFM.md to structured wiki pages:
- Home: Main entry point with navigation
- Architecture: System design and technology stack  
- Build-System: Container-friendly build documentation
- Deployment-Guide: Installation and configuration
- Features: Comprehensive feature overview
- Development: Workflow and contributing guidelines
- Troubleshooting: Common issues and solutions"
    
    git commit -m "$commit_message"
    
    # Push changes
    if git push origin main; then
        log_success "Successfully uploaded wiki to Gitea"
        log_info "Wiki URL: $GITEA_HOST/$REPO_OWNER/$REPO_NAME/wiki"
    else
        log_error "Failed to push changes to wiki repository"
        exit 1
    fi
}

# Clean up temporary files
cleanup() {
    if [[ "$CLEAN" == "true" && -d "$TEMP_WIKI_DIR" ]]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$TEMP_WIKI_DIR"
        log_success "Cleanup completed"
    elif [[ "$CLEAN" == "false" ]]; then
        log_info "Temporary files preserved at: $TEMP_WIKI_DIR"
    fi
}

# Main execution
main() {
    log_info "SoulBox Wiki Upload Script Starting..."
    log_info "Repository: $REPO_OWNER/$REPO_NAME"
    log_info "Wiki URL: $WIKI_REPO_URL"
    echo
    
    check_prerequisites
    list_wiki_pages
    echo
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
        log_info "Would upload $(find "$WIKI_DIR" -name "*.md" -type f | wc -l) wiki pages"
        return 0
    fi
    
    # Confirm upload unless force mode
    if [[ "$FORCE" != "true" ]]; then
        echo -n "Upload wiki pages to Gitea? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Upload cancelled"
            return 0
        fi
    fi
    
    # Set up trap for cleanup on exit
    trap cleanup EXIT
    
    setup_wiki_repo
    copy_wiki_pages
    upload_changes
    
    log_success "Wiki upload completed successfully!"
    echo
    log_info "Next steps:"
    log_info "  1. Visit: $GITEA_HOST/$REPO_OWNER/$REPO_NAME/wiki"
    log_info "  2. Verify all pages are displayed correctly"
    log_info "  3. Update main README.md to reference wiki instead of TFM.md"
    log_info "  4. Consider removing TFM.md after successful migration"
}

# Run main function
main "$@"
