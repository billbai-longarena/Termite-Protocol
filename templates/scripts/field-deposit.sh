#!/usr/bin/env bash
# field-deposit.sh — Session-end deposit
# Writes observations (not rules), optional .pheromone for cross-session handoff,
# and rule disputes for protocol meta-feedback.
#
# Usage:
#   # Write an observation
#   ./field-deposit.sh --pattern "desc" --context "where" --confidence high --detail "info"
#
#   # Write .pheromone (cross-model handoff)
#   ./field-deposit.sh --pheromone --caste worker --completed "..." --unresolved "..." --predecessor-useful true
#
#   # Dispute a rule (increment disputed_count)
#   ./field-deposit.sh --dispute R-001 --reason "rule not applicable when..."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

MODE="observation"  # observation | pheromone | dispute
PATTERN=""
CONTEXT=""
CONFIDENCE="medium"
DETAIL=""
CASTE="worker"
COMPLETED=""
UNRESOLVED=""
PREDECESSOR_USEFUL=""  # true | false | "" (not evaluated)
DISPUTE_RULE=""
DISPUTE_REASON=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pheromone)  MODE="pheromone"; shift ;;
    --dispute)    MODE="dispute"; DISPUTE_RULE="$2"; shift 2 ;;
    --reason)     DISPUTE_REASON="$2"; shift 2 ;;
    --pattern)    PATTERN="$2"; shift 2 ;;
    --context)    CONTEXT="$2"; shift 2 ;;
    --confidence) CONFIDENCE="$2"; shift 2 ;;
    --detail)     DETAIL="$2"; shift 2 ;;
    --caste)      CASTE="$2"; shift 2 ;;
    --completed)  COMPLETED="$2"; shift 2 ;;
    --unresolved) UNRESOLVED="$2"; shift 2 ;;
    --predecessor-useful) PREDECESSOR_USEFUL="$2"; shift 2 ;;
    *)
      log_error "Unknown argument: $1"
      echo "Usage:"
      echo "  Observation: $0 --pattern 'desc' --context 'where' [--confidence high|medium|low] [--detail 'info']"
      echo "  Pheromone:   $0 --pheromone --caste worker [--completed '...'] [--unresolved '...'] [--predecessor-useful true|false]"
      echo "  Dispute:     $0 --dispute R-001 --reason 'why rule was wrong'"
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
  # predecessor_useful: did the previous agent's .pheromone help this session?
  pred_useful_json="null"
  if [ "$PREDECESSOR_USEFUL" = "true" ]; then
    pred_useful_json="true"
  elif [ "$PREDECESSOR_USEFUL" = "false" ]; then
    pred_useful_json="false"
  fi

  cat > "$PHEROMONE_FILE" <<EOF
{
  "timestamp": "$(now_iso)",
  "caste": "${CASTE}",
  "branch": "$(current_branch)",
  "commit": "$(current_commit_short)",
  "completed": $(echo "$COMPLETED" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo "\"${COMPLETED}\""),
  "unresolved": $(echo "$UNRESOLVED" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo "\"${UNRESOLVED}\""),
  "predecessor_useful": ${pred_useful_json},
  "wip": "$(check_wip)",
  "active_signals": $(count_active_signals)
}
EOF

  log_info "Deposited .pheromone (caste=${CASTE}, branch=$(current_branch), predecessor_useful=${PREDECESSOR_USEFUL:-not_evaluated})"
  echo "$PHEROMONE_FILE"
  exit 0
fi

# ── Dispute Mode ──────────────────────────────────────────────────────

if [ "$MODE" = "dispute" ]; then
  if [ -z "$DISPUTE_RULE" ]; then
    log_error "--dispute requires a rule ID (e.g., R-001)"
    exit 1
  fi

  # Find the rule file
  rule_file="${RULES_DIR}/${DISPUTE_RULE}.yaml"
  if [ ! -f "$rule_file" ]; then
    log_error "Rule file not found: ${rule_file}"
    exit 1
  fi

  # Increment disputed_count
  current=$(yaml_read "$rule_file" "disputed_count")
  current="${current:-0}"
  new_count=$((current + 1))

  # Update disputed_count in the YAML file
  if grep -q "^disputed_count:" "$rule_file"; then
    sed -i.bak "s/^disputed_count:.*/disputed_count: ${new_count}/" "$rule_file"
    rm -f "${rule_file}.bak"
  else
    # Field doesn't exist yet — append after hit_count
    sed -i.bak "/^hit_count:/a\\
disputed_count: ${new_count}" "$rule_file"
    rm -f "${rule_file}.bak"
  fi

  # Log the dispute as an observation for audit trail
  if [ -n "$DISPUTE_REASON" ]; then
    ensure_signal_dirs
    obs_id="O-$(date +%Y%m%d%H%M%S)"
    obs_file="${OBS_DIR}/${obs_id}.yaml"
    cat > "$obs_file" <<EOF
id: ${obs_id}
pattern: "dispute:${DISPUTE_RULE}"
context: "rule dispute"
reporter: "termite:$(today_iso):${CASTE}"
confidence: high
created: $(today_iso)
detail: |
  Rule ${DISPUTE_RULE} was found inapplicable.
  Reason: ${DISPUTE_REASON}
EOF
    log_info "Dispute observation ${obs_id} deposited for ${DISPUTE_RULE}"
  fi

  log_info "Disputed ${DISPUTE_RULE}: disputed_count ${current} → ${new_count}"
  exit 0
fi
