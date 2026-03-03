#!/usr/bin/env bash
# field-migrate.sh — Migrate pre-v5.0 observation signals to v5.0 format
# Computes quality_score + source_type for old observations.
# Archives low-quality signals (< 0.3) to signals/.archive/observations/.
#
# Usage:
#   ./scripts/field-migrate.sh              # Dry-run: preview only
#   ./scripts/field-migrate.sh --apply      # Execute migration
#   ./scripts/field-migrate.sh --apply --force  # Recompute all (even already migrated)
#   ./scripts/field-migrate.sh --apply O-001 O-003  # Migrate specific signals

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

APPLY=false
FORCE=false
FILTER_IDS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=true; shift ;;
    --force) FORCE=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--apply] [--force] [signal-id ...]"
      echo ""
      echo "  (no flags)    Dry-run: preview migration without changes"
      echo "  --apply       Execute migration (write fields + archive low-quality)"
      echo "  --force       Recompute even for already-migrated signals"
      echo "  signal-id     Only migrate specific observation IDs (e.g. O-001)"
      exit 0
      ;;
    O-*|o-*) FILTER_IDS+=("$1"); shift ;;
    *)
      log_error "Unknown argument: $1"
      echo "Run $0 --help for usage"
      exit 1
      ;;
  esac
done

# ── Constants ────────────────────────────────────────────────────────

ARCHIVE_THRESHOLD="0.3"
ARCHIVE_OBS_DIR="${SIGNALS_DIR}/.archive/observations"

# ── Counters ─────────────────────────────────────────────────────────

total=0
migrated=0
archived=0
skipped=0
trace_count=0
deposit_count=0
score_sum="0.0"

log_info "Signal migration v5.0 — $([ "$APPLY" = true ] && echo "APPLY mode" || echo "DRY-RUN mode")"
echo ""

# ── Main Scan ────────────────────────────────────────────────────────

if [ ! -d "$OBS_DIR" ]; then
  log_info "No observations directory found ($OBS_DIR). Nothing to migrate."
  exit 0
fi

