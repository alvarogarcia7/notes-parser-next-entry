#!/bin/bash
# Parser Update Tool
# Updates individual parser repositories from their remote sources
# Handles version tracking and conflict resolution

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="$REPO_ROOT/parser-versions.txt"
PARSERS=(
    "google-keep-notes-parser:google-keep-notes-parser.git:08e4-implement-this-f"
    "training-parser-antlr4:training-parser-antlr4.git:08e4-implement-this-f"
    "time-entry-notes-parser:notes-parser-time-entry.git:master"
    "notes-parser-next-entry:notes-parser-next-entry.git:master"
)

# Parse arguments
PARSER_NAME=${1:-""}
MODE=${2:-"check"}  # check, update, reset, status

# Function to display help
show_help() {
    cat << EOF
$(echo -e "${BLUE}Parser Update Tool${NC}")

Usage: $(basename "$0") [PARSER] [MODE]

Parsers:
  time         - Time entry parser
  training     - Training parser (ANTLR4)
  hn           - HackerNews parser
  next         - Next entry parser
  all          - All parsers (default)

Modes:
  check        - Check for updates (default)
  update       - Pull latest from remote
  reset        - Reset to remote version (discard local changes)
  status       - Show current version information
  versions     - Show version history

Examples:
  $(basename "$0")                    # Check all parsers for updates
  $(basename "$0") time check         # Check time parser for updates
  $(basename "$0") all update         # Update all parsers
  $(basename "$0") training update    # Update training parser
  $(basename "$0") all status         # Show status of all parsers
  $(basename "$0") all versions       # Show version history

EOF
}

# Map parser names to directories
get_parser_info() {
    local name=$1
    case "$name" in
        time)
            echo "time-entry-notes-parser:notes-parser-time-entry.git:master"
            ;;
        training)
            echo "training-parser-antlr4:training-parser-antlr4.git:08e4-implement-this-f"
            ;;
        hn|hackernews)
            echo "hackernews-parser:hackernews-parser.git:master"
            ;;
        next)
            echo "notes-parser-next-entry:notes-parser-next-entry.git:master"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Initialize version tracking file
init_versions_file() {
    if [ ! -f "$VERSIONS_FILE" ]; then
        cat > "$VERSIONS_FILE" << EOF
# Parser Version Tracking
# Format: parser_name:last_updated:commit:branch
# Updated: $(date)

EOF
    fi
}

# Check for updates
check_updates() {
    local parser_dir=$1
    local parser_name=$2

    if [ ! -d "$parser_dir" ]; then
        print_warning "$parser_name directory not found"
        return 1
    fi

    cd "$parser_dir"

    print_step "Checking $parser_name for updates..."

    # Get current status
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local current_commit=$(git rev-parse --short HEAD)
    local current_commit_full=$(git rev-parse HEAD)

    # Fetch latest from remote
    git fetch origin --quiet 2>/dev/null || {
        print_warning "Could not fetch from remote for $parser_name"
        cd - > /dev/null
        return 1
    }

    # Check for differences
    local remote_branch="origin/$current_branch"
    local local_ahead=$(git rev-list --count $remote_branch..HEAD 2>/dev/null || echo 0)
    local remote_ahead=$(git rev-list --count HEAD..$remote_branch 2>/dev/null || echo 0)
    local local_status=$(git status --porcelain)

    echo ""
    echo "  Branch: $current_branch"
    echo "  Local commit: $current_commit"
    echo "  Remote commits ahead of you: $remote_ahead"
    echo "  Your commits ahead of remote: $local_ahead"

    if [ -n "$local_status" ]; then
        echo "  $(print_warning 'Local changes detected')"
    fi

    if [ "$remote_ahead" -gt 0 ]; then
        echo "  $(print_step 'Updates available')"
        echo ""
        echo "  Latest remote commits:"
        git log --oneline -3 $remote_branch 2>/dev/null || echo "    (Could not fetch commits)"
        cd - > /dev/null
        return 0  # Updates available
    else
        echo "  $(print_success 'Already up to date')"
        cd - > /dev/null
        return 1  # No updates
    fi
}

# Update parser
update_parser() {
    local parser_dir=$1
    local parser_name=$2

    if [ ! -d "$parser_dir" ]; then
        print_error "$parser_name directory not found"
        return 1
    fi

    cd "$parser_dir"

    print_step "Updating $parser_name..."

    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local current_commit=$(git rev-parse --short HEAD)

    # Check for local changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "$parser_name has local changes"
        echo "  Stashing local changes..."
        git stash push -m "Auto-stash before update - $(date)"
    fi

    # Fetch and merge
    print_step "Pulling latest from origin/$current_branch..."
    if git pull origin "$current_branch" --quiet; then
        local new_commit=$(git rev-parse --short HEAD)
        print_success "$parser_name updated"
        echo "  From: $current_commit"
        echo "  To:   $new_commit"

        # Update version file
        update_version_file "$parser_name" "$new_commit"

        cd - > /dev/null
        return 0
    else
        print_error "Failed to update $parser_name"
        echo "  Please resolve conflicts manually"
        cd - > /dev/null
        return 1
    fi
}

