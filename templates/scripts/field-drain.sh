#!/usr/bin/env bash
# field-drain.sh — Archive completed signals
# Moves signals with status=done into signals/archive/done-YYYY-MM/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

if has_db; then
  source "${SCRIPT_DIR}/termite-db.sh"
  db_drain_done
  log_info "Drain complete (DB atomic)"
  exit 0
fi

if ! has_signal_dir; then
  log_info "No signals directory — skipping drain"
  exit 0
fi

drained=0
archive_month="${ARCHIVE_DIR}/done-$(date +%Y-%m)"

while IFS= read -r signal_file; do
  [ -f "$signal_file" ] || continue

  status=$(yaml_read "$signal_file" "status")
  if [ "$status" = "done" ]; then
    mkdir -p "$archive_month"
    yaml_write "$signal_file" "status" "archived"
    mv "$signal_file" "$archive_month/"
    drained=$((drained + 1))
    log_info "Drained $(basename "$signal_file")"
  fi
done < <(list_active_signals)

log_info "Drain complete: ${drained} archived"
