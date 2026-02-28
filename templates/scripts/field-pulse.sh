#!/usr/bin/env bash
# field-pulse.sh — Health sensing
# Checks environment health indicators and writes .field-breath.
# Sensors: ALARM, WIP, build, signature ratio, signal counts, claim expiry.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Sense: ALARM ─────────────────────────────────────────────────────

alarm="false"
if check_alarm; then
  alarm="true"
fi

# ── Sense: WIP freshness ────────────────────────────────────────────

wip=$(check_wip)

# ── Sense: Build / test status ───────────────────────────────────────

build=$(check_build)

# ── Sense: Signature coverage ────────────────────────────────────────

sig_ratio=$(termite_signature_ratio 20)

# ── Sense: Signal counts ────────────────────────────────────────────

active_count=0
high_holes=0
parked_count=0
if has_signal_dir; then
  active_count=$(count_active_signals)
  high_holes=$(count_high_weight_holes)
  parked_count=$(count_parked_signals)
fi

# ── Sense: Claim expiry ─────────────────────────────────────────────

expired_claims=0
if [ -d "$CLAIMS_DIR" ]; then
  now_epoch=$(date +%s)
  for lock_file in "$CLAIMS_DIR"/*.lock; do
    [ -f "$lock_file" ] || continue
    claimed_at=$(yaml_read "$lock_file" "claimed_at")
    ttl_h=$(yaml_read "$lock_file" "ttl_hours")
    [ -z "$claimed_at" ] && continue
    ttl_h="${ttl_h:-$CLAIM_TTL_HOURS}"
    # Parse ISO timestamp
    if claim_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$claimed_at" "+%s" 2>/dev/null) || \
       claim_epoch=$(date -d "$claimed_at" "+%s" 2>/dev/null); then
      expiry=$((claim_epoch + ttl_h * 3600))
      if [ "$now_epoch" -gt "$expiry" ]; then
        expired_claims=$((expired_claims + 1))
      fi
    fi
  done
fi

# ── Sense: Blackboard freshness ─────────────────────────────────────

bb_status="absent"
if [ -f "$BLACKBOARD" ]; then
  bb_mod=$(stat -f "%m" "$BLACKBOARD" 2>/dev/null || stat -c "%Y" "$BLACKBOARD" 2>/dev/null || echo 0)
  bb_age=$(( ($(date +%s) - bb_mod) / 86400 ))
  if [ "$bb_age" -lt "$WIP_FRESHNESS_DAYS" ]; then
    bb_status="fresh"
  else
    bb_status="stale"
  fi
fi

# ── Write .field-breath ─────────────────────────────────────────────

cat > "$BREATH_FILE" <<EOF
timestamp: $(now_iso)
alarm: ${alarm}
wip: ${wip}
build: ${build}
signature_ratio: ${sig_ratio}
active_signals: ${active_count}
high_weight_holes: ${high_holes}
parked_signals: ${parked_count}
expired_claims: ${expired_claims}
blackboard: ${bb_status}
branch: $(current_branch)
commit: $(current_commit_short)
EOF

log_info "Pulse written: alarm=${alarm} wip=${wip} build=${build} signals=${active_count} holes=${high_holes} parked=${parked_count}"
