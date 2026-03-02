#!/usr/bin/env bash
# field-lib.sh — Termite Protocol shared library
# Source this file from all field-*.sh scripts.
# No yq/jq dependency. POSIX-compatible (bash + zsh).

set -euo pipefail

# ── Directory Constants ──────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SIGNALS_DIR="${PROJECT_ROOT}/signals"
ACTIVE_DIR="${SIGNALS_DIR}/active"
OBS_DIR="${SIGNALS_DIR}/observations"
RULES_DIR="${SIGNALS_DIR}/rules"
CLAIMS_DIR="${SIGNALS_DIR}/claims"
ARCHIVE_DIR="${SIGNALS_DIR}/archive"

BLACKBOARD="${PROJECT_ROOT}/BLACKBOARD.md"
WIP_FILE="${PROJECT_ROOT}/WIP.md"
ALARM_FILE="${PROJECT_ROOT}/ALARM.md"
BIRTH_FILE="${PROJECT_ROOT}/.birth"
BREATH_FILE="${PROJECT_ROOT}/.field-breath"
PHEROMONE_FILE="${PROJECT_ROOT}/.pheromone"
TERMITE_DB="${PROJECT_ROOT}/.termite.db"
AGENT_ID=""  # Set by field-arrive.sh after registration

# ── Configurable Thresholds ─────────────────────────────────────────

DECAY_FACTOR="${TERMITE_DECAY_FACTOR:-0.98}"
DECAY_THRESHOLD="${TERMITE_DECAY_THRESHOLD:-5}"
ESCALATE_THRESHOLD="${TERMITE_ESCALATE_THRESHOLD:-50}"
PROMOTION_THRESHOLD="${TERMITE_PROMOTION_THRESHOLD:-3}"
RULE_ARCHIVE_DAYS="${TERMITE_RULE_ARCHIVE_DAYS:-60}"
WIP_FRESHNESS_DAYS="${TERMITE_WIP_FRESHNESS_DAYS:-14}"
EXPLORE_MAX_DAYS="${TERMITE_EXPLORE_MAX_DAYS:-14}"
CLAIM_TTL_HOURS="${TERMITE_CLAIM_TTL_HOURS:-24}"
BREATH_MAX_AGE_MIN="${TERMITE_BREATH_MAX_AGE_MIN:-30}"
SCOUT_BREATH_INTERVAL="${TERMITE_SCOUT_BREATH_INTERVAL:-5}"
BOUNDARY_TOUCH_THRESHOLD="${TERMITE_BOUNDARY_TOUCH_THRESHOLD:-3}"
UNCOMMITTED_LINES_LIMIT="${TERMITE_UNCOMMITTED_LINES_LIMIT:-50}"

# ── Logging ──────────────────────────────────────────────────────────

log_info()  { echo "[termite:info]  $*" >&2; }
log_warn()  { echo "[termite:warn]  $*" >&2; }
log_error() { echo "[termite:error] $*" >&2; }

# ── Directory Setup ──────────────────────────────────────────────────

ensure_signal_dirs() {
  mkdir -p "$ACTIVE_DIR" "$OBS_DIR" "$RULES_DIR" "$CLAIMS_DIR"
  mkdir -p "$ARCHIVE_DIR/done-$(date +%Y-%m)" "$ARCHIVE_DIR/promoted" "$ARCHIVE_DIR/rules" "$ARCHIVE_DIR/merged"
}

has_signal_dir() {
  [ -d "$SIGNALS_DIR" ] && [ -d "$ACTIVE_DIR" ]
}

# ── SQLite Detection & Bridge ─────────────────────────────────────────

has_db() {
  [ -f "$TERMITE_DB" ]
}

has_sqlite() {
  command -v sqlite3 >/dev/null 2>&1
}

yaml_newer_than_db() {
  # Check if any YAML file in signals/ is newer than .termite.db
  # Returns 0 (true) if YAML edits detected, 1 otherwise
  [ -f "$TERMITE_DB" ] || return 1
  local db_mtime
  db_mtime=$(stat -f "%m" "$TERMITE_DB" 2>/dev/null || stat -c "%Y" "$TERMITE_DB" 2>/dev/null || echo 0)
  for dir in "$ACTIVE_DIR" "$OBS_DIR" "$RULES_DIR"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.yaml; do
      [ -f "$f" ] || continue
      local f_mtime
      f_mtime=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null || echo 0)
      if [ "$f_mtime" -gt "$db_mtime" ]; then
        return 0
      fi
    done
  done
  return 1
}

