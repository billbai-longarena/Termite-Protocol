#!/usr/bin/env bash
# termite-db-reimport.sh — Sync edited YAML files back into SQLite DB
# Use when you've manually edited YAML files and want the DB to reflect changes.
# Safe to re-run: uses INSERT OR REPLACE (upsert) semantics.
#
# Usage: ./termite-db-reimport.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"
source "${SCRIPT_DIR}/termite-db.sh"

DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo ""
      echo "Re-imports YAML files into .termite.db (upsert)."
      echo "Use after manually editing YAML files."
      echo ""
      echo "Options:"
      echo "  --dry-run  Show what would change without modifying the DB"
      exit 0
      ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ ! -f "$TERMITE_DB" ]; then
  log_error "No database found at ${TERMITE_DB}. Run field-arrive.sh first to create it."
  exit 1
fi

log_info "=== YAML→DB reimport starting ==="

# ── Reimport Signals ───────────────────────────────────────────────

reimported_signals=0
if [ -d "$ACTIVE_DIR" ]; then
  for f in "$ACTIVE_DIR"/*.yaml; do
    [ -f "$f" ] || continue

    # Skip files that are older than DB (not edited)
    local_mtime=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null || echo 0)
    db_mtime=$(stat -f "%m" "$TERMITE_DB" 2>/dev/null || stat -c "%Y" "$TERMITE_DB" 2>/dev/null || echo 0)
    [ "$local_mtime" -le "$db_mtime" ] && continue

    id=$(yaml_read "$f" "id")
    [ -z "$id" ] && continue

    type=$(yaml_read "$f" "type")
    title=$(yaml_read "$f" "title")
    status=$(yaml_read "$f" "status")
    weight=$(yaml_read "$f" "weight")
    ttl_days=$(yaml_read "$f" "ttl_days")
    created=$(yaml_read "$f" "created")
    last_touched=$(yaml_read "$f" "last_touched")
    owner=$(yaml_read "$f" "owner")
    module=$(yaml_read "$f" "module")
    tags=$(yaml_read "$f" "tags")
    next_hint=$(yaml_read "$f" "next")
    touch_count=$(yaml_read "$f" "touch_count")
    source_val=$(yaml_read "$f" "source")
    parked_reason=$(yaml_read "$f" "parked_reason" 2>/dev/null || true)
    parked_conditions=$(yaml_read "$f" "parked_conditions" 2>/dev/null || true)
    parked_at=$(yaml_read "$f" "parked_at" 2>/dev/null || true)

    if $DRY_RUN; then
      log_info "[dry-run] Would upsert signal: ${id} (weight=${weight}, status=${status})"
    else
      db_exec "INSERT OR REPLACE INTO signals(id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parked_reason,parked_conditions,parked_at)
        VALUES('$(db_escape "${id}")','$(db_escape "${type:-HOLE}")','$(db_escape "${title:-untitled}")','$(db_escape "${status:-open}")',
        ${weight:-30},${ttl_days:-14},'$(db_escape "${created:-$(today_iso)}")','$(db_escape "${last_touched:-$(today_iso)}")',
        '$(db_escape "${owner:-unassigned}")','$(db_escape "${module:-}")','$(db_escape "${tags:-[]}")','$(db_escape "${next_hint:-}")',
        ${touch_count:-0},'$(db_escape "${source_val:-autonomous}")',
        $([ -n "$parked_reason" ] && echo "'$(db_escape "$parked_reason")'" || echo "NULL"),
        $([ -n "$parked_conditions" ] && echo "'$(db_escape "$parked_conditions")'" || echo "NULL"),
        $([ -n "$parked_at" ] && echo "'$(db_escape "$parked_at")'" || echo "NULL"));"
    fi

    reimported_signals=$((reimported_signals + 1))
  done
fi
log_info "Reimported ${reimported_signals} signals"

# ── Reimport Observations ──────────────────────────────────────────

reimported_obs=0
if [ -d "$OBS_DIR" ]; then
  for f in "$OBS_DIR"/*.yaml; do
    [ -f "$f" ] || continue

    local_mtime=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null || echo 0)
    db_mtime=$(stat -f "%m" "$TERMITE_DB" 2>/dev/null || stat -c "%Y" "$TERMITE_DB" 2>/dev/null || echo 0)
    [ "$local_mtime" -le "$db_mtime" ] && continue

    id=$(yaml_read "$f" "id")
    [ -z "$id" ] && continue

    pattern=$(yaml_read "$f" "pattern")
    context=$(yaml_read "$f" "context")
    reporter=$(yaml_read "$f" "reporter")
    confidence=$(yaml_read "$f" "confidence")
    created=$(yaml_read "$f" "created")
    source_val=$(yaml_read "$f" "source")
    detail=$(yaml_read "$f" "detail" 2>/dev/null || true)
    merged_count=$(yaml_read "$f" "merged_count" 2>/dev/null || true)
    merged_from=$(yaml_read "$f" "merged_from" 2>/dev/null || true)

    if $DRY_RUN; then
      log_info "[dry-run] Would upsert observation: ${id} (pattern=${pattern})"
    else
      db_exec "INSERT OR REPLACE INTO observations(id,pattern,context,reporter,confidence,created,source,detail,merged_count,merged_from)
        VALUES('$(db_escape "$id")','$(db_escape "${pattern:-}")','$(db_escape "${context:-unknown}")','$(db_escape "${reporter:-unknown}")',
        '$(db_escape "${confidence:-medium}")','$(db_escape "${created:-$(today_iso)}")','$(db_escape "${source_val:-autonomous}")',
        '$(db_escape "${detail:-}")',${merged_count:-0},
        $([ -n "$merged_from" ] && echo "'$(db_escape "$merged_from")'" || echo "NULL"));"
    fi

    reimported_obs=$((reimported_obs + 1))
  done
fi
log_info "Reimported ${reimported_obs} observations"

# ── Reimport Rules ─────────────────────────────────────────────────

reimported_rules=0
if [ -d "$RULES_DIR" ]; then
  for f in "$RULES_DIR"/*.yaml; do
    [ -f "$f" ] || continue

    local_mtime=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null || echo 0)
    db_mtime=$(stat -f "%m" "$TERMITE_DB" 2>/dev/null || stat -c "%Y" "$TERMITE_DB" 2>/dev/null || echo 0)
    [ "$local_mtime" -le "$db_mtime" ] && continue

    id=$(yaml_read "$f" "id")
    [ -z "$id" ] && continue

    trigger=$(yaml_read "$f" "trigger")
    action=$(yaml_read "$f" "action")
    source_obs=$(yaml_read "$f" "source_observations")
    hit_count=$(yaml_read "$f" "hit_count")
    disputed_count=$(yaml_read "$f" "disputed_count")
    last_triggered=$(yaml_read "$f" "last_triggered")
    created=$(yaml_read "$f" "created")
    tags=$(yaml_read "$f" "tags")

    if $DRY_RUN; then
      log_info "[dry-run] Would upsert rule: ${id} (trigger=${trigger})"
    else
      db_exec "INSERT OR REPLACE INTO rules(id,trigger_text,action_text,source_observations,hit_count,disputed_count,last_triggered,created,tags)
        VALUES('$(db_escape "$id")','$(db_escape "${trigger:-}")','$(db_escape "${action:-}")',
        '$(db_escape "${source_obs:-[]}")',${hit_count:-0},${disputed_count:-0},
        '$(db_escape "${last_triggered:-$(today_iso)}")','$(db_escape "${created:-$(today_iso)}")','$(db_escape "${tags:-[]}")');"
    fi

    reimported_rules=$((reimported_rules + 1))
  done
fi
log_info "Reimported ${reimported_rules} rules"

# ── Refresh YAML headers after reimport ────────────────────────────

if ! $DRY_RUN && [ $((reimported_signals + reimported_obs + reimported_rules)) -gt 0 ]; then
  log_info "Refreshing YAML snapshots from DB..."
  "${SCRIPT_DIR}/termite-db-export.sh" 2>/dev/null || log_warn "Export had warnings"
fi

# ── Summary ──────────────────────────────────────────────────────────

total=$((reimported_signals + reimported_obs + reimported_rules))
if $DRY_RUN; then
  log_info "=== Dry run complete — ${total} files would be reimported ==="
else
  log_info "=== Reimport complete ==="
  log_info "  Signals:      ${reimported_signals}"
  log_info "  Observations: ${reimported_obs}"
  log_info "  Rules:        ${reimported_rules}"
fi
