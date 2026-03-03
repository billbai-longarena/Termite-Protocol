#!/usr/bin/env bash
# field-arrive.sh — Core arrival script: generates .birth
# This is the most critical file in the Termite Protocol v3.0.
# It replaces the need for agents to read TERMITE_PROTOCOL.md directly.
#
# Logic:
# 1. Source field-lib.sh
# 2. If .field-breath is stale (>30min) → run field-cycle.sh
# 3. Read .field-breath for current health
# 4. Determine caste (waterfall, first match wins)
# 5. Select top rules by relevance
# 6. Build situation summary
# 7. Write .birth (≤800 tokens)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

log_info "=== Arrival sequence starting ==="

# ── Step 1: Ensure signals infrastructure ────────────────────────────

if has_signal_dir; then
  log_info "Signal directory detected"
else
  log_info "No signal directory — will use BLACKBOARD fallback"
fi

# ── Step 1.5: Database initialization ────────────────────────────────

ensure_db || true
if has_db; then
  source "${SCRIPT_DIR}/termite-db.sh"
  AGENT_ID=$(db_agent_register)
  log_info "Agent registered: ${AGENT_ID}"
fi

# ── Step 2: Refresh breath if stale ──────────────────────────────────

if ! check_breath_freshness; then
  log_info "Breath stale or missing — running metabolism cycle"
  "${SCRIPT_DIR}/field-cycle.sh" 2>&1 | while IFS= read -r line; do
    log_info "  cycle: $line"
  done || true
fi

# ── Step 3: Read health state ────────────────────────────────────────

alarm="false"
wip="absent"
build="unknown"
sig_ratio="0.00"
active_signals=0
high_holes=0
branch="unknown"

colony_phase="active"

if has_db; then
  alarm=$(db_colony_get "alarm" 2>/dev/null || echo "false")
  wip=$(db_colony_get "wip" 2>/dev/null || echo "absent")
  build=$(db_colony_get "build" 2>/dev/null || echo "unknown")
  sig_ratio=$(db_colony_get "signature_ratio" 2>/dev/null || echo "0.00")
  active_signals=$(db_signal_count "status NOT IN ('archived','parked','done','completed')" 2>/dev/null || echo "0")
  high_holes=$(db_signal_count "type='HOLE' AND weight>=${ESCALATE_THRESHOLD} AND status!='parked'" 2>/dev/null || echo "0")
  parked_signals=$(db_signal_count "status='parked'" 2>/dev/null || echo "0")
  branch=$(db_colony_get "branch" 2>/dev/null || current_branch)
  colony_phase=$(db_colony_get "colony_phase" 2>/dev/null || echo "active")
  # Fill missing colony state via direct sensing
  [ "$alarm" = "false" ] && check_alarm && alarm="true"
  [ "$wip" = "absent" ] || [ -z "$wip" ] && wip=$(check_wip)
  [ "$build" = "unknown" ] || [ -z "$build" ] && build=$(check_build)
  [ "$branch" = "unknown" ] || [ -z "$branch" ] && branch=$(current_branch)
  [ -z "$colony_phase" ] && colony_phase="active"
elif [ -f "$BREATH_FILE" ]; then
  alarm=$(yaml_read "$BREATH_FILE" "alarm")
  wip=$(yaml_read "$BREATH_FILE" "wip")
  build=$(yaml_read "$BREATH_FILE" "build")
  sig_ratio=$(yaml_read "$BREATH_FILE" "signature_ratio")
  active_signals=$(yaml_read "$BREATH_FILE" "active_signals")
  high_holes=$(yaml_read "$BREATH_FILE" "high_weight_holes")
  parked_signals=$(yaml_read "$BREATH_FILE" "parked_signals")
  branch=$(yaml_read "$BREATH_FILE" "branch")
  colony_phase=$(yaml_read "$BREATH_FILE" "colony_phase")
  [ -z "$colony_phase" ] && colony_phase="active"
else
  # Direct sensing fallback
  alarm="false"; check_alarm && alarm="true"
  wip=$(check_wip)
  build=$(check_build)
  branch=$(current_branch)
fi

