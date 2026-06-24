#!/bin/bash
# repo-beacon: UserPromptSubmit hook
# Injects CWD and all discovered git repos (up + down) into every prompt.

LOG_FILE="$HOME/Desktop/pretooluse-hook.log"

log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

if ! command -v jq &>/dev/null; then
    log "ERROR: jq is not installed."
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit"
  }
}
EOF
    exit 0
fi

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

log "UserPromptSubmit fired | CWD: $CWD"

if [ -z "$CWD" ]; then
    log "No cwd found — skipping context injection"
    cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit"
  }
}
EOF
    exit 0
fi

# Walk up from a directory to find its git root
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

# Get repo info (local path, remote URL, branch) for a given git root
repo_context() {
    local root="$1"
    cd "$root" 2>/dev/null || return

    local branch url
    branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    url=$(git config --get remote.origin.url 2>/dev/null || echo "no remote")

    if [[ $url == git@github.com:* ]]; then
        url="https://github.com/${url#git@github.com:}"
        url="${url%.git}"
    elif [[ $url == *.git ]]; then
        url="${url%.git}"
    fi

    echo "<GIT>$url|$branch</GIT>"
}

# Collect all unique git roots: walk up from CWD + scan down up to depth 2
SEEN_ROOTS=""
REPO_CONTEXTS=""

already_seen() {
    echo "$SEEN_ROOTS" | grep -qF "|$1|"
}

# 1. Walk up — CWD may itself be inside a repo
PARENT_ROOT=$(find_git_root "$CWD")
if [ -n "$PARENT_ROOT" ]; then
    SEEN_ROOTS="|$PARENT_ROOT|"
    CTX=$(repo_context "$PARENT_ROOT")
    REPO_CONTEXTS="$REPO_CONTEXTS$CTX"$'\n'
    log "Found parent repo: $PARENT_ROOT"
fi

# 2. Scan down — find child repos up to depth 2
while IFS= read -r gitdir; do
    root=$(dirname "$gitdir")
    if ! already_seen "$root"; then
        SEEN_ROOTS="$SEEN_ROOTS|$root|"
        CTX=$(repo_context "$root")
        REPO_CONTEXTS="$REPO_CONTEXTS$CTX"$'\n'
        log "Found child repo: $root"
    fi
done < <(find "$CWD" -maxdepth 2 -name ".git" -type d 2>/dev/null)

# Build final context string
if [ -n "$REPO_CONTEXTS" ]; then
    CONTEXT="Current working directory: $CWD

Active git repositories:
$REPO_CONTEXTS"
else
    CONTEXT="Current working directory: $CWD"
    log "No git repos found under CWD"
fi

log "Injecting context:"
log "$CONTEXT"

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $(echo "$CONTEXT" | jq -Rs .)
  }
}
EOF

log "----------------------------------------"
exit 0
