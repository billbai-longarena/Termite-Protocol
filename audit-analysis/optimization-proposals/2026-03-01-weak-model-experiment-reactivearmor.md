# ReactiveArmor Weak Model Experiment Analysis

**Date**: 2026-03-01
**Analyst**: Protocol Nurse (Claude Opus)
**Audit Package**: `audit-packages/ReactiveArmor/2026-03-01/`
**Significance**: First weak model field test — validates F-009 predictions

---

## Experiment Configuration

| Parameter | Value |
|-----------|-------|
| **Genesis Model** | Codex (strong model) |
| **Runtime Models** | 2 x Claude Haiku (weak models, parallel) |
| **Trigger** | "白蚁协议" heartbeat input |
| **Duration** | ~4.5 hours (15:31 - 19:56 UTC+8) |
| **Total Commits** | 121 |
| **Agent Count** | 29 (Agent A → Agent AC) |
| **Signals Completed** | S-001 → S-024 (24 signals) |
| **Test Growth** | 93 → 174 tests passing |

---

## Executive Summary

The ReactiveArmor experiment is the **first field test of weak models running the Termite Protocol**. Two Haiku instances ran in parallel with heartbeat-triggered "白蚁协议" input after a Codex-led genesis.

**Key finding**: The core protocol loop (ARRIVE → SENSE → ACT → DEPOSIT) executed successfully, but **judgmental behaviors failed**. This validates F-009's prediction that weak models mechanically execute protocol steps without understanding the intent.

---

## Detailed Findings

### Finding W-001: Degenerate Observation Deposits (Critical)

**Evidence**: Of 14 observations in the audit package:
- 5 proper observations (genesis phase, likely Codex)
- 9 degenerate observations (Haiku runtime)

**Degenerate pattern**:
```yaml
id: O-20260301163106-74563
pattern: "S-007"           # Should be a behavioral pattern, not a signal ID
context: "unknown"         # Should describe where/when observed
detail: |
  0                        # Should be multi-line analysis
```

**Analysis**: Haiku agents:
1. Correctly identified the deposit obligation (protocol rule 4)
2. Invoked field-deposit.sh or equivalent
3. Failed to understand WHAT to deposit
4. Fell back to minimal valid YAML (signal ID as pattern, "0" as detail)

**Validates**: F-009c — "Undeclared assumption: agent general intelligence fills protocol gaps"

**Impact**: Observation quality collapses under weak models. The deposit mechanism works mechanically but produces useless data.

---

### Finding W-002: Signature Format Divergence (Medium)

**Evidence**:
```yaml
# metadata.yaml
signature_ratio_last_50: 0.00

# caste-distribution.yaml
distribution:
first_signature: unknown
last_signature: unknown
```

Yet git-signatures.txt shows 121 commits with clear termite patterns:
```
chore(molt): Agent Q MOLT ceremony — S-017 complete, 77 tests passing
chore(signals): Agent Y work record — S-023 Phase 1 foundation complete
```

**Analysis**:
1. Haiku invented its own naming convention (`Agent X`) instead of `termite:YYYY-MM-DD:caste`
2. Export script regex doesn't match Haiku's format
3. All commits appear in both "signed" and "unsigned" sections (bug)

**Root cause**: Weak models don't strictly follow the signature format in TERMITE_PROTOCOL.md but create functionally similar structures.

**Impact**: Protocol tooling fails to recognize valid termite activity from weak models.

---

### Finding W-003: Handoff Evaluation Skipped (Medium)

**Evidence**:
```yaml
# handoff-quality.yaml
total_handoffs: 6
predecessor_useful_true: 0
predecessor_useful_false: 1
predecessor_useful_not_evaluated: 5
useful_ratio: 0.00
```

**Analysis**:
- 5 of 6 handoffs have `predecessor_useful: null`
- Weak models skip the evaluation step (a judgmental behavior)
- One explicit `false` suggests at least one agent attempted evaluation

**Impact**: Cross-session learning signal is lost. Protocol cannot measure handoff effectiveness.

---

### Finding W-004: No Rule Emergence (Expected)

**Evidence**:
```yaml
# rule-health.yaml
rules:
# (empty)

# metadata.yaml
active_rules: 0
```

Despite 24 signals and 14 observations across 29 agent sessions.

**Analysis**: Protocol Rule 7 (`count(agents, same_signal) >= 3 -> EMERGE`) requires:
1. Pattern recognition across sessions
2. Abstraction from specific to general
3. Rule formulation and deposition

All three are judgmental behaviors beyond Haiku's capability.

**Impact**: Rule emergence is a strong-model-only feature. Weak model colonies will not self-organize beyond initial rule set.

---

### Finding W-005: Pheromone Deposit Incomplete (Low)

**Evidence**:
- 6 pheromone snapshots for 29 agent sessions
- Expected: ~29 deposits (one per MOLT)

**Analysis**: Most MOLT ceremonies committed `.pheromone` updates, but many sessions may have terminated without proper deposit, or the export captured only a subset.

**Impact**: Cross-session state transfer is incomplete but not catastrophic (6 deposits still provide continuity).

---

