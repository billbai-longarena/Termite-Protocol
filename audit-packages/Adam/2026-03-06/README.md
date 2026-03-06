# Audit Package

This directory contains protocol-level artifacts exported from a project
running the Termite Protocol. It contains **no project source code**.

A Protocol Nurse agent can read this package + the protocol definition
to evaluate protocol health and produce optimization recommendations.

## Contents

| File | What it tells you |
|------|-------------------|
| `metadata.yaml` | Project context, duration, volume (read first) |
| `signals/` | Complete signal tree: rules, observations, active, archive |
| `rule-health.yaml` | Per-rule hit vs disputed ratio (flags problematic rules) |
| `handoff-quality.yaml` | predecessor_useful stats (cross-session handoff effectiveness) |
| `caste-distribution.yaml` | Which castes appeared and how often |
| `git-signatures.txt` | Commit timeline with termite signatures (no code) |
| `pheromone-chain.jsonl` | .pheromone history (one JSON per line, chronological) |
| `immune-log.txt` | Immune system findings from BLACKBOARD |
| `blackboard-health.txt` | Colony health status table |
| `breath-snapshot.yaml` | Latest .field-breath health snapshot |

## How to Use

```
# Copy this directory to the protocol repo:
cp -R audit-package-YYYY-MM-DD /path/to/termite-protocol/audit-packages/project-name/

# Or analyze in place:
# A Protocol Nurse agent reads metadata.yaml first, then rule-health.yaml
# and handoff-quality.yaml for quick protocol health assessment.
```