ensure_db() {
  # Create or migrate DB. Call early in any entry-point script.
  if [ -f "$TERMITE_DB" ]; then
    # Warn if YAML files were edited after last DB write
    if yaml_newer_than_db; then
      log_warn "YAML files are newer than .termite.db — manual edits detected"
      log_warn "These edits are NOT reflected in the DB (runtime source of truth)"
      log_warn "Run ./scripts/termite-db-reimport.sh to sync YAML→DB"
    fi
    return 0
  fi
  if ! has_sqlite; then
    log_warn "sqlite3 not found — falling back to YAML mode"
    return 1
  fi
  # Auto-migrate if YAML signals exist, otherwise create fresh
  if [ -d "$ACTIVE_DIR" ] && ls "$ACTIVE_DIR"/*.yaml >/dev/null 2>&1; then
    "${SCRIPT_DIR}/termite-db-migrate.sh" 2>&1 | while IFS= read -r l; do log_info "  migrate: $l"; done || true
  else
    source "${SCRIPT_DIR}/termite-db.sh"
    db_ensure
  fi
}

generate_agent_id() {
  echo "termite-$(date +%s)-$$"
}

# ── YAML Read/Write (flat key: value only) ───────────────────────────

yaml_read() {
  # Usage: yaml_read <file> <field>
  # Reads a flat YAML field. Handles simple values and quoted strings.
  local file="$1" field="$2"
  if [ ! -f "$file" ]; then
    echo ""
    return 1
  fi
  grep -m1 "^${field}:" "$file" 2>/dev/null | sed "s/^${field}:[[:space:]]*//" | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/'
}

yaml_write() {
  # Usage: yaml_write <file> <field> <value>
  # Writes or updates a flat YAML field.
  local file="$1" field="$2" value="$3"
  if [ ! -f "$file" ]; then
    echo "${field}: ${value}" > "$file"
    return 0
  fi
  if grep -q "^${field}:" "$file" 2>/dev/null; then
    # Update existing field
    local escaped_value
    escaped_value=$(echo "$value" | sed 's/[&/\]/\\&/g')
    sed -i.bak "s|^${field}:.*|${field}: ${escaped_value}|" "$file"
    rm -f "${file}.bak"
  else
    # Append new field
    echo "${field}: ${value}" >> "$file"
  fi
}

yaml_read_list() {
  # Usage: yaml_read_list <file> <field>
  # Reads a YAML inline list field like: tags: [a, b, c]
  local file="$1" field="$2"
  grep -m1 "^${field}:" "$file" 2>/dev/null \
    | sed "s/^${field}:[[:space:]]*//" \
    | tr -d '[]' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# ── Telemetry Configuration ──────────────────────────────────────────

TELEMETRY_FILE="${PROJECT_ROOT}/.termite-telemetry.yaml"
UPSTREAM_CACHE="${PROJECT_ROOT}/.termite-upstream-check"

telemetry_enabled() {
  # Returns 0 if telemetry is fully opted-in (enabled + accepted)
  [ -f "$TELEMETRY_FILE" ] || return 1
  local enabled accepted
  enabled=$(yaml_read "$TELEMETRY_FILE" "enabled")
  accepted=$(yaml_read "$TELEMETRY_FILE" "accepted")
  [ "$enabled" = "true" ] && [ "$accepted" = "true" ]
}

telemetry_needs_acceptance() {
  # Returns 0 if enabled but not yet accepted
  [ -f "$TELEMETRY_FILE" ] || return 1
  local enabled accepted
  enabled=$(yaml_read "$TELEMETRY_FILE" "enabled")
  accepted=$(yaml_read "$TELEMETRY_FILE" "accepted")
  [ "$enabled" = "true" ] && [ "$accepted" != "true" ]
}

telemetry_upstream_repo() {
  local repo
  repo=$(yaml_read "$TELEMETRY_FILE" "upstream_repo" 2>/dev/null || true)
  echo "${repo:-billbai-longarena/Termite-Protocol}"
}

telemetry_project_name() {
  local name
  name=$(basename "$PROJECT_ROOT")
  local anon
  anon=$(yaml_read "$TELEMETRY_FILE" "anonymize_project" 2>/dev/null || echo "false")
  if [ "$anon" = "true" ]; then
    echo "$name" | shasum -a 256 | cut -c1-8
  else
    echo "$name"
  fi
}

telemetry_submit_frequency() {
  yaml_read "$TELEMETRY_FILE" "submit_frequency" 2>/dev/null || echo "session-end"
}

telemetry_should_submit() {
  # Check if submission is due based on frequency setting
  telemetry_enabled || return 1
  local freq
  freq=$(telemetry_submit_frequency)
  case "$freq" in
    session-end) return 0 ;;
    manual) return 1 ;;
    weekly)
      local last
      last=$(yaml_read "$TELEMETRY_FILE" "last_submitted" 2>/dev/null || echo "")
      [ -z "$last" ] && return 0
      local age
      age=$(days_since "$last")
      [ "$age" -ge 7 ]
      ;;
    *) return 1 ;;
  esac
}

