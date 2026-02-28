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

ensure_db() {
  # Create or migrate DB. Call early in any entry-point script.
  if [ -f "$TERMITE_DB" ]; then
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

# ── Signal Queries ───────────────────────────────────────────────────

list_active_signals() {
  # List all active signal files
  if has_signal_dir; then
    find "$ACTIVE_DIR" -name '*.yaml' -type f 2>/dev/null | sort
  fi
}

list_signals_by_weight() {
  # List active signals sorted by weight (descending)
  local tmpfile
  tmpfile=$(mktemp)
  while IFS= read -r f; do
    local w
    w=$(yaml_read "$f" "weight")
    [ -n "$w" ] && echo "$w $f"
  done < <(list_active_signals) | sort -rn > "$tmpfile"
  cat "$tmpfile"
  rm -f "$tmpfile"
}

count_active_signals() {
  list_active_signals | wc -l | tr -d ' '
}

count_high_weight_holes() {
  # Count HOLE signals with weight >= escalate_threshold
  local count=0
  while IFS= read -r f; do
    local t w
    t=$(yaml_read "$f" "type")
    w=$(yaml_read "$f" "weight")
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
