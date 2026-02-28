#!/usr/bin/env bash
# termite-db-export.sh — Export DB state to YAML files for audit/human reading
# Usage: ./termite-db-export.sh [--out <dir>]
#
# Exports:
#   signals/active/*.yaml    — from signals table (status != archived)
#   signals/observations/*.yaml — from observations table
#   signals/rules/*.yaml     — from rules table
#   .pheromone               — latest pheromone_history entry as JSON
#   .field-breath            — from colony_state table

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"
source "${SCRIPT_DIR}/termite-db.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

OUT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--out <dir>]"
      echo ""
      echo "Exports SQLite DB state to YAML files."
      echo "Default output: PROJECT_ROOT (overwrites signals/ and runtime files)"
      exit 0
      ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

OUT_DIR="${OUT_DIR:-$PROJECT_ROOT}"

if [ ! -f "$TERMITE_DB" ]; then
  log_error "No database found at ${TERMITE_DB}"
  exit 1
fi

log_info "=== DB→YAML export starting ==="
log_info "Output: ${OUT_DIR}"

# ── Export Signals ───────────────────────────────────────────────────

signals_dir="${OUT_DIR}/signals/active"
db_export_signals_dir "$signals_dir"
sig_count=$(db_signal_count "status != 'archived'" 2>/dev/null || echo "0")
log_info "Exported ${sig_count} signals to ${signals_dir}"

# ── Export Observations ──────────────────────────────────────────────

obs_dir="${OUT_DIR}/signals/observations"
db_export_obs_dir "$obs_dir"
obs_count=$(db_obs_count 2>/dev/null || echo "0")
log_info "Exported ${obs_count} observations to ${obs_dir}"

# ── Export Rules ─────────────────────────────────────────────────────

rules_dir="${OUT_DIR}/signals/rules"
db_export_rules_dir "$rules_dir"
rule_count=$(db_exec "SELECT COUNT(*) FROM rules;" 2>/dev/null || echo "0")
log_info "Exported ${rule_count} rules to ${rules_dir}"

# ── Export Pheromone (latest entry as JSON) ──────────────────────────

ph_row=$(db_pheromone_latest)
if [ -n "$ph_row" ]; then
  IFS=$'\t' read -r agent_id timestamp caste branch commit_hash completed unresolved pred_useful wip_status active_sig_count <<< "$ph_row"

  pred_json="null"
  case "$pred_useful" in
    1) pred_json="true" ;;
    0) pred_json="false" ;;
  esac

  cat > "${OUT_DIR}/.pheromone" <<EOF
{
  "timestamp": "${timestamp}",
  "caste": "${caste}",
  "branch": "${branch}",
  "commit": "${commit_hash}",
  "completed": "${completed}",
  "unresolved": "${unresolved}",
  "predecessor_useful": ${pred_json},
  "wip": "${wip_status}",
  "active_signals": ${active_sig_count:-0}
}
EOF
  log_info "Exported latest pheromone to .pheromone"
fi

# ── Export Colony State as .field-breath ──────────────────────────────

alarm=$(db_colony_get "alarm" 2>/dev/null || echo "false")
wip=$(db_colony_get "wip" 2>/dev/null || echo "absent")
build=$(db_colony_get "build" 2>/dev/null || echo "unknown")
sig_ratio=$(db_colony_get "signature_ratio" 2>/dev/null || echo "0.00")
active_signals=$(db_colony_get "active_signals" 2>/dev/null || echo "0")
high_holes=$(db_colony_get "high_weight_holes" 2>/dev/null || echo "0")
parked_signals=$(db_colony_get "parked_signals" 2>/dev/null || echo "0")
expired_claims=$(db_colony_get "expired_claims" 2>/dev/null || echo "0")
bb_status=$(db_colony_get "blackboard" 2>/dev/null || echo "absent")
branch=$(db_colony_get "branch" 2>/dev/null || echo "unknown")
commit=$(db_colony_get "commit" 2>/dev/null || echo "0000000")

cat > "${OUT_DIR}/.field-breath" <<EOF
timestamp: $(now_iso)
alarm: ${alarm}
wip: ${wip}
build: ${build}
signature_ratio: ${sig_ratio}
active_signals: ${active_signals}
high_weight_holes: ${high_holes}
parked_signals: ${parked_signals}
expired_claims: ${expired_claims}
blackboard: ${bb_status}
branch: ${branch}
commit: ${commit}
EOF
log_info "Exported colony state to .field-breath"

# ── Create signal directories for compatibility ──────────────────────

mkdir -p "${OUT_DIR}/signals/claims" "${OUT_DIR}/signals/archive" 2>/dev/null || true

log_info "=== DB→YAML export complete ==="
