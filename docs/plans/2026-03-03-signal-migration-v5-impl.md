# Signal Migration v5.0 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `field-migrate.sh` that migrates old observation signals to v5.0 format (quality_score + source_type), with dry-run preview and low-quality signal archiving.

**Architecture:** Independent bash script sourcing `field-lib.sh` for existing utility functions. Two-phase execution: dry-run (default) shows preview, `--apply` executes changes. YAML and DB dual-write. Signals scoring below 0.3 are archived to `signals/.archive/observations/`.

**Tech Stack:** Bash (set -euo pipefail), SQLite3, existing field-lib.sh functions (compute_quality_score, classify_source_type, yaml_read, yaml_write, db_*)

---

### Task 1: Add yaml_read_block() to field-lib.sh

Existing `yaml_read()` only reads single-line values. Multi-line `detail: |` blocks (like O-003 in 0227/) return `|` instead of the actual content. The migration script needs the full detail text to compute accurate quality scores.

**Files:**
- Modify: `templates/scripts/field-lib.sh:119-150` (YAML Read/Write section)

**Step 1: Add yaml_read_block() after yaml_write()**

Insert after line 150 (end of `yaml_write`), before `yaml_read_list`:

```bash
yaml_read_block() {
  # Usage: yaml_read_block <file> <field>
  # Reads a YAML field that may be a block scalar (field: |) or inline value.
  # Returns the full content as a single string (newlines replaced with spaces for block scalars).
  local file="$1" field="$2"
  [ -f "$file" ] || return 0
  local first_line
  first_line=$(grep -m1 "^${field}:" "$file" 2>/dev/null | sed "s/^${field}:[[:space:]]*//") || return 0
  # Strip quotes from inline values
  first_line=$(echo "$first_line" | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/')
  if [ "$first_line" = "|" ] || [ "$first_line" = "|-" ] || [ "$first_line" = "|+" ]; then
    # Block scalar: read indented continuation lines, join with spaces
    awk -v f="$field" '
      BEGIN { capture=0 }
      $0 ~ "^"f":[[:space:]]*[|]" { capture=1; next }
      capture && /^[[:space:]][[:space:]]/ { sub(/^[[:space:]][[:space:]]/, ""); printf "%s ", $0; next }
      capture && !/^[[:space:]][[:space:]]/ { exit }
    ' "$file" | sed 's/[[:space:]]*$//'
  else
    echo "$first_line"
  fi
}
```

**Step 2: Verify manually**

```bash
# Test with 0227 reference colony
cd /path/to/host-project
source scripts/field-lib.sh
# Single-line detail (O-001):
yaml_read_block "0227/signals/observations/O-001.yaml" "detail"
# Expected: full grep-c description text
# Multi-line detail (O-003):
yaml_read_block "0227/signals/observations/O-003.yaml" "detail"
# Expected: full audit-package text joined as single line
```

**Step 3: Commit**

```bash
git add templates/scripts/field-lib.sh
git commit -m "feat(field-lib): add yaml_read_block() for multi-line YAML fields

Needed by field-migrate.sh to read detail: | block scalars
for accurate quality score computation during v5.0 migration."
```

---

### Task 2: Create field-migrate.sh skeleton

**Files:**
- Create: `templates/scripts/field-migrate.sh`

**Step 1: Write the script skeleton with arg parsing**

```bash
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
```

**Step 2: Make executable**

```bash
chmod +x templates/scripts/field-migrate.sh
```

**Step 3: Verify it runs**

```bash
cd /path/to/protocol-repo
bash templates/scripts/field-migrate.sh --help
# Expected: usage text
```

**Step 4: Commit**

```bash
git add templates/scripts/field-migrate.sh
git commit -m "feat(field-migrate): scaffold migration script with arg parsing"
```

---

### Task 3: Implement scan + compute logic (dry-run)

**Files:**
- Modify: `templates/scripts/field-migrate.sh` (append after counters section)

**Step 1: Add the main scan loop**

Append after the counters section:

