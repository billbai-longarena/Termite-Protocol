#!/usr/bin/env bash
# field-claim.sh — Concurrent signal claiming with mutual exclusion
# Subcommands: claim, release, check, list, expired
# Uses file-based locks with git optimistic concurrency.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

usage() {
  cat <<'USAGE'
Usage: field-claim.sh <command> [args]

Commands:
  claim   <signal-id> <operation> <owner>   Claim a signal for work
  release <signal-id> <operation>           Release a claim
  check   <signal-id> <operation>           Check if operation is blocked
  list                                      List all active claims
  expired                                   Show and clean up expired claims

Operations: work, audit, review
Mutual exclusion: work⊥audit, review never blocks.
USAGE
  exit 1
}

# ── Mutual Exclusion Check ───────────────────────────────────────────

is_compatible() {
  # Usage: is_compatible <existing_op> <requested_op>
  # Returns 0 if compatible, 1 if blocked
  local existing="$1" requested="$2"
  # review never blocks
  [ "$requested" = "review" ] && return 0
  [ "$existing" = "review" ] && return 0
  # work and audit block each other
  return 1
}

# ── Claim ────────────────────────────────────────────────────────────

do_claim() {
  local signal_id="$1" op="$2" owner="$3"

  # DB-first path: atomic claim via SQLite
  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    db_claim_create "$signal_id" "$op" "$owner" "$(current_commit_short)" "$CLAIM_TTL_HOURS" \
      || { log_error "Claim blocked or failed"; exit 1; }
    log_info "Claimed ${signal_id} for ${op} by ${owner} (atomic)"
    return
  fi

  # YAML fallback
  ensure_signal_dirs

  # Validate operation
  case "$op" in
    work|audit|review) ;;
    *) log_error "Invalid operation: $op (must be work, audit, or review)"; exit 1 ;;
  esac

  local lock_file="${CLAIMS_DIR}/${signal_id}.${op}.lock"

  # Check for conflicting claims
  for existing_lock in "$CLAIMS_DIR"/${signal_id}.*.lock; do
    [ -f "$existing_lock" ] || continue
    local existing_op
    existing_op=$(basename "$existing_lock" .lock | sed "s/^${signal_id}\\.//")
    if ! is_compatible "$existing_op" "$op"; then
      local existing_owner
      existing_owner=$(yaml_read "$existing_lock" "owner")
      log_error "Blocked: ${signal_id} already has ${existing_op} claim by ${existing_owner}"
      exit 1
    fi
  done

  # Check if same claim already exists
  if [ -f "$lock_file" ]; then
    local current_owner
    current_owner=$(yaml_read "$lock_file" "owner")
    log_error "Already claimed by ${current_owner}"
    exit 1
  fi

  # Write claim lock
  cat > "$lock_file" <<EOF
signal: ${signal_id}
operation: ${op}
owner: ${owner}
base_commit: $(current_commit_short)
claimed_at: $(now_iso)
ttl_hours: ${CLAIM_TTL_HOURS}
EOF

  # Update signal status
  local signal_file="${ACTIVE_DIR}/${signal_id}.yaml"
  if [ -f "$signal_file" ]; then
    yaml_write "$signal_file" "status" "claimed"
    yaml_write "$signal_file" "owner" "$owner"
    yaml_write "$signal_file" "last_touched" "$(today_iso)"
    increment_signal_touch "$signal_file"
  fi

  log_info "Claimed ${signal_id} for ${op} by ${owner}"

  # Git optimistic concurrency (if in git repo)
  if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" add "$lock_file" 2>/dev/null || true
    if [ -f "$signal_file" ]; then
      git -C "$PROJECT_ROOT" add "$signal_file" 2>/dev/null || true
    fi
  fi
}

# ── Release ──────────────────────────────────────────────────────────

do_release() {
  local signal_id="$1" op="$2"

  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    db_claim_release "$signal_id" "$op"
    log_info "Released ${signal_id} ${op} claim (DB)"
    return
  fi

  local lock_file="${CLAIMS_DIR}/${signal_id}.${op}.lock"

  if [ ! -f "$lock_file" ]; then
    log_warn "No ${op} claim found for ${signal_id}"
    return 0
  fi

  rm -f "$lock_file"

  # If no more claims, reset signal status
  local remaining=0
  for f in "$CLAIMS_DIR"/${signal_id}.*.lock; do
    [ -f "$f" ] && remaining=$((remaining + 1))
  done
  if [ "$remaining" -eq 0 ]; then
    local signal_file="${ACTIVE_DIR}/${signal_id}.yaml"
    if [ -f "$signal_file" ]; then
      yaml_write "$signal_file" "status" "open"
      yaml_write "$signal_file" "owner" "unassigned"
    fi
  fi

  log_info "Released ${signal_id} ${op} claim"
}

