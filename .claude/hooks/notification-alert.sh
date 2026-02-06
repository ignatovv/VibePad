#!/bin/bash
# macOS notification hook for Claude Code
# Sends native notifications when Claude needs input
# Adapted from Anytype enterprise project

if ! command -v jq &> /dev/null; then
    exit 0
fi

INPUT=$(cat)
if [ -z "$INPUT" ]; then
    exit 0
fi

NOTIFICATION_TYPE=$(printf '%s' "$INPUT" | jq -r '.notification_type // "unknown"' 2>/dev/null)
MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // "Claude needs your attention"' 2>/dev/null)

case "$NOTIFICATION_TYPE" in
  "permission_prompt")
    TITLE="VibePad — Permission Request"
    ;;
  "idle_prompt")
    TITLE="VibePad — Waiting for Input"
    ;;
  *)
    TITLE="VibePad — Claude Code"
    ;;
esac

osascript - "$MESSAGE" "$TITLE" <<'EOF' 2>/dev/null || true
on run argv
  display notification (item 1 of argv) with title (item 2 of argv) sound name "Submarine"
end run
EOF