local_protocol_version() {
  # Extract version from TERMITE_PROTOCOL.md
  local proto_file="${PROJECT_ROOT}/TERMITE_PROTOCOL.md"
  [ -f "$proto_file" ] || { echo "unknown"; return; }
  grep -m1 'termite-protocol:v' "$proto_file" 2>/dev/null \
    | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown"
}

upstream_protocol_version() {
  # Check upstream version with 24h cache
  if [ -f "$UPSTREAM_CACHE" ]; then
    local cache_time
    cache_time=$(yaml_read "$UPSTREAM_CACHE" "checked_at" 2>/dev/null || echo "")
    if [ -n "$cache_time" ]; then
      local cache_age
      cache_age=$(days_since "$cache_time" 2>/dev/null || echo "999")
      if [ "$cache_age" -eq 0 ]; then
        yaml_read "$UPSTREAM_CACHE" "upstream_version" 2>/dev/null || echo "unknown"
        return
      fi
    fi
  fi

  local upstream
  upstream=$(telemetry_upstream_repo)
  local version="unknown"

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    version=$(gh api "repos/${upstream}/releases/latest" --jq '.tag_name' 2>/dev/null || echo "")
    if [ -z "$version" ] || [ "$version" = "null" ]; then
      version=$(gh api "repos/${upstream}/contents/templates/TERMITE_PROTOCOL.md" \
        --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null \
        | head -1 \
        | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown")
    fi
  elif command -v curl >/dev/null 2>&1; then
    version=$(curl -fsSL "https://raw.githubusercontent.com/${upstream}/main/templates/TERMITE_PROTOCOL.md" 2>/dev/null \
      | head -1 \
      | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown")
  fi

  # Validate version looks like vN.N (reject garbage from failed API calls)
  if ! echo "$version" | grep -qE '^v[0-9]+\.[0-9]'; then
    version="unknown"
  fi

  if [ "$version" != "unknown" ]; then
    cat > "$UPSTREAM_CACHE" <<CEOF
checked_at: $(today_iso)
upstream_version: ${version}
CEOF
  fi

  echo "$version"
}

# ── Signal Queries ───────────────────────────────────────────────────

list_active_signals() {
  # List all active signal files
  if has_signal_dir; then
    find "$ACTIVE_DIR" -name '*.yaml' -type f 2>/dev/null | sort
  fi
}

list_signals_by_weight() {
  # List active signals sorted by weight (descending), excluding done/completed/archived/parked
  local tmpfile
  tmpfile=$(mktemp)
  while IFS= read -r f; do
    local w s
    w=$(yaml_read "$f" "weight")
    s=$(yaml_read "$f" "status")
    case "$s" in done|completed|archived|parked) continue ;; esac
    [ -n "$w" ] && echo "$w $f"
  done < <(list_active_signals) | sort -rn > "$tmpfile"
  cat "$tmpfile"
  rm -f "$tmpfile"
}

count_active_signals() {
  # Count signals excluding done/completed/archived
  local count=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local s; s=$(yaml_read "$f" "status")
    case "$s" in done|completed|archived) continue ;; esac
    count=$((count + 1))
  done < <(list_active_signals)
  echo "$count"
}

