# Feedback Loop Robustness Audit

Date: 2026-03-01
Status: Complete
Auditor: Claude Opus 4.6 (Nurse-mode, protocol source repo)
Scope: All 6 feedback loops across intra-colony, cross-session, and cross-colony dimensions

## Executive Summary

The Termite Protocol implements 6 feedback loops. Intra-colony automation is robust (dual DB/YAML paths, post-commit triggers). Cross-colony loops are architecturally complete but operationally broken: 5 of 8 steps in the primary cross-colony loop are manual. One live code bug was found (pipe-subshell in field-cycle.sh DB path). The biggest systemic risk is **silent degradation** — errors are swallowed by design, meaning loops can fail without anyone noticing.

Overall robustness grade: **C+**

## Loop Inventory

| # | Loop | Path | Automated | Rating |
|---|------|------|-----------|--------|
| 1 | Intra-colony metabolism | arrive → .birth → work → post-commit → cycle → breath → arrive | 100% | A |
| 2 | Cross-session handoff | deposit --pheromone → .pheromone → arrive reads it | 80% | B |
| 3 | Observation → EMERGE | deposit --pattern → observations → cycle Step 5 promotion | 70% | B- |
| 4 | Cross-colony outbound | export-audit → submit-audit → PR → Nurse → template fix → upgrade | 37.5% | D |
| 5 | Protocol update inbound | upstream version → arrive detects → HOLE signal → Scout upgrades | 60% | C |
| 6 | Rule dispute | deposit --dispute → disputed_count → rule-health → Nurse action | 50% | C- |

## Loop 1: Intra-colony metabolism

### Chain

```
field-arrive.sh → .birth → Agent works → post-commit hook → field-cycle.sh
       ↑                                                         ↓
       └──── .field-breath refresh ← decay/drain/promote/pulse ──┘
```

### Verdict: Robust (A)

Dual-path (DB + YAML fallback) provides resilience. Post-commit hook reliably triggers the metabolism cycle. Threshold constants are configurable via environment variables.

### Issues

| ID | Severity | Description | Location |
|----|----------|-------------|----------|
| L1-1 | Low | `ensure_db \|\| true` swallows DB initialization failures silently. If SQLite is corrupt, agent proceeds in YAML mode without warning. | field-arrive.sh:32 |
| L1-2 | Info | `stat` failure produces epoch 0, making breath always "stale". Causes redundant cycle runs, not a correctness bug. | field-lib.sh:456 |

## Loop 2: Cross-session handoff

### Chain

```
Agent A → field-deposit.sh --pheromone → .pheromone
    ↓
Agent B → field-arrive.sh → reads .pheromone → predecessor_useful evaluation
```

### Verdict: Functional but fragile (B)

The handoff mechanism works when agents follow the protocol. Silent failure when they don't.

### Issues

| ID | Severity | Description | Location |
|----|----------|-------------|----------|
| L2-1 | Medium | No enforcement that agents run `field-deposit.sh --pheromone` before exiting. Crashed or killed sessions break the chain silently. No "handoff gap detection" in arrive. | field-arrive.sh (missing) |
| L2-2 | Low | `predecessor_useful` has no defined criteria. Metric is tracked but subjective with no actionable threshold. | Design gap |
| L2-3 | Low | JSON construction relies on `python3` for escaping (field-deposit.sh:145). Without python3, raw string interpolation can produce invalid JSON if value contains quotes. | field-deposit.sh:145 |

## Loop 3: Observation → Rule EMERGE

### Chain

```
Agent deposits observation → signals/observations/O-xxx.yaml
    ↓
field-cycle.sh Step 5 → count(same pattern) >= 3 → Rule created + observations archived
```

### Verdict: Works but has a live bug and structural weakness (B-)

### Live Bug: Pipe-subshell in field-cycle.sh DB path

**Location**: field-cycle.sh:104

```bash
echo "$groups" | while IFS=$'\t' read -r pattern cnt ids; do
    ...
    promoted=$((promoted + 1))  # subshell — variable lost
done
```

This is the exact Bug B pattern fixed by TF-001 across field-export-audit.sh, field-cycle.sh (YAML path), and field-deposit.sh. The DB path in Step 5 was missed. The `promoted` counter always stays 0 in the parent shell.

