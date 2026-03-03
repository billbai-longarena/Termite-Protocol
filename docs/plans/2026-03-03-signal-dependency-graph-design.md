# Signal Dependency Graph: Solving Work Starvation in Multi-Agent Swarms

Date: 2026-03-03
Status: Design approved, pending implementation
Protocol version target: v5.0 → v5.1
DB schema target: v4 → v5

> **Core problem**: In a 1 Codex + N Haiku swarm, Codex stays busy while Haiku agents idle — repeatedly self-checking and waiting for signals. The signal system was designed for sequential handoff, not parallel work distribution.

---

## Prompt Chain

> **Prompt 1** — Observation report
>
> "看看目前5.0是如何区分信号的，我在短暂的观察，1个codex 3个haiku的情况下，codex一直在忙碌，3个haiku经常在等待，不停自检然后等信号"
>
> → Root cause analysis: work starvation from flat signal structure + single-top-signal .birth + claim mutual exclusion

> **Prompt 2** — Direction choice
>
> "长期方向，一步到位"
>
> → Signal dependency graph design (parent-child relationships, strong model decomposition, environment auto-aggregation)

> **Prompt 3-6** — Design decisions via structured Q&A
>
> - Decomposition driver: 强模型主动分拆 (Shepherd Effect natural extension)
> - Child granularity: 原子任务 (each child = one Haiku-completable atomic deliverable)
> - Completion semantics: 全部子信号 done → 父自动 done (environment maintains consistency)
> - Behavioral template injection: 必须注入 (principle: "环境承载智慧")

> **Prompt 7** — Approach selection
>
> Three approaches evaluated: A (signal dependency graph), B (signal queue with tags), C (work stealing). Selected A.

> **Prompt 8-10** — Incremental design approval
>
> Data model → decomposition mechanism → auto-aggregation + trigger logic → protocol spec changes. All approved.

---

## Problem Analysis

### Root Cause Chain

```
1. signals 表是平面结构 (no parent_id, no dependency)
          ↓
2. field-arrive.sh .birth ## task 展示同一个 top signal
   (SELECT ... ORDER BY weight DESC LIMIT 1)
          ↓
3. Codex 先 claim → 3 Haiku 到达时 top signal 已被 claimed
          ↓
4. Caste waterfall 走到底部 → caste="scout", reason="default"
          ↓
5. Idle detection: "IDLE: Colony has no actionable signals"
          ↓
6. Haiku 无法有效生成 HOLE 信号 (F-009c validated)
          ↓
7. 自检 → idle → exit → restart → 自检 → idle (work starvation loop)
```

### Prior Art

