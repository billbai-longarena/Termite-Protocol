#!/usr/bin/env bash
# field-export-audit.sh — Export audit package for protocol-level review
#
# Produces a self-contained directory of protocol artifacts, stripped of all
# project source code. A Protocol Nurse agent can read ONLY this package
# (plus the protocol definition) to evaluate and optimize the protocol itself.
#
# Usage:
#   ./field-export-audit.sh                           # export to ./audit-package-YYYY-MM-DD/
#   ./field-export-audit.sh --out /path/to/target     # export to specific directory
#   ./field-export-audit.sh --tar                      # also create .tar.gz archive
#   ./field-export-audit.sh --project-name "MyApp"     # override auto-detected project name
#
# What's included (protocol artifacts only):
#   signals/          — rules, observations, active signals, archive
#   git-signatures.txt — termite commit signatures (no code diffs)
#   pheromone-chain.jsonl — .pheromone history from git (one JSON per line)
#   immune-log.txt    — immune log section from BLACKBOARD.md
#   breath-snapshot.yaml — current .field-breath
#   caste-distribution.yaml — agent type breakdown from git history
#   rule-health.yaml  — per-rule hit_count vs disputed_count summary
#   metadata.yaml     — project name, protocol version, run duration, totals
#
# What's NOT included:
#   No project source code. No business logic. No .env files. No node_modules.
#   No BLACKBOARD business sections. No DECISIONS.md business content.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

OUT_DIR=""
CREATE_TAR=false
PROJECT_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out)           OUT_DIR="$2"; shift 2 ;;
    --tar)           CREATE_TAR=true; shift ;;
    --project-name)  PROJECT_NAME="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--out <dir>] [--tar] [--project-name <name>]"
      echo ""
      echo "Exports a protocol audit package (no project source code)."
      echo "Output: ./audit-package-YYYY-MM-DD/ (or --out path)"
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Commander context variables (populated in Steps 7-9 if Commander detected)
commander_detected=false
commander_model=""
worker_count=0
task_type=""
objective=""
halt_reason=""
halt_recommendation=""
commander_cycles=0
colony_cycles=0
run_duration_seconds=0

# Default output directory
if [ -z "$OUT_DIR" ]; then
  OUT_DIR="${PROJECT_ROOT}/audit-package-$(today_iso)"
fi

# Auto-detect project name from directory
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
fi

log_info "=== Audit package export starting ==="
log_info "Project: ${PROJECT_NAME}"
log_info "Output:  ${OUT_DIR}"

# ── Setup Output ─────────────────────────────────────────────────────

mkdir -p "$OUT_DIR"

# ── 1. Signals Directory (complete copy) ─────────────────────────────

log_info "Step 1/10: Copying signals directory"

if has_db; then
  source "${SCRIPT_DIR}/termite-db.sh"
  source "${SCRIPT_DIR}/termite-db-export.sh" --out "${OUT_DIR}" 2>/dev/null || {
    # Direct export if sourcing doesn't work
    db_export_signals_dir "${OUT_DIR}/signals/active"
    db_export_obs_dir "${OUT_DIR}/signals/observations"
    db_export_rules_dir "${OUT_DIR}/signals/rules"
  }
  mkdir -p "${OUT_DIR}/signals/archive"
  rule_count=$(db_exec "SELECT COUNT(*) FROM rules;" 2>/dev/null || echo "0")
  obs_count=$(db_obs_count 2>/dev/null || echo "0")
  active_count=$(db_signal_count "status NOT IN ('archived', 'done', 'completed')" 2>/dev/null || echo "0")
  archive_count=$(db_exec "SELECT COUNT(*) FROM archive;" 2>/dev/null || echo "0")
  log_info "  rules: ${rule_count}, observations: ${obs_count}, active: ${active_count}, archived: ${archive_count} (from DB)"
