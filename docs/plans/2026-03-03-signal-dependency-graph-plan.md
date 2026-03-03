# Signal Dependency Graph — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add parent-child signal relationships so strong models decompose complex signals into atomic sub-tasks that weak models can claim independently, solving work starvation in multi-agent swarms.

**Architecture:** signals table gains `parent_id`, `child_hint`, `depth` fields. New `field-decompose.sh` script for atomic decomposition. `field-arrive.sh` switches to leaf-priority signal display. `field-cycle.sh` auto-aggregates parent signals when all children complete.

**Tech Stack:** Bash (set -euo pipefail), SQLite3 WAL mode, YAML fallback

**Design doc:** `docs/plans/2026-03-03-signal-dependency-graph-design.md`

---

### Task 1: DB Schema Migration v4 → v5

**Files:**
- Modify: `templates/scripts/termite-db-schema.sql` (line 14 version bump, after line 36 add columns)
- Modify: `templates/scripts/termite-db.sh` (after line 57 add migration function)

**Step 1: Update schema version in termite-db-schema.sql**

Change line 13 from:
```sql
INSERT OR IGNORE INTO schema_version(version) VALUES (4);
```
to:
```sql
INSERT OR IGNORE INTO schema_version(version) VALUES (5);
```

**Step 2: Add new columns to signals table in termite-db-schema.sql**

After line 33 (`source TEXT DEFAULT 'autonomous'`), before the parked fields, add:
```sql
  parent_id TEXT DEFAULT NULL,         -- parent signal ID (NULL = top-level)
  child_hint TEXT DEFAULT NULL,        -- JSON: strong model's directional guidance
  depth INTEGER DEFAULT 0,            -- tree depth (top=0, max=3)
```

After the existing `idx_signals_type_weight` index (line 37), add:
```sql
CREATE INDEX IF NOT EXISTS idx_signals_parent ON signals(parent_id);
```

**Step 3: Add migration function in termite-db.sh**

After `db_migrate_v3_to_v4()` (ends at line 59), add:

```bash
db_migrate_v4_to_v5() {
  log_info "Migrating DB schema v4 → v5"
  db_exec "ALTER TABLE signals ADD COLUMN parent_id TEXT DEFAULT NULL;" 2>/dev/null || true
  db_exec "ALTER TABLE signals ADD COLUMN child_hint TEXT DEFAULT NULL;" 2>/dev/null || true
  db_exec "ALTER TABLE signals ADD COLUMN depth INTEGER DEFAULT 0;" 2>/dev/null || true
  db_exec "CREATE INDEX IF NOT EXISTS idx_signals_parent ON signals(parent_id);" 2>/dev/null || true
  db_exec "INSERT OR REPLACE INTO schema_version(version) VALUES (5);"
  log_info "DB schema migration to v5 complete"
}
```

**Step 4: Hook migration into db_ensure()**

In `db_ensure()` (around line 35), after the v3→v4 migration block:
```bash
  if [ "${current_ver:-1}" -lt 4 ]; then
    db_migrate_v3_to_v4
  fi
```
Add:
```bash
  if [ "${current_ver:-1}" -lt 5 ]; then
    db_migrate_v4_to_v5
  fi
```

**Step 5: Verify migration**

Run in a test project with existing `.termite.db`:
```bash
cd /tmp && mkdir -p test-migrate && cd test-migrate && git init
cp /Users/bingbingbai/Desktop/白蚁协议/templates/scripts/*.sh scripts/ 2>/dev/null || true
cp /Users/bingbingbai/Desktop/白蚁协议/templates/scripts/*.sql scripts/ 2>/dev/null || true
source scripts/field-lib.sh && source scripts/termite-db.sh
db_ensure
sqlite3 .termite.db ".schema signals" | grep parent_id
```
Expected: line containing `parent_id TEXT DEFAULT NULL`

**Step 6: Commit**

```bash
git add templates/scripts/termite-db-schema.sql templates/scripts/termite-db.sh
git commit -m "feat(db): schema v4→v5 — add parent_id, child_hint, depth to signals table"
```

---

### Task 2: DB Helper Functions for Decomposition

