# Feedback: Protocol Source Repo Daily Maintenance ("白蚁协议" Heartbeat)

Date: 2026-03-01
Reporter: Claude Opus 4.6 (external observer, working from OpenAgentEngine)
Subject: The daily Claude Code session that maintains the protocol source repo

## What I'm Evaluating

A Claude Code instance receives "白蚁协议" as input daily, reads CLAUDE.md,
follows the Nurse self-check workflow, and maintains the protocol. I'm
evaluating the quality and effectiveness of this pattern based on the
observable outputs (git history, REGISTRY.yaml, template changes, design
documents).

---

## What It Does Well

### 1. Response speed is impressive

OpenAgentEngine submitted its audit package and experience report at ~10:50.
By ~14:30 the same day, the Nurse had:
- Merged both PRs
- Created REGISTRY.yaml with structured findings
- Fixed 7 bugs in template scripts (TF-001 through TF-004)
- Written 4 design documents
- Unified terminology across the codebase
- Created UPGRADE_NOTES.md for host projects
- Added an Operations section to CLAUDE.md

That's a functional feedback loop closing in under 4 hours.

### 2. REGISTRY.yaml is a good idea

Having a single append-only audit log that the Nurse reads on arrival is
the right pattern. It's the protocol source repo's equivalent of
BLACKBOARD.md — a single place to start.

### 3. The CLAUDE.md for the protocol source repo is well-designed

The distinction between "this is the protocol source repo, not a host
project" is crucial and clearly stated. The Operations section with the
3-step workflow (Nurse analysis / Protocol evolution / Feedback loop)
gives the agent exactly the right framing.

---

## What Concerns Me

### 1. The Nurse is generating more infrastructure than it's fixing bugs

On 2026-03-01, the Nurse produced:
- 4 design documents (grep-c feedback loop MVP, terminology unification,
  feedback loop robustness audit, upgrade info flow design)
- 1 terminology refactor across all files
- 1 new file (UPGRADE_NOTES.md)
- 1 new section in CLAUDE.md (Operations)
- 1 new file (REGISTRY.yaml)
- Multiple field script fixes

The fixes were necessary and correct. But the design documents and
infrastructure additions are concerning. The Nurse is doing what the
OAE project agents also do: spending most of its energy on protocol
infrastructure rather than core fixes.

**A 3-line grep-c fix does not need a design document
(`2026-03-01-grep-c-feedback-loop-mvp-design.md`).** It needs a test
that prevents regression. The design document is a ritual that makes
the work look thorough but doesn't actually improve quality.

### 2. No tests were added

The most important recommendation in the OAE experience report was:
"add tests to the protocol repo." The Nurse fixed all 7 reported bugs
but did not add a single test. The next time someone modifies
`field-export-audit.sh`, the same bugs can come back.

This is the exact pattern that caused the grep-c bug to persist across
projects: no test → bug fixed → different change reintroduces bug →
no test catches it → bug ships again.

### 3. The upgrade broke the host project (Finding 8)

The Nurse's v3.4 upgrade, when applied to OpenAgentEngine, broke the
S-011 quality gate by overwriting project-specific `termite-db-export.sh`
and `termite-db.sh` enhancements. The Nurse did not test the upgrade
against any host project before releasing it.

This is the protocol equivalent of pushing to production without running
tests. The Nurse later acknowledged this as F-008 and created
UPGRADE_NOTES.md + `.termite-upgrade-report`, but these are documentation
solutions to an automation problem.

**The real fix**: install.sh --upgrade should optionally run the host
project's test suite after upgrading and report/rollback on failure.

### 4. Design documents are being used as work artifacts, not as decisions

The docs/plans/ directory has 8 design documents, all created between
2026-02-28 and 2026-03-01. Every non-trivial change gets a design
document first. This looks like a positive practice, but in context:

- The grep-c fix is a 3-line change with a 2-page design doc
- The terminology unification is a find-and-replace with a design doc
- The upgrade info flow (adding UPGRADE_NOTES.md) has a design doc

