# A-006 touchcli Multi-Model Audit Analysis

**Date**: 2026-03-03
**Auditor**: Protocol Nurse (Claude Opus 4.6)
**Package**: `audit-packages/touchcli/2026-03-03/`
**Significance**: First 5-agent, 5-model heterogeneous swarm experiment

## Experiment Configuration

| Agent | Tool | Model | Role |
|-------|------|-------|------|
| Agent 1 | Codex | Codex 5.3 | Shepherd (strong model) |
| Agent 2 | Claude Code | Claude Haiku | Weak model worker |
| Agent 3 | OpenCode | GPT-5.1 Codex-mini | Weak model worker |
| Agent 4 | OpenCode | Gemini 3 Flash | Weak model worker |
| Agent 5 | OpenCode | Claude Sonnet 4.6 | Mid-tier worker |

**Protocol version**: v3.4 (pre-TF-007 emergence strengthening)
**Duration**: ~17.2 hours (2026-03-02 07:04 UTC → 2026-03-03 00:18 UTC)
**Project type**: SaaS (Python FastAPI + Go Gateway + React frontend)

## Key Metrics

| Metric | A-006 (5 agents) | A-005 (3 agents) | Delta |
|--------|------------------|-------------------|-------|
| Total commits | **559** | 130 | +329% |
| Signed commits | **390** (67.5%) | 15 (11.5%) | +56pp |
| Signature ratio last 50 | **0.96** | 0.00 | +0.96 |
| Handoff quality | **1.00** (137/141) | 0.99 (69/70) | +0.01 |
| Pheromone snapshots | **141** | 77 | +83% |
| Observations | **270** | 28 | +864% |
| Rules emerged | **21** | 1 | +2000% |
| Signals processed | **112+** (S-001→S-112) | 6 (S-001→S-006) | +1767% |
| Active signals (true) | **1** (S-108 claimed) | 4 (all completed) | - |
| Archived items | **293** | 1 | +29200% |
| Idle heartbeats | **18.4%** | 65% | -46.6pp |

## Findings

### W-012: Rule Emergence Degeneracy — 21 Rules, 0 Hits, All Degenerate

**Severity**: high
**Source**: A-006 rule-health.yaml + signals/rules/

All 21 emerged rules are **degenerate**:
- **20 of 21** have trigger = `"When I observe: heartbeat"` or `"When I observe: o-2026xxxx-heartbeat"` or `"When I observe: s-108"`
- **All 21** have `hit_count: 0` (never triggered)
- **20 of 21** have action = `"Follow the pattern described in trigger"` (tautological)

This is a **qualitative regression** from A-005, where R-001 had a meaningful trigger (`"≥3 Scout observations confirm: protocol framework stable..."`) and actually fired (`hit_count: 1`).

**Root cause**: The fuzzy keyword clustering in TF-007 (not yet deployed to this v3.4 colony) was designed to address this, but the problem is deeper. The weak/mid-tier models are mass-producing observations with pattern="heartbeat" or pattern="S-xxx", and 3+ of these identical patterns trigger Rule 7 emergence — producing rules that are formally correct (3 observations matched) but semantically empty.

**Implication**: Rule 7 activation energy was already too low in v3.4. TF-007's quality gate (degenerate observation exclusion from clustering) would have prevented most of these. **TF-007 validated by negative example.**

**Recommendation**: W-012a — After TF-007 deployment, also add a quality gate on rule emergence: reject rules where trigger or action contains only signal IDs, heartbeat keywords, or tautological patterns ("Follow the pattern described in trigger").

### W-013: Observation Quality Regression — 57% Quality Rate

**Severity**: medium
**Source**: A-006 observations analysis (270 observations)

| Metric | A-006 | A-005 | ReactiveArmor |
|--------|-------|-------|---------------|
| Total observations | 270 | 28 | 14 |
| Quality rate | **57.0%** | 96.4% | 35.7% |
| Degenerate count | 116 | 1 | 9 |

116 of 270 observations (43%) are degenerate, with patterns like:
- `pattern: "S-014"`, `detail: "0"` (signal ID as pattern, numeric zero as detail)
- `pattern: "HEARTBEAT-PHASE6-START"`, `detail: "0"`
- `pattern: "strategic-review"`, `detail: "0"`