**Files:**
- Modify: `templates/scripts/termite-db.sh` (append after `db_export_rules_dir`, before `db_escape`)

**Step 1: Add db_signal_decompose()**

Append before `db_escape()` (line 696):

```bash
# ── Signal Decomposition (v5.1) ──────────────────────────────────────

db_signal_decompose() {
  # Atomic decomposition: create N child signals from a parent
  # Args: parent_id child_data_json
  # child_data_json format: [{"title":"...","module":"...","hint":{...}}, ...]
  local parent_id="$1"

  # Validate parent exists and is claimed
  local parent_row
  parent_row=$(db_query "SELECT status, depth, weight, type FROM signals WHERE id='$(db_escape "$parent_id")';")
  if [ -z "$parent_row" ]; then
    log_error "Parent signal ${parent_id} not found"
    return 1
  fi

  local p_status p_depth p_weight p_type
  IFS=$'\t' read -r p_status p_depth p_weight p_type <<< "$parent_row"

  if [ "$p_status" != "claimed" ] && [ "$p_status" != "open" ]; then
    log_error "Parent signal ${parent_id} is ${p_status}, must be claimed or open"
    return 1
  fi

  local max_depth="${TERMITE_DECOMPOSE_MAX_DEPTH:-3}"
  local child_depth=$((p_depth + 1))
  if [ "$child_depth" -gt "$max_depth" ]; then
    log_error "Decomposition depth limit exceeded (${child_depth} > ${max_depth})"
    return 1
  fi

  # Parse children from positional args: title module hint [title module hint ...]
  shift
  local child_num=0
  local sql_stmts=""
  while [ $# -ge 2 ]; do
    local c_title="$1" c_module="$2" c_hint="${3:-}"
    shift 2
    [ $# -gt 0 ] && [ "${1:0:1}" != "-" ] && { c_hint="$1"; shift; } || true
    child_num=$((child_num + 1))
    local c_id="${parent_id}-${child_num}"
    sql_stmts="${sql_stmts}
      INSERT INTO signals(id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parent_id,child_hint,depth)
        VALUES('$(db_escape "$c_id")','$(db_escape "$p_type")','$(db_escape "$c_title")','open',${p_weight},14,
        '$(today_iso)','$(today_iso)','unassigned','$(db_escape "$c_module")','[]','','0','decomposed',
        '$(db_escape "$parent_id")','$(db_escape "$c_hint")',${child_depth});"
  done

  if [ "$child_num" -eq 0 ]; then
    log_error "No children specified"
    return 1
  fi

  db_transaction "$sql_stmts"
  log_info "Decomposed ${parent_id} into ${child_num} children (depth=${child_depth})"
}

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
```

**Step 2: Verify functions parse correctly**

```bash
bash -n templates/scripts/termite-db.sh
echo $?
```
Expected: `0` (no syntax errors)

**Step 3: Commit**

```bash
git add templates/scripts/termite-db.sh
git commit -m "feat(db): add decompose, aggregate, leaf-query helper functions"
```

---

### Task 3: field-decompose.sh (New Script)

**Files:**
- Create: `templates/scripts/field-decompose.sh`

**Step 1: Create the script**

