# grep-c Feedback Loop MVP — Design & Execution Record

Date: 2026-03-01
Status: Executed
Triggered by: 0227 O-001 (2026-02-27) + OpenAgentEngine audit Finding 1 (2026-03-01)

## Significance

This is the first complete closure of the Termite Protocol feedback loop:

```
0227 colony O-001 (2026-02-27)     ─┐
                                     ├──▶ Protocol Nurse analysis ──▶ Template fix ──▶ Host projects get fix on next upgrade
OAE audit Finding 1 (2026-03-01)  ─┘
```

The grep-c bug was independently observed in two host project colonies:
1. **0227 (SalesTouch)** — O-001: "grep -c 在 0 匹配时返回 exit 1 导致 || echo 0 产生双行输出"
2. **OpenAgentEngine** — Audit Finding 1: Three sub-patterns (grep-c double output, pipe-subshell variable loss, SIGPIPE)

Rule 7 (EMERGE: count >= 3 -> rule) requires 3 independent observations. We had 2 cross-colony observations. The feedback loop closure happened through manual Nurse review rather than automated EMERGE, validating the design while highlighting that the automated path isn't yet operational.

## Three Bug Patterns Fixed

### Bug A: `grep -c ... || echo "0"` double output

Under `set -euo pipefail`, `grep -c` outputs "0" AND returns exit code 1 when count is 0. `|| echo "0"` appends another "0", making the variable `"0\n0"`.

**Fix pattern**: `VAR=$(grep -c pattern file 2>/dev/null) || VAR=0`

### Bug B: `cmd | while read` pipe-subshell variable loss

Piping into `while read` runs the loop in a subshell. Variables modified inside are invisible to parent.

**Fix pattern**: `while read ...; do ... done < <(command)`

### Bug C: `grep | head -1` SIGPIPE under pipefail

When `head` closes pipe after reading, `grep` receives SIGPIPE (exit 141), killing the pipeline under `pipefail`.

**Fix pattern**: Append `|| true` to pipeline.

## Files Modified (8 fixes across 3 scripts)

| # | File | Bug | Change |
|---|------|-----|--------|
| 1 | `field-export-audit.sh:218` | A | `grep -c ... \|\| echo "0"` → `$(grep -c ...) \|\| VAR=0` |
| 2 | `field-export-audit.sh:356` | A | Same pattern |
| 3 | `field-export-audit.sh:357` | A | Same pattern |
| 4 | `field-export-audit.sh:151` | B | `db_pheromone_chain \| while read` → `while read ... done < <(db_pheromone_chain)` |
| 5 | `field-export-audit.sh:278` | B | `grep \| sed \| sort \| while read` → process substitution |
| 6 | `field-export-audit.sh:283` | C | `grep \| head -1 \| sed` → append `\|\| true` |
| 7 | `field-cycle.sh:146` | B | `cut \| sort \| uniq -c \| while read` → process substitution |
| 8 | `field-deposit.sh:274` | B | Same pattern as #7 |

## Not Modified (assessed, no fix needed)

| File | Pattern | Reason |
|------|---------|--------|
| `field-lib.sh:537` | `grep -c ... \|\| true` | Already correct — `\|\| true` prevents set -e abort, grep -c output captured by `$()` |
| `field-arrive.sh:285,294` | `$(cmd \| head -3 \| while read)` | Entire while runs inside `$()` command substitution, echo output captured correctly |
| `field-arrive.sh:245` | `grep -m1 \| head -c 120 \|\| echo "WIP exists"` | Has fallback value, works correctly |
| `field-genesis.sh:67` | `head \| grep \| head -3` | Variable has default value fallback |

## Verification

All three modified scripts pass `shellcheck` with no new warnings introduced by the changes. All existing warnings are pre-existing (SC1091 source paths, SC2034 unused vars).
