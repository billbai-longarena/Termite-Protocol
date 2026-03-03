<!-- upgrade-notes:v1.0 -->
# Termite Protocol — Upgrade Notes

> **Scout: read this file before deciding whether to run `install.sh --upgrade`.**
> After upgrading, check **Action Required** sections for each version between your old and new version.

---

## v5.1 — Signal Dependency Graph (2026-03-03)

### Changes
- **Signal decomposition**: signals table gains `parent_id`, `child_hint`, `depth` fields for parent-child relationships
- **field-decompose.sh**: New script for strong models to decompose complex signals into atomic sub-tasks
- **Leaf-priority .birth**: field-arrive.sh now shows unclaimed leaf signals (not decomposed parents) in .birth ## task
- **Auto-aggregation**: field-cycle.sh Step 4/8 auto-closes parent signals when all children complete
- **DECOMPOSE hint**: When unclaimed signals < active agents, .birth injects decomposition guidance
- **DB schema v4 → v5**: signals table +3 columns, +1 index
- **Rule 4b**: DEPOSIT(complex) → DECOMPOSE(children, hint_per_child)

### Action Required
- Run `install.sh --upgrade` to get new field-decompose.sh and updated scripts
- Existing signals are unaffected (parent_id defaults to NULL)

### Action Optional
- Strong models can now call `./scripts/field-decompose.sh` to split complex signals
- Set `TERMITE_DECOMPOSE_MAX_DEPTH` (default: 3) and `TERMITE_DECOMPOSE_MIN_AGENT_RATIO` (default: 0.5)

---

## v5.0 (2026-03-03)

### Changes
- **Protocol philosophy**: "Stateless, not blind" — all termites are stateless, the environment carries intelligence. Replaces the "blind termite" metaphor with a more accurate model: strong models produce environment intelligence, weak models consume it.
- **Rule 10 (Shepherd Effect)**: `DEPOSIT(quality ≥ threshold) → TEMPLATE` — high-quality deposits automatically become behavioral templates for successors. Promoted from deployment recommendation to core grammar rule.
- **Trace/Deposit separation**: Pheromone system now distinguishes tool-guaranteed facts (traces, no decay) from model-dependent knowledge (deposits, quality-weighted decay). `field-deposit.sh` auto-classifies each observation.
- **Artifact quality scoring**: Observations receive `quality_score` (0.0-1.0) at deposit time via H2-validated heuristic. Replaces PE-005's agent-level classification — protocol no longer judges "who you are", only "what you produced".
- **Unified .birth template**: Single state-driven template replaces PE-005's 3 differentiated templates (execution/judgment/direction). Colony phase determines token budget allocation. All agents see the same `.birth` — capability difference expresses through extraction depth, not pre-filtered input.
- **Quality-weighted emergence**: Rule 7 threshold changes from `count ≥ 3` to `sum(quality_score) ≥ 3.0`. Degenerate deposits are mathematically excluded from emergence without being prohibited.
- **DB schema v4**: New `observations.quality_score` (REAL), `observations.source_type` (TEXT) columns. Auto-migrated from v3.
- **Entry file kernel version**: v11.0 → v12.0 (both CLAUDE.md and AGENTS.md templates).
- **Protocol version**: v4.0 → v5.0.

### Action Required
- **None** — DB schema auto-migrates v3→v4 on next `field-arrive.sh` run. All changes are backward-compatible.

### Action Optional
- Update entry files (CLAUDE.md/AGENTS.md) to kernel v12.0 for Rule 10 and updated Rule 7.
- Review observation quality scoring: observations with `detail="0"` now score 0.00 and are excluded from emergence.

---

## v4.0 (2026-03-03)

### Changes
- **Strength-based participation (PE-005)**: Protocol now identifies three participant profiles — execution (weak models), judgment (strong models), direction (humans/directives) — and generates differentiated `.birth` files for each. Execution tier gets pre-selected tasks + behavioral templates; judgment tier gets full strategic context + near-threshold observation prompts; direction tier gets decisions needed + colony overview. (PE-005)
- **DB schema v3**: `agents` table gains `platform`, `strength_tier`, `trigger_type` columns. `pheromone_history` table gains `platform`, `strength_tier` columns. Auto-migrated from v2 on first script run. (PE-005 Phase 1)
- **Enhanced platform detection**: `detect_platform()` now recognizes OpenCode via `OPENCODE` or `OPENCODE_PROJECT` environment variables. Returns: `claude-code | codex-cli | opencode | unknown`. (PE-005 Phase 1)
- **Pheromone metadata**: `.pheromone` JSON and `pheromone_history` table now carry `platform` and `strength_tier` fields for cross-session strength tracking. (PE-005 Phase 1)
- **Observation deposit differentiation**: `field-deposit.sh` now accepts `--strength`, `--platform`, `--trigger-type` parameters. Execution tier silently skips degenerate observation deposits (no error). Direction tier auto-marks observations as `confidence: high, source: directive`. (PE-005 Phase 3)
- **Static content migration**: Entry files with `<!-- birth-static-included -->` marker cause `.birth` to omit grammar+safety sections, freeing ~200 tokens for dynamic content. Unmarked entry files fall back to including static content (backward compatible). (PE-005 Phase 3)
- **Rule quality gate (W-012a)**: `field-cycle.sh` Step 5 now validates rule quality before creation — rejects degenerate triggers (heartbeat/signal-ID only), tautological actions, and short actions (<20 chars). Source observations still archived to prevent re-promotion. (PE-005 Phase 4)
- **Entry file kernel version**: v10.0 → v11.0 (both CLAUDE.md and AGENTS.md templates).
- **Protocol version**: v3.5 → v4.0.