```bash
#!/usr/bin/env bash
# field-decompose.sh — Decompose a complex signal into atomic child signals
# Called by strong models after claiming a signal that needs parallelization.
#
# Usage:
#   ./scripts/field-decompose.sh --parent S-042 \
#     --child "Implement registration API" --module "src/api/auth.ts" \
#       --hint '{"next_steps":"Create POST /register","files":["src/api/auth.ts"]}' \
#     --child "Add registration form" --module "src/components/Register.tsx" \
#       --hint '{"next_steps":"Create React form","files":["src/components/Register.tsx"]}'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

PARENT_ID=""
CHILDREN=()     # Each entry: "title|module|hint"

current_title=""
current_module=""
current_hint=""

flush_child() {
  if [ -n "$current_title" ]; then
    CHILDREN+=("${current_title}|${current_module}|${current_hint}")
    current_title=""
    current_module=""
    current_hint=""
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --parent)  PARENT_ID="$2"; shift 2 ;;
    --child)   flush_child; current_title="$2"; shift 2 ;;
    --module)  current_module="$2"; shift 2 ;;
    --hint)    current_hint="$2"; shift 2 ;;
    *)
      log_error "Unknown argument: $1"
      echo "Usage: $0 --parent <signal-id> --child <title> --module <path> [--hint <json>] [--child ...]"
      exit 1
      ;;
  esac
done
flush_child

if [ -z "$PARENT_ID" ]; then
  log_error "--parent is required"
  exit 1
fi

if [ ${#CHILDREN[@]} -eq 0 ]; then
  log_error "At least one --child is required"
  exit 1
fi

# ── Decompose ────────────────────────────────────────────────────────

if ! has_db; then
  log_error "Decomposition requires SQLite database (.termite.db)"
  log_error "YAML fallback does not support signal dependency graphs"
  exit 1
fi

source "${SCRIPT_DIR}/termite-db.sh"

# Validate parent
parent_row=$(db_query "SELECT status, depth, weight, type FROM signals WHERE id='$(db_escape "$PARENT_ID")';")
if [ -z "$parent_row" ]; then
  log_error "Parent signal ${PARENT_ID} not found"
  exit 1
fi

IFS=$'\t' read -r p_status p_depth p_weight p_type <<< "$parent_row"

max_depth="${TERMITE_DECOMPOSE_MAX_DEPTH:-3}"
child_depth=$((p_depth + 1))
if [ "$child_depth" -gt "$max_depth" ]; then
  log_error "Decomposition depth limit exceeded (${child_depth} > ${max_depth})"
  exit 1
fi

# Build SQL transaction
child_num=0
sql_stmts=""
child_ids=""

for entry in "${CHILDREN[@]}"; do
  IFS='|' read -r c_title c_module c_hint <<< "$entry"
  child_num=$((child_num + 1))
  c_id="${PARENT_ID}-${child_num}"
  child_ids="${child_ids:+${child_ids}, }${c_id}"

  sql_stmts="${sql_stmts}
    INSERT INTO signals(id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parent_id,child_hint,depth)
      VALUES('$(db_escape "$c_id")','$(db_escape "$p_type")','$(db_escape "$c_title")','open',${p_weight},14,
      '$(today_iso)','$(today_iso)','unassigned','$(db_escape "$c_module")','[]','','0','decomposed',
      '$(db_escape "$PARENT_ID")','$(db_escape "$c_hint")',${child_depth});"
done

db_transaction "$sql_stmts"

log_info "Decomposed ${PARENT_ID} into ${child_num} children: [${child_ids}]"
log_info "Children are open for claiming. Parent remains ${p_status}."
echo "${child_ids}"
```

**Step 2: Make executable**

```bash
chmod +x templates/scripts/field-decompose.sh
```

**Step 3: Verify syntax**

```bash
bash -n templates/scripts/field-decompose.sh
echo $?
```
Expected: `0`

**Step 4: Commit**

```bash
git add templates/scripts/field-decompose.sh
git commit -m "feat(scripts): add field-decompose.sh — atomic signal decomposition for multi-agent work distribution"
```

---

### Task 4: field-arrive.sh — Leaf-Priority Display + DECOMPOSE Hint

**Files:**
- Modify: `templates/scripts/field-arrive.sh` (lines 431-441 top signal query, lines 384-387 idle detection, line 540 .birth task section)

**Step 1: Replace top signal query (line 434)**

Replace lines 431-442 (the `top_signal_hint` block):