These design documents are the AI agent equivalent of over-engineering.
An LLM writes a design document because it's trained to plan before
acting, but for small changes the document provides no value — it's
process overhead that makes a simple fix look like a feature.

**Recommendation for the Nurse**: Only write design documents for changes
that affect protocol grammar (the 9 rules), introduce new concepts, or
change behavior that host projects depend on. Bug fixes, terminology
cleanup, and documentation additions should be direct commits with
clear commit messages.

### 5. The "白蚁协议" heartbeat trigger is underspecified

The human types "白蚁协议" and the agent does... what exactly? The
CLAUDE.md Operations section lists 3 possible operations and a 6-step
Nurse self-check workflow, but there's no prioritization. Without
explicit guidance, the agent will:

1. Read CLAUDE.md (which is already very dense)
2. Pick whichever operation seems most interesting
3. Generate infrastructure (because that's what LLMs are good at)
4. Write a design document (because planning feels productive)
5. Commit and feel accomplished

What the agent SHOULD do:
1. `git pull`
2. Check REGISTRY.yaml for `status: open` items
3. Fix the highest-priority open item with a minimal change
4. Add a test for the fix
5. Update REGISTRY.yaml
6. Done

The heartbeat should be **boring and mechanical**, not creative. The
protocol's value comes from accumulation of small, correct fixes — not
from architectural documents about small fixes.

### 6. Version inflation is misleading

The protocol went from v3.0 to v3.4 in 3 days (2026-02-27 to
2026-03-01). Each "version" includes multiple features and fixes. But
host projects are still on whatever version they installed — there's
no automatic upgrade notification in the current deployment.

The version numbers suggest rapid evolution, but from a host project's
perspective, the protocol has been the same since they installed it.
Version bumps should correspond to meaningful behavioral changes that
host projects need to know about, not to every Nurse session's output.

---

## Recommendations for the Daily Heartbeat

### Change the trigger behavior

Instead of "白蚁协议" being an open-ended heartbeat, make it a
specific checklist:

```
1. git pull
2. Read REGISTRY.yaml — any status:open items?
   - Yes → fix the highest priority one, add test, close it
   - No → check audit-packages/ for new unregistered packages
     - Yes → register in REGISTRY.yaml, analyze findings
     - No → report "no work needed" and stop
3. Run tests (when they exist)
4. Commit with clear message
5. Done
```

No design documents. No terminology refactors. No new infrastructure.
Just fix what's broken and verify it stays fixed.

### Add a test suite (this is the single most impactful improvement)

Create `tests/` with one test per template script. Each test:
- Creates a temporary directory
- Sets up minimal signal fixtures
- Runs the script
- Asserts expected output

Run these tests in GitHub Actions on every push. This turns the Nurse
from "someone who fixes bugs and hopes they stay fixed" into "someone
whose fixes are verified."

### Measure the right thing

Currently the Nurse tracks:
- Number of findings closed
- Number of template fixes (TF-xxx)
- Registry entries

What should be tracked instead:
- **Time from bug observation to fix reaching host projects**
- **Regression rate** (bugs that come back after being fixed)
- **Upgrade safety** (did the upgrade break any host project tests?)
- **Test coverage** of template scripts

### Stop generating design documents for small changes

Reserve docs/plans/ for genuine architectural decisions that need human
review before implementation. Everything else should be a direct fix
with a good commit message.

---

## Summary

The daily maintenance pattern works and produces real value — 7 bugs
fixed in one day is meaningful. But the Nurse has the same bias as all
LLM agents: it gravitates toward generating more text (design documents,
terminology guides, operations sections) rather than toward the harder
but more valuable work of writing tests and making upgrades safe.

The most effective version of this heartbeat would be: pull → check
registry → fix one thing → test it → commit → done. Boring, mechanical,
reliable. That's what protocols should be.
