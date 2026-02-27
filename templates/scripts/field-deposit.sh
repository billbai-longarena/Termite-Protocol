#!/usr/bin/env bash
# field-deposit.sh — Session-end deposit
# Writes observations (not rules) and optional .pheromone for cross-session handoff.
#
# Usage:
#   # Write an observation
#   ./field-deposit.sh --pattern "desc" --context "where" --confidence high --detail "info"
#
#   # Write .pheromone (cross-model handoff)
#   ./field-deposit.sh --pheromone --caste worker --completed "..." --unresolved "..."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

MODE="observation"  # observation | pheromone
PATTERN=""
CONTEXT=""
CONFIDENCE="medium"
DETAIL=""
CASTE="worker"
COMPLETED=""
UNRESOLVED=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pheromone)  MODE="pheromone"; shift ;;
    --pattern)    PATTERN="$2"; shift 2 ;;
    --context)    CONTEXT="$2"; shift 2 ;;
    --confidence) CONFIDENCE="$2"; shift 2 ;;
    --detail)     DETAIL="$2"; shift 2 ;;
    --caste)      CASTE="$2"; shift 2 ;;
    --completed)  COMPLETED="$2"; shift 2 ;;
    --unresolved) UNRESOLVED="$2"; shift 2 ;;
    *)
      log_error "Unknown argument: $1"
      echo "Usage:"
      echo "  Observation: $0 --pattern 'desc' --context 'where' [--confidence high|medium|low] [--detail 'info']"
      echo "  Pheromone:   $0 --pheromone --caste worker [--completed '...'] [--unresolved '...']"
      exit 1
      ;;
  esac
done

# ── Observation Mode ─────────────────────────────────────────────────

if [ "$MODE" = "observation" ]; then
  if [ -z "$PATTERN" ]; then
    log_error "--pattern is required for observations"
    exit 1
  fi

  ensure_signal_dirs
  reporter="termite:$(today_iso):${CASTE}"

  # Generate ID: O-{timestamp} for uniqueness
  obs_id="O-$(date +%Y%m%d%H%M%S)"
  obs_file="${OBS_DIR}/${obs_id}.yaml"

  # Avoid collision
  if [ -f "$obs_file" ]; then
    obs_id="${obs_id}-$(( RANDOM % 1000 ))"
    obs_file="${OBS_DIR}/${obs_id}.yaml"
  fi

  cat > "$obs_file" <<EOF
id: ${obs_id}
pattern: "${PATTERN}"
context: "${CONTEXT:-unknown}"
reporter: "${reporter}"
confidence: ${CONFIDENCE}
created: $(today_iso)
EOF

  # Add detail as multiline if provided
  if [ -n "$DETAIL" ]; then
    echo "detail: |" >> "$obs_file"
    echo "$DETAIL" | sed 's/^/  /' >> "$obs_file"
  fi

  log_info "Deposited observation ${obs_id}: ${PATTERN}"
  echo "$obs_file"
  exit 0
fi

# ── Pheromone Mode ───────────────────────────────────────────────────

if [ "$MODE" = "pheromone" ]; then
  # Write .pheromone JSON for cross-model handoff
  cat > "$PHEROMONE_FILE" <<EOF
{
  "timestamp": "$(now_iso)",
  "caste": "${CASTE}",
  "branch": "$(current_branch)",
  "commit": "$(current_commit_short)",
  "completed": $(echo "$COMPLETED" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo "\"${COMPLETED}\""),
  "unresolved": $(echo "$UNRESOLVED" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo "\"${UNRESOLVED}\""),
  "wip": "$(check_wip)",
  "active_signals": $(count_active_signals)
}
EOF

  log_info "Deposited .pheromone (caste=${CASTE}, branch=$(current_branch))"
  echo "$PHEROMONE_FILE"
  exit 0
fi
