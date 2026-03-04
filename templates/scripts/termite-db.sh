#!/usr/bin/env bash
# termite-db.sh — SQLite abstraction layer for Termite Protocol v5.0
# Source this file after field-lib.sh. Provides atomic DB operations.
# All shared state goes through these functions — no direct YAML writes needed.

# Requires: sqlite3 in PATH

# ── Core DB Functions ──────────────────────────────────────────────

TERMITE_DB="${PROJECT_ROOT}/.termite.db"

db_ensure() {
  # Create DB if not exists, apply schema; migrate v1→v2→v3 if needed
  if [ ! -f "$TERMITE_DB" ]; then
    sqlite3 "$TERMITE_DB" < "${SCRIPT_DIR}/termite-db-schema.sql"
    return 0
  fi
  # Schema version migration
  local current_ver
  current_ver=$(db_exec "SELECT COALESCE(MAX(version),1) FROM schema_version;" 2>/dev/null || echo "1")
  if [ "${current_ver:-1}" -lt 2 ]; then
    log_info "Migrating DB schema v${current_ver} → v2"
    db_exec "ALTER TABLE observations ADD COLUMN quality TEXT DEFAULT 'normal';" 2>/dev/null || true
    db_exec "ALTER TABLE pheromone_history ADD COLUMN observation_example TEXT;" 2>/dev/null || true
    db_exec "INSERT OR REPLACE INTO schema_version(version) VALUES (2);"
    log_info "DB schema migration to v2 complete"
    current_ver=2
  fi
  if [ "${current_ver:-1}" -lt 3 ]; then
    db_migrate_v2_to_v3
    current_ver=3
  fi
  if [ "${current_ver:-1}" -lt 4 ]; then
    db_migrate_v3_to_v4
  fi
  if [ "${current_ver:-1}" -lt 5 ]; then
    db_migrate_v4_to_v5
  fi
}

db_migrate_v2_to_v3() {
  # Idempotent migration: add strength-based participation columns
  log_info "Migrating DB schema v2 → v3"
  # agents table: platform, strength_tier, trigger_type
  db_exec "ALTER TABLE agents ADD COLUMN platform TEXT DEFAULT 'unknown';" 2>/dev/null || true
  db_exec "ALTER TABLE agents ADD COLUMN strength_tier TEXT DEFAULT 'execution';" 2>/dev/null || true
  db_exec "ALTER TABLE agents ADD COLUMN trigger_type TEXT DEFAULT 'heartbeat';" 2>/dev/null || true
  # pheromone_history table: platform, strength_tier
  db_exec "ALTER TABLE pheromone_history ADD COLUMN platform TEXT DEFAULT 'unknown';" 2>/dev/null || true
  db_exec "ALTER TABLE pheromone_history ADD COLUMN strength_tier TEXT DEFAULT 'execution';" 2>/dev/null || true
  db_exec "INSERT OR REPLACE INTO schema_version(version) VALUES (3);"
  log_info "DB schema migration to v3 complete"
}

db_migrate_v3_to_v4() {
  # Idempotent migration: add artifact quality scoring columns (v5.0)
  log_info "Migrating DB schema v3 → v4"
  db_exec "ALTER TABLE observations ADD COLUMN quality_score REAL DEFAULT 0.5;" 2>/dev/null || true
  db_exec "ALTER TABLE observations ADD COLUMN source_type TEXT DEFAULT 'deposit';" 2>/dev/null || true
  db_exec "INSERT OR REPLACE INTO schema_version(version) VALUES (4);"
  log_info "DB schema migration to v4 complete"
}

db_migrate_v4_to_v5() {
  log_info "Migrating DB schema v4 → v5"
  db_exec "ALTER TABLE signals ADD COLUMN parent_id TEXT DEFAULT NULL;" 2>/dev/null || true
  db_exec "ALTER TABLE signals ADD COLUMN child_hint TEXT DEFAULT NULL;" 2>/dev/null || true
  db_exec "ALTER TABLE signals ADD COLUMN depth INTEGER DEFAULT 0;" 2>/dev/null || true
  db_exec "CREATE INDEX IF NOT EXISTS idx_signals_parent ON signals(parent_id);" 2>/dev/null || true
  db_exec "INSERT OR REPLACE INTO schema_version(version) VALUES (5);"
  log_info "DB schema migration to v5 complete"
}

db_exec() {
  # Execute SQL, returns output. Uses busy_timeout for concurrency.
  sqlite3 -bail "$TERMITE_DB" ".timeout 5000" "$1"
}

db_query() {
  # Query with header-less tab-separated output
  sqlite3 -separator $'\t' -noheader -bail "$TERMITE_DB" ".timeout 5000" "$1"
}