**Impact**: Currently only affects logging accuracy (rule creation and archival work correctly inside the subshell). The `db_rule_create` and `db_transaction` calls execute properly.

**Fix**: Replace with process substitution: `while ... done < <(echo "$groups")`

### Structural Issues

| ID | Severity | Description | Location |
|----|----------|-------------|----------|
| L3-1 | High | **Live bug**: pipe-subshell in DB promotion path. `promoted` counter lost. | field-cycle.sh:104 |
| L3-2 | Medium | Pattern matching is too naive (lowercase + trim). Semantically identical observations phrased differently won't group. EMERGE threshold of 3 is rarely hit with natural language observations. | field-cycle.sh:98-129 |
| L3-3 | Low | No cross-colony EMERGE. Rule 7 operates within a single colony. Nurse has no equivalent EMERGE mechanism for patterns seen across multiple audit packages. | Design gap |

## Loop 4: Cross-colony outbound feedback

### Chain

```
Colony → field-export-audit.sh → audit package
    ↓
field-submit-audit.sh → fork/clone → PR to protocol source repo
    ↓
PR merged → Nurse reads REGISTRY.yaml → Nurse fixes templates
    ↓
Host colony → field-arrive.sh version detection → install.sh --upgrade
```

### Verdict: Weakest loop (D)

Outbound leg (colony → PR) is automated and well-gated. Inbound leg (PR → template fix → colony upgrade) is entirely manual.

### Step-by-step analysis

| Step | Automated? | Notes |
|------|------------|-------|
| 1. Audit export | Yes | field-cycle.sh triggers field-submit-audit.sh |
| 2. PR submission | Yes | 4 gates: telemetry, disclaimer, frequency, gh CLI |
| 3. PR merge | **No** | No auto-merge, no CI, no bot |
| 4. Nurse detects new audit | **No** | Requires human to say "白蚁协议" or "Nurse 分析" |
| 5. Nurse cross-colony analysis | **No** | No automated pattern detection tool |
| 6. Nurse template fix | **No** | No automated patch generation |
| 7. Version detection in colony | Yes | field-arrive.sh Step 3.7 |
| 8. Colony applies upgrade | **Partial** | Scout sees HOLE signal, must run install.sh --upgrade manually |

**3 of 8 automated, 5 manual.**

### Issues

| ID | Severity | Description | Location |
|----|----------|-------------|----------|
| L4-1 | High | No automated Nurse trigger. Protocol source repo relies on human invocation to start analysis. | CLAUDE.md Operations section |
| L4-2 | High | No automated PR merge for audit packages. PRs accumulate without action. | Design gap |
| L4-3 | Medium | No automated cross-referencing tool. Nurse must manually compare findings across audit packages. | Design gap |
| L4-4 | Low | `PIPESTATUS[0]` after pipe is fragile — any inserted statement between pipeline and check would silently break. | field-submit-audit.sh:128 |
| L4-5 | Info | Force push to same-day branch is by design but could cause confusion with multiple agents. | field-submit-audit.sh:194 |

## Loop 5: Protocol update detection inbound

### Chain

```
Protocol source repo → version bump → field-arrive.sh Step 3.7
    ↓
upstream_protocol_version() → cache check → gh/curl fetch → compare
    ↓
Mismatch → HOLE signal (weight:35) → Scout reviews → install.sh --upgrade
```

### Verdict: Detection works, action undefined (C)

### Issues

| ID | Severity | Description | Location |
|----|----------|-------------|----------|
| L5-1 | Medium | Version comparison is string-based. `v3.04` vs `v3.4` falsely triggers. Downgrade not distinguished from upgrade. | field-arrive.sh:114 |
| L5-2 | Medium | Cache timing is inconsistent. `days_since` uses integer division by 86400. "24h cache" ranges from 1min to ~48h depending on time of day. | field-lib.sh:238-244 |
| L5-3 | Low | `gh api releases/latest` is first attempt but repo doesn't use Releases. Always falls through to raw file read, adding unnecessary latency. | field-lib.sh:256 |
| L5-4 | Low | If `gh` is authenticated but rate-limited, fallback to `curl` doesn't trigger (only on missing/unauthed gh). | field-lib.sh:255-268 |
| L5-5 | Medium | No automated upgrade script. Design doc describes "semi-autonomous upgrade" but no `field-upgrade.sh` exists. Scout must manually run `install.sh --upgrade`. | Design gap |

