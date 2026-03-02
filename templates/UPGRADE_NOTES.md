<!-- upgrade-notes:v1.0 -->
# Termite Protocol — Upgrade Notes

> **Scout: read this file before deciding whether to run `install.sh --upgrade`.**
> After upgrading, check **Action Required** sections for each version between your old and new version.

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