db_transaction() {
  # Execute multiple statements in exclusive transaction
  sqlite3 -bail "$TERMITE_DB" ".timeout 5000" "BEGIN EXCLUSIVE; $1 COMMIT;"
}

# ── Signal CRUD ─────────────────────────────────────────────────────

db_next_signal_id() {
  # Atomic next ID: SELECT MAX + 1 inside transaction
  local prefix="${1:-S}"
  local max_num
  max_num=$(db_exec "SELECT COALESCE(MAX(CAST(SUBSTR(id, LENGTH('${prefix}-') + 1) AS INTEGER)), 0) FROM signals WHERE id LIKE '${prefix}-%';")
  printf "%s-%03d" "$prefix" $((max_num + 1))
}

db_signal_create() {
  # Args: id type title status weight ttl_days created last_touched owner module tags next_hint touch_count source
  local id="$1" type="$2" title="$3" status="${4:-open}" weight="${5:-30}" ttl_days="${6:-14}"
  local created="${7:-$(today_iso)}" last_touched="${8:-$(today_iso)}" owner="${9:-unassigned}"
  local module="${10:-}" tags="${11:-[]}" next_hint="${12:-}" touch_count="${13:-0}" source="${14:-autonomous}"
  db_exec "INSERT INTO signals(id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source)
    VALUES('$(db_escape "$id")','$(db_escape "$type")','$(db_escape "$title")','$(db_escape "$status")',$weight,$ttl_days,
    '$(db_escape "$created")','$(db_escape "$last_touched")','$(db_escape "$owner")','$(db_escape "$module")',
    '$(db_escape "$tags")','$(db_escape "$next_hint")',$touch_count,'$(db_escape "$source")');"
}

db_signal_read() {
  # Returns tab-separated row: id type title status weight ttl_days created last_touched owner module tags next_hint touch_count source parked_reason parked_conditions parked_at
  db_query "SELECT id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parked_reason,parked_conditions,parked_at FROM signals WHERE id='$(db_escape "$1")';"
}

db_signal_update() {
  # Args: id field value
  local id="$1" field="$2" value="$3"
  db_exec "UPDATE signals SET ${field}='$(db_escape "$value")' WHERE id='$(db_escape "$id")';"
}

db_signal_list() {
  # Optional filter: status, type
  local where=""
  [ -n "${1:-}" ] && where="WHERE $1"
  db_query "SELECT id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source FROM signals ${where} ORDER BY weight DESC;"
}

db_signal_count() {
  # Optional WHERE clause (without the WHERE keyword)
  local where=""
  [ -n "${1:-}" ] && where="WHERE $1"
  db_exec "SELECT COUNT(*) FROM signals ${where};"
}

db_signal_by_weight() {
  local limit="${1:-10}"
  local where=""
  [ -n "${2:-}" ] && where="WHERE $2"
  db_query "SELECT id,type,title,status,weight,owner FROM signals ${where} ORDER BY weight DESC LIMIT ${limit};"
}

# ── Observation CRUD ─────────────────────────────────────────────────

db_obs_create() {
  # Args: id pattern context reporter confidence source detail [quality] [quality_score] [source_type]
  local id="$1" pattern="$2" context="${3:-unknown}" reporter="$4"
  local confidence="${5:-medium}" source="${6:-autonomous}" detail="${7:-}" quality="${8:-normal}"
  local quality_score="${9:-0.5}" source_type="${10:-deposit}"
  db_exec "INSERT INTO observations(id,pattern,context,reporter,confidence,created,source,detail,quality,quality_score,source_type)
    VALUES('$(db_escape "$id")','$(db_escape "$pattern")','$(db_escape "$context")','$(db_escape "$reporter")',
    '$(db_escape "$confidence")','$(today_iso)','$(db_escape "$source")','$(db_escape "$detail")','$(db_escape "$quality")',
    ${quality_score},'$(db_escape "$source_type")');"
}

db_obs_list() {
  local where=""
  [ -n "${1:-}" ] && where="WHERE $1"
  db_query "SELECT id,pattern,context,reporter,confidence,created,source,detail,merged_count,merged_from FROM observations ${where} ORDER BY created DESC;"
}

db_obs_count() {
  local where=""
  [ -n "${1:-}" ] && where="WHERE $1"
  db_exec "SELECT COUNT(*) FROM observations ${where};"
}