count_high_weight_holes() {
  # Count HOLE signals with weight >= escalate_threshold, excluding done/completed/archived/parked
  local count=0
  while IFS= read -r f; do
    local t w s
    t=$(yaml_read "$f" "type")
    w=$(yaml_read "$f" "weight")
    s=$(yaml_read "$f" "status")
    case "$s" in done|completed|archived|parked) continue ;; esac
    if [ "$t" = "HOLE" ] && [ "${w:-0}" -ge "$ESCALATE_THRESHOLD" ]; then
      count=$((count + 1))
    fi
  done < <(list_active_signals)
  echo "$count"
}

count_parked_signals() {
  local count=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local s; s=$(yaml_read "$f" "status")
    [ "$s" = "parked" ] && count=$((count + 1))
  done < <(list_active_signals)
  echo "$count"
}

count_high_weight_holes_excluding_parked() {
  local count=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local t w s
    t=$(yaml_read "$f" "type"); w=$(yaml_read "$f" "weight"); s=$(yaml_read "$f" "status")
    if [ "$t" = "HOLE" ] && [ "${w:-0}" -ge "$ESCALATE_THRESHOLD" ] && [ "$s" != "parked" ]; then
      count=$((count + 1))
    fi
  done < <(list_active_signals)
  echo "$count"
}

get_signal_touch_count() {
  local tc; tc=$(yaml_read "$1" "touch_count"); echo "${tc:-0}"
}

increment_signal_touch() {
  local current; current=$(get_signal_touch_count "$1")
  yaml_write "$1" "touch_count" "$((current + 1))"
}

park_signal() {
  local signal_file="$1" reason="$2" conditions="$3"
  yaml_write "$signal_file" "status" "parked"
  yaml_write "$signal_file" "parked_reason" "$reason"
  yaml_write "$signal_file" "parked_conditions" "$conditions"
  yaml_write "$signal_file" "parked_at" "$(today_iso)"
  local w; w=$(yaml_read "$signal_file" "weight")
  local reduced=$((ESCALATE_THRESHOLD - 10))
  [ "${w:-0}" -gt "$reduced" ] && yaml_write "$signal_file" "weight" "$reduced"
}

list_rules() {
  # List all rule files
  if [ -d "$RULES_DIR" ]; then
    find "$RULES_DIR" -name '*.yaml' -type f 2>/dev/null | sort
  fi
}

list_observations() {
  # List all observation files
  if [ -d "$OBS_DIR" ]; then
    find "$OBS_DIR" -name '*.yaml' -type f 2>/dev/null | sort
  fi
}

# ── BLACKBOARD.md Fallback Parsing ───────────────────────────────────

parse_blackboard_signals() {
  # Extract signal-like entries from BLACKBOARD.md when signals/ doesn't exist.
  # Looks for markdown patterns: ## HOLE: ..., ## EXPLORE: ..., etc.
  # or table rows: | S-xxx | TYPE | title | weight | status |
  if [ ! -f "$BLACKBOARD" ]; then
    return 0
  fi
  # Extract from table rows (| id | type | title | weight | status |)
  grep -E '^\|[[:space:]]*S-[0-9]+' "$BLACKBOARD" 2>/dev/null | while IFS='|' read -r _ id type title weight status _rest; do
    id=$(echo "$id" | tr -d ' ')
    type=$(echo "$type" | tr -d ' ')
    title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    weight=$(echo "$weight" | tr -d ' ')
    status=$(echo "$status" | tr -d ' ')
    echo "${weight:-0} ${id}:${type}:${status}:${title}"
  done | sort -rn
}

# ── Environment Sensing ──────────────────────────────────────────────

check_alarm() {
  # Returns 0 (true) if ALARM.md exists and is non-empty
  [ -f "$ALARM_FILE" ] && [ -s "$ALARM_FILE" ]
}

