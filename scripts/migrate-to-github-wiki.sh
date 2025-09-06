#!/bin/bash

# GitHub Wiki Migration Script
# This script migrates the local wiki/ folder content to GitHub Wiki

set -e

REPO_NAME="Project-Raven"
GITHUB_USER="SysGrimm"
WIKI_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.wiki.git"

echo "=== GitHub Wiki Migration Script ==="
echo "Repository: ${GITHUB_USER}/${REPO_NAME}"
echo "Wiki URL: ${WIKI_URL}"
echo ""

# Check if we're in the right directory
if [ ! -d "wiki" ]; then
    echo "Error: No wiki/ folder found. Please run this from the Project-Raven root directory."
    exit 1
fi

# Create a temporary directory for wiki operations
TEMP_DIR="/tmp/github-wiki-migration"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Step 1: Cloning GitHub Wiki repository..."
cd "$TEMP_DIR"

# Try to clone the wiki repository
if git clone "$WIKI_URL" wiki-repo; then
    echo "✅ Successfully cloned existing wiki repository"
    cd wiki-repo
else
    echo "⚠️  Wiki repository doesn't exist yet. Creating new one..."
    mkdir wiki-repo
    cd wiki-repo
    git init
    git remote add origin "$WIKI_URL"
    
    # Create initial Home page
    echo "# Welcome to Project-Raven Wiki" > Home.md
    echo "This wiki is being migrated from the repository wiki/ folder." >> Home.md
    git add Home.md
    git commit -m "Initial wiki setup"
fi

echo ""
echo "Step 2: Copying wiki content..."

# Copy all markdown files from the repo wiki folder
REPO_WIKI_PATH="$(dirname "$TEMP_DIR")/Project-Raven/wiki"
if [ -d "$REPO_WIKI_PATH" ]; then
    cp "$REPO_WIKI_PATH"/*.md .
    echo "✅ Copied all markdown files"
else
    echo "❌ Could not find repository wiki folder at: $REPO_WIKI_PATH"
    exit 1
fi

echo ""
echo "Step 3: GitHub Wiki filename adjustments..."

# GitHub Wiki has specific naming requirements
# Rename files to match GitHub Wiki conventions
if [ -f "_Sidebar.md" ]; then
    mv "_Sidebar.md" "_Sidebar.md"
    echo "✅ Sidebar file ready"
fi

# GitHub Wiki uses specific filenames
if [ -f "Home.md" ]; then
    echo "✅ Home page ready"
fi

echo ""
echo "Step 4: Adding and committing files..."

# Add all files
git add .

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo "ℹ️  No changes to commit - wiki is already up to date"
else
    # Commit the changes
    git commit -m "Migrate comprehensive documentation from repository wiki/ folder

Content migrated:
- Architecture Overview with Universal Package Download System
- Universal Package Download System (complete 500+ line documentation)
- Custom LibreELEC Build documentation
- CEC Troubleshooting guide
- Tailscale Add-on documentation
- Quick Start Guide
- Changelog with v2.1.0 details
- Version 2.0 Enhancements
- Known Issues documentation
- Comprehensive sidebar navigation

All content cleaned of emojis and properly formatted for GitHub Wiki."

    echo "✅ Changes committed"
fi

echo ""
echo "Step 5: Pushing to GitHub Wiki..."

# Push to GitHub Wiki
if git push origin main; then
    echo "✅ Successfully pushed to GitHub Wiki!"
else
    echo "⚠️  Push failed. You may need to enable Wiki in GitHub repository settings first."
    echo ""
    echo "To enable GitHub Wiki:"
    echo "1. Go to https://github.com/${GITHUB_USER}/${REPO_NAME}/settings"
    echo "2. Scroll to 'Features' section"
    echo "3. Check the 'Wikis' checkbox"
    echo "4. Save changes"
    echo "5. Then run this script again"
    exit 1
fi

echo ""
echo "🎉 Migration completed successfully!"
echo ""
echo "Your wiki is now available at:"
echo "https://github.com/${GITHUB_USER}/${REPO_NAME}/wiki"
echo ""
echo "Next steps:"
echo "1. Visit the wiki URL above to verify content"
echo "2. Optionally remove the wiki/ folder from repository to avoid duplication"
echo "3. Update any links in README.md to point to GitHub Wiki"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Migration script completed!"