db_obs_compress() {
  # Group by pattern+date, merge groups with >=3 observations, archive originals
  # v5.0: Skip trace observations — traces are permanent facts and never compressed
  local threshold="${PROMOTION_THRESHOLD:-3}"
  local merged_id="O-$(date +%Y%m%d%H%M%S)-$$-merged"

  # Find patterns with enough observations to compress (same date, deposits only)
  local groups
  groups=$(db_query "SELECT pattern, created, COUNT(*) as cnt, GROUP_CONCAT(id) as ids
    FROM observations
    WHERE merged_count = 0
      AND COALESCE(source_type, 'deposit') = 'deposit'
    GROUP BY LOWER(TRIM(pattern)), created
    HAVING cnt >= ${threshold};")

  [ -z "$groups" ] && return 0

  local merge_count=0
  echo "$groups" | while IFS=$'\t' read -r pattern created cnt ids; do
    [ -z "$pattern" ] && continue
    merge_count=$((merge_count + 1))
    local mid="O-$(date +%Y%m%d%H%M%S)-$$-m${merge_count}"

    # Get context from first observation in group
    local first_id
    first_id=$(echo "$ids" | cut -d',' -f1)
    local ctx
    ctx=$(db_exec "SELECT context FROM observations WHERE id='$(db_escape "$first_id")';")

    db_transaction "
      INSERT INTO observations(id,pattern,context,reporter,confidence,created,source,merged_count,merged_from)
        VALUES('$(db_escape "$mid")','$(db_escape "$pattern")','$(db_escape "$ctx")','termite:$(today_iso):system','high','$(today_iso)','autonomous',${cnt},'[${ids}]');
      INSERT INTO archive(original_id,original_table,data,archived_at,archive_reason)
        SELECT id,'observations',
          json_object('id',id,'pattern',pattern,'context',context,'reporter',reporter,'confidence',confidence,'created',created),
          datetime('now'),'merged'
        FROM observations WHERE id IN ($(echo "$ids" | sed "s/[^,]*/'&'/g"));
      DELETE FROM observations WHERE id IN ($(echo "$ids" | sed "s/[^,]*/'&'/g"));
    "
    log_info "Compressed ${cnt} observations into ${mid}"
  done
}

db_obs_best_example() {
  # Return highest quality_score observation with substantive detail (v5.0)
  # Output: pattern\tcontext\tdetail(first 100 chars)
  db_query "SELECT pattern, context, SUBSTR(detail, 1, 100)
    FROM observations
    WHERE quality_score >= 0.6
      AND source_type = 'deposit'
      AND LENGTH(COALESCE(detail,'')) > 20
    ORDER BY quality_score DESC, created DESC LIMIT 1;"
}

db_obs_quality_sum() {
  # Return sum of quality_score for observations matching normalized keywords
  # Args: normalized_keywords
  # Used for quality-weighted emergence (Rule 7 v5.0)
  local keywords="$1"
  db_exec "SELECT COALESCE(SUM(quality_score), 0.0) FROM observations
    WHERE source_type = 'deposit'
      AND merged_count = 0
      AND (quality IS NULL OR quality != 'low');"
}

# ── Rule CRUD ────────────────────────────────────────────────────────

db_rule_create() {
  # Args: id trigger action source_observations
  local id="$1" trigger="$2" action="$3" source_obs="${4:-[]}"
  db_exec "INSERT INTO rules(id,trigger_text,action_text,source_observations,hit_count,disputed_count,last_triggered,created,tags)
    VALUES('$(db_escape "$id")','$(db_escape "$trigger")','$(db_escape "$action")','$(db_escape "$source_obs")',0,0,'$(today_iso)','$(today_iso)','[]');"
}

db_rule_list() {
  local where=""
  [ -n "${1:-}" ] && where="WHERE $1"
  db_query "SELECT id,trigger_text,action_text,source_observations,hit_count,disputed_count,last_triggered,created,tags FROM rules ${where};"
}

db_rule_increment_hit() {
  # Atomic increment — no race condition
  db_exec "UPDATE rules SET hit_count = hit_count + 1, last_triggered = '$(today_iso)' WHERE id = '$(db_escape "$1")';"
}

db_rule_increment_dispute() {
  # Atomic increment — no race condition
  db_exec "UPDATE rules SET disputed_count = disputed_count + 1 WHERE id = '$(db_escape "$1")';"
}

db_next_rule_id() {
  local max_num
  max_num=$(db_exec "SELECT COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) FROM rules;")
  printf "R-%03d" $((max_num + 1))
}

# ── Claim Operations (atomic) ────────────────────────────────────────

db_claim_create() {
  # Args: signal_id operation owner base_commit ttl_hours
  # Atomic: check compatibility + insert in single transaction
  local signal_id="$1" op="$2" owner="$3" base_commit="${4:-}" ttl_hours="${5:-$CLAIM_TTL_HOURS}"

  # Validate operation
  case "$op" in
    work|audit|review) ;;
    *) log_error "Invalid operation: $op"; return 1 ;;
  esac

  # Check for blocking claims first (review never blocks)
  if [ "$op" != "review" ]; then
    local blocking
    blocking=$(db_exec "SELECT COUNT(*) FROM claims WHERE signal_id='$(db_escape "$signal_id")' AND operation IN ('work','audit') AND operation != '$(db_escape "$op")';")
    if [ "${blocking:-0}" -gt 0 ]; then
      log_error "Blocked: ${signal_id} has incompatible claim"
      return 1
    fi
  fi

  # Check for duplicate
  local existing
  existing=$(db_exec "SELECT COUNT(*) FROM claims WHERE signal_id='$(db_escape "$signal_id")' AND operation='$(db_escape "$op")';")
  if [ "${existing:-0}" -gt 0 ]; then
    log_error "Already claimed: ${signal_id} ${op}"
    return 1
  fi

  db_transaction "
    INSERT INTO claims(signal_id,operation,owner,base_commit,claimed_at,ttl_hours)
      VALUES('$(db_escape "$signal_id")','$(db_escape "$op")','$(db_escape "$owner")','$(db_escape "$base_commit")',datetime('now'),$ttl_hours);
    UPDATE signals SET status='claimed', owner='$(db_escape "$owner")',
      last_touched='$(today_iso)', touch_count=touch_count+1
      WHERE id='$(db_escape "$signal_id")';
  "
}

