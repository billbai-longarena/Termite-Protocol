#!/usr/bin/env bash
# termite-db-migrate.sh — One-time YAML→SQLite migration
# Reads existing YAML signals, observations, rules, claims, pheromone, and breath
# into the new SQLite database. Safe to re-run (skips if DB already exists).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"
source "${SCRIPT_DIR}/termite-db.sh"

if [ -f "$TERMITE_DB" ]; then
  log_info "Database already exists at ${TERMITE_DB} — skipping migration"
  exit 0
fi

log_info "=== YAML→SQLite migration starting ==="

# Create DB from schema
db_ensure

# ── Migrate Signals ──────────────────────────────────────────────────

migrated_signals=0
if [ -d "$ACTIVE_DIR" ]; then
  for f in "$ACTIVE_DIR"/*.yaml; do
    [ -f "$f" ] || continue

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
    source=$(yaml_read "$f" "source")
    parked_reason=$(yaml_read "$f" "parked_reason" 2>/dev/null || true)
    parked_conditions=$(yaml_read "$f" "parked_conditions" 2>/dev/null || true)
    parked_at=$(yaml_read "$f" "parked_at" 2>/dev/null || true)

    db_exec "INSERT OR IGNORE INTO signals(id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parked_reason,parked_conditions,parked_at)
      VALUES('$(db_escape "${id}")','$(db_escape "${type:-HOLE}")','$(db_escape "${title:-untitled}")','$(db_escape "${status:-open}")',
      ${weight:-30},${ttl_days:-14},'$(db_escape "${created:-$(today_iso)}")','$(db_escape "${last_touched:-$(today_iso)}")',
      '$(db_escape "${owner:-unassigned}")','$(db_escape "${module:-}")','$(db_escape "${tags:-[]}")','$(db_escape "${next_hint:-}")',
      ${touch_count:-0},'$(db_escape "${source:-autonomous}")',
      $([ -n "$parked_reason" ] && echo "'$(db_escape "$parked_reason")'" || echo "NULL"),
      $([ -n "$parked_conditions" ] && echo "'$(db_escape "$parked_conditions")'" || echo "NULL"),
      $([ -n "$parked_at" ] && echo "'$(db_escape "$parked_at")'" || echo "NULL"));" 2>/dev/null || true

    migrated_signals=$((migrated_signals + 1))
  done
fi
log_info "Migrated ${migrated_signals} signals"

# ── Migrate Observations ─────────────────────────────────────────────

migrated_obs=0
if [ -d "$OBS_DIR" ]; then
  for f in "$OBS_DIR"/*.yaml; do
    [ -f "$f" ] || continue

    id=$(yaml_read "$f" "id")
    [ -z "$id" ] && continue

    pattern=$(yaml_read "$f" "pattern")
    context=$(yaml_read "$f" "context")
    reporter=$(yaml_read "$f" "reporter")
    confidence=$(yaml_read "$f" "confidence")
    created=$(yaml_read "$f" "created")
    source=$(yaml_read "$f" "source")
    detail=$(yaml_read "$f" "detail" 2>/dev/null || true)
    merged_count=$(yaml_read "$f" "merged_count" 2>/dev/null || true)
    merged_from=$(yaml_read "$f" "merged_from" 2>/dev/null || true)

    db_exec "INSERT OR IGNORE INTO observations(id,pattern,context,reporter,confidence,created,source,detail,merged_count,merged_from)
      VALUES('$(db_escape "$id")','$(db_escape "${pattern:-}")','$(db_escape "${context:-unknown}")','$(db_escape "${reporter:-unknown}")',
      '$(db_escape "${confidence:-medium}")','$(db_escape "${created:-$(today_iso)}")','$(db_escape "${source:-autonomous}")',
      '$(db_escape "${detail:-}")',${merged_count:-0},
      $([ -n "$merged_from" ] && echo "'$(db_escape "$merged_from")'" || echo "NULL"));" 2>/dev/null || true

    migrated_obs=$((migrated_obs + 1))
  done
fi
log_info "Migrated ${migrated_obs} observations"

# ── Migrate Rules ────────────────────────────────────────────────────

migrated_rules=0
if [ -d "$RULES_DIR" ]; then
  for f in "$RULES_DIR"/*.yaml; do
    [ -f "$f" ] || continue

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

    db_exec "INSERT OR IGNORE INTO rules(id,trigger_text,action_text,source_observations,hit_count,disputed_count,last_triggered,created,tags)
      VALUES('$(db_escape "$id")','$(db_escape "${trigger:-}")','$(db_escape "${action:-}")',
      '$(db_escape "${source_obs:-[]}")',${hit_count:-0},${disputed_count:-0},
      '$(db_escape "${last_triggered:-$(today_iso)}")','$(db_escape "${created:-$(today_iso)}")','$(db_escape "${tags:-[]}")');" 2>/dev/null || true

    migrated_rules=$((migrated_rules + 1))
  done
fi
log_info "Migrated ${migrated_rules} rules"

# ── Migrate Claims ───────────────────────────────────────────────────

migrated_claims=0
if [ -d "$CLAIMS_DIR" ]; then
  for f in "$CLAIMS_DIR"/*.lock; do
    [ -f "$f" ] || continue

    signal=$(yaml_read "$f" "signal")
    operation=$(yaml_read "$f" "operation")
    owner=$(yaml_read "$f" "owner")
    base_commit=$(yaml_read "$f" "base_commit" 2>/dev/null || true)
    claimed_at=$(yaml_read "$f" "claimed_at" 2>/dev/null || true)
    ttl_hours=$(yaml_read "$f" "ttl_hours" 2>/dev/null || true)

    [ -z "$signal" ] || [ -z "$operation" ] && continue

    db_exec "INSERT OR IGNORE INTO claims(signal_id,operation,owner,base_commit,claimed_at,ttl_hours)
      VALUES('$(db_escape "$signal")','$(db_escape "$operation")','$(db_escape "${owner:-unknown}")',
      '$(db_escape "${base_commit:-}")','$(db_escape "${claimed_at:-$(now_iso)}")',${ttl_hours:-$CLAIM_TTL_HOURS});" 2>/dev/null || true

    migrated_claims=$((migrated_claims + 1))
  done
fi
log_info "Migrated ${migrated_claims} claims"

# ── Migrate Pheromone ────────────────────────────────────────────────

migrated_pheromone=0
if [ -f "$PHEROMONE_FILE" ]; then
  ph_caste=$(grep '"caste"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"caste"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
  ph_branch=$(grep '"branch"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"branch"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
  ph_commit=$(grep '"commit"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"commit"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
  ph_completed=$(grep '"completed"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"completed"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
  ph_unresolved=$(grep '"unresolved"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"unresolved"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
  ph_timestamp=$(grep '"timestamp"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"timestamp"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
  ph_pred=$(grep '"predecessor_useful"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"predecessor_useful"[[:space:]]*:[[:space:]]*//' | tr -d ' ,')

  pred_val="NULL"
  case "$ph_pred" in
    true)  pred_val="1" ;;
    false) pred_val="0" ;;
  esac

  if [ -n "$ph_caste" ]; then
    db_exec "INSERT INTO pheromone_history(agent_id,timestamp,caste,branch,commit_hash,completed,unresolved,predecessor_useful)
      VALUES('migration','$(db_escape "${ph_timestamp:-$(now_iso)}")','$(db_escape "$ph_caste")','$(db_escape "${ph_branch:-}")',
      '$(db_escape "${ph_commit:-}")','$(db_escape "${ph_completed:-}")','$(db_escape "${ph_unresolved:-}")',${pred_val});" 2>/dev/null || true
    migrated_pheromone=1
  fi
