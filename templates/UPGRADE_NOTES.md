<!-- upgrade-notes:v1.0 -->
# Termite Protocol — Upgrade Notes

> **Scout: read this file before deciding whether to run `install.sh --upgrade`.**
> After upgrading, check **Action Required** sections for each version between your old and new version.

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
