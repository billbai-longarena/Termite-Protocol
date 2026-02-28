#!/usr/bin/env bash
# hook-user-prompt.sh — UserPromptSubmit hook
# Detects "白蚁协议" / "termite protocol" trigger and injects .birth context.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Skip if not a termite project
if ! is_termite_project; then
  cat > /dev/null
  exit 0
fi

# Read hook input
INPUT="$(read_stdin_json)"

# Extract user prompt
user_prompt=$(json_get "$INPUT" "user_prompt")

# Check for trigger words (case-insensitive)
trigger_found=false
prompt_lower=$(echo "$user_prompt" | tr '[:upper:]' '[:lower:]')

case "$prompt_lower" in
  *白蚁协议*|*termite\ protocol*|*termite-protocol*)
    trigger_found=true
    ;;
esac

if [ "$trigger_found" = "false" ]; then
  exit 0
fi

# Trigger detected — inject .birth content as system message
birth_content="$(read_birth)"

if [ -z "$birth_content" ]; then
  # No .birth yet — try to generate one
  arrive_script=""
  arrive_script=$(find_field_script "field-arrive.sh") || true
  if [ -n "$arrive_script" ]; then
    "$arrive_script" 2>/dev/null || true
    birth_content="$(read_birth)"
  fi
fi

if [ -n "$birth_content" ]; then
  hook_system_message "[termite:heartbeat] 白蚁协议心跳触发。以下是你的 .birth 出生证明，按此行动：

${birth_content}"
fi