check_wip() {
  # Returns: "fresh", "stale", or "absent"
  if [ ! -f "$WIP_FILE" ]; then
    echo "absent"
    return
  fi
  local mod_epoch now_epoch age_days
  mod_epoch=$(stat -f "%m" "$WIP_FILE" 2>/dev/null || stat -c "%Y" "$WIP_FILE" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  age_days=$(( (now_epoch - mod_epoch) / 86400 ))
  if [ "$age_days" -lt "$WIP_FRESHNESS_DAYS" ]; then
    echo "fresh"
  else
    echo "stale"
  fi
}

check_build() {
  # Heuristic: check common CI status indicators
  # Returns: "pass", "fail", or "unknown"
  # Check for common CI result files
  for f in ".ci-status" "ci-status.txt"; do
    if [ -f "${PROJECT_ROOT}/$f" ]; then
      local status
      status=$(cat "${PROJECT_ROOT}/$f" | tr '[:upper:]' '[:lower:]' | head -1)
      case "$status" in
        *pass*|*success*|*ok*) echo "pass"; return ;;
        *fail*|*error*) echo "fail"; return ;;
      esac
    fi
  done
  # Check last test run exit code if available
  if [ -f "${PROJECT_ROOT}/.last-test-exit" ]; then
    local code
    code=$(cat "${PROJECT_ROOT}/.last-test-exit" | head -1)
    if [ "$code" = "0" ]; then echo "pass"; return; fi
    echo "fail"; return
  fi
  echo "unknown"
}