elif [ -d "$SIGNALS_DIR" ]; then
  # Copy entire signals tree, preserving structure.
  # Remove target first to prevent cp -R nesting (signals/signals/) when target exists.
  rm -rf "${OUT_DIR}/signals"
  cp -R "$SIGNALS_DIR" "${OUT_DIR}/signals"

  # Remove any claim locks (ephemeral, not useful for audit)
  rm -rf "${OUT_DIR}/signals/claims" 2>/dev/null || true

  # Count what we got
  rule_count=$(find "${OUT_DIR}/signals/rules" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
  obs_count=$(find "${OUT_DIR}/signals/observations" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
  
  # Filter out completed/done signals for accurate active count
  active_count=0
  if [ -d "${OUT_DIR}/signals/active" ]; then
    for f in "${OUT_DIR}/signals/active"/*.yaml; do
      [ -f "$f" ] || continue
      status=$(grep -E "^status:" "$f" 2>/dev/null | awk '{print $2}' || echo "")
      if [ "$status" != "done" ] && [ "$status" != "completed" ]; then
        active_count=$((active_count + 1))
      fi
    done
  fi
  
  archive_count=$(find "${OUT_DIR}/signals/archive" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')

  log_info "  rules: ${rule_count}, observations: ${obs_count}, active: ${active_count}, archived: ${archive_count}"
else
  mkdir -p "${OUT_DIR}/signals"
  rule_count=0; obs_count=0; active_count=0; archive_count=0
  log_warn "  No signals directory found"
fi

# ── 2. Git Signatures (no code diffs) ────────────────────────────────

log_info "Step 2/10: Extracting git signatures"

sig_file="${OUT_DIR}/git-signatures.txt"

if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  # Extract all termite-signed commits: hash, date, caste tag, subject
  # Format: <short-hash> <date> <subject-with-signature>
  git -C "$PROJECT_ROOT" log --all --format="%h %ai %s" --grep='\[termite:' \
    > "$sig_file" 2>/dev/null || true

  total_commits=$(git -C "$PROJECT_ROOT" log --all --oneline 2>/dev/null | wc -l | tr -d ' ')
  signed_commits=$(wc -l < "$sig_file" | tr -d ' ')

  # Also extract unsigned commits (just hash + date + subject, no code)
  echo "" >> "$sig_file"
  echo "# --- Unsigned commits (for IC-3 foreign body analysis) ---" >> "$sig_file"
  git -C "$PROJECT_ROOT" log --all --format="%h %ai %s" 2>/dev/null \
    | grep -v '\[termite:' >> "$sig_file" 2>/dev/null || true

  log_info "  ${signed_commits}/${total_commits} commits signed"
else
  echo "# No git repository found" > "$sig_file"
  total_commits=0; signed_commits=0
  log_warn "  No git repository"
fi

# ── 3. Pheromone Chain (from git history) ─────────────────────────────

log_info "Step 3/10: Extracting pheromone chain"

chain_file="${OUT_DIR}/pheromone-chain.jsonl"
> "$chain_file"

if has_db; then
  chain_count=0
  while IFS=$'\t' read -r agent_id timestamp caste branch commit_hash completed unresolved pred_useful wip_status active_sig_count; do
    [ -z "$agent_id" ] && continue
    pred_json="null"
    case "$pred_useful" in
      1) pred_json="true" ;;
      0) pred_json="false" ;;
    esac
    echo "{\"timestamp\":\"${timestamp}\",\"caste\":\"${caste}\",\"branch\":\"${branch}\",\"commit\":\"${commit_hash}\",\"completed\":\"${completed}\",\"unresolved\":\"${unresolved}\",\"predecessor_useful\":${pred_json},\"agent_id\":\"${agent_id}\"}" >> "$chain_file"
    chain_count=$((chain_count + 1))
  done < <(db_pheromone_chain)
  log_info "  ${chain_count} pheromone snapshots from DB"
elif git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  # Find all commits that touched .pheromone, extract the file content at each
  pheromone_commits=$(git -C "$PROJECT_ROOT" log --all --follow --format="%H" -- ".pheromone" 2>/dev/null || true)
  chain_count=0

  for commit_hash in $pheromone_commits; do
    # Extract .pheromone content at this commit
    content=$(git -C "$PROJECT_ROOT" show "${commit_hash}:.pheromone" 2>/dev/null || true)
    if [ -n "$content" ]; then
      # Output as single-line JSON (one per line = JSONL)
      echo "$content" | tr '\n' ' ' | sed 's/[[:space:]]*$//' >> "$chain_file"
      echo "" >> "$chain_file"
      chain_count=$((chain_count + 1))
    fi
  done

  # Also include current .pheromone if it exists and isn't committed
  if [ -f "$PHEROMONE_FILE" ]; then
    current_content=$(cat "$PHEROMONE_FILE" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    # Check if it's already the last entry (avoid duplicate)
    last_entry=$(tail -1 "$chain_file" 2>/dev/null | sed 's/[[:space:]]*$//')
    if [ "$current_content" != "$last_entry" ] && [ -n "$current_content" ]; then
      echo "$current_content" >> "$chain_file"
      chain_count=$((chain_count + 1))
    fi
  fi

  # Remove empty lines
  sed -i.bak '/^[[:space:]]*$/d' "$chain_file" 2>/dev/null || true
  rm -f "${chain_file}.bak"

  log_info "  ${chain_count} pheromone snapshots extracted"
else
  echo '{"error": "no git repository"}' > "$chain_file"
  chain_count=0
fi

# ── 4. Immune Log (from BLACKBOARD, stripped of business content) ─────

log_info "Step 4/10: Extracting immune log"

immune_file="${OUT_DIR}/immune-log.txt"
> "$immune_file"

if [ -f "$BLACKBOARD" ]; then
  # Extract the immune log section: match any ## heading containing 免疫 or [Ii]mmune
  awk '/^## .*(免疫|[Ii]mmune)/,/^## [^#]/' "$BLACKBOARD" 2>/dev/null \
    | sed '$d' >> "$immune_file" || true

  if [ -s "$immune_file" ]; then
    immune_entries=$(grep -c '|' "$immune_file" 2>/dev/null) || immune_entries=0
    log_info "  ${immune_entries} immune log entries"
  else
    echo "(no immune log section found in BLACKBOARD.md)" > "$immune_file"
    log_info "  No immune log section found"
  fi

  # Also extract the health status section (protocol-relevant, not business)
  # Match any ## heading containing 健康 or [Hh]ealth
  health_file="${OUT_DIR}/blackboard-health.txt"
  awk '/^## .*(健康|[Hh]ealth)/,/^## [^#]/' "$BLACKBOARD" 2>/dev/null \
    | sed '$d' > "$health_file" || true
  [ ! -s "$health_file" ] && echo "(no health section found)" > "$health_file"
else
  echo "(no BLACKBOARD.md found)" > "$immune_file"
  log_warn "  No BLACKBOARD.md"
fi

# ── 5. Breath Snapshot ───────────────────────────────────────────────

log_info "Step 5/10: Copying breath snapshot"

if [ -f "$BREATH_FILE" ]; then
  cp "$BREATH_FILE" "${OUT_DIR}/breath-snapshot.yaml"
  log_info "  Copied current .field-breath"
else
  cat > "${OUT_DIR}/breath-snapshot.yaml" <<EOF
# No .field-breath found at export time
alarm: unknown
wip: unknown
build: unknown
signature_ratio: 0.00
active_signals: 0
high_weight_holes: 0
branch: unknown
EOF
  log_info "  No .field-breath found, created placeholder"
fi

# ── 6. Derived Metrics ──────────────────────────────────────────────

log_info "Step 6/10: Computing derived metrics"

# 6a. Caste distribution from git signatures
caste_file="${OUT_DIR}/caste-distribution.yaml"
cat > "$caste_file" <<EOF
# Caste distribution from git commit signatures
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
EOF

if [ -s "$sig_file" ] && [ "$signed_commits" -gt 0 ]; then
  # Parse [termite:DATE:CASTE] patterns and count castes
  echo "distribution:" >> "$caste_file"
  while read -r count caste; do
    echo "  ${caste}: ${count}" >> "$caste_file"
  done < <(grep -oE '\[termite:[0-9-]+:[a-z-]+\]' "$sig_file" 2>/dev/null \
    | sed 's/.*:\([a-z-]*\)\]/\1/' \
    | sort | uniq -c | sort -rn || true)

  # Time range
  first_sig=$(grep -oE '\[termite:[0-9-]+:' "$sig_file" 2>/dev/null | head -1 | sed 's/\[termite://;s/:$//' || true)
  last_sig=$(grep -oE '\[termite:[0-9-]+:' "$sig_file" 2>/dev/null | tail -1 | sed 's/\[termite://;s/:$//' || true)
  echo "first_signature: ${last_sig:-unknown}" >> "$caste_file"
  echo "last_signature: ${first_sig:-unknown}" >> "$caste_file"
else
  echo "distribution: {}" >> "$caste_file"
  echo "first_signature: none" >> "$caste_file"
  echo "last_signature: none" >> "$caste_file"
fi

log_info "  Caste distribution computed"

# 6b. Rule health summary (hit vs disputed)
rule_health_file="${OUT_DIR}/rule-health.yaml"
cat > "$rule_health_file" <<EOF
# Rule health: hit_count vs disputed_count
# disputed_ratio > 0.3 flags a rule for review
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
rules:
EOF

if [ -d "${OUT_DIR}/signals/rules" ]; then
  for rf in "${OUT_DIR}/signals/rules"/*.yaml; do
    [ -f "$rf" ] || continue
    rid=$(yaml_read "$rf" "id")
    hits=$(yaml_read "$rf" "hit_count")
    disputed=$(yaml_read "$rf" "disputed_count")
    trigger=$(yaml_read "$rf" "trigger")
    hits="${hits:-0}"
    disputed="${disputed:-0}"

    # Compute ratio (avoid division by zero)
    if [ "$hits" -gt 0 ]; then
      ratio=$(awk "BEGIN { printf \"%.2f\", ${disputed}/${hits} }")
    else
      ratio="0.00"
    fi

    # Flag if ratio > 0.3
    flag=""
    if [ "${hits:-0}" -gt 0 ]; then
      needs_review=$(awk "BEGIN { print (${disputed}/${hits} > 0.3) ? \"true\" : \"false\" }")
    else
      needs_review="false"
    fi
    if [ "$needs_review" = "true" ] && [ "$hits" -gt 0 ]; then
      flag="  # REVIEW NEEDED"
    fi

    cat >> "$rule_health_file" <<EOF
  - id: ${rid}
    trigger: "${trigger}"
    hit_count: ${hits}
    disputed_count: ${disputed}
    disputed_ratio: ${ratio}${flag}
EOF
  done
fi

log_info "  Rule health summary computed"

# 6c. Pheromone chain quality (predecessor_useful stats)
handoff_file="${OUT_DIR}/handoff-quality.yaml"
cat > "$handoff_file" <<EOF
# Cross-session handoff quality from pheromone chain
# predecessor_useful: true/false/null evaluation chain
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
EOF

if [ -s "$chain_file" ]; then
  total_handoffs=$(wc -l < "$chain_file" | tr -d ' ')
  useful_count=$(grep -c '"predecessor_useful"[[:space:]]*:[[:space:]]*true' "$chain_file" 2>/dev/null) || useful_count=0
  not_useful_count=$(grep -c '"predecessor_useful"[[:space:]]*:[[:space:]]*false' "$chain_file" 2>/dev/null) || not_useful_count=0
  not_evaluated=$((total_handoffs - useful_count - not_useful_count))

  cat >> "$handoff_file" <<EOF
total_handoffs: ${total_handoffs}
predecessor_useful_true: ${useful_count}
predecessor_useful_false: ${not_useful_count}
predecessor_useful_not_evaluated: ${not_evaluated}
EOF

  if [ "$((useful_count + not_useful_count))" -gt 0 ]; then
    useful_ratio=$(awk "BEGIN { printf \"%.2f\", ${useful_count}/(${useful_count}+${not_useful_count}) }")
    echo "useful_ratio: ${useful_ratio}" >> "$handoff_file"
  else
    echo "useful_ratio: null  # no evaluations yet" >> "$handoff_file"
  fi
else
  cat >> "$handoff_file" <<EOF
total_handoffs: 0
predecessor_useful_true: 0
predecessor_useful_false: 0
predecessor_useful_not_evaluated: 0
useful_ratio: null
EOF
fi

log_info "  Handoff quality stats computed"

# ── 7. Commander Input Signals ────────────────────────────────────────

log_info "Step 7/10: Extracting Commander input signals"

# Detect Commander presence
commander_status_file="${PROJECT_ROOT}/.commander-status.json"
commander_lock_file="${PROJECT_ROOT}/commander.lock"

if [ -f "$commander_status_file" ] || [ -f "$commander_lock_file" ]; then
  commander_detected=true
  mkdir -p "${OUT_DIR}/commander"
  log_info "  Commander detected"

  # 7a. Objective — extract from .commander-status.json
  if [ -f "$commander_status_file" ]; then
    objective=$(grep -o '"objective"[[:space:]]*:[[:space:]]*"[^"]*"' "$commander_status_file" 2>/dev/null \
      | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
    if [ -n "$objective" ]; then
      echo "$objective" > "${OUT_DIR}/commander/objective.txt"
      log_info "  objective.txt written (${#objective} chars)"
    fi

    # 7b. Task type
    task_type=$(grep -o '"taskType"[[:space:]]*:[[:space:]]*"[^"]*"' "$commander_status_file" 2>/dev/null \
      | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
    if [ -n "$task_type" ]; then
      echo "$task_type" > "${OUT_DIR}/commander/task-type.txt"
      log_info "  task-type.txt written: ${task_type}"
    fi
  fi

  # 7c. DIRECTIVE.md (truncated to 10KB)
  if [ -f "${PROJECT_ROOT}/DIRECTIVE.md" ]; then
    head -c 10240 "${PROJECT_ROOT}/DIRECTIVE.md" > "${OUT_DIR}/commander/directive.md"
    log_info "  directive.md copied (truncated to 10KB)"
  fi

  # 7d. PLAN.md (truncated to 20KB)
  if [ -f "${PROJECT_ROOT}/PLAN.md" ]; then
    head -c 20480 "${PROJECT_ROOT}/PLAN.md" > "${OUT_DIR}/commander/plan.md"
    log_info "  plan.md copied (truncated to 20KB)"
  fi
else
  log_info "  No Commander detected — skipping"
fi

# ── 8. Commander Fleet Signals ────────────────────────────────────────

log_info "Step 8/10: Extracting Commander fleet signals"

if [ "$commander_detected" = true ] && [ -f "$commander_status_file" ]; then
  fleet_file="${OUT_DIR}/commander/fleet.yaml"

  # Extract commander model
  commander_model=$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$commander_status_file" 2>/dev/null \
    | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)

  # Extract default worker CLI and model
  default_worker_cli=$(grep -o '"defaultWorkerCli"[[:space:]]*:[[:space:]]*"[^"]*"' "$commander_status_file" 2>/dev/null \
    | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
  default_worker_model=$(grep -o '"defaultWorkerModel"[[:space:]]*:[[:space:]]*"[^"]*"' "$commander_status_file" 2>/dev/null \
    | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)

  # Extract active/running worker counts
  active_workers=$(grep -o '"activeWorkers"[[:space:]]*:[[:space:]]*[0-9]*' "$commander_status_file" 2>/dev/null \
    | head -1 | sed 's/.*:[[:space:]]*//' || true)
  running_workers=$(grep -o '"runningWorkers"[[:space:]]*:[[:space:]]*[0-9]*' "$commander_status_file" 2>/dev/null \
    | head -1 | sed 's/.*:[[:space:]]*//' || true)
  worker_count="${active_workers:-0}"

  cat > "$fleet_file" <<EOF
# Commander Fleet Configuration
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
models:
  commander: "${commander_model:-unknown}"
  default_worker_cli: "${default_worker_cli:-unknown}"
  default_worker_model: "${default_worker_model:-unknown}"
heartbeat:
  active_workers: ${active_workers:-0}
  running_workers: ${running_workers:-0}
EOF

  # Extract individual worker entries
  # Workers are JSON objects in a "workers" array — extract each worker's fields
  if grep -q '"workers"' "$commander_status_file" 2>/dev/null; then
    echo "workers:" >> "$fleet_file"
    # Use awk to extract worker objects between [ and ] after "workers":
    # Each worker has id, cli, model, status fields
    awk '
      /"workers"[[:space:]]*:/ { in_workers=1; next }
      in_workers && /\]/ { in_workers=0; next }
      in_workers && /"id"/ {
        gsub(/.*"id"[[:space:]]*:[[:space:]]*"/, ""); gsub(/".*/, "");
        wid=$0
      }
      in_workers && /"cli"/ {
        gsub(/.*"cli"[[:space:]]*:[[:space:]]*"/, ""); gsub(/".*/, "");
        wcli=$0
      }
      in_workers && /"model"/ {
        gsub(/.*"model"[[:space:]]*:[[:space:]]*"/, ""); gsub(/".*/, "");
        wmodel=$0
      }
      in_workers && /"status"/ {
        gsub(/.*"status"[[:space:]]*:[[:space:]]*"/, ""); gsub(/".*/, "");
        wstatus=$0
        printf "  - id: \"%s\"\n    cli: \"%s\"\n    model: \"%s\"\n    status: \"%s\"\n", wid, wcli, wmodel, wstatus
        wid=""; wcli=""; wmodel=""; wstatus=""
      }
    ' "$commander_status_file" >> "$fleet_file" 2>/dev/null || true
  fi

  log_info "  fleet.yaml written (commander: ${commander_model:-unknown}, workers: ${worker_count})"
else
  log_info "  No Commander fleet data — skipping"
fi

# ── 9. Commander Lifecycle Signals ────────────────────────────────────

log_info "Step 9/10: Extracting Commander lifecycle signals"

if [ "$commander_detected" = true ]; then
  # 9a. Halt summary
  halt_file="${OUT_DIR}/commander/halt-summary.yaml"

  # Try DB first (halt_log table)
  halt_from_db=false
  if has_db; then
    halt_row=$(db_exec "SELECT reason, recommendation, halted_at, commander_cycles, colony_cycles FROM halt_log ORDER BY halted_at DESC LIMIT 1;" 2>/dev/null || true)
    if [ -n "$halt_row" ]; then
      halt_from_db=true
      halt_reason=$(echo "$halt_row" | cut -d'|' -f1)
      halt_recommendation=$(echo "$halt_row" | cut -d'|' -f2)
      halt_at=$(echo "$halt_row" | cut -d'|' -f3)
      commander_cycles=$(echo "$halt_row" | cut -d'|' -f4)
      colony_cycles=$(echo "$halt_row" | cut -d'|' -f5)

      cat > "$halt_file" <<EOF
# Commander Halt Summary (from DB)
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
halt_reason: "${halt_reason}"
halt_recommendation: "${halt_recommendation}"
halted_at: "${halt_at}"
commander_cycles: ${commander_cycles:-0}
colony_cycles: ${colony_cycles:-0}
source: "db"
EOF
      log_info "  halt-summary.yaml written from DB (reason: ${halt_reason})"
    fi
  fi

  # Fallback: read HALT.md
  if [ "$halt_from_db" = false ] && [ -f "${PROJECT_ROOT}/HALT.md" ]; then
    cat > "$halt_file" <<EOF
# Commander Halt Summary (from HALT.md)
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
source: "file"
EOF
    # Extract reason from HALT.md (typically first meaningful line)
    halt_reason=$(grep -m1 -E '(reason|Reason|REASON|halt|stopped|complete)' "${PROJECT_ROOT}/HALT.md" 2>/dev/null \
      | sed 's/^[#* -]*//' | head -c 200 || true)
    if [ -n "$halt_reason" ]; then
      echo "halt_reason: \"${halt_reason}\"" >> "$halt_file"
    fi
    echo "---" >> "$halt_file"
    # Append full HALT.md content (truncated to 5KB)
    head -c 5120 "${PROJECT_ROOT}/HALT.md" >> "$halt_file"
    log_info "  halt-summary.yaml written from HALT.md"
  elif [ "$halt_from_db" = false ]; then
    log_info "  No halt data found"
  fi

  # 9b. Events tail (last 100 lines)
  events_log="${PROJECT_ROOT}/.commander.events.log"
  if [ -f "$events_log" ]; then
    tail -100 "$events_log" > "${OUT_DIR}/commander/events-tail.txt"
    event_lines=$(wc -l < "${OUT_DIR}/commander/events-tail.txt" | tr -d ' ')
    log_info "  events-tail.txt written (${event_lines} lines)"
  fi

  # 9c. Run duration from commander.lock startedAt
  if [ -f "$commander_lock_file" ]; then
    started_at=$(grep -o '"startedAt"[[:space:]]*:[[:space:]]*"[^"]*"' "$commander_lock_file" 2>/dev/null \
      | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//' || true)
    if [ -n "$started_at" ]; then
      # Try to compute epoch difference
      start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${started_at%%.*}" "+%s" 2>/dev/null || \
                    date -d "${started_at}" "+%s" 2>/dev/null || echo "")
      if [ -n "$start_epoch" ]; then
        now_epoch=$(date "+%s")
        run_duration_seconds=$((now_epoch - start_epoch))
        [ "$run_duration_seconds" -lt 0 ] && run_duration_seconds=0
        log_info "  run_duration: ${run_duration_seconds}s"
      fi
    fi
  fi
else
  log_info "  No Commander lifecycle data — skipping"
fi

# ── 10. Metadata ──────────────────────────────────────────────────────

log_info "Step 10/10: Writing metadata"

# Detect protocol version from TERMITE_PROTOCOL.md
protocol_version="unknown"
if [ -f "${PROJECT_ROOT}/TERMITE_PROTOCOL.md" ]; then
  protocol_version=$(grep -m1 'termite-protocol:v' "${PROJECT_ROOT}/TERMITE_PROTOCOL.md" 2>/dev/null \
    | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown")
fi

# Detect kernel version from entry file
kernel_version="unknown"
for entry_file in "${PROJECT_ROOT}/CLAUDE.md" "${PROJECT_ROOT}/AGENTS.md"; do
  if [ -f "$entry_file" ]; then
    kv=$(grep -m1 'termite-kernel:v' "$entry_file" 2>/dev/null \
      | sed 's/.*termite-kernel:\(v[0-9.]*\).*/\1/' || true)
    if [ -n "$kv" ]; then
      kernel_version="$kv"
      break
    fi
  fi
done

# Compute protocol run duration (first signed commit to now)
run_days=0
if [ -n "${last_sig:-}" ] && [ "$last_sig" != "unknown" ] && [ "$last_sig" != "none" ]; then
  run_days=$(days_since "$last_sig")
fi

# Signature ratio
sig_ratio=$(termite_signature_ratio 50)

# v5.0: Compute quality statistics
obs_quality_mean="0.00"
trace_count=0
deposit_count=0
if has_db; then
  obs_quality_mean=$(db_exec "SELECT COALESCE(printf('%.2f', AVG(quality_score)), '0.00') FROM observations WHERE source_type='deposit';" 2>/dev/null || echo "0.00")
  trace_count=$(db_exec "SELECT COUNT(*) FROM observations WHERE source_type='trace';" 2>/dev/null || echo "0")
  deposit_count=$(db_exec "SELECT COUNT(*) FROM observations WHERE source_type='deposit';" 2>/dev/null || echo "0")
fi

cat > "${OUT_DIR}/metadata.yaml" <<EOF
# Audit Package Metadata
# This file describes the context of the export.
# Protocol Nurse: read this first to understand the project context.

project_name: "${PROJECT_NAME}"
export_date: "$(now_iso)"
protocol_version: "${protocol_version}"
kernel_version: "${kernel_version}"

# Duration & Volume
run_duration_days: ${run_days}
total_commits: ${total_commits}
signed_commits: ${signed_commits}
signature_ratio_last_50: ${sig_ratio}

# Signal Inventory
active_signals: ${active_count}
pending_observations: ${obs_count}
active_rules: ${rule_count}
archived_items: ${archive_count}
pheromone_snapshots: ${chain_count}

# Observation Quality (v5.0)
observation_quality_mean: ${obs_quality_mean}
trace_count: ${trace_count}
deposit_count: ${deposit_count}

# Current State
current_branch: "$(current_branch)"
current_alarm: $([ -f "$ALARM_FILE" ] && echo "true" || echo "false")
current_wip: "$(check_wip)"
current_build: "$(check_build)"
EOF

# Append Commander context if detected
if [ "$commander_detected" = true ]; then
  cat >> "${OUT_DIR}/metadata.yaml" <<EOF

# Commander Context
commander_detected: true
commander_model: "${commander_model}"
worker_count: ${worker_count}
task_type: "${task_type}"
objective_length: ${#objective}
halt_reason: "${halt_reason}"
commander_cycles: ${commander_cycles}
run_duration_seconds: ${run_duration_seconds}
EOF
else
  cat >> "${OUT_DIR}/metadata.yaml" <<EOF

# Commander Context
commander_detected: false
EOF
fi

log_info "  Metadata written"

# ── Package Summary ──────────────────────────────────────────────────

# Write a README for the package
cat > "${OUT_DIR}/README.md" <<'READMEEOF'
# Audit Package

This directory contains protocol-level artifacts exported from a project
running the Termite Protocol. It contains **no project source code**.

A Protocol Nurse agent can read this package + the protocol definition
to evaluate protocol health and produce optimization recommendations.

## Contents

| File | What it tells you |
|------|-------------------|
| `metadata.yaml` | Project context, duration, volume (read first) |
| `signals/` | Complete signal tree: rules, observations, active, archive |
| `rule-health.yaml` | Per-rule hit vs disputed ratio (flags problematic rules) |
| `handoff-quality.yaml` | predecessor_useful stats (cross-session handoff effectiveness) |
| `caste-distribution.yaml` | Which castes appeared and how often |
| `git-signatures.txt` | Commit timeline with termite signatures (no code) |
| `pheromone-chain.jsonl` | .pheromone history (one JSON per line, chronological) |
| `immune-log.txt` | Immune system findings from BLACKBOARD |
| `blackboard-health.txt` | Colony health status table |
| `breath-snapshot.yaml` | Latest .field-breath health snapshot |
| `commander/` | Commander context: objective, fleet, halt, events (if Commander detected) |

## How to Use

```
# Copy this directory to the protocol repo:
cp -R audit-package-YYYY-MM-DD /path/to/termite-protocol/audit-packages/project-name/

# Or analyze in place:
# A Protocol Nurse agent reads metadata.yaml first, then rule-health.yaml
# and handoff-quality.yaml for quick protocol health assessment.
```
READMEEOF

# ── Optional: tar.gz ─────────────────────────────────────────────────

if [ "$CREATE_TAR" = true ]; then
  tar_name="$(basename "$OUT_DIR").tar.gz"
  tar_path="$(dirname "$OUT_DIR")/${tar_name}"
  tar -czf "$tar_path" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")"
  log_info "Archive created: ${tar_path}"
fi

# ── Done ─────────────────────────────────────────────────────────────

log_info "=== Audit package exported to: ${OUT_DIR} ==="
log_info "Contents:"
log_info "  metadata.yaml            — project context (read first)"
log_info "  signals/                 — ${rule_count} rules, ${obs_count} observations, ${active_count} active, ${archive_count} archived"
log_info "  rule-health.yaml         — hit vs disputed per rule"
log_info "  handoff-quality.yaml     — predecessor_useful chain stats"
log_info "  caste-distribution.yaml  — agent caste breakdown"
log_info "  git-signatures.txt       — ${signed_commits}/${total_commits} signed commits"
log_info "  pheromone-chain.jsonl    — ${chain_count} handoff snapshots"
log_info "  immune-log.txt           — immune system findings"
log_info "  breath-snapshot.yaml     — current health"
if [ "$commander_detected" = true ]; then
  log_info "  commander/               — model: ${commander_model:-unknown}, workers: ${worker_count}, type: ${task_type:-unknown}, halt: ${halt_reason:-unknown}"
fi
echo ""
echo "${OUT_DIR}"