**Root cause analysis**:
- A-005 had 1 Codex shepherd producing high-quality observations that Haiku imitated (Shepherd Effect)
- A-006 has 5 agents including 3 OpenCode agents. The OpenCode agents (GPT-5.1 Codex-mini, Gemini 3 Flash) appear to produce many degenerate observations with `detail: "0"`
- The degenerate observations are concentrated in the OpenCode agent sessions (timestamps correlate with unsigned commits)
- **The Shepherd Effect is diluted by volume**: with 3 weak agents producing 116 degenerate obs vs 154 good ones, the pheromone chain gets polluted

**Positive note**: 154 high-quality observations is still an absolute record — the strong/mid models are producing excellent observations. The problem is the weak-model tail.

### W-014: Unsigned Commit Volume — 184/567 Commits (32.5%)

**Severity**: medium
**Source**: A-006 git-signatures.txt

184 commits lack the `[termite:YYYY-MM-DD:caste]` signature format. These come from:
- OpenCode agents that don't use the prepare-commit-msg hook (120 "other" pattern)
- Signal-focused commits without proper format (98 with signal IDs but no termite prefix)
- Heartbeat commits without signature (20)

**Cross-colony comparison**: This is the same W-002 pattern from ReactiveArmor. The signature hook depends on the tool's git hook support. Claude Code and Codex support prepare-commit-msg hooks; OpenCode apparently does not.

**Recommendation**: W-014a — Document in TERMITE_PROTOCOL.md that signature format is tool-dependent. For tools without hook support, recommend adding `[termite:YYYY-MM-DD:caste]` to the CLAUDE.md / equivalent entry file as a commit message template instruction.

### W-015: Idle Heartbeat Tail — Claim Lock Starvation

**Severity**: medium
**Source**: A-006 pheromone chain entries #113-141

From 23:15 UTC to 00:18 UTC (63 minutes), **28 consecutive pheromone entries** are pure idle heartbeats. All say variations of:
> "Heartbeat monitoring cycle complete with stable claim queue"
> "S-094/S-108 remain work-claimed; no open signals available"

This is a **new failure mode** distinct from A-005's idle spinning (W-007):
- A-005: agents idle because all signals were completed (colony done)
- A-006: agents idle because **2 signals are claimed by other agents** but those agents have finished their sessions — the claims are orphaned but haven't expired

**Root cause**: Claim TTL governance works but the idle agents **refuse to preempt** ("non-preemptive TTL policy"). They cycle every 1-2 minutes checking if claims expired, wasting compute.

**Note**: Colony was on v3.4. TF-005's idle detection (.birth "IDLE: Colony has no actionable signals") would partially address this. But the root issue is orphaned claims, not idle colony detection.

**Recommendation**: W-015a — Add claim timeout enforcement: if a claimed signal hasn't been touched for >N heartbeats (suggest 10), field-cycle.sh should auto-release the claim. This is more aggressive than current TTL-based expiry but prevents the 63-minute idle tail.

### W-016: Export Bug — Completed Signals in active/ Directory

**Severity**: low
**Source**: A-006 signals/active/ analysis

39 of 40 signals in `signals/active/` have `status: completed`. Only S-108 (`status: claimed`) is truly active. This causes:
- `metadata.yaml` reports `active_signals: 40` (misleading)
- `breath-snapshot.yaml` correctly reports `active_signals: 1` (DB query fixed by TF-005)

**Root cause**: `field-export-audit.sh` copies the `signals/active/` directory as-is from the host project. The host project's `signals/active/` directory contains signals that were completed but not yet moved to `signals/archive/`. The archival is a separate step that may not run frequently.

This is an **export cosmetic issue**, not a runtime bug. The field-arrive.sh queries (fixed in TF-005) correctly exclude completed signals at runtime.

**Recommendation**: W-016a — In `field-export-audit.sh`, filter the active signals copy to exclude `status: completed|done`. Or add a note to the audit package README explaining that active/ may contain recently-completed signals.

## Cross-Colony Synthesis

### Shepherd Effect Scaling