```bash
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
  obs_id=$(yaml_read "$obs_file" "id")
  [ -z "$obs_id" ] && { log_warn "Skipping ${obs_file}: no id field"; continue; }

  total=$((total + 1))

  # Check if already migrated
  existing_score=$(yaml_read "$obs_file" "quality_score")
  if [ -n "$existing_score" ] && [ "$existing_score" != "0.5" ] && [ "$FORCE" = false ]; then
    skipped=$((skipped + 1))
    continue
  fi

  # Read fields
  pattern=$(yaml_read "$obs_file" "pattern")
  context=$(yaml_read "$obs_file" "context")
  detail=$(yaml_read_block "$obs_file" "detail")

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

  if [ "$should_archive" -eq 1 ]; then
    if [ "$APPLY" = false ]; then
      printf "  %-8s score=%-5s type=%-8s [→ 归档]\n" "$obs_id" "$score" "$stype"
    fi
  else
    if [ "$APPLY" = false ]; then
      printf "  %-8s score=%-5s type=%-8s [保留]\n" "$obs_id" "$score" "$stype"
    fi
  fi
done
```

**Step 2: Add summary output for dry-run**

Append after the loop:

```bash
# ── Summary ──────────────────────────────────────────────────────────

computed=$((total - skipped))
to_archive=$(awk "BEGIN { n=0 } END { print n }" /dev/null)  # placeholder, computed below

echo ""
echo "--- 汇总 ---"
printf "  总计: %d 个 observation\n" "$total"
printf "  已计算: %d  跳过: %d\n" "$computed" "$skipped"
printf "  trace: %d  deposit: %d\n" "$trace_count" "$deposit_count"
if [ "$computed" -gt 0 ]; then
  avg=$(awk "BEGIN { printf \"%.2f\", ${score_sum} / ${computed} }")
  printf "  平均 quality_score: %s\n" "$avg"
fi

if [ "$APPLY" = false ] && [ "$computed" -gt 0 ]; then
  echo ""
  echo "运行 $0 --apply 执行迁移"
fi
```

**Step 3: Test dry-run against 0227**

This needs running from a host project context where SCRIPT_DIR resolves correctly. For protocol repo testing, temporarily symlink or copy:

```bash
# Quick test — dry-run should show 3 observations from 0227
cd /path/to/protocol-repo
OBS_DIR=0227/signals/observations bash templates/scripts/field-migrate.sh
```

**Step 4: Commit**

```bash
git add templates/scripts/field-migrate.sh
git commit -m "feat(field-migrate): implement scan + compute + dry-run preview"
```

---

### Task 4: Implement --apply mode (write + archive)