- **乱石墙比喻** (protocol-philosophy-revision.md): "邻石感知（依赖关系）：信号之间无结构化依赖 → 环境应包含信号间关系"
- **W-007**: Idle heartbeat spinning (partially fixed with IDLE guidance, but root cause unaddressed)
- **W-015**: Claim lock starvation (fixed with heartbeat timeout, but doesn't create new work)
- **W-009**: Signal granularity lacks guidance (fixed with soft hint, but no structural enforcement)

### Design Principles Applied

| Principle | Application |
|-----------|------------|
| 环境承载智慧 | Signal dependency graph = structured intelligence in environment |
| 仁者见仁智者见智 | DECOMPOSE hint in .birth: strong models act on it, weak models ignore (harmless) |
| Shepherd Effect | Upgraded from passive (pheromone chain templates) to active (per-child behavioral hints) |
| 无状态 | All dependency state in DB, not in agent memory |
| 心跳自足 | Auto-aggregation runs in metabolism cycle, no human intervention needed |

---

## Design

### 1. Data Model (DB Schema v4 → v5)

**signals table additions**:

```sql
-- Migration v4 → v5
ALTER TABLE signals ADD COLUMN parent_id TEXT DEFAULT NULL;
ALTER TABLE signals ADD COLUMN child_hint TEXT DEFAULT NULL;  -- JSON
ALTER TABLE signals ADD COLUMN depth INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_signals_parent ON signals(parent_id);
```

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `parent_id` | TEXT | NULL | Parent signal ID (NULL = top-level) |
| `child_hint` | TEXT (JSON) | NULL | Strong model's directional guidance for this child |
| `depth` | INTEGER | 0 | Tree depth (top=0, max=3) |

**`child_hint` JSON schema**:

```json
{
  "next_steps": "Create POST /register endpoint, reference src/api/login.ts pattern",
  "files": ["src/api/auth.ts", "src/models/user.ts"],
  "example": "See login.ts:15 for request validation pattern"
}
```

**Signal lifecycle with decomposition**:

```
S-042 (open) → claimed by Codex → DECOMPOSE →
  ├─ S-042-1 (open) → claimed by Haiku-1 → done
  ├─ S-042-2 (open) → claimed by Haiku-2 → done
  └─ S-042-3 (open) → claimed by Haiku-3 → done
                          ↓ (all children done)
S-042 → auto-done (by field-cycle.sh aggregation)
```

**Backward compatibility**:
- `parent_id = NULL` signals behave exactly as before
- Old scripts without parent_id awareness work unchanged
- YAML export includes new fields for audit visibility

### 2. Decomposition Script (field-decompose.sh)

**New script**: Strong model calls after claiming a complex signal.

```bash
# Usage:
./scripts/field-decompose.sh --parent S-042 \
  --child "Implement user registration API" --module "src/api/auth.ts" \
    --hint '{"next_steps":"Create POST /register, ref src/api/login.ts","files":["src/api/auth.ts"]}' \
  --child "Add registration form component" --module "src/components/Register.tsx" \
    --hint '{"next_steps":"Create React form, reuse LoginForm validation","files":["src/components/Register.tsx"]}' \
  --child "Registration integration tests" --module "tests/api/auth.test.ts" \
    --hint '{"next_steps":"Test happy path + duplicate email + weak password","files":["tests/api/auth.test.ts"]}'
```

**Atomic operation** (single DB transaction):

1. Validate parent signal exists and is claimed
2. Validate `depth < max_depth` (default: 3)
3. Create N child signals:
   - `parent_id` = parent's ID
   - `depth` = parent's depth + 1
   - `status` = open
   - `weight` = parent's weight (inherit urgency)
   - `type` = parent's type
   - `source` = 'decomposed'
   - `child_hint` = strong model's guidance JSON
   - `title` = provided title
   - `module` = provided module
4. Parent signal remains `claimed` (decomposer can claim one child to continue working)

**Child signal ID format**: `{parent_id}-{sequence}` (e.g., S-042-1, S-042-2, S-042-3)

### 3. .birth Leaf-Priority Display

**field-arrive.sh change**: top signal query becomes leaf-priority.

Current (all agents see same signal):
```sql
SELECT id,type,title,next_hint FROM signals
  WHERE status NOT IN ('archived','parked','done','completed')
  ORDER BY weight DESC LIMIT 1;
```

New (each agent sees best unclaimed leaf):
```sql
SELECT s.id, s.type, s.title, s.next_hint, s.child_hint, s.parent_id
FROM signals s
WHERE s.status = 'open'
  AND NOT EXISTS (
    SELECT 1 FROM signals c
    WHERE c.parent_id = s.id
    AND c.status NOT IN ('done','completed','archived')
  )
ORDER BY s.weight DESC
LIMIT 1;
```

Key changes:
- `status = 'open'` — excludes claimed signals (different agents see different unclaimed signals)
- `NOT EXISTS (active children)` — only shows leaf signals (decomposed parents are hidden)

**Haiku's .birth example**:

```
## task
S-042-1(HOLE): Implement user registration API
  parent: S-042 (User registration feature)
  hint: Create POST /register, ref src/api/login.ts
  files: src/api/auth.ts, src/models/user.ts

behavioral_template:
  example: pattern="API endpoint implementation" context="src/api/login.ts:15" ...
```

Self-contained atomic task: what to do, how to do it, which files, reference pattern.

### 4. Auto-Aggregation (field-cycle.sh)

**New Step 3.5** in metabolism cycle (after boundary detection):

```sql
-- Auto-close parent signals when all children are done
UPDATE signals SET status='done', last_touched=date('now')
WHERE id IN (
  SELECT DISTINCT parent_id FROM signals
  WHERE parent_id IS NOT NULL
  GROUP BY parent_id
  HAVING COUNT(*) = SUM(CASE WHEN status IN ('done','completed') THEN 1 ELSE 0 END)
)
AND status NOT IN ('done','completed','archived');
```

**Child blocked → parent weight escalation**:

```sql
UPDATE signals SET weight = MIN(weight + 10, 100)
WHERE id IN (
  SELECT DISTINCT parent_id FROM signals
  WHERE parent_id IS NOT NULL AND status = 'blocked'
)
AND status NOT IN ('done','completed','archived');
```

Both are single-SQL atomic operations in the existing metabolism cycle.

### 5. Decomposition Trigger

**field-arrive.sh** injects decomposition hint when signal-to-agent ratio is imbalanced:

```bash
unclaimed_leaves = count of open leaf signals
active_agents = count of agents with session_status='active'

if unclaimed_leaves < active_agents * min_agent_ratio:
  inject into .birth ## situation:
  "DECOMPOSE: {N} agents active but only {M} unclaimed tasks.
   Consider decomposing complex signals into atomic sub-tasks
   using ./scripts/field-decompose.sh"
```

**"仁者见仁智者见智"**:
- Strong model sees DECOMPOSE → understands → decomposes
- Weak model sees DECOMPOSE → doesn't understand → ignores (harmless)

### 6. Protocol Spec Changes

**New grammar sub-rule (Rule 4b)**:

```
规则 4b: DEPOSIT(complex_signal) → DECOMPOSE(children, hint_per_child)
         当行动的对象是复合信号时，先分拆为原子子信号再执行。
         每个子信号必须自包含：title + module + next_hint + behavioral_template。
```

**New configuration block**:

```yaml
# decomposition-config — parsed by field-decompose.sh and field-cycle.sh
decompose:
  max_depth: 3
  min_agent_ratio: 0.5
  child_weight_inherit: true
  auto_aggregate: true
  blocked_escalation: 10
```

**New signal source value**:

```yaml
signal_source:
  autonomous: "heartbeat-generated"
  directive: "human-injected"
  emergent: "observation-promoted"
  decomposed: "strong-model-decomposed"    # NEW
```

---

## Version Bump Plan

| Component | From | To |
|-----------|------|-----|
| Protocol spec | v5.0 | v5.1 |
| DB schema | v4 | v5 |
| Field lib | v22 | v23 |
| Kernel | v12 | v13 |

---

## Files Changed

| File | Change |
|------|--------|
| `templates/scripts/termite-db-schema.sql` | signals +3 fields, +1 index, schema v5 |
| `templates/scripts/termite-db.sh` | +migration, +db_signal_decompose(), +db_signal_aggregate(), +db_unclaimed_leaf_count() |
| `templates/scripts/field-decompose.sh` | **NEW**: decomposition script |
| `templates/scripts/field-arrive.sh` | leaf-priority query, DECOMPOSE hint injection, child_hint → .birth |
| `templates/scripts/field-cycle.sh` | +Step 3.5 auto-aggregation, +child blocked escalation |
| `templates/scripts/field-lib.sh` | +leaf signal query helpers |
| `templates/scripts/termite-db-export.sh` | YAML export supports parent_id, child_hint, depth |
| `templates/TERMITE_PROTOCOL.md` | +Rule 4b, +decomposition-config, +signal dependency graph docs |
| `templates/UPGRADE_NOTES.md` | +v5.1 changelog |
| `install.sh` | field-decompose.sh added to install list |

## Files NOT Changed

- Signal types (HOLE/EXPLORE/etc) — unchanged
- Claim mechanism — children are claimed independently, same as any signal
- Decay/emergence/rule engine — unchanged
- YAML fallback — decomposition is SQLite-only feature (degradation: flat signals still work)

---

## Design Assumptions

| ID | Assumption | If wrong |
|----|-----------|----------|
| DA-001 | Strong model understands DECOMPOSE hint without explicit training | Give explicit command in .birth instead of hint; or make it a caste transition (scout → decompose → worker) |
| DA-002 | Atomic tasks (single file/module) are right granularity for Haiku | Allow module-level decomposition as fallback; add granularity guidance |
| DA-003 | Parent-child tree depth ≤ 3 is sufficient | Increase max_depth; but deep trees suggest problem is too complex for signal system |
| DA-004 | Signal-to-agent ratio < 0.5 is the right trigger threshold | Make configurable via TERMITE_MIN_AGENT_RATIO env var |
| DA-005 | YAML fallback doesn't need decomposition | If SQLite-only is limiting, add parent_id to YAML schema later |

---

## Expected Outcome

**Before (v5.0)**:
```
Codex: ████████████████████ (always busy)
Haiku-1: ░░█░░░░█░░░░█░░░░ (mostly idle, self-check loops)
Haiku-2: ░░░█░░░░█░░░░░░░░ (mostly idle, self-check loops)
Haiku-3: ░█░░░░░░░█░░░░░░░ (mostly idle, self-check loops)
```

**After (v5.1)**:
```
Codex: ██ scout/decompose ████████ work on child-1 ████████
Haiku-1: ░░ ████████ child-2 ████████ ████ child-5 ████████
Haiku-2: ░░ ████████ child-3 ████████ ████ child-6 ████████
Haiku-3: ░░ ████████ child-4 ████████ ████ child-7 ████████
```

Codex's first action = scout → decompose → then work on one child.
Haiku agents immediately claim remaining children = parallel execution.
Total throughput: ~3-4x improvement from parallelization.