check_breath_freshness() {
  # Returns 0 if .field-breath exists and is fresh (< BREATH_MAX_AGE_MIN minutes)
  if [ ! -f "$BREATH_FILE" ]; then
    return 1
  fi
  local mod_epoch now_epoch age_min
  mod_epoch=$(stat -f "%m" "$BREATH_FILE" 2>/dev/null || stat -c "%Y" "$BREATH_FILE" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  age_min=$(( (now_epoch - mod_epoch) / 60 ))
  [ "$age_min" -lt "$BREATH_MAX_AGE_MIN" ]
}

# ── Git Utilities ────────────────────────────────────────────────────

current_branch() {
  git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

current_commit_short() {
  git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "0000000"
}

count_uncommitted_lines() {
  if [ ! -d "${PROJECT_ROOT}/.git" ]; then echo "0"; return; fi
  local staged unstaged
  staged=$(git -C "$PROJECT_ROOT" diff --cached --numstat 2>/dev/null | awk '{s+=$1+$2} END {print s+0}')
  unstaged=$(git -C "$PROJECT_ROOT" diff --numstat 2>/dev/null | awk '{s+=$1+$2} END {print s+0}')
  echo $((staged + unstaged))
}

breath_age_minutes() {
  if [ ! -f "$BREATH_FILE" ]; then echo "unknown"; return; fi
  local mod_epoch now_epoch
  mod_epoch=$(stat -f "%m" "$BREATH_FILE" 2>/dev/null || stat -c "%Y" "$BREATH_FILE" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  echo $(( (now_epoch - mod_epoch) / 60 ))
}

detect_platform() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] || [ -n "${CLAUDE_ENV_FILE:-}" ]; then echo "claude-code"; return; fi
  if [ -n "${CODEX_CLI:-}" ]; then echo "codex-cli"; return; fi
  if [ -f "${PROJECT_ROOT}/AGENTS.md" ] && [ ! -f "${PROJECT_ROOT}/CLAUDE.md" ]; then echo "codex-cli"; return; fi
  echo "unknown"
}

signal_concentration() {
  # Returns: "concentrated" | "balanced" | "dispersed"
  # Based on module-field distribution of active non-parked signals.
  local total=0 max_count=0
  if has_db && has_sqlite; then
    total=$(db_exec "SELECT COUNT(*) FROM signals WHERE status NOT IN ('archived','parked');")
    if [ "${total:-0}" -le 2 ]; then echo "dispersed"; return; fi
    max_count=$(db_exec "SELECT COUNT(*) as c FROM signals WHERE status NOT IN ('archived','parked') GROUP BY COALESCE(NULLIF(module,''),'_none_') ORDER BY c DESC LIMIT 1;")
  elif has_signal_dir; then
    local tmpfile; tmpfile=$(mktemp)
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      local s; s=$(yaml_read "$f" "status")
      [ "$s" = "parked" ] && continue
      local m; m=$(yaml_read "$f" "module")
      echo "${m:-_none_}" >> "$tmpfile"
      total=$((total + 1))
    done < <(list_active_signals)
    if [ "$total" -le 2 ]; then rm -f "$tmpfile"; echo "dispersed"; return; fi
    max_count=$(sort "$tmpfile" | uniq -c | sort -rn | head -1 | awk '{print $1}')
    rm -f "$tmpfile"
  else
    echo "balanced"; return
  fi
  [ "${total:-0}" -eq 0 ] && { echo "dispersed"; return; }
  # max_share = max_count / total (percentage, integer)
  local max_share=$((max_count * 100 / total))
  if [ "$max_share" -ge 60 ]; then echo "concentrated"
  elif [ "$max_share" -le 30 ]; then echo "dispersed"
  else echo "balanced"
  fi
}

termite_signature_ratio() {
  # Ratio of recent N commits that have [termite:...] signature
  local n="${1:-20}"
  local total signed
  total=$(git -C "$PROJECT_ROOT" log --oneline -n "$n" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total" -eq 0 ]; then
    echo "0.00"
    return
  fi
  signed=$(git -C "$PROJECT_ROOT" log --oneline -n "$n" 2>/dev/null | grep -c '\[termite:' || true)
  # Calculate ratio with 2 decimal places using awk
  awk "BEGIN { printf \"%.2f\", ${signed}/${total} }"
}

count_consecutive_caste() {
  # Read .pheromone git history, count consecutive same-caste sessions
  # Returns: "count last_caste"
  local max_depth="${1:-10}"
  local count=0 last_caste=""
  local commits
  commits=$(git -C "$PROJECT_ROOT" log --format="%H" -n "$max_depth" -- ".pheromone" 2>/dev/null || true)
  if [ -z "$commits" ]; then
    if [ -f "$PHEROMONE_FILE" ]; then
      last_caste=$(grep '"caste"' "$PHEROMONE_FILE" 2>/dev/null | sed 's/.*"caste"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
      [ -n "$last_caste" ] && count=1
    fi
    echo "${count} ${last_caste:-unknown}"; return
  fi
  for h in $commits; do
    local c; c=$(git -C "$PROJECT_ROOT" show "${h}:.pheromone" 2>/dev/null | grep '"caste"' | sed 's/.*"caste"[[:space:]]*:[[:space:]]*"//' | tr -d '",')
    [ -z "$c" ] && continue
    if [ -z "$last_caste" ]; then last_caste="$c"; count=1
    elif [ "$c" = "$last_caste" ]; then count=$((count + 1))
    else break; fi
  done
  echo "${count} ${last_caste:-unknown}"
}

# ── Date Utilities ───────────────────────────────────────────────────

today_iso() {
  date +%Y-%m-%d
}

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

days_since() {
  # Usage: days_since <YYYY-MM-DD>
  local target="$1"
  local target_epoch now_epoch
  # macOS date vs GNU date
  if date -j -f "%Y-%m-%d" "$target" "+%s" >/dev/null 2>&1; then
    target_epoch=$(date -j -f "%Y-%m-%d" "$target" "+%s")
  else
    target_epoch=$(date -d "$target" "+%s" 2>/dev/null || echo 0)
  fi
  now_epoch=$(date +%s)
  echo $(( (now_epoch - target_epoch) / 86400 ))
}

# ── Next ID Generation ───────────────────────────────────────────────

next_signal_id() {
  local prefix="${1:-S}"
  local dir
  case "$prefix" in
    S) dir="$ACTIVE_DIR" ;;
    O) dir="$OBS_DIR" ;;
    R) dir="$RULES_DIR" ;;
    *) dir="$ACTIVE_DIR" ;;
  esac
  local max=0
  if [ -d "$dir" ]; then
    for f in "$dir"/${prefix}-*.yaml; do
      [ -f "$f" ] || continue
      local num
      num=$(basename "$f" .yaml | sed "s/^${prefix}-0*//" | sed 's/^$/0/')
      if [ "$num" -gt "$max" ] 2>/dev/null; then
        max=$num
      fi
    done
  fi
  printf "%s-%03d" "$prefix" $((max + 1))
}