obs_files=()
if [ ${#FILTER_IDS[@]} -gt 0 ]; then
  for fid in "${FILTER_IDS[@]}"; do
    f="${OBS_DIR}/${fid}.yaml"
    if [ -f "$f" ]; then
      obs_files+=("$f")
    else
      log_warn "Signal ${fid} not found at ${f}, skipping"
    fi
  done
else
  for f in "$OBS_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    obs_files+=("$f")
  done
fi

if [ ${#obs_files[@]} -eq 0 ]; then
  log_info "No observation signals to migrate."
  exit 0
fi

if [ "$APPLY" = false ]; then
  echo "=== 信号迁移预览 (v5.0) ==="
else
  echo "=== 执行信号迁移 (v5.0) ==="
fi
echo ""

for obs_file in "${obs_files[@]}"; do
  obs_id=$(yaml_read "$obs_file" "id" || true)
  [ -z "$obs_id" ] && { log_warn "Skipping ${obs_file}: no id field"; continue; }

  total=$((total + 1))

  # Check if already migrated (quality_score may not exist in old signals)
  existing_score=$(yaml_read "$obs_file" "quality_score" || true)
  if [ -n "$existing_score" ] && [ "$existing_score" != "0.5" ] && [ "$FORCE" = false ]; then
    skipped=$((skipped + 1))
    continue
  fi

  # Read fields (|| true guards for pipefail when fields are missing)
  pattern=$(yaml_read "$obs_file" "pattern" || true)
  context=$(yaml_read "$obs_file" "context" || true)
  detail=$(yaml_read_block "$obs_file" "detail" || true)

  # Compute v5.0 fields
  score=$(compute_quality_score "$pattern" "${context:-unknown}" "${detail:-}")
  stype=$(classify_source_type "$pattern" "${context:-unknown}")

  # Update counters
  score_sum=$(awk "BEGIN { printf \"%.2f\", ${score_sum} + ${score} }")
  if [ "$stype" = "trace" ]; then
    trace_count=$((trace_count + 1))
  else
    deposit_count=$((deposit_count + 1))
  fi

  # Determine action
  should_archive=$(awk "BEGIN { print (${score} < ${ARCHIVE_THRESHOLD}) ? 1 : 0 }")

  if [ "$APPLY" = true ]; then
    if [ "$should_archive" -eq 1 ]; then
      # Write fields before archiving (so archive has v5.0 data)
      yaml_write "$obs_file" "quality_score" "$score"
      yaml_write "$obs_file" "source_type" "$stype"
      # Archive
      mkdir -p "$ARCHIVE_OBS_DIR"
      mv "$obs_file" "${ARCHIVE_OBS_DIR}/$(basename "$obs_file")"
      archived=$((archived + 1))
      printf "  → %-8s score=%-5s → %s\n" "$obs_id" "$score" "signals/.archive/observations/"
    else
      # Write v5.0 fields
      yaml_write "$obs_file" "quality_score" "$score"
      yaml_write "$obs_file" "source_type" "$stype"
      migrated=$((migrated + 1))
      printf "  ✓ %-8s score=%-5s type=%s\n" "$obs_id" "$score" "$stype"
    fi
  else
    if [ "$should_archive" -eq 1 ]; then
      printf "  %-8s score=%-5s type=%-8s [→ 归档]\n" "$obs_id" "$score" "$stype"
    else
      printf "  %-8s score=%-5s type=%-8s [保留]\n" "$obs_id" "$score" "$stype"
    fi
  fi
done

# ── DB Migration (if DB exists) ──────────────────────────────────────

db_updated=0
if [ "$APPLY" = true ] && has_db && has_sqlite; then
  source "${SCRIPT_DIR}/termite-db.sh"
  db_ensure

  log_info "Updating DB records..."

  if [ "$FORCE" = true ]; then
    where_extra=""
  else
    where_extra="AND (quality_score IS NULL OR quality_score = 0.5)"
  fi

  for obs_file in "${obs_files[@]}"; do
    obs_id=$(yaml_read "$obs_file" "id" || true)
    [ -z "$obs_id" ] && continue

    # Read computed fields from YAML (or archived copy)
    local_file="$obs_file"
    archived_file="${ARCHIVE_OBS_DIR}/$(basename "$obs_file")"
    [ -f "$archived_file" ] && local_file="$archived_file"

    score=$(yaml_read "$local_file" "quality_score" || true)
    stype=$(yaml_read "$local_file" "source_type" || true)
    [ -z "$score" ] && continue

    # Update quality_score and source_type
    db_exec "UPDATE observations SET quality_score = ${score}, source_type = '$(db_escape "${stype:-deposit}")' WHERE id = '$(db_escape "$obs_id")' ${where_extra};" 2>/dev/null || true

    # Mark archived in DB
    should_archive=$(awk "BEGIN { print (${score} < ${ARCHIVE_THRESHOLD}) ? 1 : 0 }")
    if [ "$should_archive" -eq 1 ]; then
      db_exec "UPDATE observations SET quality = 'archived' WHERE id = '$(db_escape "$obs_id")';" 2>/dev/null || true
    fi

    db_updated=$((db_updated + 1))
  done

  log_info "DB updated: ${db_updated} records"
fi

# ── Summary ──────────────────────────────────────────────────────────

computed=$((total - skipped))

echo ""
if [ "$APPLY" = true ]; then
  echo "--- 完成 ---"
  printf "  迁移: %d  归档: %d  跳过: %d\n" "$migrated" "$archived" "$skipped"
  printf "  trace: %d  deposit: %d\n" "$trace_count" "$deposit_count"
  if [ "$computed" -gt 0 ]; then
    avg=$(awk "BEGIN { printf \"%.2f\", ${score_sum} / ${computed} }")
    printf "  平均 quality_score: %s\n" "$avg"
  fi
else
  echo "--- 汇总 ---"
  printf "  总计: %d 个 observation\n" "$total"
  printf "  将迁移: %d  将跳过: %d\n" "$computed" "$skipped"
  printf "  trace: %d  deposit: %d\n" "$trace_count" "$deposit_count"
  if [ "$computed" -gt 0 ]; then
    avg=$(awk "BEGIN { printf \"%.2f\", ${score_sum} / ${computed} }")
    printf "  平均 quality_score: %s\n" "$avg"
  fi
  echo ""
  echo "运行 $0 --apply 执行迁移"
fi
