# Cross-Colony Feedback Loop Design

Date: 2026-02-28
Status: Approved
Protocol Version: v3.4

## Problem

Host projects using the Termite Protocol generate valuable protocol-level data (signal patterns, rule effectiveness, handoff quality), but this data stays isolated within each host project's colony. The protocol cannot self-improve without cross-colony feedback. Additionally, host projects have no mechanism to detect or pull protocol updates.

## Architecture

```
                         +-----------------------------+
                         |  Protocol Source Repo        |
                         |  (protocol + audit database)|
                         |                             |
                         |  audit-packages/            |
                         |    ProjectA/                |
                         |      2026-02-28/            |
                         |    ProjectB/                |
                         |      2026-02-25/            |
                         |                             |
                         |  Protocol Nurse analyzes    |
                         |  -> optimizes protocol      |
                         +-------+----------^----------+
                    version check |          | audit PR
                    (gh api)      |          | (gh pr create)
                                  |          |
          +-----------------------v----------+-------------------+
          |  Host Project Colony (e.g. OpenAgentEngine)            |
          |                                                      |
          |  field-arrive.sh -> version check -> HOLE signal     |
          |  field-submit-audit.sh -> export -> fork -> PR       |
          |  .termite-telemetry.yaml -> opt-in control           |
          +------------------------------------------------------+
```

Data flows through files and PRs (stigmergic), not API calls or webhooks. Every link is observable, traceable, interruptible.

## Component 1: Opt-in & Disclaimer

### `.termite-telemetry.yaml`

```yaml
# Termite Protocol -- Cross-Colony Feedback Configuration
enabled: false
accepted: false          # must confirm disclaimer before first submission
upstream_repo: "billbai-longarena/Termite-Protocol"
anonymize_project: false # true = project name sha256[:8]
submit_frequency: "session-end"  # session-end | weekly | manual
```

### Disclaimer (shown on first activation)

When `enabled: true` but `accepted: false`, `field-submit-audit.sh` displays:

- Audit packages contain ONLY protocol artifacts (signals, rules, handoff chain, caste distribution)
- No source code, business logic, .env files, or secrets
- Submitted as PR to protocol source repo for Nurse analysis
- Can disable at any time by setting `enabled: false`
- `anonymize_project: true` hashes the project name

User must type 'accept' to confirm. Script writes `accepted: true` to the YAML.

### Behavior Matrix

| State | Behavior |
|-------|----------|
| `enabled: false` (default) | Everything works as before. No network, no export, no fork. |
| `enabled: true, accepted: false` | Show disclaimer, wait for confirmation |
| `enabled: true, accepted: true` | Participate in feedback loop |
| User changes to `enabled: false` | Immediately stop. Existing PRs remain. |
| `anonymize_project: true` | Project name replaced with sha256[:8] in all outputs |

### `install.sh` Integration

New install step asks host project whether to enable feedback (default: No), generates `.termite-telemetry.yaml`. `--upgrade` does not overwrite existing config.

## Component 2: Audit Submission (Outbound)

### `field-submit-audit.sh` (new script)

Trigger: After `field-deposit.sh --pheromone` at session end, or via hook.

```
1. Read .termite-telemetry.yaml
   enabled=false? -> exit 0 (silent)
   accepted=false? -> show disclaimer -> exit 1

2. Frequency control
   session-end -> submit every time
   weekly -> check last_submitted in config, <7 days -> skip
   manual -> exit 0 (require --force flag)

3. Export audit package
   field-export-audit.sh --tar --project-name "$PROJECT_NAME"

4. Fork/clone upstream (idempotent)
   gh repo fork $protocol_source_repo --clone=false (skip if already forked)
   git clone --depth 1 fork to temp directory

5. Create audit branch + commit
   branch: audit/$project_name/$(date +%Y-%m-%d)
   copy audit package to audit-packages/$project_name/
   git add + commit

6. Push + PR
   git push fork
   gh pr create --title "audit($project_name): $(date)" --body "metadata summary"

7. Cleanup temp dir, record last_submitted timestamp
```

### Key Design Points

- **Idempotent**: Same-day submissions overwrite same branch. Max one PR per day.
- **Anonymization**: When `anonymize_project: true`, project name -> `sha256(name)[:8]`.
- **Dependency**: Requires `gh` CLI authenticated. If `gh auth status` fails, `log_warn` and skip. Never blocks termite work.

## Component 3: Protocol Update Detection (Inbound)

### New step in `field-arrive.sh`

Added after breath freshness check, before caste determination.

```
1. Feedback enabled? (.termite-telemetry.yaml enabled=true + accepted=true)
   No -> skip detection

2. Get upstream protocol version (with cache)
   - Local version: grep 'termite-protocol:v' TERMITE_PROTOCOL.md -> v3.4
   - Cache: .termite-upstream-check (if checked <24h ago -> use cache)
   - Otherwise: gh api repos/$upstream/releases/latest or curl raw TERMITE_PROTOCOL.md line 1
   - Write cache: { checked_at, upstream_version }

3. Compare versions
   local == upstream -> no action
   local < upstream -> create HOLE signal:
     type: HOLE
     title: "Protocol update available: v3.4 -> v3.5"
     weight: 35  (visible but not urgent)
     next: "Scout: read UPGRADE_NOTES.md for changes and action items, then decide whether to run install.sh --upgrade"
     source: autonomous
     module: "termite-protocol"
```

