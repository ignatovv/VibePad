#!/bin/bash

# Post-Tool-Use Tracker Hook
# Logs all Edit/Write operations for monitoring and debugging
# Adapted from Anytype enterprise project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LOG_FILE="$LOG_DIR/tool-usage.log"
mkdir -p "$LOG_DIR"

# Read event data from stdin
EVENT_DATA=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$EVENT_DATA" | jq -r '.tool // "unknown"')

# Only track file modification tools
case "$TOOL_NAME" in
    Edit|Write|MultiEdit|NotebookEdit)
        ;;
    *)
        exit 0
        ;;
esac

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Extract file path(s)
FILE_PATHS=""
case "$TOOL_NAME" in
    Edit|Write|NotebookEdit)
        FILE_PATHS=$(echo "$EVENT_DATA" | jq -r '.parameters.file_path // .parameters.notebook_path // "unknown"')
        ;;
    MultiEdit)
        FILE_PATHS=$(echo "$EVENT_DATA" | jq -r '.parameters.edits[]?.file_path // empty' | tr '\n' ', ' | sed 's/,$//')
        ;;
esac

if [ -z "$FILE_PATHS" ]; then
    exit 0
fi

echo "[$TIMESTAMP] $TOOL_NAME: $FILE_PATHS" >> "$LOG_FILE"

# Categorize by project area
for file in $(echo "$FILE_PATHS" | tr ',' '\n'); do
    file=$(echo "$file" | xargs)
    AREA="unknown"
    if echo "$file" | grep -q "VibePad/"; then
        if echo "$file" | grep -q "GamepadManager\|InputMapper\|KeyboardEmitter"; then
            AREA="Core"
        elif echo "$file" | grep -q "OverlayHUD\|StatusBar\|App\.swift\|MenuBar"; then
            AREA="UI"
        elif echo "$file" | grep -q "Config\|Mapping"; then
            AREA="Config"
        else
            AREA="App"
        fi
    elif echo "$file" | grep -q "Tests"; then
        AREA="Tests"
    elif echo "$file" | grep -q "\.claude/"; then
        AREA="Claude Config"
    fi
    echo "  └─ Area: $AREA" >> "$LOG_FILE"
done

exit 0