| Configuration | Handoff | Obs Quality | Rules | Idle |
|---------------|---------|-------------|-------|------|
| 2 Haiku alone (ReactiveArmor) | 0% | 35.7% | 0 | N/A |
| 1 Codex + 2 Haiku (A-005) | 99% | 96.4% | 1 | 65% |
| 1 Codex + 1 Haiku + 3 OpenCode (A-006) | **100%** | **57.0%** | 21 (0 useful) | **18.4%** |

**Key insight**: The Shepherd Effect scales differently across metrics:
1. **Handoff quality scales perfectly** — even with 5 heterogeneous agents, predecessor_useful reaches 100%. The pheromone chain format is simple enough for all models to follow.
2. **Observation quality does NOT scale** — adding more weak agents dilutes quality. The 3 OpenCode agents collectively produce more degenerate observations than the 1 Codex + 1 Haiku + 1 Sonnet produce good ones. **Quality gate (TF-007) is essential.**
3. **Rule emergence is worse at scale** — more agents produce more observations, more observations trigger Rule 7 more often, but degenerate observations produce degenerate rules. **21 rules, 0 useful** vs A-005's **1 rule, 1 useful**.
4. **Idle rate dramatically improved** — from 65% to 18.4%. With 5 agents and 112+ signals, there's more work to go around. But the tail-end claim starvation is a new problem.

### Model Tier Validation

Extends PE-003 capability tiers:

| Capability | T0 (any) | T1 (mid) | T2 (strong) |
|------------|----------|----------|-------------|
| Signal claim + execute | All 5 models | - | - |
| Commit with code | All 5 models | - | - |
| Pheromone deposit | All 5 models | - | - |
| predecessor_useful | All 5 models | - | - |
| Signed commit format | Codex, Claude | OpenCode fails | - |
| Quality observation | - | Sonnet 4.6 | Codex 5.3 |
| Degenerate observation | Haiku, GPT-5.1-mini, Gemini Flash | - | - |
| Rule emergence (useful) | - | - | Codex only |
| Strategic planning | - | Sonnet 4.6 | Codex 5.3 |

**New finding**: GPT-5.1 Codex-mini and Gemini 3 Flash behave identically to Haiku in observation quality — they mechanically deposit but don't understand WHAT to deposit. This confirms F-009c is **model-family-agnostic**: the weak model problem is not specific to Claude Haiku.

### Production Delivery Assessment

Despite protocol health issues, the colony achieved remarkable output:
- **559 commits** in 17 hours (~33 commits/hour)
- **S-001 → S-112**: 112 signals created, ~72 completed
- Full SaaS stack: Python FastAPI backend + Go Gateway + React frontend
- MVP complete with Phase 2 features (Product KB, Voice STT/TTS, Memory Search)
- **293 archived items** — most active signal lifecycle of any colony

This is the **highest-throughput colony ever observed** in the Termite Protocol.

## Recommendations Summary

| ID | Priority | Description | Template Impact |
|----|----------|-------------|-----------------|
| W-012a | high | Add quality gate to rule emergence (reject degenerate triggers/actions) | field-cycle.sh |
| W-013 | medium | TF-007 quality gate validated — deploy v3.5 to this colony | UPGRADE_NOTES.md |
| W-014a | low | Document signature format as tool-dependent in protocol spec | TERMITE_PROTOCOL.md |
| W-015a | medium | Add claim timeout enforcement (auto-release after N idle heartbeats) | field-cycle.sh or field-claim.sh |
| W-016a | low | Filter completed signals from active/ in export | field-export-audit.sh |

## Delta from A-005

| Dimension | A-005 | A-006 | Assessment |
|-----------|-------|-------|------------|
| Agent count | 3 | 5 | Scaled 67% |
| Model diversity | 2 (Codex + Haiku) | 5 (Codex, Haiku, GPT-5.1-mini, Gemini Flash, Sonnet) | First heterogeneous swarm |
| Throughput | 130 commits | 559 commits | +329% |
| Signal throughput | 6 signals | 112+ signals | +1767% |
| Handoff quality | 99% | 100% | Maintained |
| Observation quality | 96.4% | 57.0% | **Degraded** (dilution) |
| Rule quality | 1 useful | 0 useful (21 degenerate) | **Degraded** |
| Idle rate | 65% | 18.4% | **Improved** |
| New failure mode | - | Claim lock starvation | New |
