#!/usr/bin/env bash
# hook-post-edit.sh — PostToolUse(Write|Edit) hook
# Safety net S3: warn when uncommitted changes exceed 50 lines.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin
cat > /dev/null

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Count uncommitted lines
lines=$(count_uncommitted_lines)

if [ "$lines" -ge 50 ]; then
  echo "[termite:S3] 未提交改动已达 ${lines} 行（阈值 50）。建议立即 git commit -m '[WIP] ...' 防止丢失。" >&2
  exit 2
fi

exit 0
