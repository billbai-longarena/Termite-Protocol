#!/usr/bin/env bash
# hook-stop.sh — Stop hook
# Enforces "no silent death" — blocks stop until pheromone is deposited.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin
cat > /dev/null

# Skip if not a termite project — approve immediately
if ! is_termite_project; then
  hook_approve
  exit 0
fi

# Check 1: Uncommitted changes
if has_uncommitted_changes; then
  lines=$(count_uncommitted_lines)
  if [ "$lines" -gt 0 ]; then
    hook_block \
      "[termite] 有 ${lines} 行未提交改动。请先 commit [WIP] 或运行 ./scripts/field-deposit.sh --pheromone 再结束。" \
      "[termite:S3] 禁止无声死亡。有 ${lines} 行未提交改动。请 commit [WIP] 或运行 ./scripts/field-deposit.sh --pheromone 留下信息素。"
    exit 0
  fi
fi

# Check 2: Pheromone freshness
# .pheromone should be newer than .birth (written during this session)
pheromone_file="${PROJECT_ROOT}/.pheromone"
birth_file="${PROJECT_ROOT}/.birth"

if [ -f "$birth_file" ]; then
  if [ ! -f "$pheromone_file" ] || ! is_newer_than "$pheromone_file" "$birth_file"; then
    hook_block \
      "[termite] 本次会话尚未沉淀信息素。请运行 ./scripts/field-deposit.sh --pheromone 再结束。" \
      "[termite] 禁止无声死亡。请运行: ./scripts/field-deposit.sh --pheromone --caste <your_caste> --completed '已完成的工作' --unresolved '未解决的问题' --predecessor-useful true"
    exit 0
  fi
fi

# All checks passed
hook_approve
