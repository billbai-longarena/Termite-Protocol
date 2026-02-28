#!/usr/bin/env bash
# hook-post-commit.sh — PostToolUse(Bash) hook
# Triggers field-cycle.sh (metabolism) after git commit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Read hook input
INPUT="$(read_stdin_json)"

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Extract command
command_str=$(json_get "$INPUT" "tool_input.command")

if [ -z "$command_str" ]; then
  exit 0
fi

# Check if this was a git commit command
if ! echo "$command_str" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# Run metabolism cycle in background (don't block the hook)
cycle_script=""
cycle_script=$(find_field_script "field-cycle.sh") || true

if [ -n "$cycle_script" ]; then
  "$cycle_script" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo "[termite] Metabolism cycle triggered (background)."
fi

exit 0
