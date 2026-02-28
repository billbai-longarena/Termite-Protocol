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
SOURCE="autonomous"
COMPRESS_SIGNAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pheromone)  MODE="pheromone"; shift ;;
    --compress)   MODE="compress"; shift ;;
    --signal)     COMPRESS_SIGNAL="$2"; shift 2 ;;
    --source)     SOURCE="$2"; shift 2 ;;
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

  # DB-first path
  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    obs_id="O-$(date +%Y%m%d%H%M%S)-$$"
    reporter="termite:$(today_iso):${CASTE}"
    db_obs_create "$obs_id" "$PATTERN" "${CONTEXT:-unknown}" "$reporter" "$CONFIDENCE" "$SOURCE" "$DETAIL"
    log_info "Deposited observation ${obs_id}: ${PATTERN} (DB)"
    echo "$obs_id"
    exit 0
  fi

  # YAML fallback
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
source: ${SOURCE}
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
  # DB-first path
  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    local_agent_id="${AGENT_ID:-$(generate_agent_id)}"
    db_pheromone_deposit "$local_agent_id" "$CASTE" "$(current_branch)" "$(current_commit_short)" \
      "$COMPLETED" "$UNRESOLVED" "$PREDECESSOR_USEFUL"
    log_info "Deposited pheromone (DB, caste=${CASTE}, predecessor_useful=${PREDECESSOR_USEFUL:-not_evaluated})"
  fi

  # Always write .pheromone file too for backward compat
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

  # DB-first path
  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    db_rule_increment_dispute "$DISPUTE_RULE"
    if [ -n "$DISPUTE_REASON" ]; then
      obs_id="O-$(date +%Y%m%d%H%M%S)-$$"
      db_obs_create "$obs_id" "dispute:${DISPUTE_RULE}" "rule dispute" \
        "termite:$(today_iso):${CASTE}" "high" "autonomous" \
        "Rule ${DISPUTE_RULE} was found inapplicable. Reason: ${DISPUTE_REASON}"
      log_info "Dispute observation ${obs_id} deposited for ${DISPUTE_RULE}"
    fi
    log_info "Disputed ${DISPUTE_RULE} (DB atomic)"
    exit 0
  fi

  # YAML fallback
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

# ── Compress Mode ────────────────────────────────────────────────────

if [ "$MODE" = "compress" ]; then
  # DB-first path
  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    db_obs_compress
    log_info "Compression complete (DB)"
    exit 0
  fi

  # YAML fallback
  if [ ! -d "$OBS_DIR" ]; then
    log_info "No observations directory — nothing to compress"
    exit 0
  fi

  ensure_signal_dirs

  # Build signal reference groups: date+signal → observation files
  tmpfile=$(mktemp)
  obs_count=0

  while IFS= read -r obs_file; do
    [ -f "$obs_file" ] || continue
    obs_count=$((obs_count + 1))
    local_pattern=$(yaml_read "$obs_file" "pattern")
    local_context=$(yaml_read "$obs_file" "context")
    local_created=$(yaml_read "$obs_file" "created")

    # Extract signal references from pattern and context
    signal_refs=$(echo "${local_pattern} ${local_context}" | grep -oE 'S-[0-9]+' | sort -u | tr '\n' ',' | sed 's/,$//')

    if [ -n "$signal_refs" ]; then
      group_key="${local_created}:${signal_refs}"
      echo "${group_key}|${obs_file}" >> "$tmpfile"
    fi
  done < <(list_observations)

  if [ "$obs_count" -eq 0 ] || [ ! -s "$tmpfile" ]; then
    log_info "No observations with signal references to compress"
    rm -f "$tmpfile"
    exit 0
  fi

  # Find groups with >= 3 observations
  merged_total=0
  cut -d'|' -f1 "$tmpfile" | sort | uniq -c | sort -rn | while read -r gcount group_key; do
    gcount=$(echo "$gcount" | tr -d ' ')
    if [ "$gcount" -ge 3 ]; then
      log_info "Compressing group (${gcount} observations): ${group_key}"

      # Collect observation files and IDs for this group
      group_files=""
      group_ids=""
      last_pattern=""
      last_context=""

      while IFS='|' read -r gk gf; do
        if [ "$gk" = "$group_key" ]; then
          group_files="${group_files:+${group_files} }${gf}"
          local_id=$(yaml_read "$gf" "id")
          group_ids="${group_ids:+${group_ids}, }${local_id}"
          last_pattern=$(yaml_read "$gf" "pattern")
          last_context=$(yaml_read "$gf" "context")
        fi
      done < "$tmpfile"

      # Create merged observation
      merged_id="O-$(date +%Y%m%d%H%M%S)-merged"
      merged_file="${OBS_DIR}/${merged_id}.yaml"

      cat > "$merged_file" <<MEOF
id: ${merged_id}
pattern: "${last_pattern}"
context: "${last_context}"
reporter: "termite:$(today_iso):system"
confidence: high
created: $(today_iso)
source: autonomous
merged_count: ${gcount}
merged_from: [${group_ids}]
detail: |
  Merged from ${gcount} observations referencing ${group_key#*:}.
  Original observations archived to archive/merged/.
MEOF

      log_info "Created merged observation ${merged_id} from [${group_ids}]"

      # Move originals to archive/merged/
      mkdir -p "${ARCHIVE_DIR}/merged"
      for f in $group_files; do
        [ -f "$f" ] && mv "$f" "${ARCHIVE_DIR}/merged/"
      done

      merged_total=$((merged_total + 1))
    fi
  done

  rm -f "$tmpfile"
  log_info "Compression complete"
  exit 0
fi