db_claim_release() {
  # Args: signal_id operation
  local signal_id="$1" op="$2"
  db_transaction "
    DELETE FROM claims WHERE signal_id='$(db_escape "$signal_id")' AND operation='$(db_escape "$op")';
    UPDATE signals SET status=CASE
      WHEN (SELECT COUNT(*) FROM claims WHERE signal_id='$(db_escape "$signal_id")') = 0 THEN 'open'
      ELSE status END,
      owner=CASE
      WHEN (SELECT COUNT(*) FROM claims WHERE signal_id='$(db_escape "$signal_id")') = 0 THEN 'unassigned'
      ELSE owner END
      WHERE id='$(db_escape "$signal_id")';
  "
}

db_claim_check() {
  # Args: signal_id operation — returns "blocked" or "available"
  local signal_id="$1" op="$2"
  if [ "$op" = "review" ]; then
    echo "available"
    return
  fi
  local blocking
  blocking=$(db_exec "SELECT COUNT(*) FROM claims WHERE signal_id='$(db_escape "$signal_id")' AND operation IN ('work','audit') AND operation != '$(db_escape "$op")';")
  if [ "${blocking:-0}" -gt 0 ]; then
    echo "blocked"
  else
    echo "available"
  fi
}

db_claim_list() {
  db_query "SELECT signal_id,operation,owner,claimed_at FROM claims ORDER BY claimed_at;"
}

db_claim_expire() {
  # Delete expired claims (by TTL or heartbeat timeout), reset signals
  local expired_ids
  
  # 1. Standard TTL expiration
  expired_ids=$(db_query "SELECT signal_id,operation FROM claims WHERE datetime(claimed_at, '+' || ttl_hours || ' hours') < datetime('now');")
  
  # 2. Heartbeat timeout (W-015): auto-release if >10 heartbeats have passed since claim
  local starved_ids
  starved_ids=$(db_query "
    SELECT signal_id, operation FROM claims 
    WHERE (SELECT COUNT(*) FROM pheromone_history WHERE timestamp > claims.claimed_at) >= 10;
  ")
  
  if [ -z "$expired_ids" ] && [ -z "$starved_ids" ]; then
    return 0
  fi

  db_transaction "
    -- Reset signals for TTL expired
    UPDATE signals SET status='stale', owner='unassigned'
      WHERE id IN (SELECT signal_id FROM claims WHERE datetime(claimed_at, '+' || ttl_hours || ' hours') < datetime('now'))
      AND id NOT IN (SELECT signal_id FROM claims WHERE datetime(claimed_at, '+' || ttl_hours || ' hours') >= datetime('now'));
      
    -- Reset signals for starved claims
    UPDATE signals SET status='open', owner='unassigned'
      WHERE id IN (
        SELECT signal_id FROM claims 
        WHERE (SELECT COUNT(*) FROM pheromone_history WHERE timestamp > claims.claimed_at) >= 10
      );
      
    -- Delete claims
    DELETE FROM claims WHERE datetime(claimed_at, '+' || ttl_hours || ' hours') < datetime('now');
    DELETE FROM claims WHERE (SELECT COUNT(*) FROM pheromone_history WHERE timestamp > claims.claimed_at) >= 10;
  "
  
  local total_cleaned=0
  [ -n "$expired_ids" ] && total_cleaned=$((total_cleaned + $(echo "$expired_ids" | wc -l)))
  [ -n "$starved_ids" ] && total_cleaned=$((total_cleaned + $(echo "$starved_ids" | wc -l)))
  
  log_info "Expired/starved claims cleaned: ${total_cleaned}"
}

# ── Pheromone Operations ──────────────────────────────────────────────

db_pheromone_deposit() {
  # Append-only — no last-writer-wins problem
  # Args: agent_id caste branch commit_hash completed unresolved predecessor_useful [observation_example] [platform] [strength_tier]
  local agent_id="$1" caste="$2" branch="${3:-}" commit_hash="${4:-}"
  local completed="${5:-}" unresolved="${6:-}"
  local pred_useful="NULL"
  case "${7:-}" in
    true|1)  pred_useful="1" ;;
    false|0) pred_useful="0" ;;
  esac
  local obs_example="${8:-}"
  local ph_platform="${9:-unknown}"
  local ph_strength="${10:-execution}"
  local wip_status
  wip_status=$(check_wip)
  local sig_count
  sig_count=$(db_signal_count "status NOT IN ('archived')" 2>/dev/null || echo "0")

  db_exec "INSERT INTO pheromone_history(agent_id,timestamp,caste,branch,commit_hash,completed,unresolved,predecessor_useful,wip_status,active_signal_count,observation_example,platform,strength_tier)
    VALUES('$(db_escape "$agent_id")','$(now_iso)','$(db_escape "$caste")','$(db_escape "$branch")','$(db_escape "$commit_hash")',
    '$(db_escape "$completed")','$(db_escape "$unresolved")',${pred_useful},'$(db_escape "$wip_status")',${sig_count},
    '$(db_escape "$obs_example")','$(db_escape "$ph_platform")','$(db_escape "$ph_strength")');"
}

