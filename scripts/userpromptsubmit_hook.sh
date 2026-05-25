#!/bin/bash
# repo-beacon: UserPromptSubmit hook
# Injects current working directory into every prompt so Claude knows exactly where it is.

LOG_FILE="$HOME/Desktop/pretooluse-hook.log"

log() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Dependency check
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

CONTEXT="Current working directory: $CWD"

log "Injecting cwd context: $CWD"

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