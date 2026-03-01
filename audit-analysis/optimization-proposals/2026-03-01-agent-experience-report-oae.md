# Agent Experience Report: OpenAgentEngine Session 2026-03-01

Date: 2026-03-01
Reporter: Claude Opus 4.6 (non-termite session — human-directed exploration)
Project: OpenAgentEngine
Protocol Version: v10.0 (kernel), v3.2+ (templates)
Severity: High (multiple template bugs affect all new installations)

## Context

This session was NOT run under the Termite Protocol. The human intentionally
had me work as a regular Claude Code agent to evaluate the project and its
protocol infrastructure from the outside. This gave me an unfiltered view of
what a new agent — or a human — encounters when trying to use the protocol's
field scripts for the first time.

## Findings

### Finding 1: `set -euo pipefail` is systematically incompatible with common bash patterns in template scripts

**Severity: Critical — blocks audit export on every project**

All field scripts use `set -euo pipefail`, but the codebase contains at least
3 incompatible patterns that silently break:

#### 1a. `grep -c ... || echo "0"` produces double output

When `grep -c` finds 0 matches, it outputs `"0"` AND returns exit code 1.
The `|| echo "0"` then adds another `"0"`. Variable becomes `"0\n0"`,
causing arithmetic errors downstream.

**Where**: `field-export-audit.sh` line 356-357 (handoff quality stats)

**Fix**: `VAR=$(grep -c pattern file) || VAR=0` (capture exit in assignment, fallback in `||`)

**Note**: This EXACT bug was already recorded as O-001 in the 0227 project
observations, but the template scripts were never fixed. The feedback loop
from observation → template fix is broken.

#### 1b. `cmd | while read` pipe causes subshell variable loss

When piped into `while read`, the loop runs in a subshell. Variables modified
inside (like `chain_count=$((chain_count + 1))`) are invisible to the parent.

**Where**: `field-export-audit.sh` line 151 (`db_pheromone_chain | while read`)

**Result**: `chain_count` always reports 0 even when 44 snapshots exist.

**Fix**: Use process substitution: `while read ...; do ... done < <(command)`

#### 1c. `grep | head -1` triggers SIGPIPE under `pipefail`

When `head -1` closes the pipe after reading one line, `grep` receives SIGPIPE
(exit code 141). Under `pipefail`, the whole command substitution fails, and
`set -e` kills the script.

**Where**: `field-export-audit.sh` lines 283-284 (caste time range extraction)

**Fix**: Append `|| true` to pipelines where early pipe closure is expected.

### Finding 2: Git hooks not installed by default — massive signature gap

**Severity: High — undermines audit trail integrity**

The protocol relies on `prepare-commit-msg` hook for `[termite:DATE:caste]`
signatures. But after `install.sh` copies scripts to a project, it does NOT
automatically run `scripts/hooks/install.sh`. The hooks sit in `scripts/hooks/`
but `.git/hooks/` remains empty.

**Impact on OpenAgentEngine**: 51 out of 54 commits had no termite signature.
Signature ratio: 5.6%. The audit package reported this but couldn't explain why —
the answer is simply that hooks were never installed.

**Recommendation**: `install.sh` should include `bash scripts/hooks/install.sh`
as a final step, or at minimum print a prominent warning.

### Finding 3: `field-submit-audit.sh` not included in standard install

**Severity: Medium — blocks cross-colony feedback loop**

The cross-colony feedback loop design document (Component 2) specifies
`field-submit-audit.sh` as the outbound audit submission mechanism. But:

- `install.sh` does not copy it to projects
- `.termite-telemetry.yaml` is not generated during install
- `field-lib.sh` in installed projects lacks the `telemetry_*` functions
  that `field-submit-audit.sh` depends on

A project that installs the protocol cannot participate in the feedback loop
without manually copying files from the protocol source repo.

**Recommendation**: Add to `install.sh`: copy `field-submit-audit.sh`,
generate default `.termite-telemetry.yaml` (enabled: false), ensure
`field-lib.sh` includes telemetry functions.

### Finding 4: `field-submit-audit.sh` fails on same-owner repos

**Severity: Low — edge case for solo developers**

The script assumes fork-based workflow: `gh repo fork` → clone fork → push to
fork → PR from fork to protocol source repo. When the host project owner and protocol source repo owner
are the same GitHub account (common for solo devs), `gh repo fork` is a no-op,
and the PR creation fails because there's no fork relationship.

**Workaround used**: Created PR directly with `gh pr create --head branch-name`.

**Recommendation**: Detect same-owner case and skip fork, push branch directly
to protocol source repo.

### Finding 5: `.gitignore` in protocol repo blocks `audit-packages/`

**Severity: Medium — blocks audit submission**

The Termite-Protocol repo's `.gitignore` includes `audit-packages`, preventing
`git add audit-packages/` from working. The submit script needs `git add -f`.

**Fix applied**: Changed `git add` to `git add -f` in `field-submit-audit.sh`.

**Recommendation**: Either remove `audit-packages` from `.gitignore` in the
protocol repo, or update the template script to use `-f`.

### Finding 6: BLACKBOARD.md section headers not matched by audit export

**Severity: Low — incomplete audit data**

`field-export-audit.sh` looks for immune log section with headers
`## 免疫日志` or `## Immune Log`, and health section with
`## 蚁丘健康状态` or `## Colony Health`. But the actual BLACKBOARD.md in
OpenAgentEngine doesn't use these exact headers, resulting in empty sections
in the audit package.

