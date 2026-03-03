#!/usr/bin/env bash
# field-cycle.sh — Post-commit metabolism cycle
# Sequence: decay → drain → boundary detection → signal aggregation → pulse → observation promotion → compression → rule archival
# Typically triggered by post-commit hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

log_info "=== Metabolism cycle starting ==="

# ── Step 1/8: Decay ────────────────────────────────────────────────────

log_info "Step 1/8: Decay"
if has_db; then
  source "${SCRIPT_DIR}/termite-db.sh"
  concentration=$(signal_concentration)
  case "$concentration" in
    concentrated) adj_factor=$(awk "BEGIN { f=${DECAY_FACTOR}-0.02; if(f<0.90) f=0.90; printf \"%.4f\",f }") ;;
    dispersed)    adj_factor=$(awk "BEGIN { f=${DECAY_FACTOR}+0.01; if(f>0.995) f=0.995; printf \"%.4f\",f }") ;;
    *)            adj_factor="$DECAY_FACTOR" ;;
  esac
  log_info "Decay: concentration=${concentration} factor=${adj_factor}"
  db_decay_all "$adj_factor"
  log_info "Decay complete (DB atomic)"
else
  "${SCRIPT_DIR}/field-decay.sh" || log_warn "Decay had warnings"
fi

# ── Step 2/8: Drain ────────────────────────────────────────────────────

log_info "Step 2/8: Drain"
if has_db; then
  db_drain_done
  log_info "Drain complete (DB atomic)"
else
  "${SCRIPT_DIR}/field-drain.sh" || log_warn "Drain had warnings"
fi

# ── Step 3/8: Boundary detection ───────────────────────────────────────

log_info "Step 3/8: Boundary detection"
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

# ── Step 4/8: Signal aggregation (v5.1) ──────────────────────────────

log_info "Step 4/8: Signal aggregation"
if has_db; then
  agg_count=$(db_signal_aggregate 2>/dev/null || echo "0")
  [ "${agg_count:-0}" -gt 0 ] && log_info "Aggregated ${agg_count} parent signals"
fi

# ── Step 5/8: Pulse ────────────────────────────────────────────────────

log_info "Step 5/8: Pulse"
"${SCRIPT_DIR}/field-pulse.sh" || log_warn "Pulse had warnings"

# ── Step 6/8: Observation → Rule Promotion ─────────────────────────────

log_info "Step 6/8: Observation promotion scan"

# Rule quality gate (W-012a): reject degenerate rules before creation
validate_rule_quality() {
  # Args: trigger_text action_text
  # Returns: 0 if valid, 1 if degenerate
  local trigger="$1" action="$2"

  # Reject trigger that is only "heartbeat", signal IDs, or pure stop words
  if echo "$trigger" | grep -qiE '^(when i observe:?\s*)?(heartbeat|[SO]-[0-9]+|signal|the|a|an)$'; then
    log_warn "Rule quality gate: trigger is degenerate ('${trigger}')"
    return 1
  fi

  # Reject trigger that is only a signal ID pattern
  if echo "$trigger" | grep -qE '^When I observe:\s*[SO]-[0-9]+$'; then
    log_warn "Rule quality gate: trigger references only a signal ID"
    return 1
  fi

  # Reject tautological action
  if echo "$action" | grep -qiE '^follow the pattern'; then
    log_warn "Rule quality gate: action is tautological ('${action}')"
    return 1
  fi

  # Reject action shorter than 20 chars
  if [ "${#action}" -lt 20 ]; then
    log_warn "Rule quality gate: action too short (${#action} chars < 20)"
    return 1
  fi

  return 0
}