### Action Required
- **None** — DB schema auto-migrates from v2 to v3 on first run. All changes are additive and backward-compatible. Entry files are preserved on upgrade (only new installations get v11.0 kernel).

### Action Optional
- Add `<!-- birth-static-included -->` to your existing entry files (CLAUDE.md / AGENTS.md) to enable static content migration and free ~200 tokens in `.birth`. Only do this if your entry files already contain the 9 grammar rules + 4 safety nets.
- Set `TERMITE_TRIGGER_TYPE=directive` in your Claude Code hook to enable direction-tier `.birth` for human-initiated sessions.

---

## v3.5 (2026-03-02)

### Changes
- **DB schema v2**: `observations` table gains `quality` column (`normal`/`low`); `pheromone_history` table gains `observation_example` column (JSON). Auto-migrated from v1 on first script run. (TF-007)
- **Observation quality gate**: `field-deposit.sh` now detects degenerate observation deposits (pattern is a signal ID like `S-007`, detail is empty/short/numeric) and marks them `quality: low`. Soft gate — deposits are accepted but excluded from rule promotion and behavioral templates. (TF-007, partially addresses W-001)
- **Fuzzy keyword clustering**: `field-cycle.sh` Step 5 now uses keyword normalization instead of exact pattern matching for observation→rule promotion. Observations with similar but differently-worded patterns are grouped together, dramatically lowering the activation energy for Rule 7 emergence. (TF-007, partially addresses W-004)
- **Colony life phase**: `field-pulse.sh` now computes `colony_phase` (genesis/active/maintaining/idle) and writes it to `.field-breath` and colony_state. `field-arrive.sh` reads the phase and injects maintenance guidance when phase=maintaining. (TF-007)
- **Pheromone behavioral template**: `field-deposit.sh --pheromone` now includes an `observation_example` field — the best recent high-quality observation. Enables the "Shepherd Effect": weak models imitate observation format from the pheromone chain. (TF-007)
- **Deployment topology docs**: `TERMITE_PROTOCOL.md` Part III now documents the recommended 1-strong+N-weak deployment configuration and T0/T1/T2 capability tiers. (PE-003)
- **`field-lib.sh`**: New `normalize_pattern_keywords()` function for fuzzy pattern matching.

### Action Required
- **None** — DB schema auto-migrates from v1 to v2 on first run. All changes are additive and backward-compatible.

### Action Optional
- For optimal results with weak models (Haiku, etc.), ensure at least one strong model session runs first to seed the pheromone chain with high-quality behavioral templates. See TERMITE_PROTOCOL.md "部署拓扑" for details.

---

## v3.4 (2026-03-01)

### Changes
- **field-cycle.sh**: Metabolism loop now auto-invokes `field-submit-audit.sh` at end of each cycle. Controlled by `.termite-telemetry.yaml` gates. (TF-003)
- **field-export-audit.sh**: Fixed `cp -R` nesting bug that created `signals/signals/` and doubled audit package size. (TF-002, F-007)
- **field-export-audit.sh**: BLACKBOARD section matching now uses keyword-based patterns (`免疫/immune`, `健康/health`) instead of exact headers. (TF-003, F-005)
- **field-submit-audit.sh**: Added same-owner detection — skips fork and pushes branch directly when host project owner matches protocol source repo owner. (TF-003, F-006)
- **field-export-audit.sh, field-cycle.sh, field-deposit.sh**: Fixed `grep -c` returning exit code 1 under `set -euo pipefail`, pipe-subshell variable loss, and `grep|head` SIGPIPE. (TF-001, F-001)
- **install.sh**: Now prints upgrade summary with changes and action items when running `--upgrade`.
- **UPGRADE_NOTES.md**: New file — structured changelog installed into host projects.

### Action Required
- **None** — all changes are bug fixes or additive features that work with existing configuration.

### Action Optional
- To enable automatic audit submission to the protocol source repo, set `enabled: true` and `accepted: true` in `.termite-telemetry.yaml`. This activates the cross-colony feedback loop. Default remains `enabled: false` (no behavior change).

---

## v3.3 (2026-02-28)

### Changes
- **SQLite WAL-mode**: Protocol state now persisted in `.termite.db` with WAL-mode for concurrent access.
- **Drift robustness**: Enhanced signal decay and claim expiration handling.

### Action Required
- **None** — database is auto-initialized by `field-arrive.sh` on first run.

### Action Optional
- (none)
