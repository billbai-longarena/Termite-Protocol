#!/usr/bin/env bash
# hook-pre-compact.sh — PreCompact hook
# Injects .birth and .pheromone into context before compaction to preserve protocol state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin
cat > /dev/null

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Build preserved context
preserved=""

# Include .birth
birth_content="$(read_birth)"
if [ -n "$birth_content" ]; then
  preserved="${preserved}## 白蚁协议 .birth（当前种姓与态势）
${birth_content}
"
fi

# Include .pheromone if it exists
pheromone_file="${PROJECT_ROOT}/.pheromone"
if [ -f "$pheromone_file" ]; then
  pheromone_content=$(cat "$pheromone_file")
  preserved="${preserved}
## 白蚁协议 .pheromone（交接状态）
${pheromone_content}
"
fi

if [ -n "$preserved" ]; then
  hook_system_message "[termite:PreCompact] 以下是压缩前必须保留的协议状态：

${preserved}
请在压缩后继续按以上种姓和态势工作。"
fi
