#!/usr/bin/env bash
# termite-hook-lib.sh — Shared utilities for Termite Protocol Claude Code hooks
# Source this from all hook-*.sh scripts.
# Zero external dependencies: jq → python3 → grep/sed fallback chain.

set -euo pipefail

# ── Project Root ────────────────────────────────────────────────────

find_project_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return 0
  fi
  git rev-parse --show-toplevel 2>/dev/null || echo ""
}

PROJECT_ROOT="$(find_project_root)"

# ── Termite Project Detection ───────────────────────────────────────

is_termite_project() {
  [ -n "$PROJECT_ROOT" ] && {
    [ -f "${PROJECT_ROOT}/.birth" ] ||
    [ -f "${PROJECT_ROOT}/TERMITE_PROTOCOL.md" ] ||
    { [ -f "${PROJECT_ROOT}/CLAUDE.md" ] && grep -q "termite-kernel" "${PROJECT_ROOT}/CLAUDE.md" 2>/dev/null; }
  }
}

# ── Field Script Location ──────────────────────────────────────────

find_field_script() {
  local script_name="$1"
  local path="${PROJECT_ROOT}/scripts/${script_name}"
  if [ -x "$path" ]; then
    echo "$path"
    return 0
  fi
  return 1
}

# ── JSON Parsing (3-tier fallback) ─────────────────────────────────

json_get() {
  local json="$1" field="$2"

  # Tier 1: jq
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r ".${field} // empty" 2>/dev/null && return 0
  fi

  # Tier 2: python3
  if command -v python3 >/dev/null 2>&1; then
    echo "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    keys = '${field}'.split('.')
    v = d
    for k in keys:
        v = v[k]
    print(v if v is not None else '')
except: pass
" 2>/dev/null && return 0
  fi

  # Tier 3: grep/sed (flat keys only, no nested)
  local flat_field="${field##*.}"
  echo "$json" | grep -o "\"${flat_field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null \
    | sed "s/\"${flat_field}\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//' && return 0

  echo ""
}

read_stdin_json() {
  cat
}

# ── .birth Reading ─────────────────────────────────────────────────

read_birth() {
  local birth_file="${PROJECT_ROOT}/.birth"
  if [ -f "$birth_file" ]; then
    cat "$birth_file"
  else
    echo ""
  fi
}

birth_field() {
  local field="$1"
  local birth_file="${PROJECT_ROOT}/.birth"
  if [ -f "$birth_file" ]; then
    grep -m1 "^${field}:" "$birth_file" 2>/dev/null \
      | sed "s/^${field}:[[:space:]]*//" || true
  fi
}

# ── Git Utilities ──────────────────────────────────────────────────

count_uncommitted_lines() {
  if [ -z "$PROJECT_ROOT" ] || [ ! -d "${PROJECT_ROOT}/.git" ]; then
    echo "0"
    return
  fi
  local staged unstaged total
  staged=$(git -C "$PROJECT_ROOT" diff --cached --numstat 2>/dev/null \
    | awk '{s+=$1+$2} END {print s+0}')
  unstaged=$(git -C "$PROJECT_ROOT" diff --numstat 2>/dev/null \
    | awk '{s+=$1+$2} END {print s+0}')
  total=$((staged + unstaged))
  echo "$total"
}

has_uncommitted_changes() {
  [ -n "$PROJECT_ROOT" ] && [ -d "${PROJECT_ROOT}/.git" ] && \
    { ! git -C "$PROJECT_ROOT" diff --quiet 2>/dev/null || \
      ! git -C "$PROJECT_ROOT" diff --cached --quiet 2>/dev/null; }
}

# ── File Freshness ─────────────────────────────────────────────────

is_newer_than() {
  local file_a="$1" file_b="$2"
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    return 1
  fi
  local mod_a mod_b
  mod_a=$(stat -f "%m" "$file_a" 2>/dev/null || stat -c "%Y" "$file_a" 2>/dev/null || echo 0)
  mod_b=$(stat -f "%m" "$file_b" 2>/dev/null || stat -c "%Y" "$file_b" 2>/dev/null || echo 0)
  [ "$mod_a" -gt "$mod_b" ]
}

# ── Output Helpers ─────────────────────────────────────────────────

hook_approve() {
  echo '{"decision":"approve"}'
}

hook_block() {
  local reason="$1"
  local msg="${2:-$reason}"
  # Escape for JSON
  reason=$(echo "$reason" | sed 's/"/\\"/g' | tr '\n' ' ')
  msg=$(echo "$msg" | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"decision\":\"block\",\"reason\":\"${reason}\",\"systemMessage\":\"${msg}\"}"
}

hook_allow() {
  echo '{"hookSpecificOutput":{"permissionDecision":"allow"}}'
}

hook_deny() {
  local reason="$1"
  reason=$(echo "$reason" | sed 's/"/\\"/g' | tr '\n' ' ')
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"},\"systemMessage\":\"${reason}\"}"
}

hook_system_message() {
  local msg="$1"
  if command -v python3 >/dev/null 2>&1; then
    local escaped
    escaped=$(echo "$msg" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))' 2>/dev/null)
    echo "{\"systemMessage\":${escaped}}"
  else
    msg=$(echo "$msg" | sed 's/"/\\"/g' | tr '\n' '\\n')
    echo "{\"systemMessage\":\"${msg}\"}"
  fi
}
