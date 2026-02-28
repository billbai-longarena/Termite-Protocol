#!/usr/bin/env bash
# field-decay.sh — Weight decay for active signals
# Multiplies each active signal's weight by DECAY_FACTOR (default 0.98).
# Signals dropping below DECAY_THRESHOLD are auto-archived.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Source DB layer early (needed by signal_concentration) ────────────
if has_db; then
  source "${SCRIPT_DIR}/termite-db.sh"
fi

# ── Adaptive Decay: compute adjusted factor ──────────────────────────
concentration=$(signal_concentration)
case "$concentration" in
  concentrated) adj_factor=$(awk "BEGIN { f=${DECAY_FACTOR}-0.02; if(f<0.90) f=0.90; printf \"%.4f\",f }") ;;
  dispersed)    adj_factor=$(awk "BEGIN { f=${DECAY_FACTOR}+0.01; if(f>0.995) f=0.995; printf \"%.4f\",f }") ;;
  *)            adj_factor="$DECAY_FACTOR" ;;
esac
log_info "Decay: concentration=${concentration} factor=${adj_factor} (base=${DECAY_FACTOR})"

if has_db; then
  db_decay_all "$adj_factor"
  log_info "Decay complete (DB atomic)"
  exit 0
fi

if ! has_signal_dir; then
  log_info "No signals directory — skipping decay"
  exit 0
fi

archived=0
decayed=0

while IFS= read -r signal_file; do
  [ -f "$signal_file" ] || continue

  weight=$(yaml_read "$signal_file" "weight")
  [ -z "$weight" ] && continue

  # Apply decay: weight × adj_factor, truncated to integer
  new_weight=$(awk "BEGIN { w = int(${weight} * ${adj_factor}); if (w < 0) w = 0; print w }")

  if [ "$new_weight" -lt "$DECAY_THRESHOLD" ]; then
    # Archive signal
    local_archive="${ARCHIVE_DIR}/done-$(date +%Y-%m)"
    mkdir -p "$local_archive"
    yaml_write "$signal_file" "status" "archived"
    yaml_write "$signal_file" "weight" "$new_weight"
    mv "$signal_file" "$local_archive/"
    archived=$((archived + 1))
    log_info "Archived $(basename "$signal_file") (weight ${weight}→${new_weight})"
  else
    yaml_write "$signal_file" "weight" "$new_weight"
    decayed=$((decayed + 1))
  fi
done < <(list_active_signals)

log_info "Decay complete: ${decayed} decayed, ${archived} archived"