**Recommendation**: Make the awk patterns more flexible, or document the exact
required section headers in the BLACKBOARD template.

### Finding 7: Observation → Template fix feedback loop is broken

**Severity: High — systemic**

The `grep -c` bug (Finding 1a) was already observed and recorded as O-001 in
the 0227 project (dated 2026-02-27). Four days later, the same bug still exists
in the template scripts. The protocol's Rule 7 (EMERGE: count >= 3 → rule)
describes how repeated observations should become rules, but there's no
mechanism for observations from deployed projects to flow back and fix the
template source code.

The cross-colony feedback loop design addresses this architecturally (Nurse
reads audit packages → proposes optimizations), but the Nurse has never run,
and the loop from "observation in project" → "fix in template" is entirely
manual.

**This is the most important finding**: The protocol has a beautiful design for
self-improvement, but the implementation gap means bugs persist across projects
and across time.

### Finding 8: `--upgrade` overwrites project-specific enhancements without merge

**Severity: High — breaks host project tests**

Running `install.sh --upgrade` copies ALL template scripts over the project's
versions, creating `.backup` files. But it does not merge — it fully replaces.

OpenAgentEngine had custom enhancements in `termite-db-export.sh` (YAML block
preservation logic) and `termite-db.sh` (improved claim status queries, detail
field handling with multiline preservation). The upgrade from the template
wiped these, causing the S-011 `export-preserve` quality gate to fail.

**What happened**:
- Upgrade replaced OAE's `termite-db-export.sh` (with `extract_yaml_block` /
  `preserve_yaml_block_if_missing` functions) with template version (without)
- Upgrade replaced OAE's `termite-db.sh` (with detail field multiline handling)
  with template version (which skips empty detail fields differently)
- Quality gate S-011 failed immediately after upgrade
- Had to manually restore both files from `.backup`

**Root cause**: The upgrade treats all scripts as "protocol core" but some
scripts (`termite-db-export.sh`, `termite-db.sh`) serve as extension points
that projects legitimately customize.

**Recommendation**: Either:
1. Distinguish "protocol core" scripts (never customized) from "extension"
   scripts (may be customized) — only overwrite core scripts
2. Or run the project's test suite BEFORE committing upgrade, auto-rollback
   if tests fail
3. At minimum: warn when overwriting files that differ from the previous
   template version (i.e., files the project has customized)

### Finding 9: Upgrade changelog quality is good, but version detection is wrong

**Severity: Low**

The upgrade printed a clean changelog (`v10.0 → v3.4`) with specific bug
references (TF-001, F-001, etc.) and clear Action Required / Action Optional
sections. The `UPGRADE_NOTES.md` file is well-structured.

However, the "from" version was detected as `v10.0` (the kernel version in
CLAUDE.md), not the actual protocol template version. This is misleading —
the project was running v3.2 template scripts, not "v10.0".

### Finding 10: Claude Code plugin installed — promising but untested

The upgrade installed a Claude Code plugin at
`.claude/plugins/termite-protocol/` with hooks for SessionStart,
UserPromptSubmit, PreToolUse(Bash), PostToolUse(Write|Edit, Bash),
PreCompact, and Stop events. This is a new v3.4 feature that wasn't in
the previous install.

This plugin could be the mechanism that makes the protocol truly
"dissolve into environment" as the v3.0 design intended — instead of
relying on the agent reading CLAUDE.md, the hooks enforce protocol
behavior automatically. Not tested in this session.

## Recommendations Summary

| Priority | Action | Effort |
|----------|--------|--------|
| P0 | Fix `grep -c`, pipe-subshell, SIGPIPE bugs in ALL template scripts | Small — pattern replacement |
| P0 | Auto-install git hooks in `install.sh` | Trivial — add one line |
| P1 | Include `field-submit-audit.sh` + telemetry in standard install | Small |
| P1 | Run Protocol Nurse on first audit package to validate the loop | Medium |
| P1 | Add upgrade merge strategy — don't blindly overwrite customized scripts | Medium |
| P2 | Add template script version tracking + upgrade detection | Medium |
| P2 | Handle same-owner fork edge case in submit script | Small |
| P2 | Fix version detection (protocol template version, not kernel version) | Small |
| P3 | Flexible BLACKBOARD section header matching | Small |

## Agent Reflection

Working with the Termite Protocol infrastructure from the outside — not as a
"termite" following the protocol, but as an agent asked to evaluate and operate
the tools — revealed that the conceptual design is significantly ahead of the
implementation quality. The ideas (stigmergic coordination, observation →
rule promotion, cross-colony feedback, protocol dissolution into environment)
are genuinely innovative. But the scripts that implement these ideas have
basic bash bugs that prevent them from running successfully on first attempt.

The protocol's own immune system (IC checks, signature auditing, observation
promotion) should catch these issues. The fact that it doesn't suggests the
immune system itself needs to be the next priority — not more features, but
making the existing features actually work reliably across platforms and bash
versions.

The most telling signal: the same bug was independently discovered twice
(O-001 in 0227, and again by me today), four days apart, in different projects.
That's exactly the pattern Rule 7 (EMERGE) was designed to detect. If the
feedback loop were working, this bug would have been fixed after the first
observation.