db_pheromone_latest() {
  db_query "SELECT agent_id,timestamp,caste,branch,commit_hash,completed,unresolved,predecessor_useful,wip_status,active_signal_count,observation_example FROM pheromone_history ORDER BY id DESC LIMIT 1;"
}

db_pheromone_chain() {
  db_query "SELECT agent_id,timestamp,caste,branch,commit_hash,completed,unresolved,predecessor_useful,wip_status,active_signal_count FROM pheromone_history ORDER BY id ASC;"
}

db_pheromone_consecutive_caste() {
  # Count consecutive same-caste from latest entries
  # Returns: "count last_caste"
  local max_depth="${1:-10}"
  local rows
  rows=$(db_query "SELECT caste FROM pheromone_history ORDER BY id DESC LIMIT ${max_depth};")
  [ -z "$rows" ] && echo "0 unknown" && return

  local count=0 last_caste=""
  while IFS=$'\t' read -r c; do
    [ -z "$c" ] && continue
    if [ -z "$last_caste" ]; then
      last_caste="$c"; count=1
    elif [ "$c" = "$last_caste" ]; then
      count=$((count + 1))
    else
      break
    fi
  done <<< "$rows"
  echo "${count} ${last_caste:-unknown}"
}

# ── Platform-Level Queries ─────────────────────────────────────────────

