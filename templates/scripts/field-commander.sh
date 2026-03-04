#!/usr/bin/env bash
# field-commander.sh — Commander <-> Colony bridge
# Usage:
#   field-commander.sh status
#   field-commander.sh create-signal <json>
#   field-commander.sh create-signals --plan <file>
#   field-commander.sh update-signal --id <id> --field <f> --value <v>
#   field-commander.sh check-stall --since <minutes>
#   field-commander.sh pulse

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/termite-db.sh"

COLONY_ROOT="${COLONY_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export PROJECT_ROOT="${COLONY_ROOT}"
db_ensure

cmd_status() {
  local total open claimed done blocked
  total=$(db_signal_count)
  open=$(db_signal_count "status='open'")
  claimed=$(db_signal_count "status='claimed'")
  done=$(db_signal_count "status IN ('done','completed')")
  blocked=$(db_signal_count "status='open' AND id IN (SELECT signal_id FROM claims WHERE operation='work')")
  printf '{"total":%d,"open":%d,"claimed":%d,"done":%d,"blocked":%d}\n' \
    "$total" "$open" "$claimed" "$done" "$blocked"
}

cmd_create_signal() {
  local json="$1"
  local type title weight source parent_id child_hint module next_hint
  type=$(echo "$json" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
  title=$(echo "$json" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
  weight=$(echo "$json" | grep -o '"weight":[0-9]*' | cut -d: -f2)
  source=$(echo "$json" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
  parent_id=$(echo "$json" | grep -o '"parent_id":"[^"]*"' | cut -d'"' -f4)
  child_hint=$(echo "$json" | grep -o '"child_hint":"[^"]*"' | cut -d'"' -f4)
  module=$(echo "$json" | grep -o '"module":"[^"]*"' | cut -d'"' -f4)
  next_hint=$(echo "$json" | grep -o '"next_hint":"[^"]*"' | cut -d'"' -f4)

  type="${type:-HOLE}"
  weight="${weight:-80}"
  source="${source:-directive}"
  local depth=0
  [ -n "${parent_id:-}" ] && depth=1

  local id now
  id=$(db_next_signal_id S)
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  db_signal_create "$id" "$type" "$(db_escape "$title")" "open" "$weight" "14" \
    "$now" "$now" "commander" "${module:-}" "[]" "$(db_escape "${next_hint:-}")" \
    "0" "$source" "${parent_id:-}" "$(db_escape "${child_hint:-}")" "$depth"

  printf '{"id":"%s","status":"created"}\n' "$id"
}

cmd_create_signals() {
  local plan_file="$1"
  if [ ! -f "$plan_file" ]; then
    echo '{"error":"plan file not found"}' >&2
    exit 1
  fi
  local count=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    cmd_create_signal "$line"
    count=$((count + 1))
  done < "$plan_file"
  printf '{"created":%d}\n' "$count"
}

cmd_update_signal() {
  local id="" field="" value=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      --field) field="$2"; shift 2 ;;
      --value) value="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -z "$id" ] || [ -z "$field" ] || [ -z "$value" ]; then
    echo '{"error":"missing --id, --field, or --value"}' >&2
    exit 1
  fi
  db_signal_update "$id" "$field" "$(db_escape "$value")"
  printf '{"id":"%s","updated":"%s"}\n' "$id" "$field"
}

cmd_check_stall() {
  local since_minutes="${1:-30}"
  local last_commit_ts now age_minutes open claimed
  last_commit_ts=$(git -C "${COLONY_ROOT}" log -1 --format=%ct 2>/dev/null || echo 0)
  now=$(date +%s)
  age_minutes=$(( (now - last_commit_ts) / 60 ))
  open=$(db_signal_count "status='open'")
  claimed=$(db_signal_count "status='claimed'")

  local stalled="false"
  [ "$age_minutes" -gt "$since_minutes" ] && stalled="true"

  printf '{"stalled":%s,"last_commit_minutes_ago":%d,"open_signals":%d,"claimed_signals":%d}\n' \
    "$stalled" "$age_minutes" "$open" "$claimed"
}

cmd_pulse() {
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "$now" > "${COLONY_ROOT}/.commander-pulse"
  printf '{"pulsed_at":"%s"}\n' "$now"
}

# --- Main dispatch ---
case "${1:-}" in
  status)
    cmd_status
    ;;
  create-signal)
    cmd_create_signal "${2:-{}}"
    ;;
  create-signals)
    shift
    _plan_file=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --plan) _plan_file="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_create_signals "$_plan_file"
    ;;
  update-signal)
    shift
    cmd_update_signal "$@"
    ;;
  check-stall)
    shift
    _since="30"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --since) _since="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_check_stall "$_since"
    ;;
  pulse)
    cmd_pulse
    ;;
  *)
    echo "Usage: field-commander.sh {status|create-signal|create-signals|update-signal|check-stall|pulse}" >&2
    exit 1
    ;;
esac