# ── Step 3.5: Genesis detection ────────────────────────────────────────

genesis=false
active_count_check=0
if has_db; then
  active_count_check=$(db_signal_count "status NOT IN ('archived','done','completed')" 2>/dev/null || echo "0")
else
  active_count_check=$(count_active_signals 2>/dev/null || echo "0")
fi
if [ ! -f "$BLACKBOARD" ] && [ "$active_count_check" -eq 0 ] && [ "$wip" = "absent" ]; then
  genesis=true
  log_info "Genesis conditions — running field-genesis.sh"
  if [ -x "${SCRIPT_DIR}/field-genesis.sh" ]; then
    "${SCRIPT_DIR}/field-genesis.sh" 2>&1 | while IFS= read -r line; do log_info "  genesis: $line"; done || true
    "${SCRIPT_DIR}/field-pulse.sh" 2>/dev/null || true
    # Re-read health
    [ -f "$BREATH_FILE" ] && active_signals=$(yaml_read "$BREATH_FILE" "active_signals")
  fi
fi

# ── Step 3.7: Protocol version detection ─────────────────────────────

if telemetry_enabled; then
  local_ver=$(local_protocol_version)
  upstream_ver=$(upstream_protocol_version)
  if [ "$upstream_ver" != "unknown" ] && [ "$local_ver" != "unknown" ] && [ "$upstream_ver" != "$local_ver" ]; then
    log_info "Protocol update available: ${local_ver} → ${upstream_ver}"
    update_signal_exists=false
    if has_db; then
      escaped_ver=$(db_escape "$upstream_ver")
      existing=$(db_signal_count "module='termite-protocol' AND title LIKE '%${escaped_ver}%' AND status NOT IN ('archived','done')" 2>/dev/null || echo "0")
      [ "${existing:-0}" -gt 0 ] && update_signal_exists=true
    fi
    if ! $update_signal_exists; then
      if has_db; then
        update_id=$(db_next_signal_id "S")
        db_signal_create "$update_id" "HOLE" \
          "Protocol update available: ${local_ver} → ${upstream_ver}" \
          "open" "35" "14" "$(today_iso)" "$(today_iso)" "unassigned" \
          "termite-protocol" "[]" \
          "Scout: read UPGRADE_NOTES.md for changes and action items, then decide whether to run install.sh --upgrade" \
          "0" "autonomous"
        log_info "Created signal ${update_id} for protocol update"
      else
        ensure_signal_dirs
        update_id=$(next_signal_id S)
        cat > "${ACTIVE_DIR}/${update_id}.yaml" <<SIGEOF
id: ${update_id}
type: HOLE
title: "Protocol update available: ${local_ver} → ${upstream_ver}"
status: open
weight: 35
ttl_days: 14
created: $(today_iso)
last_touched: $(today_iso)
owner: unassigned
module: "termite-protocol"
tags: []
next: "Scout: read UPGRADE_NOTES.md for changes and action items, then decide whether to run install.sh --upgrade"
touch_count: 0
source: autonomous
SIGEOF
        log_info "Created signal ${update_id} for protocol update"
      fi
    fi
  fi
fi

# ── Step 3.8: Read upgrade report if present ──────────────────────────

upgrade_context=""
UPGRADE_REPORT="${PROJECT_ROOT}/.termite-upgrade-report"
if [ -f "$UPGRADE_REPORT" ]; then
  from_ver=$(yaml_read "$UPGRADE_REPORT" "from_version" 2>/dev/null || echo "unknown")
  to_ver=$(yaml_read "$UPGRADE_REPORT" "to_version" 2>/dev/null || echo "unknown")
  upgrade_context="Protocol recently upgraded: ${from_ver} → ${to_ver}. Read UPGRADE_NOTES.md for changes and action items."
  log_info "Upgrade report detected: ${from_ver} → ${to_ver}"
fi

# ── Step 3.9: Platform & trigger detection ─────────────────────────────

# Capability detection
cap_platform=$(detect_platform)
cap_git="no"; command -v git >/dev/null 2>&1 && [ -d "${PROJECT_ROOT}/.git" ] && cap_git="yes"
cap_push="unknown"
if [ "$cap_git" = "yes" ]; then
  git -C "$PROJECT_ROOT" remote -v 2>/dev/null | grep -q . && cap_push="available" || cap_push="no-remote"
