#!/usr/bin/env bash
# hook-pre-bash.sh — PreToolUse(Bash) hook
# Safety net S2: prevent deletion of .md files and critical directories.

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

# Extract command
command_str=$(json_get "$INPUT" "tool_input.command")

if [ -z "$command_str" ]; then
  exit 0
fi

# Pattern 1: rm + .md file
if echo "$command_str" | grep -qE '\brm\b.*\.md\b'; then
  hook_deny "[termite:S2] 安全网 S2: 禁止删除 .md 文件。白蚁协议保护 .md 文件不被删除。如果确实需要删除，请人类手动操作。"
  exit 0
fi

# Pattern 2: rm -rf on critical directories
if echo "$command_str" | grep -qE '\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\b.*(signals/|scripts/|\.claude/)'; then
  hook_deny "[termite:S2] 安全网 S2: 禁止递归删除协议关键目录 (signals/, scripts/, .claude/)。"
  exit 0
fi

# No dangerous pattern — allow
exit 0
