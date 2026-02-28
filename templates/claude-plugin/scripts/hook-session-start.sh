#!/usr/bin/env bash
# hook-session-start.sh — SessionStart hook
# Runs field-arrive.sh to generate .birth, injects summary into session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin (required by hook protocol even if unused)
cat > /dev/null

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Try to run field-arrive.sh
arrive_script=""
arrive_script=$(find_field_script "field-arrive.sh") || true

if [ -n "$arrive_script" ]; then
  "$arrive_script" 2>/dev/null || true
fi

# Read .birth for summary
birth_content="$(read_birth)"
if [ -z "$birth_content" ]; then
  exit 0
fi

# Inject birth content as environment variable (persists across session)
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  birth_b64=$(echo "$birth_content" | base64 | tr -d '\n')
  echo "export TERMITE_BIRTH_B64=\"${birth_b64}\"" >> "$CLAUDE_ENV_FILE"
fi

# Extract summary fields from .birth
caste=$(birth_field "caste")
branch=$(birth_field "branch")
health=$(birth_field "health")

echo "[termite] Arrived. Caste: ${caste:-unknown}. Branch: ${branch:-unknown}. ${health:-no health data}."