fi
case "$cap_platform" in
  claude-code) cap_sandbox="full" ;;
  codex-cli)   cap_sandbox="restricted" ;;
  opencode)    cap_sandbox="restricted" ;;
  *)           cap_sandbox="unknown" ;;
esac

# Trigger type detection
trigger_type="${TERMITE_TRIGGER_TYPE:-}"
if [ -z "$trigger_type" ]; then
  if [ "${TERMITE_AUTO:-}" = "1" ]; then
    trigger_type="heartbeat"
  else
    case "$cap_platform" in
      codex-cli|opencode) trigger_type="heartbeat" ;;
      claude-code) trigger_type="directive" ;;
      *) trigger_type="heartbeat" ;;
    esac
  fi
fi

# v5.0: strength_tier still computed for backward compat (DB records) but no longer drives .birth
strength_tier=$(compute_strength_tier "$cap_platform" "${AGENT_ID:-}")
log_info "Platform: ${cap_platform} trigger=${trigger_type} strength=${strength_tier}(deprecated)"

# Update agent record with strength metadata
if has_db && [ -n "$AGENT_ID" ]; then
  db_agent_set_strength "$AGENT_ID" "$cap_platform" "$strength_tier" "$trigger_type"
fi

# ── Step 4: Caste determination (waterfall, first hit wins) ──────────

caste="scout"
breath_needed=false

if [ "$alarm" = "true" ]; then
  caste="soldier"; caste_reason="ALARM.md present"
elif [ "$build" = "fail" ]; then
  caste="soldier"; caste_reason="build/test failure"
elif [ "$wip" = "fresh" ]; then
  # Breath cycle check: N consecutive same-caste sessions → force Scout
  if has_db; then
    breath_info=$(db_pheromone_consecutive_caste "$SCOUT_BREATH_INTERVAL")
  else
    breath_info=$(count_consecutive_caste "$SCOUT_BREATH_INTERVAL")
  fi
  consecutive_count=$(echo "$breath_info" | awk '{print $1}')
  consecutive_caste=$(echo "$breath_info" | awk '{print $2}')
  if [ "$consecutive_count" -ge "$SCOUT_BREATH_INTERVAL" ]; then
    breath_needed=true
    caste="scout"; caste_reason="strategic breath — ${consecutive_count} consecutive ${consecutive_caste} sessions"
  else
    caste="worker"; caste_reason="WIP.md is fresh — continuing work"
  fi
elif [ "${high_holes:-0}" -gt 0 ]; then
  caste="worker"; caste_reason="${high_holes} high-weight HOLE signals"
else
  caste="scout"; caste_reason="default — no urgency detected"
fi

log_info "Caste: ${caste} (${caste_reason})"

# ── Step 5: Rule selection (top 5 by relevance) ─────────────────────

rules_section=""
rule_count=0

if [ -d "$RULES_DIR" ]; then
  # Score rules by: recency of last_triggered, hit_count, tag match with branch
  tmpfile=$(mktemp)
  while IFS= read -r rule_file; do
    [ -f "$rule_file" ] || continue
    rid=$(yaml_read "$rule_file" "id")
    trigger=$(yaml_read "$rule_file" "trigger")
    action=$(yaml_read "$rule_file" "action")
    hits=$(yaml_read "$rule_file" "hit_count")
    last=$(yaml_read "$rule_file" "last_triggered")
    hits="${hits:-0}"

    # Score: base from hit_count + recency bonus
    score="$hits"
    if [ -n "$last" ]; then
      age=$(days_since "$last")
      # More recently triggered = higher score
      recency_bonus=$((100 - age))
      [ "$recency_bonus" -lt 0 ] && recency_bonus=0
      score=$((score + recency_bonus))
    fi

    echo "${score}|${trigger}|${action}" >> "$tmpfile"
  done < <(list_rules)

  # Take top 5
  if [ -s "$tmpfile" ]; then
    rule_num=0
    sort -t'|' -k1 -rn "$tmpfile" | head -5 | while IFS='|' read -r _score trigger action; do
      rule_num=$((rule_num + 1))
      echo "${rule_num}. ${trigger} → ${action}"
    done > "${tmpfile}.formatted"
    rules_section=$(cat "${tmpfile}.formatted" 2>/dev/null || true)
    rule_count=$(wc -l < "${tmpfile}.formatted" 2>/dev/null | tr -d ' ')
    rm -f "${tmpfile}.formatted"
  fi
  rm -f "$tmpfile"
