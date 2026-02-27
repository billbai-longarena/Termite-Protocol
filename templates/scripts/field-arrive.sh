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

if [ -f "$BREATH_FILE" ]; then
  alarm=$(yaml_read "$BREATH_FILE" "alarm")
  wip=$(yaml_read "$BREATH_FILE" "wip")
  build=$(yaml_read "$BREATH_FILE" "build")
  sig_ratio=$(yaml_read "$BREATH_FILE" "signature_ratio")
  active_signals=$(yaml_read "$BREATH_FILE" "active_signals")
  high_holes=$(yaml_read "$BREATH_FILE" "high_weight_holes")
  branch=$(yaml_read "$BREATH_FILE" "branch")
else
  # Direct sensing fallback
  alarm="false"; check_alarm && alarm="true"
  wip=$(check_wip)
  build=$(check_build)
  branch=$(current_branch)
fi

# ── Step 4: Caste determination (waterfall, first hit wins) ──────────

caste="scout"  # default

if [ "$alarm" = "true" ]; then
  caste="soldier"
  caste_reason="ALARM.md present"
elif [ "$build" = "fail" ]; then
  caste="soldier"
  caste_reason="build/test failure"
elif [ "$wip" = "fresh" ]; then
  caste="worker"
  caste_reason="WIP.md is fresh — continuing work"
elif [ "${high_holes:-0}" -gt 0 ]; then
  caste="worker"
  caste_reason="${high_holes} high-weight HOLE signals"
else
  caste="scout"
  caste_reason="default — no urgency detected"
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
if [ -f "$PHEROMONE_FILE" ]; then
  ph_unresolved=""
  # Simple JSON extraction without jq
  ph_unresolved=$(grep '"unresolved"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"unresolved"[[:space:]]*:[[:space:]]*//' | tr -d '",')
  if [ -n "$ph_unresolved" ] && [ "$ph_unresolved" != "null" ]; then
    situation="${situation}Handoff: ${ph_unresolved}\n"
  fi
fi

# Top signals
if has_signal_dir; then
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

# ── Step 7: Write .birth ─────────────────────────────────────────────

alarm_display="none"
if [ "$alarm" = "true" ] && [ -f "$ALARM_FILE" ]; then
  alarm_display=$(head -1 "$ALARM_FILE" 2>/dev/null | head -c 60)
  alarm_display="${alarm_display:-active}"
fi

cat > "$BIRTH_FILE" <<BIRTHEOF
# .birth
caste: ${caste}
branch: ${branch}
alarm: ${alarm_display}
health: build=${build} wip=${wip} signals=${active_signals}

## situation
$(echo -e "$situation" | sed '/^$/d')

## rules
${rules_section:-No rules yet — observe patterns and deposit observations.}

## grammar
1. ARRIVE→SENSE→STATE (done)
2. STATE→CASTE→PERMISSIONS (you: ${caste})
3. ACTION∈PERMISSIONS→DO
4. DO→DEPOSIT(signal,weight,TTL,location)
5. weight<threshold→EVAPORATE (automatic)
6. weight>threshold→ESCALATE
7. count(agents,same_signal)≥3→EMERGE (observation→rule)
8. context>80%→MOLT (write WIP + .pheromone, die)

## safety
- Commit every 50 lines [WIP]
- Don't delete .md files
- ALARM.md → stop and fix
- Before end: ./scripts/field-deposit.sh
BIRTHEOF

# ── Token budget check ───────────────────────────────────────────────

word_count=$(wc -w < "$BIRTH_FILE" | tr -d ' ')
token_estimate=$(awk "BEGIN { printf \"%d\", ${word_count} * 1.3 }")

if [ "$token_estimate" -gt 800 ]; then
  log_warn ".birth is ~${token_estimate} tokens (target ≤800). Consider trimming rules."
fi

log_info "=== .birth written (${word_count} words, ~${token_estimate} tokens, caste=${caste}) ==="
log_info "Agent: read .birth and begin work."