if has_db; then
  # DB path: fuzzy keyword clustering for observation → rule promotion
  # v5.0: quality-weighted emergence — sum(quality_score) >= 3.0 replaces count >= 3
  # 1. Query all unmerged, deposit-type, non-low-quality observations with quality_score
  obs_rows=$(db_query "SELECT id, pattern, COALESCE(quality_score, 0.5) FROM observations
    WHERE merged_count = 0
      AND COALESCE(source_type, 'deposit') = 'deposit'
      AND (quality IS NULL OR quality != 'low');" 2>/dev/null || true)

  if [ -n "$obs_rows" ]; then
    # 2. Normalize each pattern to keywords and group with quality scores
    keyword_map=$(mktemp)
    keyword_scores=$(mktemp)
    while IFS=$'\t' read -r obs_id obs_pattern obs_qs; do
      [ -z "$obs_id" ] && continue
      keywords=$(normalize_pattern_keywords "$obs_pattern")
      [ -z "$keywords" ] && continue
      echo "${keywords}|${obs_id}" >> "$keyword_map"
      echo "${keywords}|${obs_qs:-0.5}" >> "$keyword_scores"
    done <<< "$obs_rows"

    # 3. Find keyword groups where sum(quality_score) >= 3.0
    if [ -s "$keyword_map" ]; then
      promoted=0
      # Get unique keywords
      cut -d'|' -f1 "$keyword_map" | sort -u | while read -r keywords; do
        [ -z "$keywords" ] && continue

        # Sum quality scores for this keyword group
        quality_sum=$(grep "^${keywords}|" "$keyword_scores" | cut -d'|' -f2 \
          | awk '{ s += $1 } END { printf "%.2f", s }')
        obs_count_group=$(grep -c "^${keywords}|" "$keyword_map" || true)

        # v5.0: quality-weighted threshold
        meets_threshold=$(awk "BEGIN { print (${quality_sum} >= 3.0) ? 1 : 0 }")
        if [ "$meets_threshold" -eq 1 ]; then
          # Collect observation IDs for this keyword group
          group_ids=""
          while IFS='|' read -r kw oid; do
            if [ "$kw" = "$keywords" ]; then
              group_ids="${group_ids:+${group_ids},}${oid}"
            fi
          done < "$keyword_map"
          [ -z "$group_ids" ] && continue

          log_info "Promoting fuzzy pattern (${obs_count_group} observations, quality_sum=${quality_sum}, keywords: ${keywords})"

          # Get detail from first observation
          first_id=$(echo "$group_ids" | cut -d',' -f1)
          detail=$(db_exec "SELECT detail FROM observations WHERE id='$(db_escape "$first_id")';")
          first_pattern=$(db_exec "SELECT pattern FROM observations WHERE id='$(db_escape "$first_id")';")

          # Rule quality gate (W-012a): validate before creation
          candidate_trigger="When I observe: ${first_pattern:-${keywords}}"
          candidate_action="${detail:-Follow the pattern described in trigger}"
          if ! validate_rule_quality "$candidate_trigger" "$candidate_action"; then
            log_info "Rule rejected by quality gate — archiving source observations anyway"
            # Still archive to prevent re-promotion of degenerate clusters
            db_transaction "
              INSERT INTO archive(original_id,original_table,data,archived_at,archive_reason)
                SELECT id,'observations',
                  json_object('id',id,'pattern',pattern,'context',context,'reporter',reporter),
                  datetime('now'),'promoted'
                FROM observations WHERE id IN ($(echo "$group_ids" | sed "s/[^,]*/'&'/g"));
              DELETE FROM observations WHERE id IN ($(echo "$group_ids" | sed "s/[^,]*/'&'/g"));
            "
            continue
          fi

          # Create rule
          rule_id=$(db_next_rule_id)
          db_rule_create "$rule_id" "$candidate_trigger" "$candidate_action" "[${group_ids}]"
          log_info "Created rule ${rule_id} from observations: [${group_ids}]"

          # Archive source observations
          db_transaction "
            INSERT INTO archive(original_id,original_table,data,archived_at,archive_reason)
              SELECT id,'observations',
                json_object('id',id,'pattern',pattern,'context',context,'reporter',reporter),
                datetime('now'),'promoted'
              FROM observations WHERE id IN ($(echo "$group_ids" | sed "s/[^,]*/'&'/g"));
            DELETE FROM observations WHERE id IN ($(echo "$group_ids" | sed "s/[^,]*/'&'/g"));
          "
          promoted=$((promoted + 1))
        fi
      done
    fi
    rm -f "$keyword_map" "$keyword_scores"
  fi
elif [ -d "$OBS_DIR" ]; then
  # YAML path: fuzzy keyword clustering with quality-weighted emergence (v5.0)
  tmpfile=$(mktemp)
  score_file=$(mktemp)
  while IFS= read -r obs_file; do
    [ -f "$obs_file" ] || continue
    quality=$(yaml_read "$obs_file" "quality")
    [ "$quality" = "low" ] && continue
    src_type=$(yaml_read "$obs_file" "source_type")
    [ "${src_type:-deposit}" != "deposit" ] && continue
    pattern=$(yaml_read "$obs_file" "pattern")
    [ -z "$pattern" ] && continue
    keywords=$(normalize_pattern_keywords "$pattern")
    [ -z "$keywords" ] && continue
    qs=$(yaml_read "$obs_file" "quality_score")
    qs="${qs:-0.5}"
    echo "${keywords}|${obs_file}" >> "$tmpfile"
    echo "${keywords}|${qs}" >> "$score_file"
  done < <(list_observations)

  # Find keyword groups where sum(quality_score) >= 3.0
  if [ -s "$tmpfile" ]; then
    promoted=0
    cut -d'|' -f1 "$tmpfile" | sort -u | while read -r keywords; do
      [ -z "$keywords" ] && continue

      # Sum quality scores for this keyword group
      quality_sum=$(grep "^${keywords}|" "$score_file" | cut -d'|' -f2 \
        | awk '{ s += $1 } END { printf "%.2f", s }')
      obs_count_group=$(grep -c "^${keywords}|" "$tmpfile" || true)

      meets_threshold=$(awk "BEGIN { print (${quality_sum} >= 3.0) ? 1 : 0 }")
      if [ "$meets_threshold" -eq 1 ]; then
        log_info "Promoting fuzzy pattern (${obs_count_group} observations, quality_sum=${quality_sum}, keywords: ${keywords})"

        # Collect source observation IDs and files
        obs_ids=""
        obs_files=""
        while IFS='|' read -r kw f; do
          if [ "$kw" = "$keywords" ]; then
            oid=$(yaml_read "$f" "id")
            obs_ids="${obs_ids:+${obs_ids}, }${oid}"
            obs_files="${obs_files:+${obs_files} }${f}"
          fi
        done < "$tmpfile"

        # Get details from first observation for trigger/action
        first_file=$(echo "$obs_files" | awk '{print $1}')
        detail=$(yaml_read "$first_file" "detail")
        first_pattern=$(yaml_read "$first_file" "pattern")

        # Rule quality gate (W-012a)
        yaml_trigger="When I observe: ${first_pattern:-${keywords}}"
        yaml_action="${detail:-Follow the pattern described in trigger}"
        if ! validate_rule_quality "$yaml_trigger" "$yaml_action"; then
          log_info "Rule rejected by quality gate — archiving source observations anyway"
          mkdir -p "${ARCHIVE_DIR}/promoted"
          for f in $obs_files; do
            [ -f "$f" ] && mv "$f" "${ARCHIVE_DIR}/promoted/"
          done
          continue
        fi

        # Generate rule
        ensure_signal_dirs
        rule_id=$(next_signal_id R)
        rule_file="${RULES_DIR}/${rule_id}.yaml"

        cat > "$rule_file" <<RULEEOF
id: ${rule_id}
trigger: "When I observe: ${first_pattern:-${keywords}}"
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
  rm -f "$tmpfile" "$score_file"
fi

# ── Step 7/8: Observation compression ──────────────────────────────────

log_info "Step 7/8: Observation compression"
if has_db; then
  db_obs_compress
  log_info "Compression complete (DB)"
else
  "${SCRIPT_DIR}/field-deposit.sh" --compress 2>&1 | while IFS= read -r line; do
    log_info "  compress: $line"
  done || true
fi

# ── Step 8/8: Rule Archival ────────────────────────────────────────────

log_info "Step 8/8: Rule archival scan"

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

# ── Auto-export: Keep YAML audit snapshots in sync with DB ──────────

if has_db; then
  "${SCRIPT_DIR}/termite-db-export.sh" 2>/dev/null || log_warn "Auto-export had warnings"
  log_info "YAML snapshots refreshed from DB"
fi

# ── Cross-colony feedback: submit audit if enabled ──────────────────

if [ -x "${SCRIPT_DIR}/field-submit-audit.sh" ]; then
  "${SCRIPT_DIR}/field-submit-audit.sh" 2>/dev/null || true
fi

log_info "=== Metabolism cycle complete ==="