### Semi-Autonomous Upgrade

When a Scout caste termite encounters the "protocol update available" signal:

1. Read `UPGRADE_NOTES.md` for changes and action items
2. Assess impact on current project
3. Decision:
   - **Upgrade**: Run `install.sh --upgrade`, mark signal done
   - **Skip**: Leave observation explaining why, touch_count +1
   - **Defer**: Don't process. Signal naturally decays if no one cares.

### Constraints

- **No auto-upgrade in arrive**: Arrival ceremony is read-only sensing. No side effects.
- **24h detection cache**: Avoid network request on every arrive.
- **Silent skip if gh unavailable**: Network issues must not block local work.
- **Signal weight 35**: Below ESCALATE_THRESHOLD (50). Won't trigger alarm.

## Component 4: Protocol Nurse (Self-Optimization)

### Termite-Protocol repo structure additions

```
audit-packages/
  OpenAgentEngine/
    2026-02-28/
      metadata.yaml, signals/, rule-health.yaml, ...
  SomeOtherProject/
    2026-02-25/
      ...

audit-analysis/
  cross-project-report.yaml
  optimization-proposals/
    2026-03-01-decay-factor-adjustment.md
    2026-03-05-rule-promotion-threshold.md
```

### Nurse Workflow

Nurse is a termite in the protocol source repo with nurse caste. Input: audit packages from host project colonies. Output: optimization proposals.

1. **Sense**: Detect new audit packages in `audit-packages/`
2. **Cross-project comparison**:
   - Rule health across host projects (which rules are highly disputed everywhere?)
   - Handoff quality distribution (useful_ratio across host project colonies)
   - Caste distribution (healthy balance?)
   - Decay rate effectiveness (signals disappearing too fast/slow?)
3. **Produce optimization proposals**:
   - Write to `audit-analysis/optimization-proposals/`
   - Quantifiable threshold adjustments -> direct PR to field-lib.sh defaults
   - Rule modifications -> proposal.md for human review
4. **Generate cross-project report**: `audit-analysis/cross-project-report.yaml`

### Nurse Constraints

- Cannot modify protocol grammar (9 rules): Grammar is human collective decision
- Can propose threshold adjustments: DECAY_FACTOR, PROMOTION_THRESHOLD, etc. (needs PR review)
- Audit packages are read-only: Nurse produces analysis reports, never modifies packages
- No audit packages -> Nurse has nothing to do: Never fabricates data

## Security & Boundaries

| Risk | Mitigation |
|------|------------|
| Audit package accidentally includes source code | field-export-audit.sh isolation principle: only reads signals/, git signatures, pheromone |
| gh token exposure | Uses gh CLI's existing auth. No token storage. Silent skip without gh. |
| Malicious audit package poisoning | PR review is natural defense. Nurse only reads known-schema YAML. |
| Breaking protocol upgrade | Semi-autonomous: Scout must review UPGRADE_NOTES.md before deciding to upgrade |
| Fork permission issues | gh fork is standard GitHub operation, no write access to target needed |

## Protocol Spirit Alignment

| Protocol Rule | Manifestation in Feedback Loop |
|---------------|-------------------------------|
| Rule 4: DO -> DEPOSIT | Audit package = deposit. Each colony's action traces converge at protocol repo |
| Rule 5: weight < threshold -> EVAPORATE | Old audit packages naturally superseded by new ones. History in git. |
| Rule 6: weight > threshold -> ESCALATE | Cross-project high-dispute rules -> Nurse escalates to optimization proposal |
| Rule 7: count >= 3 -> EMERGE | 3+ host project colonies observe same pattern -> auto-promote to protocol-level rule |
| Safety S2: Don't delete .md files | Audit packages and configs are append-only |

## Non-Participating Projects

For `enabled: false` (default), behavior is completely unchanged:

- No network checks for protocol version
- No audit package export
- No repository forking
- All field-*.sh scripts work normally
- `.termite-telemetry.yaml` exists but produces zero side effects

Equivalent to a self-sufficient colony -- the host project runs independently, not exchanging pheromones with the protocol source repo. A perfectly valid way to exist.

## Exit Mechanism

```yaml
enabled: false  # one-line change, immediately effective
```

Already-submitted PRs remain (git history is immutable), but no new submissions occur.

## New Files

| File | Type | Purpose |
|------|------|---------|
| `templates/scripts/field-submit-audit.sh` | Script | Audit package PR submission |
| `templates/.termite-telemetry.yaml` | Template | Default opt-in config (enabled: false) |
| Protocol additions to `field-arrive.sh` | Modification | Version detection step |
| Protocol additions to `install.sh` | Modification | Telemetry config generation + ask |
| `audit-packages/` directory in protocol source repo | Convention | Landing zone for audit PRs |
| `audit-analysis/` directory in protocol source repo | Convention | Nurse output |