## Loop 6: Rule dispute feedback

### Chain

```
Agent → field-deposit.sh --dispute R-xxx → disputed_count++
    ↓
rule-health.yaml in audit package → Nurse sees high dispute ratio → action
```

### Verdict: Recording works, no automated response (C-)

### Issues

| ID | Severity | Description | Location |
|----|----------|-------------|----------|
| L6-1 | Medium | No dispute threshold triggers any action. 95% disputed rule stays active. Archival uses `last_triggered` staleness, not dispute ratio. | field-cycle.sh Step 7 |
| L6-2 | Low | `rule-health.yaml` flags `disputed_ratio > 0.3` in comments, but nobody reads this flag automatically. | field-export-audit.sh:322 |
| L6-3 | Low | No cross-colony EMERGE for rule deprecation. "Rule X disputed in 3+ colonies" pattern is undetectable. | Design gap |

## Cross-cutting findings

| ID | Severity | Finding |
|----|----------|---------|
| CC-1 | Medium | **Silent degradation.** `\|\| true` and `2>/dev/null` appear 40+ times. Failures are invisible by design. No metric tracks silent failure count. |
| CC-2 | Medium | **No feedback loop health metrics.** No meta-metric like "days since last loop closure" or "audit packages pending Nurse review." |
| CC-3 | Low | **REGISTRY.yaml is protocol-source-repo-only.** Host projects can't see which findings are addressed without reading upstream REGISTRY. |
| CC-4 | Low | **No post-upgrade verification.** `install.sh --upgrade` copies files but doesn't verify success (no checksum, no receipt, no test run). |
| CC-5 | Info | **macOS/Linux compatibility** is well-handled throughout (stat, date, sed fallbacks). |

## Full chain trace: Bug discovery → Fix propagation

Tracing the complete lifecycle of a template bug:

| Step | Description | Automated? | Actual status |
|------|-------------|------------|---------------|
| 1 | Agent hits bug, deposits observation | Yes | Working (proven by O-001) |
| 2 | EMERGE promotes if count >= 3 | Yes | Rarely fires (single agent = 1 observation) |
| 3 | Audit package captures observation | Yes | Working |
| 4 | Audit PR submitted to protocol source repo | Yes | Working (if telemetry enabled) |
| 5 | PR merged | Manual | No automation |
| 6 | Nurse reads REGISTRY, detects pattern | Manual | No automation |
| 7 | Nurse locates bug in template | Manual | No automation |
| 8 | Nurse fixes template, bumps version | Manual | No automation |
| 9 | Colony detects version update | Yes | Working (if telemetry enabled) |
| 10 | Scout applies upgrade | Manual | No field-upgrade.sh exists |

**Minimum time from bug discovery to fix propagation**: Unbounded (depends on human triggering Nurse). The first feedback loop closure (grep-c, TF-001) took 4 days and required human intervention at steps 5-8.

## Recommendations (prioritized)

| Priority | ID | Recommendation | Addresses |
|----------|----|----------------|-----------|
| P0 | R-1 | Fix pipe-subshell in field-cycle.sh:104 (DB promotion path) | L3-1 |
| P1 | R-2 | Add automated Nurse trigger: cron/GitHub Action that runs Nurse analysis when new audit PRs are merged | L4-1, L4-2 |
| P1 | R-3 | Add dispute-ratio-based action to field-cycle.sh Step 7 (e.g., auto-park rules with disputed_ratio > 0.5) | L6-1 |
| P2 | R-4 | Add handoff gap detection to field-arrive.sh: check if .pheromone is stale relative to last commit, emit warning | L2-1 |
| P2 | R-5 | Add semantic version comparison function to field-lib.sh | L5-1, L5-2 |
| P2 | R-6 | Add feedback loop health metrics to audit packages: loop_closures_count, days_since_last_upstream_check, silent_error_count | CC-1, CC-2 |
| P3 | R-7 | Add cross-colony EMERGE to Nurse workflow: when 3+ colonies observe the same pattern, auto-generate template fix proposal | L3-3, L6-3 |
| P3 | R-8 | Add post-upgrade verification to install.sh: checksum comparison + post-install test | CC-4 |
| P3 | R-9 | Create field-upgrade.sh for semi-autonomous upgrade path | L5-5 |