### Finding W-006: Core Protocol Loop Successful (Positive)

**Evidence**:
- 121 structured commits following signal-driven pattern
- MOLT ceremonies executed on context exhaustion
- Test count grew consistently (93 → 174)
- S-001 → S-024 completed in order

**Analysis**: Despite judgmental failures, the **mechanical protocol core works**:
- ARRIVE: Agents read .birth / WIP
- SENSE: Agents identified next signal
- ACT: Implementation proceeded
- DEPOSIT: Commits made (even if observation content was poor)
- MOLT: Context-triggered handoffs occurred

**Impact**: Weak models can execute structured development workflows when signals are pre-defined.

---

## F-009 Validation Matrix

| F-009 Sub-finding | Status | Evidence |
|-------------------|--------|----------|
| F-009a: Entry files reference 1193-line TERMITE_PROTOCOL.md | **Inconclusive** | No direct evidence in audit |
| F-009b: .birth spends 25% token budget on static content | **Inconclusive** | No .birth files in audit package |
| F-009c: Undeclared assumption — agent intelligence fills gaps | **VALIDATED** | 9/14 degenerate observations |
| F-009d: field-arrive.sh complexity creates black box | **Inconclusive** | No direct evidence |

---

## Protocol Improvement Recommendations

### Immediate (Template Fixes)

1. **R-001: Fix signature detection regex** in `field-export-audit.sh`
   - Match `Agent [A-Z]+` pattern in addition to `termite:YYYY-MM-DD:caste`
   - Severity: Medium (tooling accuracy)

2. **R-002: Add observation validation** in `field-deposit.sh`
   - Reject observations where `pattern` matches `^S-\d+$` or `^O-\*$`
   - Reject observations where `detail` is numeric-only
   - Severity: High (data quality)

### Short-term (Protocol Evolution)

3. **R-003: Provide observation examples in .birth**
   - Include 1-2 example observations with proper pattern/context/detail
   - Weak models can copy structure without understanding intent
   - Severity: High (weak model support)

4. **R-004: Make predecessor_useful evaluation explicit**
   - Add prompt in .birth: "Evaluate predecessor session: true/false/null"
   - Severity: Medium (handoff quality)

### Long-term (Architecture)

5. **R-005: Define protocol capability tiers**
   ```
   T0 (Mechanical): Safety nets only, deposits optional
   T1 (Conditional): Deposits required, format validated
   T2 (Judgmental): Rule emergence, caste transitions, value checks
   ```
   - T0/T1 achievable by weak models
   - T2 requires strong models or infrastructure support
   - Severity: Strategic (protocol evolution direction)

6. **R-006: Infrastructure-assisted judgment**
   - Move judgmental behaviors into field scripts where possible
   - Example: field-deposit.sh could prompt for observation fields
   - Example: field-arrive.sh could suggest caste based on signal type
   - Severity: Strategic (reduces intelligence dependency)

---

## Cross-Colony Pattern Check

| Pattern | ReactiveArmor | OpenAgentEngine | 0227 |
|---------|---------------|-----------------|------|
| Degenerate observations | 9/14 (64%) | 0/74 (0%) | 0/3 (0%) |
| Signature format divergence | Yes | No | No |
| Handoff evaluation skipped | 5/6 (83%) | 0% | Unknown |
| Rule emergence | None | None | None |
| Core loop success | Yes | Yes | Yes |

**Conclusion**: ReactiveArmor's issues are **model-specific** (Haiku), not protocol bugs. Strong model colonies (OAE, 0227) do not exhibit these patterns.

---

## Appendix: Observation Quality Comparison

### Proper Observation (Genesis/Codex)
```yaml
id: O-20260301155342-40150
pattern: "protocol-audit: interruption/claim guidance mostly sufficient, workspace-drift runbook missing"
context: "BLACKBOARD.md##Immune Log; TERMITE_PROTOCOL.md recovery/concurrency sections"
reporter: "termite:2026-03-01:worker"
confidence: high
detail: |
  Recorded two audit notes: (1) interruption+claim flows are covered, but no explicit
  in-flight workspace drift procedure; (2) audit submission channel exists but telemetry
  is disabled (enabled=false, accepted=false). Proposed follow-up: add workspace_drift
  recovery hint and owner-verified claim release semantics in protocol tooling.
```

### Degenerate Observation (Runtime/Haiku)
```yaml
id: O-20260301163106-74563
pattern: "S-007"
context: "unknown"
reporter: "termite:2026-03-01:worker"
confidence: medium
detail: |
  0
```

The contrast is stark. Codex produces actionable protocol feedback; Haiku produces placeholder data.

---

## Conclusion

The ReactiveArmor experiment provides **invaluable weak model data** that validates F-009's core thesis: the protocol has accumulated judgmental behaviors that cannot be executed by weak models.

The path forward is clear:
1. Accept that T2 behaviors require strong models
2. Move T1 behaviors into infrastructure where possible
3. Ensure T0 (safety nets) work regardless of model capability

This experiment should be repeated with other weak models (GPT-3.5, Gemini Flash) to determine if the findings are Haiku-specific or generalizable to all weak models.