```bash
# Get top signal with next_hint for .birth task section
# v5.1: leaf-priority — show unclaimed leaf signals, not decomposed parents
top_signal_hint=""
if has_db; then
  top_row=$(db_query "SELECT s.id, s.type, s.title, s.next_hint, s.child_hint, s.parent_id, s.module
    FROM signals s
    WHERE s.status = 'open'
      AND NOT EXISTS (
        SELECT 1 FROM signals c
        WHERE c.parent_id = s.id
        AND c.status NOT IN ('done','completed','archived')
      )
    ORDER BY s.weight DESC
    LIMIT 1;" 2>/dev/null || true)
  if [ -n "$top_row" ]; then
    IFS=$'\t' read -r ts_id ts_type ts_title ts_next ts_child_hint ts_parent ts_module <<< "$top_row"
    top_signal_hint="${ts_id}(${ts_type}): ${ts_title}"
    [ -n "$ts_next" ] && top_signal_hint="${top_signal_hint} → ${ts_next}"
    # Include parent context and child_hint for decomposed signals
    if [ -n "$ts_parent" ] && [ "$ts_parent" != "null" ]; then
      parent_title=$(db_exec "SELECT title FROM signals WHERE id='$(db_escape "$ts_parent")';" 2>/dev/null || true)
      [ -n "$parent_title" ] && top_signal_hint="${top_signal_hint}\n  parent: ${ts_parent} (${parent_title})"
    fi
    if [ -n "$ts_child_hint" ] && [ "$ts_child_hint" != "null" ]; then
      top_signal_hint="${top_signal_hint}\n  hint: ${ts_child_hint}"
    fi
    if [ -n "$ts_module" ] && [ "$ts_module" != "null" ] && [ -n "$ts_module" ]; then
      top_signal_hint="${top_signal_hint}\n  files: ${ts_module}"
    fi
  fi
fi
```

**Step 2: Add DECOMPOSE hint injection (after idle detection, around line 387)**

After the idle colony detection block (`IDLE: Colony has no actionable signals...`), add:

```bash
# v5.1: Decomposition hint — when signal-to-agent ratio is imbalanced
if has_db; then
  unclaimed_leaves=$(db_exec "
    SELECT COUNT(*) FROM signals s
    WHERE s.status = 'open'
      AND NOT EXISTS (
        SELECT 1 FROM signals c
        WHERE c.parent_id = s.id
        AND c.status NOT IN ('done','completed','archived')
      );" 2>/dev/null || echo "0")
  decompose_agents=$(db_exec "SELECT COUNT(*) FROM agents WHERE session_status='active';" 2>/dev/null || echo "1")
  min_ratio="${TERMITE_DECOMPOSE_MIN_AGENT_RATIO:-0.5}"
  needs_decompose=$(awk "BEGIN { print (${decompose_agents} > 1 && ${unclaimed_leaves} < ${decompose_agents} * ${min_ratio}) ? 1 : 0 }")
  if [ "$needs_decompose" -eq 1 ]; then
    situation="${situation}DECOMPOSE: ${decompose_agents} agents active but only ${unclaimed_leaves} unclaimed tasks. Consider decomposing complex signals into atomic sub-tasks using ./scripts/field-decompose.sh\n"
  fi
fi
```

**Step 3: Verify syntax**

```bash
bash -n templates/scripts/field-arrive.sh
echo $?
```
Expected: `0`

**Step 4: Commit**

```bash
git add templates/scripts/field-arrive.sh
git commit -m "feat(arrive): leaf-priority signal display + DECOMPOSE hint for multi-agent work distribution"
```

---

### Task 5: field-cycle.sh — Auto-Aggregation Step

**Files:**
- Modify: `templates/scripts/field-cycle.sh` (after Step 3/7 Boundary detection, before Step 4/7 Pulse)

**Step 1: Renumber steps from 7 to 8**

Update all step references: Steps are now 1-8 instead of 1-7.
- Line 15: `"Step 1/8: Decay"` (was `1/7`)
- Line 31: `"Step 2/8: Drain"` (was `2/7`)
- Line 43: `"Step 3/8: Boundary detection"` (was `3/7`)
- Line 89: `"Step 5/8: Pulse"` → was Step 4/7, now Step 5/8
- Line 94: `"Step 6/8: Observation promotion scan"` → was Step 5/7
- Line 315: `"Step 7/8: Observation compression"` → was Step 6/7
- Line 327: `"Step 8/8: Rule archival scan"` → was Step 7/7

**Step 2: Insert Step 4/8 after boundary detection (after line 85)**

```bash
# ── Step 4/8: Signal aggregation (v5.1) ──────────────────────────────

log_info "Step 4/8: Signal aggregation"
if has_db; then
  agg_count=$(db_signal_aggregate 2>/dev/null || echo "0")
  [ "${agg_count:-0}" -gt 0 ] && log_info "Aggregated ${agg_count} parent signals"
fi
```

**Step 3: Verify syntax**

