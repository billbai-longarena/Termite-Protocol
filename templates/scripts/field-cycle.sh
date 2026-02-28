#!/usr/bin/env bash
# field-cycle.sh — Post-commit metabolism cycle
# Sequence: decay → drain → boundary detection → pulse → observation promotion → compression → rule archival
# Typically triggered by post-commit hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

log_info "=== Metabolism cycle starting ==="

# ── Step 1/7: Decay ────────────────────────────────────────────────────

log_info "Step 1/7: Decay"
if has_db; then
  source "${SCRIPT_DIR}/termite-db.sh"
  db_decay_all
  log_info "Decay complete (DB atomic)"
else
  "${SCRIPT_DIR}/field-decay.sh" || log_warn "Decay had warnings"
fi

# ── Step 2/7: Drain ────────────────────────────────────────────────────

log_info "Step 2/7: Drain"
if has_db; then
  db_drain_done
  log_info "Drain complete (DB atomic)"
else
  "${SCRIPT_DIR}/field-drain.sh" || log_warn "Drain had warnings"
fi

# ── Step 3/7: Boundary detection ───────────────────────────────────────

log_info "Step 3/7: Boundary detection"
if has_db; then
  # Single SQL: park signals where touch_count >= threshold
  parked_count=$(db_exec "
    SELECT COUNT(*) FROM signals
    WHERE touch_count >= ${BOUNDARY_TOUCH_THRESHOLD}
      AND type IN ('BLOCKED','HOLE')
      AND status NOT IN ('parked','done','archived');
  ")
  if [ "${parked_count:-0}" -gt 0 ]; then
    db_exec "
      UPDATE signals SET
        status='parked',
        parked_reason='environment_boundary',
        parked_conditions='Touched ' || touch_count || 'x without resolution',
        parked_at='$(today_iso)',
        weight=CASE WHEN weight > ($ESCALATE_THRESHOLD-10) THEN ($ESCALATE_THRESHOLD-10) ELSE weight END
      WHERE touch_count >= $BOUNDARY_TOUCH_THRESHOLD
        AND type IN ('BLOCKED','HOLE')
        AND status NOT IN ('parked','done','archived');
    "
    log_info "Parked ${parked_count} signals (DB)"
  fi
elif has_signal_dir; then
  parked_count=0
  while IFS= read -r signal_file; do
    [ -f "$signal_file" ] || continue
    local_status=$(yaml_read "$signal_file" "status")
    local_type=$(yaml_read "$signal_file" "type")
    local_tc=$(get_signal_touch_count "$signal_file")
    if [ "$local_status" != "parked" ] && [ "$local_status" != "done" ] && [ "$local_status" != "archived" ]; then
      if [ "$local_tc" -ge "$BOUNDARY_TOUCH_THRESHOLD" ]; then
        if [ "$local_type" = "BLOCKED" ] || [ "$local_type" = "HOLE" ]; then
          log_info "Parking $(basename "$signal_file") — touched ${local_tc}x without resolution"
          park_signal "$signal_file" "environment_boundary" \
            "Touched ${local_tc}x without status change. Likely requires external resource."
          parked_count=$((parked_count + 1))
        fi
      fi
    fi
  done < <(list_active_signals)
  [ "$parked_count" -gt 0 ] && log_info "Parked ${parked_count} signals"
fi

# ── Step 4/7: Pulse ────────────────────────────────────────────────────

log_info "Step 4/7: Pulse"
"${SCRIPT_DIR}/field-pulse.sh" || log_warn "Pulse had warnings"

# ── Step 5/7: Observation → Rule Promotion ─────────────────────────────

log_info "Step 5/7: Observation promotion scan"

if has_db; then
  # DB path: find patterns with >= PROMOTION_THRESHOLD observations
  groups=$(db_query "SELECT LOWER(TRIM(pattern)) as p, COUNT(*) as cnt, GROUP_CONCAT(id) as ids
    FROM observations WHERE merged_count = 0
    GROUP BY LOWER(TRIM(pattern))
    HAVING cnt >= ${PROMOTION_THRESHOLD};" 2>/dev/null || true)

  if [ -n "$groups" ]; then
    promoted=0
    echo "$groups" | while IFS=$'\t' read -r pattern cnt ids; do
      [ -z "$pattern" ] && continue
      log_info "Promoting pattern (${cnt} observations): ${pattern}"

      # Get detail from first observation
      first_id=$(echo "$ids" | cut -d',' -f1)
      detail=$(db_exec "SELECT detail FROM observations WHERE id='$(db_escape "$first_id")';")

      # Create rule
      rule_id=$(db_next_rule_id)
      db_rule_create "$rule_id" "When I observe: ${pattern}" "${detail:-Follow the pattern described in trigger}" "[${ids}]"
      log_info "Created rule ${rule_id} from observations: [${ids}]"

      # Archive source observations
      db_transaction "
        INSERT INTO archive(original_id,original_table,data,archived_at,archive_reason)
          SELECT id,'observations',
            json_object('id',id,'pattern',pattern,'context',context,'reporter',reporter),
            datetime('now'),'promoted'
          FROM observations WHERE id IN ($(echo "$ids" | sed "s/[^,]*/'&'/g"));
        DELETE FROM observations WHERE id IN ($(echo "$ids" | sed "s/[^,]*/'&'/g"));
      "
      promoted=$((promoted + 1))
    done
  fi
elif [ -d "$OBS_DIR" ]; then
  # Group observations by pattern (normalized: lowercase, stripped)
  declare -A pattern_groups 2>/dev/null || true

  # Collect patterns and their files
  tmpfile=$(mktemp)
  while IFS= read -r obs_file; do
    [ -f "$obs_file" ] || continue
    pattern=$(yaml_read "$obs_file" "pattern" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//')
    [ -z "$pattern" ] && continue
    echo "${pattern}|${obs_file}" >> "$tmpfile"
  done < <(list_observations)

  # Find patterns with >= PROMOTION_THRESHOLD observations
  if [ -s "$tmpfile" ]; then
    promoted=0
    cut -d'|' -f1 "$tmpfile" | sort | uniq -c | sort -rn | while read -r count pattern; do
      count=$(echo "$count" | tr -d ' ')
      if [ "$count" -ge "$PROMOTION_THRESHOLD" ]; then
        log_info "Promoting pattern (${count} observations): ${pattern}"

        # Collect source observation IDs and files
        obs_ids=""
        obs_files=""
        while IFS='|' read -r p f; do
          normalized=$(echo "$p" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//')
          if [ "$normalized" = "$pattern" ]; then
            oid=$(yaml_read "$f" "id")
            obs_ids="${obs_ids:+${obs_ids}, }${oid}"
            obs_files="${obs_files:+${obs_files} }${f}"
          fi
        done < "$tmpfile"

        # Get details from first observation for trigger/action
        first_file=$(echo "$obs_files" | awk '{print $1}')
        detail=$(yaml_read "$first_file" "detail")

        # Generate rule
        ensure_signal_dirs
        rule_id=$(next_signal_id R)
        rule_file="${RULES_DIR}/${rule_id}.yaml"

        cat > "$rule_file" <<RULEEOF
id: ${rule_id}
trigger: "When I observe: ${pattern}"
action: "${detail:-Follow the pattern described in trigger}"
source_observations: [${obs_ids}]
hit_count: 0
disputed_count: 0
last_triggered: $(today_iso)
created: $(today_iso)
tags: []
RULEEOF

        log_info "Created rule ${rule_id} from observations: [${obs_ids}]"

        # Move source observations to archive/promoted/
        mkdir -p "${ARCHIVE_DIR}/promoted"
        for f in $obs_files; do
          [ -f "$f" ] && mv "$f" "${ARCHIVE_DIR}/promoted/"
        done

        promoted=$((promoted + 1))
      fi
    done
  fi
  rm -f "$tmpfile"
fi

# ── Step 6/7: Observation compression ──────────────────────────────────

log_info "Step 6/7: Observation compression"
if has_db; then
  db_obs_compress
  log_info "Compression complete (DB)"
else
  "${SCRIPT_DIR}/field-deposit.sh" --compress 2>&1 | while IFS= read -r line; do
    log_info "  compress: $line"
  done || true
fi

# ── Step 7/7: Rule Archival ────────────────────────────────────────────

log_info "Step 7/7: Rule archival scan"

if has_db; then
  db_archive_rules_stale
  log_info "Rule archival complete (DB)"
elif [ -d "$RULES_DIR" ]; then
  archived_rules=0
  while IFS= read -r rule_file; do
    [ -f "$rule_file" ] || continue
    last_triggered=$(yaml_read "$rule_file" "last_triggered")
    [ -z "$last_triggered" ] && continue

    age=$(days_since "$last_triggered")
    if [ "$age" -gt "$RULE_ARCHIVE_DAYS" ]; then
      mkdir -p "${ARCHIVE_DIR}/rules"
      log_info "Archiving stale rule $(basename "$rule_file") (last triggered ${age} days ago)"
      mv "$rule_file" "${ARCHIVE_DIR}/rules/"
      archived_rules=$((archived_rules + 1))
    fi
  done < <(list_rules)
  [ "$archived_rules" -gt 0 ] && log_info "Archived ${archived_rules} stale rules"
fi

# ── Final: Refresh breath ────────────────────────────────────────────

# Re-run pulse to capture post-cycle state
"${SCRIPT_DIR}/field-pulse.sh" 2>/dev/null || true

log_info "=== Metabolism cycle complete ==="