# ── Check ────────────────────────────────────────────────────────────

do_check() {
  local signal_id="$1" op="$2"

  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    db_claim_check "$signal_id" "$op"
    return
  fi

  for existing_lock in "$CLAIMS_DIR"/${signal_id}.*.lock; do
    [ -f "$existing_lock" ] || continue
    local existing_op
    existing_op=$(basename "$existing_lock" .lock | sed "s/^${signal_id}\\.//")
    if ! is_compatible "$existing_op" "$op"; then
      echo "blocked"
      return 0
    fi
  done
  echo "available"
}

# ── List ─────────────────────────────────────────────────────────────

do_list() {
  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    local result
    result=$(db_claim_list)
    if [ -z "$result" ]; then
      echo "No active claims"
    else
      echo "$result"
    fi
    return
  fi

  if [ ! -d "$CLAIMS_DIR" ]; then
    echo "No claims directory"
    return 0
  fi
  local count=0
  for lock_file in "$CLAIMS_DIR"/*.lock; do
    [ -f "$lock_file" ] || continue
    count=$((count + 1))
    local sig op owner claimed
    sig=$(yaml_read "$lock_file" "signal")
    op=$(yaml_read "$lock_file" "operation")
    owner=$(yaml_read "$lock_file" "owner")
    claimed=$(yaml_read "$lock_file" "claimed_at")
    echo "${sig}  ${op}  ${owner}  ${claimed}"
  done
  if [ "$count" -eq 0 ]; then
    echo "No active claims"
  fi
}

# ── Expired ──────────────────────────────────────────────────────────

do_expired() {
  if has_db; then
    source "${SCRIPT_DIR}/termite-db.sh"
    db_claim_expire
    return
  fi

  if [ ! -d "$CLAIMS_DIR" ]; then
    return 0
  fi
  local now_epoch cleaned=0
  now_epoch=$(date +%s)

  for lock_file in "$CLAIMS_DIR"/*.lock; do
    [ -f "$lock_file" ] || continue
    local claimed_at ttl_h claim_epoch expiry
    claimed_at=$(yaml_read "$lock_file" "claimed_at")
    ttl_h=$(yaml_read "$lock_file" "ttl_hours")
    [ -z "$claimed_at" ] && continue
    ttl_h="${ttl_h:-$CLAIM_TTL_HOURS}"

    if claim_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$claimed_at" "+%s" 2>/dev/null) || \
       claim_epoch=$(date -d "$claimed_at" "+%s" 2>/dev/null); then
      expiry=$((claim_epoch + ttl_h * 3600))
      if [ "$now_epoch" -gt "$expiry" ]; then
        local sig op
        sig=$(yaml_read "$lock_file" "signal")
        op=$(yaml_read "$lock_file" "operation")
        log_warn "Expired claim: ${sig} ${op} — removing"
        rm -f "$lock_file"
        # Reset signal status
        local signal_file="${ACTIVE_DIR}/${sig}.yaml"
        if [ -f "$signal_file" ]; then
          yaml_write "$signal_file" "status" "stale"
          yaml_write "$signal_file" "owner" "unassigned"
        fi
        cleaned=$((cleaned + 1))
      fi
    fi
  done
  log_info "Expired claims cleaned: ${cleaned}"
}

# ── Main ─────────────────────────────────────────────────────────────

[ $# -lt 1 ] && usage

cmd="$1"
shift

case "$cmd" in
  claim)
    [ $# -lt 3 ] && { log_error "Usage: claim <signal-id> <operation> <owner>"; exit 1; }
    do_claim "$1" "$2" "$3"
    ;;
  release)
    [ $# -lt 2 ] && { log_error "Usage: release <signal-id> <operation>"; exit 1; }
    do_release "$1" "$2"
    ;;
  check)
    [ $# -lt 2 ] && { log_error "Usage: check <signal-id> <operation>"; exit 1; }
    do_check "$1" "$2"
    ;;
  list)
    do_list
    ;;
  expired)
    do_expired
    ;;
  *)
    usage
    ;;
esac
