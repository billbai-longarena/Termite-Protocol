# Termite Protocol — Signal YAML Schema

> This document defines the canonical YAML schema for all signal types
> used by the Termite Protocol's field infrastructure scripts.

---

## Directory Layout

```
signals/
  active/          # Live signals (HOLE, EXPLORE, PHEROMONE, PROBE, FEEDBACK, BLOCKED)
    S-001.yaml
    S-002.yaml
  observations/    # Agent observations (not yet promoted to rules)
    O-001.yaml
    O-002.yaml
  rules/           # Promoted rules (emerged from ≥3 independent observations)
    R-001.yaml
    R-002.yaml
  claims/          # Concurrency locks
    S-001.work.lock
  archive/         # Completed / promoted / expired items
    done-YYYY-MM/
    promoted/
    rules/
```

---

## Active Signal — `signals/active/S-xxx.yaml`

An active signal represents a unit of work, exploration, or feedback
that agents sense and respond to.

```yaml
id: S-001
type: HOLE              # HOLE | EXPLORE | PHEROMONE | PROBE | FEEDBACK | BLOCKED
title: "Fix auth bypass in tenant filter"
status: open            # open | claimed | done | stale | archived
weight: 45              # 0–100, decays each cycle (×0.98)
ttl_days: 14            # auto-stale after this many days untouched
created: 2026-02-27
last_touched: 2026-02-27
owner: unassigned        # "unassigned" or "termite:DATE:caste"
module: "backend/src/auth"
tags: [auth, multi-tenant]
next: "Add organizationId JOIN to all write endpoints"
```

### Signal Types

| Type | Purpose | Typical Weight |
|------|---------|---------------|
| `HOLE` | Known gap / bug / missing feature | 30–80 |
| `EXPLORE` | Open question needing investigation | 10–40 |
| `PHEROMONE` | Trail marker for cross-session continuity | 20–60 |
| `PROBE` | Diagnostic check / health inspection | 10–30 |
| `FEEDBACK` | Result of completed work needing review | 20–50 |
| `BLOCKED` | Dependency or external blocker | 40–70 |

### Status Lifecycle

```
open → claimed → done → archived
         ↓
       stale (TTL expired, no activity)
         ↓
       archived
```

### Weight Rules

- Initial weight: set by creator (0–100)
- Decay: ×0.98 per cycle (configurable via `TERMITE_DECAY_FACTOR`)
- Weight < `decay_threshold` (default 5) → auto-archived
- Manual boost: agent may increase weight on re-encounter
- Concentration: multiple agents touching same signal → weight increases

---

## Observation — `signals/observations/O-xxx.yaml`

An observation is a pattern noticed by an agent during work.
Observations are **not rules** — they are raw data points.
When ≥3 independent observations share the same pattern,
they are promoted to a rule by `field-cycle.sh`.

```yaml
id: O-001
pattern: "organizationId parsed as integer causes silent data loss"
context: "backend/src/services/tenant.ts:42"
reporter: "termite:2026-02-27:worker"
confidence: high         # high | medium | low
created: 2026-02-27
detail: |
  parseInt(organizationId) silently truncates UUID strings.
  Must use String().trim() for all organizationId handling.
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Unique identifier (O-xxx or O-{timestamp}) |
| `pattern` | yes | Short description of the observed pattern |
| `context` | yes | Where the observation was made (file:line or module) |
| `reporter` | yes | Termite signature of the observing agent |
| `confidence` | yes | `high` / `medium` / `low` |
| `created` | yes | Date of observation |
| `detail` | no | Extended description with specifics |

---

## Rule — `signals/rules/R-xxx.yaml`

A rule is a promoted pattern that has been independently observed
by ≥3 agents or sessions. Rules are injected into `.birth` by
`field-arrive.sh` based on relevance to the current context.

```yaml
id: R-001
trigger: "When I encounter organizationId in any expression"
action: "Never use parseInt() or Number(). Always use String().trim()."
source_observations: [O-001, O-005, O-012]
hit_count: 7
disputed_count: 1
last_triggered: 2026-02-27
created: 2026-02-27
tags: [auth, multi-tenant, data-integrity]
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Unique identifier (R-xxx) |
| `trigger` | yes | "When I observe..." condition |
| `action` | yes | "I must do..." response |
| `source_observations` | yes | List of observation IDs that led to promotion |
| `hit_count` | no | Times this rule has been triggered (default 0) |
| `disputed_count` | no | Times an agent found this rule inapplicable or incorrect (default 0). When `disputed_count / hit_count > 0.3`, the rule should be reviewed. |
| `last_triggered` | no | Date of last trigger |
| `created` | yes | Date rule was promoted |
| `tags` | no | Categorization tags |

### Rule Lifecycle

- **Promotion:** ≥3 observations with same `pattern` → auto-promoted by `field-cycle.sh`
- **Active use:** `field-arrive.sh` selects top-N rules by relevance for `.birth`
- **Dispute:** Agent encounters trigger but finds action wrong/inapplicable → increments `disputed_count`
- **Review:** `disputed_count / hit_count > 0.3` → rule flagged for human review or demotion
- **Archival:** `last_triggered` > 60 days → moved to `signals/archive/rules/`

---

## Claim Lock — `signals/claims/S-xxx.<op>.lock`

A claim lock prevents concurrent work on the same signal.
Created by `field-claim.sh`, verified via git optimistic concurrency.

```yaml
signal: S-001
operation: work          # work | audit | review
owner: "termite:2026-02-27:worker"
base_commit: abc1234
claimed_at: 2026-02-27T14:30:00Z
ttl_hours: 24
```

### Mutual Exclusion Matrix

| | work | audit | review |
|---|---|---|---|
| **work** | blocked | blocked | allowed |
| **audit** | blocked | blocked | allowed |
| **review** | allowed | allowed | allowed |

- `work` and `audit` are mutually exclusive (cannot run simultaneously)
- `review` never blocks and is never blocked

### Claim Lifecycle

```
claim → work → release
  ↓
expired (ttl_hours exceeded) → auto-released by field-claim.sh expired
```

---

## Thresholds & Configuration

These values are read from `TERMITE_PROTOCOL.md Part II` or environment variables:

| Parameter | Default | Env Override | Description |
|-----------|---------|-------------|-------------|
| `decay_factor` | 0.98 | `TERMITE_DECAY_FACTOR` | Weight multiplier per cycle |
| `decay_threshold` | 5 | `TERMITE_DECAY_THRESHOLD` | Weight below which signals are archived |
| `escalate_threshold` | 50 | `TERMITE_ESCALATE_THRESHOLD` | Weight above which signals escalate |
| `promotion_threshold` | 3 | `TERMITE_PROMOTION_THRESHOLD` | Observations needed to promote to rule |
| `rule_archive_days` | 60 | `TERMITE_RULE_ARCHIVE_DAYS` | Days since last trigger before rule archival |
| `wip_freshness_days` | 14 | `TERMITE_WIP_FRESHNESS_DAYS` | Days before WIP.md considered stale |
| `explore_max_days` | 14 | `TERMITE_EXPLORE_MAX_DAYS` | Max age for EXPLORE signals |
| `claim_ttl_hours` | 24 | `TERMITE_CLAIM_TTL_HOURS` | Default claim lock duration |