**Files:**
- Modify: `templates/scripts/field-migrate.sh` (update the scan loop's apply branch)

**Step 1: Replace the apply-mode placeholders in the scan loop**

In the scan loop, after `should_archive` computation, update the `--apply` branches:

```bash
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
  fi
```

**Step 2: Update summary for apply mode**

Replace the summary section to handle both modes:

```bash
echo ""
if [ "$APPLY" = true ]; then
  echo "--- 完成 ---"
  printf "  迁移: %d  归档: %d  跳过: %d\n" "$migrated" "$archived" "$skipped"
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
```

**Step 3: Test apply with a temp copy of 0227 signals**

```bash
# Create temp test directory
cp -R 0227/signals/observations /tmp/test-migrate-obs
OBS_DIR=/tmp/test-migrate-obs SIGNALS_DIR=/tmp bash templates/scripts/field-migrate.sh --apply
# Check: each .yaml should now have quality_score and source_type fields
grep "quality_score" /tmp/test-migrate-obs/O-001.yaml
# Clean up
rm -rf /tmp/test-migrate-obs
```

**Step 4: Commit**

```bash
git add templates/scripts/field-migrate.sh
git commit -m "feat(field-migrate): implement --apply mode with yaml write + archive"
```

---

### Task 5: Implement DB migration path

**Files:**
- Modify: `templates/scripts/field-migrate.sh` (add DB update section after YAML loop)

**Step 1: Add DB update block after the scan loop, before summary**

```bash
# ── DB Migration (if DB exists) ──────────────────────────────────────

db_updated=0
if [ "$APPLY" = true ] && has_db && has_sqlite; then
  source "${SCRIPT_DIR}/termite-db.sh"
  db_ensure

  log_info "Updating DB records..."

  # Get all observation IDs from DB that need migration
  if [ "$FORCE" = true ]; then
    where_clause=""
  else
    where_clause="AND (quality_score IS NULL OR quality_score = 0.5)"
  fi

  # Re-scan: for each migrated/archived observation, update DB
  # Use the YAML files as source of truth for the computed values
  for obs_file in "${obs_files[@]}"; do
    obs_id=$(yaml_read "$obs_file" "id")
    [ -z "$obs_id" ] && continue
    score=$(yaml_read "$obs_file" "quality_score")
    stype=$(yaml_read "$obs_file" "source_type")
    [ -z "$score" ] && continue

    # Check if this was archived
    archived_file="${ARCHIVE_OBS_DIR}/$(basename "$obs_file")"
    if [ -f "$archived_file" ]; then
      score=$(yaml_read "$archived_file" "quality_score")
      stype=$(yaml_read "$archived_file" "source_type")
    fi

    # Update DB
    db_exec "UPDATE observations SET quality_score = ${score}, source_type = '$(db_escape "${stype:-deposit}")' WHERE id = '$(db_escape "$obs_id")' ${where_clause};" 2>/dev/null || true

    # Mark archived in DB
    should_archive=$(awk "BEGIN { print (${score} < ${ARCHIVE_THRESHOLD}) ? 1 : 0 }")
    if [ "$should_archive" -eq 1 ]; then
      db_exec "UPDATE observations SET quality = 'archived' WHERE id = '$(db_escape "$obs_id")';" 2>/dev/null || true
    fi

    db_updated=$((db_updated + 1))
  done

  log_info "DB updated: ${db_updated} records"
fi
```

**Step 2: Commit**

```bash
git add templates/scripts/field-migrate.sh
git commit -m "feat(field-migrate): add DB migration path for quality_score + source_type"
```

---

### Task 6: Add migration hint to install.sh

**Files:**
- Modify: `install.sh:480-485` (upgrade next-steps section)

**Step 1: Add migration hint after existing upgrade next-steps**

After line 485 (`log "  3. Run: cd ${TARGET_DIR} && ./scripts/field-arrive.sh"`), add:

```bash
  # Check if old signals exist without v5.0 fields
  if [ -d "${TARGET_DIR}/signals/observations" ]; then
    local has_old_signals=false
    for f in "${TARGET_DIR}/signals/observations"/*.yaml; do
      [ -f "$f" ] || continue
      if ! grep -q "^quality_score:" "$f" 2>/dev/null; then
        has_old_signals=true
        break
      fi
    done
    if [ "$has_old_signals" = true ]; then
      echo ""
      log "[MIGRATE] Pre-v5.0 signals detected. Preview migration:"
      log "  cd ${TARGET_DIR} && ./scripts/field-migrate.sh"
      log "Then apply:  ./scripts/field-migrate.sh --apply"
    fi
  fi
```

**Step 2: Commit**

```bash
git add install.sh
git commit -m "feat(install): add v5.0 signal migration hint on upgrade"
```

---

### Task 7: Verify with 0227 reference colony

**Files:** None (verification only)

**Step 1: Run dry-run against 0227**

```bash
cd /path/to/protocol-repo
# Point the script at 0227's signals for testing
# (The script uses PROJECT_ROOT from field-lib.sh, so we need to adjust)
# Option: create a temp symlink or just test the expected output
bash -c '
  SCRIPT_DIR="templates/scripts"
  source templates/scripts/field-lib.sh
  OBS_DIR="0227/signals/observations"
  SIGNALS_DIR="0227/signals"
  source templates/scripts/field-migrate.sh
'
```

Expected output:
```
=== 信号迁移预览 (v5.0) ===

  O-001    score=0.XX  type=deposit  [保留]
  O-002    score=0.XX  type=deposit  [保留]
  O-003    score=0.XX  type=deposit  [保留]

--- 汇总 ---
  总计: 3 个 observation
  将迁移: 3  将跳过: 0
  ...
```

**Step 2: Verify O-001 (single-line detail) scores correctly**

O-001 has: pattern with lowercase words (+0.15), context != pattern (+0.10), detail > 80 chars with path chars (+0.15), detail has causal words (+0.10). Expected: ~0.95-1.00 (clamped to 1.00).

**Step 3: Verify O-003 (multi-line detail) reads correctly**

O-003 has `detail: |` block. `yaml_read_block` should join the lines. Verify the joined text is non-empty and the score reflects the content.

**Step 4: Final shellcheck**

```bash
shellcheck templates/scripts/field-migrate.sh
# Fix any warnings
```

**Step 5: Final commit (if fixes needed)**

```bash
git add templates/scripts/field-migrate.sh templates/scripts/field-lib.sh
git commit -m "fix(field-migrate): shellcheck fixes and verification"
```
