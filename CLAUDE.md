# Termite Protocol — Source Repository

This is the specification and tooling repository for the Termite Protocol (白蚁协议), a cross-session collaboration framework for stateless AI agents.

**This is NOT a downstream project using the Termite Protocol. This is the protocol itself.** Your work here evolves the protocol specification and field scripts that all downstream colonies depend on.

## Repository Map

```
templates/
  TERMITE_PROTOCOL.md   ← Canonical protocol spec (v3.4). Changes here propagate to all downstream projects on next upgrade.
  CLAUDE.md / AGENTS.md ← Entry file templates installed into downstream projects.
  TERMITE_SEED.md       ← Minimal protocol payload injected into generated agent systems.
  scripts/
    field-lib.sh        ← Shared function library (path resolution, YAML parsing, signal I/O, DB bridge)
    field-arrive.sh     ← Agent arrival: reads environment + protocol, computes .birth file
    field-cycle.sh      ← Heartbeat: sense → act → notice → deposit
    field-deposit.sh    ← Pheromone deposition (observations/decisions → YAML signals)
    field-decay.sh      ← Pheromone decay (expire stale signals)
    field-drain.sh      ← Bulk signal clearing
    field-pulse.sh      ← Project status snapshot
    field-claim.sh      ← Atomic task lock/release/query
    field-genesis.sh    ← Self-initialization for new colonies
    field-export-audit.sh  ← Export audit packages (protocol artifacts only, no source code)
    field-submit-audit.sh  ← Submit audit packages as PRs to this repo
    termite-db.sh       ← SQLite WAL-mode database + migrations
    hooks/              ← Git hooks (pre-commit, pre-push, prepare-commit-msg, post-commit)
install.sh              ← One-click installer for downstream projects (copies templates, creates dirs, installs hooks)

0227/                   ← Production reference colony (SalesTouch). Contains live signals, observations, and rules from real usage.
audit-packages/         ← Cross-colony audit data submitted from downstream projects.
audit-analysis/         ← Analysis reports and optimization proposals derived from audit data.
docs/plans/             ← Design documents for major features.
```

## Current State

- **Protocol version**: v3.4 (SQLite WAL-mode, drift robustness)
- **Field lib version**: v20.0
- **Entry kernel versions**: Claude v10.0, Agents v8.0
- **Downstream colonies validated**: 0227/SalesTouch (production stable), OpenAgentEngine (audited, 7 findings)

### Known Issues

1. `grep -c` returns exit code 1 when count is 0 under `set -euo pipefail`, causing script failures (observed in 0227 O-001, reconfirmed in OpenAgentEngine audit)
2. `install.sh` does not auto-run `scripts/hooks/install.sh` — git hooks sit in `scripts/hooks/` but never reach `.git/hooks/` unless manually installed
3. `field-submit-audit.sh` is not included in the standard install flow
4. `.gitignore` blocks `audit-packages/` directory, requiring `git add -f`
5. `field-export-audit.sh` does not match BLACKBOARD section headers correctly
6. Observation → template fix feedback loop is entirely manual (no automated path from downstream O-xxx to template patches)

### Recent Work

- Cross-colony feedback loop design (`docs/plans/2026-02-28-cross-colony-feedback-loop-*`)
- Claude Code plugin integration with 7 hooks (`docs/plans/2026-02-28-claude-code-hook-integration-*`)
- OpenAgentEngine agent experience audit (`audit-analysis/optimization-proposals/2026-03-01-agent-experience-report-oae.md`)

## Development Conventions

- Field scripts must work under `set -euo pipefail`
- All script changes should pass `shellcheck`
- Protocol text changes (`TERMITE_PROTOCOL.md`) require a version bump
- Entry file template changes require kernel version sync between `CLAUDE.md` and `AGENTS.md`
- Do NOT run `field-arrive.sh`, `field-cycle.sh`, or other field scripts in this repo — they are designed for downstream projects
- **Keep this file current**: When your work changes the protocol version, fixes a known issue, or shifts the project focus, update the Current State section of this file before ending your session

## Impact Awareness

| You change... | Impact |
|---|---|
| `templates/TERMITE_PROTOCOL.md` | All downstream projects on next `install.sh --upgrade` |
| `templates/scripts/*.sh` | Runtime behavior of all downstream colonies |
| `templates/CLAUDE.md` or `AGENTS.md` | New installations only (existing entry files are preserved on upgrade) |
| `install.sh` | Installation and upgrade flow for all future adopters |
| `0227/` | Reference colony only — do not modify without understanding it is a live production snapshot |