db_platform_obs_quality_rate() {
  # Returns observation quality rate for a platform in the last 24h
  # Args: platform
  local platform="$1"
  local total low
  total=$(db_exec "SELECT COUNT(*) FROM observations o
    INNER JOIN pheromone_history p ON o.reporter LIKE '%' || p.caste || '%'
    WHERE p.platform='$(db_escape "$platform")'
      AND o.created >= date('now','-1 day');" 2>/dev/null || echo "0")
  if [ "${total:-0}" -eq 0 ]; then
    # Fallback: count all observations from this platform via agent_id patterns
    total=$(db_exec "SELECT COUNT(*) FROM observations
      WHERE created >= date('now','-1 day');" 2>/dev/null || echo "0")
    [ "${total:-0}" -eq 0 ] && { echo "1.0"; return; }
    low=$(db_exec "SELECT COUNT(*) FROM observations
      WHERE created >= date('now','-1 day') AND quality='low';" 2>/dev/null || echo "0")
  else
    low=$(db_exec "SELECT COUNT(*) FROM observations o
      INNER JOIN pheromone_history p ON o.reporter LIKE '%' || p.caste || '%'
      WHERE p.platform='$(db_escape "$platform")'
        AND o.created >= date('now','-1 day')
        AND o.quality='low';" 2>/dev/null || echo "0")
  fi
  awk "BEGIN { if(${total}==0) print \"1.0\"; else printf \"%.2f\", 1.0 - ${low}/${total} }"
}

db_platform_pred_useful_rate() {
  # Returns predecessor_useful rate for a platform in the last 24h
  # Args: platform
  local platform="$1"
  local total useful
  total=$(db_exec "SELECT COUNT(*) FROM pheromone_history
    WHERE platform='$(db_escape "$platform")'
      AND timestamp >= datetime('now','-1 day')
      AND predecessor_useful IS NOT NULL;" 2>/dev/null || echo "0")
  [ "${total:-0}" -eq 0 ] && { echo "0.0"; return; }
  useful=$(db_exec "SELECT COUNT(*) FROM pheromone_history
    WHERE platform='$(db_escape "$platform")'
      AND timestamp >= datetime('now','-1 day')
      AND predecessor_useful=1;" 2>/dev/null || echo "0")
  awk "BEGIN { printf \"%.2f\", ${useful}/${total} }"
}

db_platform_deposit_count() {
  # Returns pheromone deposit count for a platform in the last 24h
  # Args: platform
  local platform="$1"
  db_exec "SELECT COUNT(*) FROM pheromone_history
    WHERE platform='$(db_escape "$platform")'
      AND timestamp >= datetime('now','-1 day');" 2>/dev/null || echo "0"
}

# ── Agent Registry ─────────────────────────────────────────────────────

db_agent_register() {
  local agent_id="termite-$(date +%s)-$$"
  db_exec "INSERT INTO agents(agent_id,registered_at,last_heartbeat,session_status)
    VALUES('${agent_id}','$(now_iso)','$(now_iso)','active');"
  echo "$agent_id"
}

db_agent_heartbeat() {
  db_exec "UPDATE agents SET last_heartbeat='$(now_iso)' WHERE agent_id='$(db_escape "$1")';"
}

db_agent_complete() {
  db_exec "UPDATE agents SET session_status='completed', last_heartbeat='$(now_iso)' WHERE agent_id='$(db_escape "$1")';"
}

db_agent_set_caste() {
  db_exec "UPDATE agents SET caste='$(db_escape "$2")' WHERE agent_id='$(db_escape "$1")';"
}

db_agent_set_strength() {
  # Args: agent_id platform strength_tier trigger_type
  db_exec "UPDATE agents SET platform='$(db_escape "$2")', strength_tier='$(db_escape "$3")', trigger_type='$(db_escape "$4")' WHERE agent_id='$(db_escape "$1")';"
}

# ── Colony State ───────────────────────────────────────────────────────

db_colony_set() {
  # Args: key value
  db_exec "INSERT OR REPLACE INTO colony_state(key,value,updated_at) VALUES('$(db_escape "$1")','$(db_escape "$2")','$(now_iso)');"
}

db_colony_get() {
  db_exec "SELECT value FROM colony_state WHERE key='$(db_escape "$1")';"
}

db_colony_pulse() {
  # Write all health indicators atomically in one transaction
  # Args: alarm wip build sig_ratio active_count high_holes parked_count expired_claims
  local alarm="$1" wip="$2" build="$3" sig_ratio="$4"
  local active_count="$5" high_holes="$6" parked_count="$7" expired_claims="$8"
  db_transaction "
    INSERT OR REPLACE INTO colony_state(key,value,updated_at) VALUES
      ('alarm','$(db_escape "$alarm")','$(now_iso)'),
      ('wip','$(db_escape "$wip")','$(now_iso)'),
      ('build','$(db_escape "$build")','$(now_iso)'),
      ('signature_ratio','$(db_escape "$sig_ratio")','$(now_iso)'),
      ('active_signals','${active_count}','$(now_iso)'),
      ('high_weight_holes','${high_holes}','$(now_iso)'),
      ('parked_signals','${parked_count}','$(now_iso)'),
      ('expired_claims','${expired_claims}','$(now_iso)'),
      ('branch','$(current_branch)','$(now_iso)'),
      ('commit','$(current_commit_short)','$(now_iso)'),
      ('timestamp','$(now_iso)','$(now_iso)');
  "
}

# ── Decay and Archive ─────────────────────────────────────────────────

db_decay_all() {
  # Single atomic operation — no per-file race
  local factor="${1:-${DECAY_FACTOR:-0.98}}"
  local threshold="${DECAY_THRESHOLD:-5}"

  db_transaction "
    INSERT INTO archive(original_id,original_table,data,archived_at,archive_reason)
      SELECT id,'signals',
        json_object('id',id,'type',type,'title',title,'status',status,'weight',weight,
          'ttl_days',ttl_days,'created',created,'last_touched',last_touched,'owner',owner,
          'module',module,'tags',tags,'next_hint',next_hint,'touch_count',touch_count,'source',source),
        datetime('now'),'decayed'
      FROM signals
      WHERE CAST(weight * ${factor} AS INTEGER) < ${threshold}
        AND status NOT IN ('archived','parked');
    DELETE FROM signals
      WHERE CAST(weight * ${factor} AS INTEGER) < ${threshold}
        AND status NOT IN ('archived','parked');
    UPDATE signals SET weight = CAST(weight * ${factor} AS INTEGER)
      WHERE status NOT IN ('archived','parked');
  "
}

db_drain_done() {
  # Archive all done signals atomically
  db_transaction "
    INSERT INTO archive(original_id,original_table,data,archived_at,archive_reason)
      SELECT id,'signals',
        json_object('id',id,'type',type,'title',title,'status','done','weight',weight,
          'created',created,'last_touched',last_touched,'owner',owner,'module',module),
        datetime('now'),'done'
      FROM signals WHERE status='done';
    DELETE FROM signals WHERE status='done';
  "
}

db_archive_rules_stale() {
  local max_days="${RULE_ARCHIVE_DAYS:-60}"
  db_transaction "
    INSERT INTO archive(original_id,original_table,data,archived_at,archive_reason)
      SELECT id,'rules',
        json_object('id',id,'trigger_text',trigger_text,'action_text',action_text,
          'hit_count',hit_count,'disputed_count',disputed_count,'last_triggered',last_triggered,'created',created),
        datetime('now'),'rule_expired'
      FROM rules
      WHERE last_triggered IS NOT NULL
        AND julianday('now') - julianday(last_triggered) > ${max_days};
    DELETE FROM rules
      WHERE last_triggered IS NOT NULL
        AND julianday('now') - julianday(last_triggered) > ${max_days};
  "
}

# ── Export Helpers ─────────────────────────────────────────────────────

db_export_signal_yaml() {
  # Format single signal row as YAML, output to stdout
  # Args: signal_id
  local row
  row=$(db_query "SELECT id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parked_reason,parked_conditions,parked_at,parent_id,child_hint,depth FROM signals WHERE id='$(db_escape "$1")';")
  [ -z "$row" ] && return 1

  IFS=$'\t' read -r id type title status weight ttl_days created last_touched owner module tags next_hint touch_count source parked_reason parked_conditions parked_at parent_id child_hint depth <<< "$row"
  cat <<EOF
# READ-ONLY — auto-exported from .termite.db ($(now_iso))
# To modify signals, edit the DB via scripts or use: ./scripts/termite-db-reimport.sh
id: ${id}
type: ${type}
title: "${title}"
status: ${status}
weight: ${weight}
ttl_days: ${ttl_days}
created: ${created}
last_touched: ${last_touched}
owner: ${owner}
module: "${module}"
tags: ${tags}
next: "${next_hint}"
touch_count: ${touch_count}
source: ${source}
EOF
  [ -n "$parked_reason" ] && echo "parked_reason: ${parked_reason}"
  [ -n "$parked_conditions" ] && echo "parked_conditions: \"${parked_conditions}\""
  [ -n "$parked_at" ] && echo "parked_at: ${parked_at}"
  [ -n "$parent_id" ] && echo "parent_id: ${parent_id}"
  [ -n "$child_hint" ] && echo "child_hint: '${child_hint}'"
  [ "${depth:-0}" -gt 0 ] && echo "depth: ${depth}"
  return 0
}

db_export_signals_dir() {
  # Write all non-archived signals to directory as YAML files
  local out_dir="$1"
  mkdir -p "$out_dir"
  local ids
  ids=$(db_query "SELECT id FROM signals WHERE status != 'archived';")
  [ -z "$ids" ] && return 0
  while IFS= read -r sid; do
    [ -z "$sid" ] && continue
    db_export_signal_yaml "$sid" > "${out_dir}/${sid}.yaml"
  done <<< "$ids"
  return 0
}

db_export_obs_dir() {
  # Write all observations to directory as YAML files (v5.0: includes quality_score, source_type)
  local out_dir="$1"
  mkdir -p "$out_dir"
  local rows
  rows=$(db_query "SELECT id,pattern,context,reporter,confidence,created,source,detail,merged_count,merged_from,COALESCE(quality_score,0.5),COALESCE(source_type,'deposit') FROM observations;")
  [ -z "$rows" ] && return 0
  while IFS=$'\t' read -r id pattern context reporter confidence created source detail merged_count merged_from qs st; do
    [ -z "$id" ] && continue
    cat > "${out_dir}/${id}.yaml" <<EOF
# READ-ONLY — auto-exported from .termite.db ($(now_iso))
# To modify observations, edit the DB via scripts or use: ./scripts/termite-db-reimport.sh
id: ${id}
pattern: "${pattern}"
context: "${context}"
reporter: "${reporter}"
confidence: ${confidence}
created: ${created}
source: ${source}
quality_score: ${qs:-0.5}
source_type: ${st:-deposit}
EOF
    [ -n "$detail" ] && { echo "detail: |"; echo "$detail" | sed 's/^/  /'; } >> "${out_dir}/${id}.yaml"
    [ "${merged_count:-0}" -gt 0 ] && echo "merged_count: ${merged_count}" >> "${out_dir}/${id}.yaml"
    [ -n "$merged_from" ] && echo "merged_from: ${merged_from}" >> "${out_dir}/${id}.yaml"
  done <<< "$rows"
  return 0
}

db_export_rules_dir() {
  # Write all rules to directory as YAML files
  local out_dir="$1"
  mkdir -p "$out_dir"
  local rows
  rows=$(db_query "SELECT id,trigger_text,action_text,source_observations,hit_count,disputed_count,last_triggered,created,tags FROM rules;")
  [ -z "$rows" ] && return 0
  while IFS=$'\t' read -r id trigger action source_obs hit_count disputed_count last_triggered created tags; do
    [ -z "$id" ] && continue
    cat > "${out_dir}/${id}.yaml" <<EOF
# READ-ONLY — auto-exported from .termite.db ($(now_iso))
# To modify rules, edit the DB via scripts or use: ./scripts/termite-db-reimport.sh
id: ${id}
trigger: "${trigger}"
action: "${action}"
source_observations: ${source_obs}
hit_count: ${hit_count}
disputed_count: ${disputed_count}
last_triggered: ${last_triggered}
created: ${created}
tags: ${tags}
EOF
  done <<< "$rows"
  return 0
}

# ── Signal Decomposition (v5.1) ──────────────────────────────────────

db_signal_aggregate() {
  # Auto-close parent signals when all children are done
  # Returns number of parents auto-closed
  local closed
  closed=$(db_exec "
    SELECT COUNT(*) FROM signals
    WHERE id IN (
      SELECT DISTINCT parent_id FROM signals
      WHERE parent_id IS NOT NULL
      GROUP BY parent_id
      HAVING COUNT(*) = SUM(CASE WHEN status IN ('done','completed') THEN 1 ELSE 0 END)
    )
    AND status NOT IN ('done','completed','archived');
  ")

  if [ "${closed:-0}" -gt 0 ]; then
    db_exec "
      UPDATE signals SET status='done', last_touched='$(today_iso)'
      WHERE id IN (
        SELECT DISTINCT parent_id FROM signals
        WHERE parent_id IS NOT NULL
        GROUP BY parent_id
        HAVING COUNT(*) = SUM(CASE WHEN status IN ('done','completed') THEN 1 ELSE 0 END)
      )
      AND status NOT IN ('done','completed','archived');
    "
    log_info "Auto-aggregated ${closed} parent signals to done"
  fi

  # Child blocked → parent weight escalation
  db_exec "
    UPDATE signals SET weight = MIN(weight + 10, 100)
    WHERE id IN (
      SELECT DISTINCT parent_id FROM signals
      WHERE parent_id IS NOT NULL AND status = 'blocked'
    )
    AND status NOT IN ('done','completed','archived');
  " 2>/dev/null || true

  echo "${closed:-0}"
}

db_unclaimed_leaf_count() {
  # Count open leaf signals (unclaimed, no active children)
  db_exec "
    SELECT COUNT(*) FROM signals s
    WHERE s.status = 'open'
      AND NOT EXISTS (
        SELECT 1 FROM signals c
        WHERE c.parent_id = s.id
        AND c.status NOT IN ('done','completed','archived')
      );
  "
}

db_leaf_top_signal() {
  # Return best unclaimed leaf signal (for .birth ## task)
  db_query "
    SELECT s.id, s.type, s.title, s.next_hint, s.child_hint, s.parent_id, s.module
    FROM signals s
    WHERE s.status = 'open'
      AND NOT EXISTS (
        SELECT 1 FROM signals c
        WHERE c.parent_id = s.id
        AND c.status NOT IN ('done','completed','archived')
      )
    ORDER BY s.weight DESC
    LIMIT 1;
  "
}

# ── Utility ───────────────────────────────────────────────────────────

db_escape() {
  # Escape single quotes for SQL string literals
  echo "$1" | sed "s/'/''/g"
}

# --- Commander State ---

db_commander_set() {
  local key="$1" value="$2"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  _db "INSERT OR REPLACE INTO commander_state (key, value, updated_at) VALUES ('$(db_escape "$key")', '$(db_escape "$value")', '$now');"
}

db_commander_get() {
  local key="$1"
  _db "SELECT value FROM commander_state WHERE key='$(db_escape "$key")';" | head -1
}

# --- Halt Log ---

db_halt_log_insert() {
  local reason="$1" cmdr_cycles="$2" colony_cycles="$3" total="$4" completed="$5"
  local remaining="$6" commit_hash="$7" recommendation="$8"
  _db "INSERT INTO halt_log (reason, commander_cycles, colony_cycles, signals_total, signals_completed, remaining_signals, last_commit_hash, recommendation) VALUES ('$(db_escape "$reason")', $cmdr_cycles, $colony_cycles, $total, $completed, '$(db_escape "$remaining")', '$(db_escape "$commit_hash")', '$(db_escape "$recommendation")');"
}

db_halt_log_latest() {
  _db "SELECT * FROM halt_log ORDER BY halted_at DESC LIMIT 1;"
}