fi

# Fallback: if no YAML rules, try BLACKBOARD
if [ "$rule_count" -eq 0 ] && [ -f "$BLACKBOARD" ]; then
  rules_section="(No YAML rules — refer to BLACKBOARD.md for project context)"
fi

# ── Step 6: Situation summary ────────────────────────────────────────

situation=""

# WIP context
if [ "$wip" = "fresh" ] && [ -f "$WIP_FILE" ]; then
  # Extract first meaningful line from WIP
  wip_summary=$(grep -m1 -E '^[^#]' "$WIP_FILE" 2>/dev/null | head -c 120 || echo "WIP exists")
  situation="${situation}WIP: \"${wip_summary}\"\n"
fi

# Pheromone context
if has_db; then
  ph_row=$(db_pheromone_latest 2>/dev/null || true)
  if [ -n "$ph_row" ]; then
    IFS=$'\t' read -r _ph_agent _ph_ts _ph_caste _ph_branch _ph_commit _ph_completed ph_unresolved ph_pred_useful _ph_wip _ph_sigcount <<< "$ph_row"
    if [ -n "$ph_unresolved" ] && [ "$ph_unresolved" != "null" ] && [ "$ph_unresolved" != "" ]; then
      situation="${situation}Handoff: ${ph_unresolved}\n"
    fi
    if [ "$ph_pred_useful" = "0" ]; then
      log_warn "Previous agent reported predecessor handoff was NOT useful — pheromone quality may need attention"
    fi
  fi
elif [ -f "$PHEROMONE_FILE" ]; then
  ph_unresolved=""
  # Simple JSON extraction without jq
  ph_unresolved=$(grep '"unresolved"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"unresolved"[[:space:]]*:[[:space:]]*//' | tr -d '",')
  if [ -n "$ph_unresolved" ] && [ "$ph_unresolved" != "null" ]; then
    situation="${situation}Handoff: ${ph_unresolved}\n"
  fi

  # Read predecessor's evaluation of THEIR predecessor
  ph_pred_useful=$(grep '"predecessor_useful"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"predecessor_useful"[[:space:]]*:[[:space:]]*//' | tr -d ' ,')
  if [ "$ph_pred_useful" = "false" ]; then
    log_warn "Previous agent reported predecessor handoff was NOT useful — pheromone quality may need attention"
  fi
fi

# Top signals
if has_db; then
  top_signals=$(db_signal_by_weight 3 "status NOT IN ('archived','parked','done','completed')" | while IFS=$'\t' read -r sid stype stitle sstatus sw sowner; do
    echo -n "${sid}(w:${sw} ${stype}) "
  done)
  if [ -n "$top_signals" ]; then
    situation="${situation}Top signals: ${top_signals}\n"
  fi
elif has_signal_dir; then
  top_signals=$(list_signals_by_weight | head -3 | while read -r w path; do
    sid=$(yaml_read "$path" "id")
    tags=$(yaml_read "$path" "tags" | tr -d '[]' | awk '{print $1}')
    echo -n "${sid}(w:${w} ${tags}) "
  done)
  if [ -n "$top_signals" ]; then
    situation="${situation}Top signals: ${top_signals}\n"
  fi
elif [ -f "$BLACKBOARD" ]; then
  bb_top=$(parse_blackboard_signals | head -3 | while read -r w info; do
    echo -n "${info%:*}(w:${w}) "
  done)
  if [ -n "$bb_top" ]; then
    situation="${situation}Blackboard top: ${bb_top}\n"
  fi
fi

# Alarm context
if [ "$alarm" = "true" ] && [ -f "$ALARM_FILE" ]; then
  alarm_line=$(head -1 "$ALARM_FILE" | head -c 100)
  situation="${situation}ALARM: ${alarm_line}\n"
