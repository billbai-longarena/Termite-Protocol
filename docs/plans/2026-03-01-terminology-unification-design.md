# Terminology Unification Design

Date: 2026-03-01
Status: Approved
Scope: Protocol source repo + templates/ (excluding 0227/, audit-packages/)

## Problem

The codebase uses ambiguous referential terms that conflate 4+ distinct entities:
the protocol spec document, the protocol source repo, host projects, and colonies.
"This project", "downstream project", "the protocol", and "colony" each have
multiple referents depending on context, causing confusion for both human
developers and AI agents.

## Glossary (Authoritative Definitions)

| Entity | Chinese Term | English Term | Definition |
|--------|-------------|--------------|------------|
| The framework concept | **白蚁协议** | **Termite Protocol** | The cross-session AI collaboration framework as a whole. Use only when referring generically. |
| The spec document | **协议规范** | **protocol spec** | `TERMITE_PROTOCOL.md` and the 9 grammar rules + 4 safety nets it defines. |
| This Git repository | **协议源仓库** | **protocol source repo** | `billbai-longarena/Termite-Protocol`. Contains templates/, scripts/, install.sh, docs/, audit data. |
| A project using the protocol | **宿主项目** | **host project** | Any external project that installed protocol templates and scripts via `install.sh`. |
| Runtime signal ecosystem | **蚁丘** | **colony** | The signals/ + rules/ + .pheromone + .birth ecosystem inside a host project. Not synonymous with the project itself. |
| Files in `/templates/` | **协议模板** | **protocol template(s)** | Files copied to host projects by `install.sh`. |
| Audit return path | **反馈回路** | **feedback loop** | Colony -> audit package -> protocol source repo -> Nurse analysis -> template fix -> host project upgrade. |

## Substitution Rules

### Prohibited Terms -> Replacement

| Prohibited (in source repo docs) | Replace with |
|----------------------------------|-------------|
| "本项目" / "此项目" / "该项目" (when referring to protocol source repo) | **协议源仓库** |
| "本项目" (in templates/ files, which get copied to host projects) | **宿主项目** |
| "this repo" (in templates/ files) | **the host project** or remove if obvious from context |
| "downstream project" / "下游项目" | **宿主项目** / **host project** |
| "upstream" / "上游" (in source repo's own docs) | **协议源仓库** / **protocol source repo** |
| "the protocol" (when meaning the spec document) | **协议规范** / **protocol spec** |
| "the protocol" (when meaning this repo) | **协议源仓库** / **protocol source repo** |
| "template repo" | **协议源仓库** |
| "colony" (when meaning the host project itself) | **宿主项目** |
| "project" (standalone, ambiguous) | Qualify: **宿主项目** or **协议源仓库** |

### Allowed Terms (No Change Needed)

| Term | Context | Reason |
|------|---------|--------|
| "白蚁协议" | Generic references to the framework | Acceptable as brand name |
| "蚁丘" / "colony" | Referring to runtime signal ecosystem | Correct metaphor, well-defined |
| "upstream" | Inside `field-submit-audit.sh` and telemetry scripts | Correct: from host project's perspective, source repo IS upstream |
| "Nurse" | Protocol role | Well-defined caste |

## Files to Modify

| File | Changes |
|------|---------|
| `/CLAUDE.md` | Add glossary section; replace "downstream projects" with "宿主项目"; clarify "this repo" references |
| `/templates/TERMITE_PROTOCOL.md` | Add terminology section to Part I; replace ambiguous "项目"/"蚁丘" conflations |
| `/templates/CLAUDE.md` | Replace "本项目" with "宿主项目"; ensure "this repo" unambiguity after copy |
| `/templates/AGENTS.md` | Same as CLAUDE.md |
| `/templates/TERMITE_SEED.md` | Check and fix any ambiguous referents |
| `/templates/scripts/field-*.sh` | Fix comments only; no logic changes |
| `/install.sh` | Fix comments: "target project" -> "host project" |
| `/docs/plans/*.md` | Fix "upstream repo" -> "协议源仓库", "project" -> qualified form |
| `/audit-analysis/**/*.md` | Fix "template repo" -> "协议源仓库", "installed projects" -> "宿主项目" |

## Out of Scope

- `0227/` — Production reference colony snapshot; historical terms preserved
- `audit-packages/` — Audit data snapshots; historical terms preserved
- Script logic changes — This design covers terminology only; grep-c fix is a separate task