fi
log_info "Migrated ${migrated_pheromone} pheromone entries"

# ── Migrate Colony State from .field-breath ──────────────────────────

migrated_colony=0
if [ -f "$BREATH_FILE" ]; then
  for key in alarm wip build signature_ratio active_signals high_weight_holes parked_signals expired_claims blackboard branch commit; do
    val=$(yaml_read "$BREATH_FILE" "$key")
    if [ -n "$val" ]; then
      db_exec "INSERT OR REPLACE INTO colony_state(key,value,updated_at) VALUES('$(db_escape "$key")','$(db_escape "$val")','$(now_iso)');" 2>/dev/null || true
      migrated_colony=$((migrated_colony + 1))
    fi
  done
fi
log_info "Migrated ${migrated_colony} colony state entries"

# ── Backup old YAML dirs ─────────────────────────────────────────────

if [ -d "$SIGNALS_DIR" ] && [ "$migrated_signals" -gt 0 ]; then
  backup_dir="${SIGNALS_DIR}.yaml-backup"
  if [ ! -d "$backup_dir" ]; then
    cp -R "$SIGNALS_DIR" "$backup_dir"
    log_info "Backed up signals/ to signals.yaml-backup/"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────

log_info "=== Migration complete ==="
log_info "  Signals:      ${migrated_signals}"
log_info "  Observations: ${migrated_obs}"
log_info "  Rules:        ${migrated_rules}"
log_info "  Claims:       ${migrated_claims}"
log_info "  Pheromone:    ${migrated_pheromone}"
log_info "  Colony state: ${migrated_colony}"
log_info "  Database:     ${TERMITE_DB}"
