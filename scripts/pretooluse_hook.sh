#!/bin/bash

LOG_FILE="$HOME/Desktop/pretooluse-hook.log"

log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
BASH_CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

log "PreToolUse fired | Tool: $TOOL_NAME"

# Function to find git root
find_git_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo ""
}

# Extract a usable path depending on the tool
extract_path() {
    case "$TOOL_NAME" in
        Write|Edit|Read)
            echo "$FILE_PATH"
            ;;
        Bash)
            # Try to extract a path from the bash command
            # Look for absolute paths in the command first
            local found
            found=$(echo "$BASH_CMD" | grep -oE '/[a-zA-Z0-9/_.-]+' | head -1)
            if [ -n "$found" ]; then
                echo "$found"
            else
                # Fall back to the current working directory so we still
                # inject repo context for cwd-relative commands like
                # `find . -name foo` or `ls`
                pwd
            fi
            ;;
        Glob|Grep)
            echo "$( echo "$INPUT" | jq -r '.tool_input.path // ""' )"
            ;;
        *)
            echo ""
            ;;
    esac
}

TARGET_PATH=$(extract_path)
log "Extracted path: ${TARGET_PATH:-none}"

# Only proceed if we have a path
if [ -z "$TARGET_PATH" ]; then
    log "No path found for tool: $TOOL_NAME — allowing without context"
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    log "----------------------------------------"
    exit 0
fi

# Find git root from the extracted path
GIT_ROOT=$(find_git_root "$(dirname "$TARGET_PATH")")

if [ -z "$GIT_ROOT" ]; then
    log "No git repo found for path: $TARGET_PATH — allowing without context"
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
EOF
    log "----------------------------------------"
    exit 0
fi

log "Found repo: $(basename "$GIT_ROOT")"

# Build repo context
cd "$GIT_ROOT" 2>/dev/null || exit 0

BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
URL=$(git config --get remote.origin.url 2>/dev/null || echo "No remote")

if [[ $URL == git@github.com:* ]]; then
    URL="https://github.com/${URL#git@github.com:}"
    URL="${URL%.git}"
elif [[ $URL == *.git ]]; then
    URL="${URL%.git}"
fi

README=""
for f in README.md README.MD Readme.md; do
    if [ -f "$f" ]; then
        README=$(head -c 8000 "$f" 2>/dev/null)
        break
    fi
done

CONTEXT="=== ACTIVE REPO CONTEXT ===\n"
#CONTEXT+="Repo: $(basename "$GIT_ROOT")\n"
CONTEXT+="GitHub: ${URL}\n"
CONTEXT+="Branch: ${BRANCH}\n"
#CONTEXT+="Path: $GIT_ROOT\n\n"
#CONTEXT+="README.md:\n${README:-No README found.}\n"
CONTEXT+="==========================="

log "Injecting context for: $(basename "$GIT_ROOT")"
log "=== CONTEXT ==="
log "$CONTEXT"
log "=== END CONTEXT ==="

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": $(echo "$CONTEXT" | jq -Rs . 2>/dev/null || echo "\"$CONTEXT\"")
  }
}
EOF

log "----------------------------------------"
exit 0