# Reset parser to remote version
reset_parser() {
    local parser_dir=$1
    local parser_name=$2

    if [ ! -d "$parser_dir" ]; then
        print_error "$parser_name directory not found"
        return 1
    fi

    cd "$parser_dir"

    print_warning "Resetting $parser_name to remote version..."
    echo "  This will discard all local changes"

    # Confirm action
    read -p "  Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Reset cancelled"
        cd - > /dev/null
        return 1
    fi

    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local current_commit=$(git rev-parse --short HEAD)

    # Reset hard
    git fetch origin --quiet
    git reset --hard "origin/$current_branch" --quiet

    local new_commit=$(git rev-parse --short HEAD)
    print_success "$parser_name reset"
    echo "  From: $current_commit"
    echo "  To:   $new_commit (matches remote)"

    cd - > /dev/null
    return 0
}

# Show parser status
show_status() {
    local parser_dir=$1
    local parser_name=$2

    if [ ! -d "$parser_dir" ]; then
        print_error "$parser_name directory not found"
        return 1
    fi

    cd "$parser_dir"

    print_step "$parser_name status"

    local branch=$(git rev-parse --abbrev-ref HEAD)
    local commit=$(git rev-parse --short HEAD)
    local commit_full=$(git rev-parse HEAD)
    local author=$(git log -1 --pretty=format:"%an")
    local date=$(git log -1 --pretty=format:"%ai")
    local message=$(git log -1 --pretty=format:"%s")

    echo "  Branch:  $branch"
    echo "  Commit:  $commit ($commit_full)"
    echo "  Author:  $author"
    echo "  Date:    $date"
    echo "  Message: $message"

    # Check if dirty
    if ! git diff-index --quiet HEAD --; then
        echo "  Status:  $(print_warning 'Has uncommitted changes')"
    else
        echo "  Status:  $(print_success 'Clean')"
    fi

    cd - > /dev/null
    return 0
}

# Update version file
update_version_file() {
    local parser_name=$1
    local commit=$2
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    # Remove old entry if exists
    grep -v "^$parser_name:" "$VERSIONS_FILE" > "$VERSIONS_FILE.tmp" || true
    mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"

    # Add new entry
    echo "$parser_name:$timestamp:$commit" >> "$VERSIONS_FILE"
}

# Show version history
show_versions() {
    init_versions_file

    print_step "Parser Version History"
    echo ""
    cat "$VERSIONS_FILE"
    echo ""
}

# Process parsers
process_parsers() {
    local filter=$1
    local mode=$2

    init_versions_file

    local success=0
    local failed=0

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 Parser Update Tool                        ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""

    for parser_spec in "${PARSERS[@]}"; do
        IFS=':' read -r parser_dir parser_repo parser_branch <<< "$parser_spec"

        # Apply filter
        if [ "$filter" != "all" ]; then
            case "$filter" in
                time) [[ "$parser_dir" != "time-entry-notes-parser" ]] && continue ;;
                training) [[ "$parser_dir" != "training-parser-antlr4" ]] && continue ;;
                hn|hackernews) [[ "$parser_dir" != "hackernews-parser" ]] && continue ;;
                next) [[ "$parser_dir" != "notes-parser-next-entry" ]] && continue ;;
                google) [[ "$parser_dir" != "google-keep-notes-parser" ]] && continue ;;
            esac
        fi

        echo ""

        case "$mode" in
            check)
                if check_updates "$REPO_ROOT/$parser_dir" "$parser_dir"; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
            update)
                if update_parser "$REPO_ROOT/$parser_dir" "$parser_dir"; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
            reset)
                if reset_parser "$REPO_ROOT/$parser_dir" "$parser_dir"; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
            status)
                if show_status "$REPO_ROOT/$parser_dir" "$parser_dir"; then
                    ((success++))
                else
                    ((failed++))
                fi
                ;;
        esac
    done

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    if [ "$failed" -eq 0 ]; then
        print_success "All operations completed"
    else
        print_error "$failed operation(s) failed"
    fi
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Main logic
if [ "$PARSER_NAME" = "help" ] || [ "$PARSER_NAME" = "-h" ] || [ "$PARSER_NAME" = "--help" ]; then
    show_help
    exit 0
fi

if [ "$PARSER_NAME" = "versions" ]; then
    show_versions
    exit 0
fi

# Default to "all" if not specified
PARSER_NAME=${PARSER_NAME:-all}

# Validate parser name
case "$PARSER_NAME" in
    time|training|hn|hackernews|next|all|google)
        ;;
    *)
        print_error "Unknown parser: $PARSER_NAME"
        echo ""
        show_help
        exit 1
        ;;
esac

# Process the parsers
process_parsers "$PARSER_NAME" "$MODE"