```bash
bash -n templates/scripts/field-cycle.sh
echo $?
```
Expected: `0`

**Step 4: Commit**

```bash
git add templates/scripts/field-cycle.sh
git commit -m "feat(cycle): add Step 4/8 signal aggregation — auto-close parents when all children done"
```

---

### Task 6: install.sh — Add field-decompose.sh

**Files:**
- Modify: `install.sh` (line 32-49 PROTOCOL_SCRIPTS array)

**Step 1: Add field-decompose.sh to PROTOCOL_SCRIPTS**

After `scripts/field-deposit.sh` (line 38), add:
```bash
  scripts/field-decompose.sh
```

**Step 2: Commit**

```bash
git add install.sh
git commit -m "feat(install): add field-decompose.sh to installation script list"
```

---

### Task 7: YAML Export Support

**Files:**
- Modify: `templates/scripts/termite-db.sh` (`db_export_signal_yaml` function, around line 593)

**Step 1: Add parent_id, child_hint, depth to YAML export**

In `db_export_signal_yaml()`, update the SELECT query (line 597) to include new columns:

Replace:
```bash
  row=$(db_query "SELECT id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parked_reason,parked_conditions,parked_at FROM signals WHERE id='$(db_escape "$1")';")
```
With:
```bash
  row=$(db_query "SELECT id,type,title,status,weight,ttl_days,created,last_touched,owner,module,tags,next_hint,touch_count,source,parked_reason,parked_conditions,parked_at,parent_id,child_hint,depth FROM signals WHERE id='$(db_escape "$1")';")
```

Update the IFS read (line 600) to include new fields:
```bash
  IFS=$'\t' read -r id type title status weight ttl_days created last_touched owner module tags next_hint touch_count source parked_reason parked_conditions parked_at parent_id child_hint depth <<< "$row"
```

After the parked fields output (line 621), add:
```bash
  [ -n "$parent_id" ] && echo "parent_id: ${parent_id}"
  [ -n "$child_hint" ] && echo "child_hint: '${child_hint}'"
  [ "${depth:-0}" -gt 0 ] && echo "depth: ${depth}"
```

**Step 2: Commit**

```bash
git add templates/scripts/termite-db.sh
git commit -m "feat(export): YAML export includes parent_id, child_hint, depth fields"
```

---

### Task 8: Protocol Spec + UPGRADE_NOTES

**Files:**
- Modify: `templates/TERMITE_PROTOCOL.md` (Part I grammar rules, Part II signal config)
- Modify: `templates/UPGRADE_NOTES.md`

**Step 1: Add Rule 4b to grammar rules in TERMITE_PROTOCOL.md**

After Rule 4 (line 73, `DO → DEPOSIT(signal, weight, TTL, location)`), insert:

```
规则 4b: DEPOSIT(complex) → DECOMPOSE(children, hint_per_child)
         复合信号必须先分拆为原子子信号。子信号自包含：title + module + hint。
```

**Step 2: Add decomposition-config to Part II**

After the `adaptive-decay` yaml block (ends around line 289), add a new section:

```yaml
## 信号分拆配置 (Signal Decomposition)

> **强模型主动分拆复合信号为原子子信号，弱模型各自 claim 一个子信号独立执行。**
> Shepherd Effect 从被动模仿升级为主动指导：每个子信号自带定向 behavioral hint。

```yaml
# decomposition-config — parsed by field-decompose.sh and field-cycle.sh
decompose:
  max_depth: 3                        # 最大分拆深度 (top=0)
  min_agent_ratio: 0.5                # unclaimed_signals/active_agents < 此值时触发提示
  child_weight_inherit: true          # 子信号继承父信号 weight
  auto_aggregate: true                # 所有子信号 done → 父信号 auto-done
  blocked_escalation: 10              # 子信号 blocked → 父信号 weight +10
```

**Step 3: Add `decomposed` to signal source**

In the signal-types yaml block (around line 183), after `source: autonomous` field in the Active Signal schema (around line 1221), add `decomposed` to the source documentation.

**Step 4: Add v5.1 entry to UPGRADE_NOTES.md**

Prepend a new version entry before the v5.0 entry:

```markdown
## v5.1 — Signal Dependency Graph (2026-03-03)

