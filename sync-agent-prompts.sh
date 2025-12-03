#!/usr/bin/env bash

# sync-agent-prompts.sh
# Creates symlinks for all .agent.md files from ./agents/ to VS Code User prompts directory
# Usage: ./sync-agent-prompts.sh [--dry-run] [--help]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/agents"
TARGET_DIR="${HOME}/Library/Application Support/Code/User/prompts"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
created_count=0
skipped_count=0
replaced_count=0
dry_run=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            dry_run=true
            echo -e "${BLUE}🔍 DRY RUN MODE - No changes will be made${NC}\n"
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Creates symlinks for .agent.md files from ./agents/ to VS Code prompts directory"
            echo ""
            echo "Options:"
            echo "  --dry-run    Preview what would be created without making changes"
            echo "  --help, -h   Display this help message"
            echo ""
            echo "Examples:"
            echo "  $0                  # Create symlinks"
            echo "  $0 --dry-run        # Preview without changes"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate directories
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Error: Source directory not found: $SOURCE_DIR${NC}"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}❌ Error: Target directory not found: $TARGET_DIR${NC}"
    echo -e "${YELLOW}💡 Create it with: mkdir -p \"$TARGET_DIR\"${NC}"
    exit 1
fi

echo -e "${BLUE}📂 Source: $SOURCE_DIR${NC}"
echo -e "${BLUE}📂 Target: $TARGET_DIR${NC}"
echo ""

# Find and process all .agent.md files
while IFS= read -r -d '' source_file; do
    filename="$(basename "$source_file")"
    target_file="$TARGET_DIR/$filename"
    
    # Check if target exists
    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        # Check if it's a broken symlink
        if [ -L "$target_file" ] && [ ! -e "$target_file" ]; then
            # Broken symlink - replace it
            if [ "$dry_run" = true ]; then
                echo -e "${YELLOW}[DRY RUN] Would replace broken symlink: $filename${NC}"
            else
                rm "$target_file"
                ln -s "$source_file" "$target_file"
                echo -e "${GREEN}✅ Replaced broken symlink: $filename${NC}"
            fi
            ((replaced_count++))
        # Check if it's a symlink pointing to a different location
        elif [ -L "$target_file" ]; then
            current_target="$(readlink "$target_file")"
            if [ "$current_target" != "$source_file" ]; then
                # Symlink points elsewhere - replace it
                if [ "$dry_run" = true ]; then
                    echo -e "${YELLOW}[DRY RUN] Would replace symlink (points to different location): $filename${NC}"
                    echo -e "${YELLOW}           Current: $current_target${NC}"
                    echo -e "${YELLOW}           New: $source_file${NC}"
                else
                    rm "$target_file"
                    ln -s "$source_file" "$target_file"
                    echo -e "${GREEN}✅ Replaced symlink (updated target): $filename${NC}"
                fi
                ((replaced_count++))
            else
                # Already correctly symlinked - skip
                echo -e "${BLUE}⏭️  Already linked: $filename${NC}"
                ((skipped_count++))
            fi
        else
            # Regular file exists - skip
            echo -e "${YELLOW}⚠️  File exists (not a symlink): $filename - skipping${NC}"
            ((skipped_count++))
        fi
    else
        # Target doesn't exist - create symlink
        if [ "$dry_run" = true ]; then
            echo -e "${GREEN}[DRY RUN] Would create symlink: $filename${NC}"
        else
            ln -s "$source_file" "$target_file"
            echo -e "${GREEN}✅ Created symlink: $filename${NC}"
        fi
        ((created_count++))
    fi
done < <(find "$SOURCE_DIR" -name "*.agent.md" -type f -print0)

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$dry_run" = true ]; then
    echo -e "${BLUE}📊 Summary (Dry Run):${NC}"
    echo -e "${GREEN}   Would create: $created_count${NC}"
else
    echo -e "${BLUE}📊 Summary:${NC}"
    echo -e "${GREEN}   Created: $created_count${NC}"
fi
echo -e "${YELLOW}   Replaced: $replaced_count${NC}"
echo -e "${BLUE}   Skipped: $skipped_count${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$dry_run" = true ]; then
    echo -e "\n${YELLOW}💡 Run without --dry-run to apply changes${NC}"
fi