fi

# Breath cycle context
if [ "$breath_needed" = "true" ]; then
  situation="${situation}BREATH CYCLE: Strategic review session. Review BLACKBOARD, evaluate signal landscape, check parked signals, write DECISIONS.md [AUDIT].\n"
fi
# Parked signal awareness
if [ "${parked_signals:-0}" -gt 0 ]; then
  situation="${situation}Parked: ${parked_signals} signal(s) at environment boundary (skipped)\n"
fi
# Genesis context
if [ "$genesis" = "true" ]; then
  situation="${situation}GENESIS: First session. BLACKBOARD + S-001 auto-generated. Verify build/test, map project, refine BLACKBOARD.\n"
fi
# Upgrade context
if [ -n "${upgrade_context:-}" ]; then
  situation="${situation}UPGRADE: ${upgrade_context}\n"
fi
# Maintaining phase: rules exist but no active signals — nurse tasks
if [ "$colony_phase" = "maintaining" ]; then
  situation="${situation}MAINTENANCE: Colony stable, rules active. Consider nurse tasks: tests, docs, code quality.\n"
fi
# Idle colony detection (W-007): no actionable signals, not genesis, not alarm, not fresh WIP
if [ "${active_signals:-0}" -eq 0 ] && [ "$wip" != "fresh" ] && [ "$alarm" != "true" ] && [ "$genesis" != "true" ]; then
  situation="${situation}IDLE: Colony has no actionable signals. Either deposit a HOLE signal for new work, or exit session.\n"
fi

