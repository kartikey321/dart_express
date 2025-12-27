#!/bin/bash
# README Switch Script
# Switches between GitHub (clean) and pub.dev (with Rob's credit) versions
#
# Usage:
#   ./tool/switch_readme.sh --pubdev   # Switch to pub.dev version (inject Rob's notice)
#   ./tool/switch_readme.sh --github   # Switch to GitHub version (restore clean)

set -e  # Exit on error

# Parse arguments
MODE=""
if [ "$1" == "--pubdev" ]; then
    MODE="pubdev"
elif [ "$1" == "--github" ]; then
    MODE="github"
else
    echo "Usage: $0 [--pubdev|--github]"
    echo ""
    echo "  --pubdev   Switch to pub.dev version (inject Rob's credit notice)"
    echo "  --github   Switch to GitHub version (restore clean README)"
    echo ""
    exit 1
fi

echo "📝 README Switch Script"
echo "======================"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Run this script from packages/fletch/"
    exit 1
fi

# ============================================================================
# MODE: Switch to pub.dev version (inject Rob's notice)
# ============================================================================
if [ "$MODE" == "pubdev" ]; then
    echo "Mode: Switch to pub.dev version (with Rob's credit)"
    echo ""
    
    # Check if Rob's notice file exists
    if [ ! -f ".pubdev/PACKAGE_HISTORY_NOTICE.md" ]; then
        echo "❌ Error: .pubdev/PACKAGE_HISTORY_NOTICE.md not found"
        exit 1
    fi
    
    # Check if README already has Rob's notice
    if grep -q "Package History Notice" README.md; then
        echo "⚠️  README.md already contains Rob's notice"
        echo "   Already in pub.dev mode!"
        exit 0
    fi
    
    echo "Step 1: Backing up clean README..."
    cp README.md README_BACKUP.md
    echo "   ✅ Backed up to README_BACKUP.md"
    
    echo ""
    echo "Step 2: Injecting Rob's credit notice..."
    
    # Find the line number after the badges
    BADGE_LINE=$(grep -n "^\[\!\[License: MIT\]" README.md | cut -d: -f1)
    
    if [ -z "$BADGE_LINE" ]; then
        echo "   ❌ Could not find badge line in README.md"
        rm README_BACKUP.md
        exit 1
    fi
    
    # Calculate insertion point (after badges, before content)
    INSERT_LINE=$((BADGE_LINE + 2))
    
    # Create temporary README with Rob's notice injected
    {
        head -n $BADGE_LINE README.md
        echo ""
        cat .pubdev/PACKAGE_HISTORY_NOTICE.md
        tail -n +$INSERT_LINE README.md
    } > README_TEMP.md
    
    # Replace README with the version that includes Rob's notice
    mv README_TEMP.md README.md
    echo "   ✅ Injected Rob's credit notice"
    
    echo ""
    echo "✅ README switched to pub.dev version!"
    echo ""
    echo "Preview (first 20 lines):"
    echo "---"
    head -n 20 README.md
    echo "..."
    echo "---"
    echo ""
    echo "Next steps:"
    echo "1. Review the modified README.md"
    echo "2. Run: ./tool/publish.sh"
    echo "3. After publishing, restore with: ./tool/switch_readme.sh --github"
    echo ""

# ============================================================================
# MODE: Switch to GitHub version (restore clean)
# ============================================================================
elif [ "$MODE" == "github" ]; then
    echo "Mode: Switch to GitHub version (clean)"
    echo ""
    
    # Check if README has Rob's notice
    if ! grep -q "Package History Notice" README.md; then
        echo "ℹ️  README.md doesn't contain Rob's notice"
        echo "   Already in GitHub mode!"
        exit 0
    fi
    
    # Check if backup exists
    if [ ! -f "README_BACKUP.md" ]; then
        echo "❌ Error: README_BACKUP.md not found"
        echo ""
        echo "Cannot restore clean version without backup."
        echo "The backup is created when you run: ./tool/switch_readme.sh --pubdev"
        echo ""
        exit 1
    fi
    
    echo "Step 1: Restoring clean README from backup..."
    cp README_BACKUP.md README.md
    echo "   ✅ Restored clean README.md"
    
    echo ""
    echo "Step 2: Cleaning up backup..."
    rm README_BACKUP.md
    echo "   ✅ Removed README_BACKUP.md"
    
    echo ""
    echo "✅ README switched to GitHub version (clean)!"
    echo ""
    echo "Preview (first 15 lines):"
    echo "---"
    head -n 15 README.md
    echo "..."
    echo "---"
    echo ""
    echo "GitHub README is now clean (no Rob's notice)"
    echo ""
fi