### Changes
- **Signal decomposition**: signals table gains `parent_id`, `child_hint`, `depth` fields for parent-child relationships
- **field-decompose.sh**: New script for strong models to decompose complex signals into atomic sub-tasks
- **Leaf-priority .birth**: field-arrive.sh now shows unclaimed leaf signals (not decomposed parents) in .birth ## task
- **Auto-aggregation**: field-cycle.sh Step 4/8 auto-closes parent signals when all children complete
- **DECOMPOSE hint**: When unclaimed signals < active agents, .birth injects decomposition guidance
- **DB schema v4 → v5**: signals table +3 columns, +1 index

### Action Required
- Run `install.sh --upgrade` to get new field-decompose.sh and updated scripts
- Existing signals are unaffected (parent_id defaults to NULL)

### Action Optional
- Strong models can now call `./scripts/field-decompose.sh` to split complex signals
- Set `TERMITE_DECOMPOSE_MAX_DEPTH` (default: 3) and `TERMITE_DECOMPOSE_MIN_AGENT_RATIO` (default: 0.5)
```

**Step 5: Commit**

```bash
git add templates/TERMITE_PROTOCOL.md templates/UPGRADE_NOTES.md
git commit -m "feat(protocol): v5.0→v5.1 — signal dependency graph, Rule 4b, decomposition config"
```

---

### Task 9: Version Bumps + CLAUDE.md Known Issues Update

**Files:**
- Modify: `CLAUDE.md` (Current State section — protocol version, field lib version, known issues)
- Modify: `templates/TERMITE_PROTOCOL.md` (line 1 version tag)
- Modify: `templates/scripts/field-lib.sh` (if version tracked there)

**Step 1: Update TERMITE_PROTOCOL.md version tag**

Line 1: change `<!-- termite-protocol:v5.0 -->` to `<!-- termite-protocol:v5.1 -->`
Line 2: change `# 白蚁协议 v5.0` to `# 白蚁协议 v5.1`

**Step 2: Update CLAUDE.md Current State**

Update the protocol source repo CLAUDE.md:
- `Protocol version: v5.1`
- Add new Known Issues entry about YAML fallback not supporting decomposition
- Record this work in Recent Work section

**Step 3: Commit**

```bash
git add CLAUDE.md templates/TERMITE_PROTOCOL.md
git commit -m "chore: version bump v5.0→v5.1, update known issues and recent work"
```

---

### Task 10: field-lib.sh — Decomposition Threshold Constants

**Files:**
- Modify: `templates/scripts/field-lib.sh` (after line 42, the threshold constants block)

**Step 1: Add decomposition thresholds**

After `UNCOMMITTED_LINES_LIMIT` (line 42), add:

```bash
DECOMPOSE_MAX_DEPTH="${TERMITE_DECOMPOSE_MAX_DEPTH:-3}"
DECOMPOSE_MIN_AGENT_RATIO="${TERMITE_DECOMPOSE_MIN_AGENT_RATIO:-0.5}"
DECOMPOSE_BLOCKED_ESCALATION="${TERMITE_DECOMPOSE_BLOCKED_ESCALATION:-10}"
```

**Step 2: Commit**

```bash
git add templates/scripts/field-lib.sh
git commit -m "feat(lib): add decomposition threshold constants with env var overrides"
```

---

### Summary: Implementation Order

| Task | Description | Depends On |
|------|-------------|-----------|
| 1 | DB Schema v4→v5 | — |
| 2 | DB helper functions | Task 1 |
| 3 | field-decompose.sh | Task 1, 2 |
| 4 | field-arrive.sh leaf-priority | Task 2 |
| 5 | field-cycle.sh aggregation | Task 2 |
| 6 | install.sh | Task 3 |
| 7 | YAML export | Task 1 |
| 8 | Protocol spec + UPGRADE_NOTES | — |
| 9 | Version bumps | Task 8 |
| 10 | field-lib.sh constants | — |

Tasks 1, 8, 10 can run in parallel (no dependencies).
Tasks 3, 4, 5, 7 can run in parallel after Task 2.
Task 6 after Task 3. Task 9 after Task 8.