# v5.1: Decomposition hint — when signal-to-agent ratio is imbalanced
if has_db; then
  unclaimed_leaves=$(db_exec "
    SELECT COUNT(*) FROM signals s
    WHERE s.status = 'open'
      AND NOT EXISTS (
        SELECT 1 FROM signals c
        WHERE c.parent_id = s.id
        AND c.status NOT IN ('done','completed','archived')
      );" 2>/dev/null || echo "0")
  decompose_agents=$(db_exec "SELECT COUNT(*) FROM agents WHERE session_status='active';" 2>/dev/null || echo "1")
  min_ratio="${TERMITE_DECOMPOSE_MIN_AGENT_RATIO:-0.5}"
  needs_decompose=$(awk "BEGIN { print (${decompose_agents} > 1 && ${unclaimed_leaves} < ${decompose_agents} * ${min_ratio}) ? 1 : 0 }")
  if [ "$needs_decompose" -eq 1 ]; then
    situation="${situation}DECOMPOSE: ${decompose_agents} agents active but only ${unclaimed_leaves} unclaimed tasks. Consider decomposing complex signals into atomic sub-tasks using ./scripts/field-decompose.sh\n"
  fi
fi

# ── Step 6.5: Update agent caste in DB ──────────────────────────────

if has_db && [ -n "$AGENT_ID" ]; then
  db_agent_set_caste "$AGENT_ID" "$caste"
fi

# ── Step 6.8: Effort budget ─────────────────────────────────────────
uncommitted_lines=$(count_uncommitted_lines)
breath_age=$(breath_age_minutes)

# ── Step 7: Write .birth (strength-differentiated) ──────────────────

# Per-agent .birth for multi-agent support
if [ -n "$AGENT_ID" ]; then
  BIRTH_FILE="${PROJECT_ROOT}/.birth.${AGENT_ID}"
fi

alarm_display="none"
if [ "$alarm" = "true" ] && [ -f "$ALARM_FILE" ]; then
  alarm_display=$(head -1 "$ALARM_FILE" 2>/dev/null | head -c 60)
  alarm_display="${alarm_display:-active}"
fi

# Detect if entry file already contains grammar+safety (birth-static-included)
birth_static_included=false
for ef in "${PROJECT_ROOT}/CLAUDE.md" "${PROJECT_ROOT}/AGENTS.md"; do
  if [ -f "$ef" ] && grep -q 'birth-static-included' "$ef" 2>/dev/null; then
    birth_static_included=true
    break
  fi
done

# Get behavioral template from pheromone chain (Shepherd Effect amplifier)
behavioral_template=""
if has_db; then
  obs_ex=$(db_obs_best_example 2>/dev/null || true)
  if [ -n "$obs_ex" ]; then
    IFS=$'\t' read -r bt_pattern bt_context bt_detail <<< "$obs_ex"
    behavioral_template="example: pattern=\"${bt_pattern}\" context=\"${bt_context}\" detail=\"${bt_detail}\""
  fi
fi

# Get top signal with next_hint for .birth task section
# v5.1: leaf-priority — show unclaimed leaf signals, not decomposed parents
top_signal_hint=""
if has_db; then
  top_row=$(db_query "SELECT s.id, s.type, s.title, s.next_hint, s.child_hint, s.parent_id, s.module
    FROM signals s
    WHERE s.status = 'open'
      AND NOT EXISTS (
        SELECT 1 FROM signals c
        WHERE c.parent_id = s.id
        AND c.status NOT IN ('done','completed','archived')
      )
    ORDER BY s.weight DESC
    LIMIT 1;" 2>/dev/null || true)
  if [ -n "$top_row" ]; then
    IFS=$'\t' read -r ts_id ts_type ts_title ts_next ts_child_hint ts_parent ts_module <<< "$top_row"
    top_signal_hint="${ts_id}(${ts_type}): ${ts_title}"
    [ -n "$ts_next" ] && top_signal_hint="${top_signal_hint} → ${ts_next}"
    # Include parent context and child_hint for decomposed signals
    if [ -n "$ts_parent" ] && [ "$ts_parent" != "null" ] && [ "$ts_parent" != "" ]; then
      parent_title=$(db_exec "SELECT title FROM signals WHERE id='$(db_escape "$ts_parent")';" 2>/dev/null || true)
      [ -n "$parent_title" ] && top_signal_hint="${top_signal_hint}\n  parent: ${ts_parent} (${parent_title})"
    fi
    if [ -n "$ts_child_hint" ] && [ "$ts_child_hint" != "null" ] && [ "$ts_child_hint" != "" ]; then
      top_signal_hint="${top_signal_hint}\n  hint: ${ts_child_hint}"
    fi
    if [ -n "$ts_module" ] && [ "$ts_module" != "null" ] && [ "$ts_module" != "" ]; then
      top_signal_hint="${top_signal_hint}\n  files: ${ts_module}"
    fi
  fi
fi

# Get near-threshold observation clusters (v5.0: available to all agents via unified .birth)
obs_prompts=""
if has_db; then
  # v5.0: find keyword groups where sum(quality_score) is close to 3.0 threshold
  near_promo=$(db_query "SELECT pattern, COUNT(*) as cnt, SUM(quality_score) as qs FROM observations
    WHERE merged_count=0 AND source_type='deposit'
      AND (quality IS NULL OR quality != 'low')
    GROUP BY LOWER(TRIM(pattern))
    HAVING qs >= 2.0 AND qs < 3.0
    ORDER BY qs DESC
    LIMIT 3;" 2>/dev/null || true)
  if [ -n "$near_promo" ]; then
    obs_prompts="Near emergence:"
    while IFS=$'\t' read -r np_pattern np_count np_qs; do
      [ -z "$np_pattern" ] && continue
      obs_prompts="${obs_prompts}\n  - \"${np_pattern}\" (${np_count} obs, quality_sum=${np_qs}/3.0)"
    done <<< "$near_promo"
  fi
fi

# Get colony status summary (v5.0: available to all agents, used by direction .birth and unified context section)
colony_summary=""
idle_agents=0
if has_db; then
  idle_agents=$(db_exec "SELECT COUNT(*) FROM agents WHERE session_status='active';" 2>/dev/null || echo "0")
fi
recent_rules=0
if has_db; then
  recent_rules=$(db_exec "SELECT COUNT(*) FROM rules WHERE julianday('now') - julianday(created) < 7;" 2>/dev/null || echo "0")
fi
colony_summary="phase=${colony_phase} signals=${active_signals} agents=${idle_agents} recent_rules=${recent_rules}"

# Get decisions needed (direction .birth uses these prominently; unified .birth includes in context)
decisions_needed=""
if has_db; then
  blocked=$(db_query "SELECT id,title FROM signals WHERE type='BLOCKED' AND status NOT IN ('done','completed','archived','parked') LIMIT 3;" 2>/dev/null || true)
  if [ -n "$blocked" ]; then
    decisions_needed="BLOCKED signals:"
    while IFS=$'\t' read -r bl_id bl_title; do
      [ -z "$bl_id" ] && continue
      decisions_needed="${decisions_needed}\n  - ${bl_id}: ${bl_title}"
    done <<< "$blocked"
  fi
fi

# Get recent pheromone activity (for direction .birth)
recent_activity=""
if has_db; then
  recent_ph=$(db_query "SELECT agent_id,caste,completed FROM pheromone_history ORDER BY id DESC LIMIT 3;" 2>/dev/null || true)
  if [ -n "$recent_ph" ]; then
    recent_activity="Recent activity:"
    while IFS=$'\t' read -r ra_agent ra_caste ra_completed; do
      [ -z "$ra_agent" ] && continue
      ra_summary="${ra_caste}"
      [ -n "$ra_completed" ] && [ "$ra_completed" != "null" ] && ra_summary="${ra_summary}: $(echo "$ra_completed" | head -c 60)"
      recent_activity="${recent_activity}\n  - ${ra_summary}"
    done <<< "$recent_ph"
  fi
fi

# ── Write .birth (v5.0: unified template, state-driven budget) ────────

write_birth_header() {
  cat <<HEOF
# .birth
caste: ${caste}
branch: ${branch}
alarm: ${alarm_display}
channel: ${trigger_type}
health: build=${build} wip=${wip} signals=${active_signals} phase=${colony_phase}
HEOF
}

write_birth_capabilities() {
  cat <<CEOF

## capabilities
platform: ${cap_platform}
shell: yes  git: ${cap_git}  push: ${cap_push}
sandbox: ${cap_sandbox}

## effort_budget
uncommitted: ${uncommitted_lines}/${UNCOMMITTED_LINES_LIMIT} lines
breath_age: ${breath_age}min
CEOF
}

write_birth_unified() {
  # v5.0 Unified .birth template — same structure for all agents.
  # Colony phase determines token budget allocation (design doc lines 82-88).
  # "仁者见仁智者见智" — same text, different extraction depth.
  write_birth_header

  # ── ## task (200-350 tokens, state-driven) ──
  echo ""
  echo "## task"
  if [ -n "$top_signal_hint" ]; then
    echo "$top_signal_hint"
  else
    echo "$(echo -e "$situation" | sed '/^$/d' | head -3)"
  fi

  # Behavioral template: Rule 10 (Shepherd Effect) — highest quality deposit
  if [ -n "$behavioral_template" ]; then
    echo ""
    echo "behavioral_template:"
    echo "  $behavioral_template"
  fi

  # ── ## situation (150-250 tokens, state-driven) ──
  echo ""
  echo "## situation"
  echo -e "$situation" | sed '/^$/d'

  # ── ## context (0-200 tokens, only when colony has content) ──
  local has_context=false

  if [ "${rule_count:-0}" -gt 0 ] || [ -n "$obs_prompts" ] || [ -n "$decisions_needed" ]; then
    echo ""
    echo "## context"
    has_context=true
  fi

  # Active rules (top 5)
  if [ "${rule_count:-0}" -gt 0 ]; then
    echo "rules:"
    echo "${rules_section}" | head -5
  fi

  # Near-threshold observation clusters
  if [ -n "$obs_prompts" ]; then
    echo -e "$obs_prompts"
  fi

  # Blocked signals needing decisions
  if [ -n "$decisions_needed" ]; then
    echo -e "$decisions_needed"
  fi

  # Grammar + safety only if entry file lacks them
  if [ "$birth_static_included" = "false" ]; then
    echo ""
    echo "## grammar"
    echo "1. ARRIVE→SENSE→STATE (done)"
    echo "2. STATE→CASTE→PERMISSIONS (you: ${caste})"
    echo "3. ACTION∈PERMISSIONS→DO"
    echo "4. DO→DEPOSIT(signal,weight,TTL,location)"
    echo "5. weight<threshold→EVAPORATE (automatic)"
    echo "6. weight>threshold→ESCALATE"
    echo "7. sum(quality)≥3.0→EMERGE (observation→rule, quality-weighted)"
    echo "8. context>80%→MOLT (write WIP + .pheromone, die)"
    echo "9. DO(gen_agent)→SEED"
    echo "10. DEPOSIT(quality≥threshold)→TEMPLATE (Shepherd Effect)"

    echo ""
    echo "## safety"
    echo "- Commit every 50 lines [WIP]"
    echo "- Don't delete .md files"
    echo "- ALARM.md → stop and fix"
    echo "- Before end: ./scripts/field-deposit.sh"
  fi

  write_birth_capabilities

  # ── ## recovery (50-80 tokens, fixed) ──
  echo ""
  echo "## recovery_hints"
  echo "tool_fail: retry once, then ALARM"
  echo "permission_denied: ALARM immediately"
  echo "context_pressure: MOLT now"
  echo "build_fail: soldier, fix first"
  echo "stuck_3_turns: deposit, end session"
  echo "idle_colony: deposit HOLE or exit session"
  echo "deposit: submit trace (git commit message suffices)."
  echo "  observation: optional — write if you find a pattern worth recording."
  echo "  quality standard: cite file path + describe phenomenon + explain impact."
  echo "predecessor_eval: evaluate predecessor .pheromone usefulness"
  echo "signal_scope: one signal ≈ one verifiable deliverable"
}

write_birth_direction() {
  # Direction tier: for directive trigger type only (human-initiated sessions)
  # Decision-centric structure — not agent classification, but trigger type
  write_birth_header

  # Decisions needed
  echo ""
  echo "## decisions_needed"
  if [ -n "$decisions_needed" ]; then
    echo -e "$decisions_needed"
  else
    echo "No blocked signals. Review colony health and signal landscape."
  fi

  # Colony status
  echo ""
  echo "## colony_status"
  echo "$colony_summary"

  # Recent activity
  if [ -n "$recent_activity" ]; then
    echo ""
    echo "## recent_activity"
    echo -e "$recent_activity"
  fi

  # Full situation
  echo ""
  echo "## situation"
  echo -e "$situation" | sed '/^$/d'

  # Safety always included for direction tier (human may not know protocol)
  echo ""
  echo "## safety"
  echo "- Commit every 50 lines [WIP]"
  echo "- Don't delete .md files"
  echo "- ALARM.md → stop and fix"
  echo "- Before end: ./scripts/field-deposit.sh"

  write_birth_capabilities

  echo ""
  echo "## recovery_hints"
  echo "tool_fail: retry once, then ALARM"
  echo "permission_denied: ALARM immediately"
  echo "context_pressure: MOLT now"
  echo "build_fail: soldier, fix first"
  echo "stuck_3_turns: deposit, end session"
  echo "signal_scope: one signal ≈ one verifiable deliverable"
}

# v5.0: Write .birth based on trigger type (not strength tier)
if [ "$trigger_type" = "directive" ]; then
  write_birth_direction > "$BIRTH_FILE"
else
  write_birth_unified > "$BIRTH_FILE"
fi

# Also write default .birth for backward compatibility
if [ -n "$AGENT_ID" ] && [ "$BIRTH_FILE" != "${PROJECT_ROOT}/.birth" ]; then
  cp "$BIRTH_FILE" "${PROJECT_ROOT}/.birth"
fi

# ── Token budget check ───────────────────────────────────────────────

word_count=$(wc -w < "$BIRTH_FILE" | tr -d ' ')
token_estimate=$(awk "BEGIN { printf \"%d\", ${word_count} * 1.3 }")

if [ "$token_estimate" -gt 800 ]; then
  log_warn ".birth is ~${token_estimate} tokens (target ≤800). Consider trimming rules."
fi

log_info "=== .birth written (${word_count} words, ~${token_estimate} tokens, caste=${caste}, strength=${strength_tier}) ==="
log_info "Agent: read .birth and begin work."
