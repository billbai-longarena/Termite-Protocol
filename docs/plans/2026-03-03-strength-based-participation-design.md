# PE-005: Strength-Based Participation (优势参与)

> Design document for the protocol evolution from uniform .birth to strength-differentiated .birth.

## Context

Six audits (4 host projects) revealed the protocol's fundamental design flaw: treating all participants as homogeneous "blind termites" when actual capabilities vary widely. A-006 (5-model heterogeneous swarm) showed weak models forced to deposit degenerate observations (`detail:"0"`), strong models spending time on mechanical execution, and humans limited to four-character input.

## Core Value

**"让参与白蚁协议的任何参与方——人类、AI 大模型、或其他系统——都能发挥它最擅长的长处，并且形成群体的优势。"**

Inspired by Gallup StrengthsFinder: don't fix weaknesses, maximize strengths.

## Implementation

### Phase 1: Infrastructure (no behavior change)
- DB Schema v2→v3: agents + pheromone_history gain platform/strength/trigger columns
- Enhanced platform detection: OpenCode via OPENCODE/OPENCODE_PROJECT env vars
- Pheromone extension: --platform, --strength, --trigger-type params in field-deposit.sh

### Phase 2: Strength Profiles (observe, don't act)
- compute_strength_tier(): platform + 24h behavioral data → execution|judgment|direction
- Trigger type detection: TERMITE_TRIGGER_TYPE env var, TERMITE_AUTO, platform heuristic
- Agent registration: platform, strength_tier, trigger_type stored in agents table

### Phase 3: Differentiated .birth (core behavior change)
- Static content migration: birth-static-included marker in entry files → omit grammar+safety from .birth
- Three .birth template functions: write_birth_execution(), write_birth_judgment(), write_birth_direction()
- Observation deposit differentiation: execution=optional, judgment=required, direction=auto-high

### Phase 4: Rule Quality Gate (W-012a)
- validate_rule_quality() in field-cycle.sh Step 5
- Rejects degenerate triggers, tautological actions, short actions
- Source observations archived regardless (prevents re-promotion)

### Phase 5: Protocol Documentation
- TERMITE_PROTOCOL.md: new "Strength-Based Participation" section, v3.5→v4.0
- UPGRADE_NOTES.md: v4.0 entry
- Entry file kernel: v10.0→v11.0
- REGISTRY.yaml: PE-005 record

## Backward Compatibility

| Component | Old (v3.5) | New (v4.0) | Compatibility |
|-----------|-----------|-----------|---------------|
| .birth format | Single format | Three templates | Old agents read any .birth (plain text) |
| .pheromone | 10 fields | 12 fields | Additive, old parsers ignore new fields |
| DB schema | v2 | v3 | ALTER TABLE ADD COLUMN (idempotent) |
| Entry file | No marker | birth-static-included | No marker → fallback includes static = current behavior |

## Assumptions

| ID | Assumption | If wrong |
|----|-----------|----------|
| A-001 | Heartbeat trigger = autotermite | Platform detection + behavioral observation fallback |
| A-002 | 3 deposits enough for cold start | Conservative default (execution) doesn't break, only loses efficiency |
| A-003 | Static content in entry file doesn't lose info | Detection failure → fallback includes static = current behavior |
