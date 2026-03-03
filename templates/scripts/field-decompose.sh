#!/usr/bin/env bash
# field-decompose.sh — Decompose a complex signal into atomic child signals
# Called by strong models after claiming a signal that needs parallelization.
#
# Usage:
#   ./scripts/field-decompose.sh --parent S-042 \
#     --child "Implement registration API" --module "src/api/auth.ts" \
#       --hint '{"next_steps":"Create POST /register","files":["src/api/auth.ts"]}' \
#     --child "Add registration form" --module "src/components/Register.tsx" \
#       --hint '{"next_steps":"Create React form","files":["src/components/Register.tsx"]}'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

PARENT_ID=""
CHILDREN=()     # Each entry: "title|module|hint"

current_title=""
current_module=""
current_hint=""

flush_child() {
  if [ -n "$current_title" ]; then
    CHILDREN+=("${current_title}|${current_module}|${current_hint}")
    current_title=""
    current_module=""
    current_hint=""
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --parent)  PARENT_ID="$2"; shift 2 ;;
    --child)   flush_child; current_title="$2"; shift 2 ;;
    --module)  current_module="$2"; shift 2 ;;
    --hint)    current_hint="$2"; shift 2 ;;
    *)
      log_error "Unknown argument: $1"
      echo "Usage: $0 --parent <signal-id> --child <title> --module <path> [--hint <json>] [--child ...]"
      exit 1
      ;;
  esac
done
flush_child

if [ -z "$PARENT_ID" ]; then
  log_error "--parent is required"
  exit 1
fi

if [ ${#CHILDREN[@]} -eq 0 ]; then
  log_error "At least one --child is required"
  exit 1
fi

# ── Decompose ────────────────────────────────────────────────────────

if ! has_db; then
  log_error "Decomposition requires SQLite database (.termite.db)"
  log_error "YAML fallback does not support signal dependency graphs"
  exit 1
fi

source "${SCRIPT_DIR}/termite-db.sh"

# Validate parent
parent_row=$(db_query "SELECT status, depth, weight, type FROM signals WHERE id='$(db_escape "$PARENT_ID")';")
if [ -z "$parent_row" ]; then
  log_error "Parent signal ${PARENT_ID} not found"
  exit 1
fi

IFS=$'\t' read -r p_status p_depth p_weight p_type <<< "$parent_row"

max_depth="${TERMITE_DECOMPOSE_MAX_DEPTH:-3}"
child_depth=$((p_depth + 1))
if [ "$child_depth" -gt "$max_depth" ]; then
  log_error "Decomposition depth limit exceeded (${child_depth} > ${max_depth})"
  exit 1
fi

# Build SQL transaction
child_num=0
sql_stmts=""
child_ids=""

for entry in "${CHILDREN[@]}"; do
  IFS='|' read -r c_title c_module c_hint <<< "$entry"
  child_num=$((child_num + 1))
  c_id="${PARENT_ID}-${child_num}"
  child_ids="${child_ids:+${child_ids}, }${c_id}"

  sql_stmts="${sql_stmts}
    INSERT INTO signals(id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parent_id,child_hint,depth)
      VALUES('$(db_escape "$c_id")','$(db_escape "$p_type")','$(db_escape "$c_title")','open',${p_weight},14,
      '$(today_iso)','$(today_iso)','unassigned','$(db_escape "$c_module")','[]','','0','decomposed',
      '$(db_escape "$PARENT_ID")','$(db_escape "$c_hint")',${child_depth});"
done

db_transaction "$sql_stmts"

log_info "Decomposed ${PARENT_ID} into ${child_num} children: [${child_ids}]"
log_info "Children are open for claiming. Parent remains ${p_status}."
echo "${child_ids}"
