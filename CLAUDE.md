# Termite Protocol — Source Repository

This is the **协议源仓库 (protocol source repo)** for the Termite Protocol (白蚁协议), a cross-session collaboration framework for stateless AI agents.

**This is NOT a 宿主项目 (host project). This is the protocol source repo itself.** Your work here evolves the protocol spec and field scripts that all host project colonies depend on.

## Terminology (权威术语表)

| 中文 | English | Meaning |
|------|---------|---------|
| **白蚁协议** | **Termite Protocol** | The framework as a whole (generic reference only) |
| **协议规范** | **protocol spec** | The `TERMITE_PROTOCOL.md` document and its 10+4 rules |
| **协议源仓库** | **protocol source repo** | This Git repo (`billbai-longarena/Termite-Protocol`) |
| **宿主项目** | **host project** | Any project that installed the protocol via `install.sh` |
| **蚁丘** | **colony** | The runtime signal ecosystem (signals/ + rules/ + .pheromone + .birth) inside a host project |
| **协议模板** | **protocol template(s)** | Files in `/templates/` that get copied to host projects |
| **反馈回路** | **feedback loop** | Colony → audit package → protocol source repo → Nurse → template fix → host project upgrade |

## Repository Map

```
templates/
  TERMITE_PROTOCOL.md   ← Canonical protocol spec (v5.1). Changes here propagate to all host projects on next upgrade.
  CLAUDE.md / AGENTS.md ← Entry file templates installed into host projects.
  TERMITE_SEED.md       ← Minimal protocol payload injected into generated agent systems.
  UPGRADE_NOTES.md      ← Structured changelog with per-version changes and action items for host projects.
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
install.sh              ← One-click installer for host projects (copies protocol templates, creates dirs, installs hooks, prints upgrade summary)

0227/                   ← Production reference colony (SalesTouch). Contains live signals, observations, and rules from real usage.
audit-packages/         ← Cross-colony audit data submitted from host projects.
audit-analysis/         ← Analysis reports and optimization proposals derived from audit data.
docs/plans/             ← Design documents for major features.
```

## Current State

- **Protocol version**: v5.1 (signal dependency graph: parent-child decomposition, leaf-priority .birth, auto-aggregation, Rule 4b DECOMPOSE)
- **Field lib version**: v22.0
- **Entry kernel versions**: Claude v13.0, Agents v13.0
- **Host project colonies validated**: 0227/SalesTouch (production stable), OpenAgentEngine (audited, 7 findings closed), ReactiveArmor (weak model experiment, 6 findings), touchcli (A-005 Codex shepherd 2 findings closed; A-006 5-model heterogeneous swarm 5 findings open)

### Known Issues

1. ~~`grep -c` returns exit code 1 when count is 0 under `set -euo pipefail`~~ **FIXED** — grep-c double-output, pipe-subshell variable loss, and SIGPIPE bugs fixed across field-export-audit.sh, field-cycle.sh, field-deposit.sh (first feedback loop closure: 0227 O-001 + OAE audit → Nurse → template fix)
2. ~~`install.sh` does not auto-run `scripts/hooks/install.sh`~~ **FIXED** — install.sh already has inline hook installation (lines 299-330) that copies hooks to `.git/hooks/`. OAE's low signature ratio was due to running an older install.sh version.
3. ~~`field-submit-audit.sh` is not included in the standard install flow~~ **FIXED** — integrated into `field-cycle.sh` metabolism loop; script's own gates (telemetry, disclaimer, frequency) control activation
4. ~~`.gitignore` blocks `audit-packages/` directory~~ **FIXED** — removed `audit-packages/` from protocol source repo `.gitignore`
5. ~~`field-export-audit.sh` does not match BLACKBOARD section headers correctly~~ **FIXED** — replaced exact header matching with keyword-based awk patterns (免疫/immune, 健康/health)
6. ~~`field-submit-audit.sh` fails on same-owner repos~~ **FIXED** — added same-owner detection; skips fork and pushes branch directly
7. ~~`field-export-audit.sh` `cp -R` creates nested `signals/signals/` directory~~ **FIXED** — added `rm -rf` before `cp -R` to prevent nesting when target exists (cross-colony signal: ReactArmor O-003)
8. Observation → template fix feedback loop is entirely manual (no automated path from host project O-xxx to protocol template patches)
9. ~~Upgrade information flow has three broken links — no changelog, no semantic summary, no action guidance~~ **FIXED** — created `templates/UPGRADE_NOTES.md`, install.sh --upgrade now prints change summary and writes `.termite-upgrade-report`, HOLE signal next field references UPGRADE_NOTES.md, field-arrive.sh Step 3.8 injects upgrade context into .birth
10. Protocol concept surface area (~79 concepts) exceeds blind agent cognitive budget (F-009, status: **F-009c VALIDATED by ReactiveArmor**) — .birth ≤800 tokens cannot encode the judgmental behaviors the protocol expects; strong models compensate with general intelligence, **weak models break exactly as predicted** (9/14 degenerate observations, 0% handoff evaluation, 0 rule emergence). Sub-issues: (a) entry file lookup index references 1193-line TERMITE_PROTOCOL.md; (b) .birth static content consumes 25% of token budget; **(c) VALIDATED: weak models mechanically execute deposits but don't understand WHAT to deposit**; (d) field-arrive.sh 434-line black box. See W-001 through W-005 in REGISTRY.yaml.
11. ~~Audit package lacks result verification (F-010)~~ **WONTFIX** — result verification is out of protocol scope; protocol is agent coordination framework, not CI/CD. Host projects should use existing CI/CD or manual verification. Complexity of language-agnostic result parsing (cargo, npm, pytest, go test...) exceeds protocol's minimal design philosophy.
12. ~~Completed signals leak into active set (W-008)~~ **FIXED** — DB queries and YAML fallback functions now exclude `done`/`completed` from active signal counts. 4 SQL queries (field-pulse.sh, field-arrive.sh) + 3 YAML functions (field-lib.sh) patched. Cross-colony signal: touchcli A-005.
13. ~~Idle heartbeat spinning when all signals completed (W-007)~~ **FIXED** — field-arrive.sh now detects idle colony (active_signals=0, no WIP, no alarm, no genesis) and injects IDLE guidance into .birth situation + recovery_hints. Agents know to deposit HOLE or exit session. Cross-colony signal: touchcli A-005.
14. ~~Signal granularity lacks guidance (W-009)~~ **FIXED** — added `signal_scope: one signal ≈ one verifiable deliverable` to .birth recovery_hints. Soft guidance, ~7 tokens.
15. Signal lifecycle lacks intermediate states between open and completed (W-010) — **DEFERRED**, adding states conflicts with F-009 concept area reduction. Better path: strengthen `next` field convention.
16. Signal "completed" semantics undefined (W-011) — **DEFERRED**, aligns with F-010 WONTFIX rationale. Document semantic: completed = agent believes done, verification = host CI/CD.
17. ~~Rule emergence degeneracy at scale (W-012)~~ **FIXED** — PE-005 Phase 4 adds rule quality gate in field-cycle.sh: rejects degenerate triggers (heartbeat/signal-ID only), tautological actions, and short actions (<20 chars). Source observations still archived to prevent re-promotion.
18. Observation quality regression with heterogeneous swarm (W-013) — 57% quality rate in 5-model experiment vs 96.4% in A-005. **Partially addressed**: PE-005 differentiated .birth gives execution tier behavioral templates (Shepherd Effect amplifier) and makes observation deposit optional; judgment tier requires observation deposit with quality prompt.
19. Claim lock starvation (W-015) — 63-minute idle tail from orphaned claims in 5-agent swarm. Different from W-007: work exists but is locked behind expired sessions. Need active claim timeout enforcement.

### Pending Philosophy Revision (v5.0 direction)

A foundational re-examination of the protocol's core metaphor ("termites are blind") produced three insights that will inform the next major version. Full analysis: `docs/plans/2026-03-03-protocol-philosophy-revision.md`.

**Guiding principle**: 沿袭长期智慧，而不是短期效率和聪明。

1. **"Stateless, not blind"** — "Blind" correctly captures no cross-session memory, but incorrectly implies no within-session understanding. Strong models DO understand structure. Replacement principle: "All termites are stateless. The environment carries intelligence." Strong models = environment intelligence producers; weak models = consumers.

2. **11 concept clarifications** — Stigmergy is actually explicit communication (not indirect). Pheromone conflates traces (tool-reliable facts) and deposits (model-reliable knowledge). Shepherd Effect is the core mechanism, not a deployment recommendation. Emergence (Rule 7) has noise flood risk when weak models outnumber strong. Caste for weak models is an assigned label, not a self-selected role.

3. **Uniform text over classification ("仁者见仁智者见智")** — PE-005's test→classify→differentiate approach is fragile (classification error, cold start, self-fulfilling bias). Long-term wisdom: give ALL agents the same layered text; capability difference expresses through extraction depth, not pre-filtered input. Same forest: eagle sees panorama, ant sees soil. Forest doesn't test who you are. PE-005's insight preserved (different capabilities contribute differently); its mechanism replaced (no pre-classification).

**Nurse review identified 6 counter-arguments** (800-token budget tension, cargo culting risk, classification-at-exit instead of entrance, etc.) — see "批判与盲区" section in the design doc. Conclusion: insights 1+2 are solid; insight 3's principle is correct but mechanism needs refinement under token budget constraints.

### Recent Work

- **v5.1 Signal Dependency Graph** — parent-child signal relationships solve work starvation in multi-agent swarms. Strong models decompose complex signals via `field-decompose.sh`, leaf-priority `.birth` display ensures each agent sees different unclaimed tasks, auto-aggregation closes parents when all children done. DB schema v4→v5, field lib v22→v23, kernel v12→v13.

- **v5.0 Stateless + Intelligent Environment** — protocol philosophy revision: "all termites are stateless, the environment carries intelligence". Replaces PE-005's agent-classification approach with artifact quality scoring (0.0-1.0 per observation). Unified .birth template (state-driven budget, no agent pre-classification). Trace/deposit separation (traces=tool-facts don't decay, deposits=model-knowledge quality-weighted). Rule 10 (Shepherd Effect) promoted to core grammar. Quality-weighted emergence (sum≥3.0 replaces count≥3). DB schema v3→v4, kernel v11→v12. Addresses philosophy revision insights 1+2+3.

- **PE-005 Strength-Based Participation** — protocol evolves from "uniform .birth → uniform behavior" to "identify strengths → differentiated .birth → each plays to their strengths". Three strength tiers (execution/judgment/direction), differentiated .birth templates, rule quality gate (W-012a), DB schema v3, enhanced platform detection (OpenCode), pheromone metadata extension. Protocol v3.5→v4.0, field lib v21→v22, kernel v10→v11. Addresses W-012, partially addresses W-013 and F-009b/F-009c. **Superseded by v5.0** — quality scoring replaces agent classification, unified .birth replaces differentiated templates.

- **A-006 touchcli 5-model audit** — first heterogeneous swarm (Codex 5.3, Haiku, GPT-5.1 Codex-mini, Gemini 3 Flash, Sonnet 4.6). Highest throughput ever (559 commits, 112+ signals). Handoff 100% but observation quality regressed to 57%. Rule emergence exploded (21 rules) but all degenerate. New failure mode: claim lock starvation. 5 findings (W-012 through W-016).

- **TF-007 Emergence strengthening** — lowered activation energy for protocol emergence mechanisms: (1) observation quality gate detects degenerate deposits (W-001 partial), (2) fuzzy keyword clustering replaces exact-match promotion (W-004 partial), (3) colony life phase computation (genesis/active/maintaining/idle), (4) pheromone behavioral template (observation_example field formalizes Shepherd Effect), (5) deployment topology docs (1-strong+N-weak recommended), (6) DB schema v1→v2 migration. Protocol v3.4→v3.5, field lib v20→v21.
- **W-008 + W-007 template fix (TF-005)** — ported touchcli A-005 findings to protocol templates: excluded done/completed from active signal counts (4 DB queries + 3 YAML functions), added idle colony detection + exit guidance in .birth. Second complete feedback loop closure: touchcli observation → Nurse → template fix.
- **touchcli audit (A-005)** — first Codex shepherd + Haiku swarm experiment. Discovered "Shepherd Effect" (strong model pheromone templates enable weak model imitation). Also discovered idle heartbeat spinning (W-007) and completed signal leakage (W-008). Most complete project delivery of all audited colonies.
- **ReactiveArmor weak model experiment (A-003)** — first weak model field test: 2 Haiku parallel with Codex genesis. Core protocol loop succeeded (121 commits, S-001→S-024, 93→174 tests). Judgmental behaviors failed: 9/14 degenerate observations (W-001), signature format divergence (W-002), 0% handoff evaluation (W-003), 0 rule emergence (W-004). **Validates F-009c**. See `audit-analysis/optimization-proposals/2026-03-01-weak-model-experiment-reactivearmor.md`.
- **Blind premise audit (F-009)** — human-directed audit of whether protocol evolution respects "termites are blind, context is limited"; identified concept surface area inflation, .birth budget waste, and undeclared agent-intelligence dependency. **F-009c now validated by ReactiveArmor experiment**.
- **Upgrade information flow fix (F-008)** (`docs/plans/2026-03-01-upgrade-info-flow-design.md`) — created UPGRADE_NOTES.md, install.sh upgrade summary, field-arrive.sh upgrade report injection; synced CLAUDE.md + AGENTS.md templates
- **Nurse batch fix TF-002 + TF-003** — closed all 7 OAE audit findings: F-001 grep-c, F-002 hooks, F-003 submit flow, F-004 .gitignore, F-005 header matching, F-006 same-owner, F-007 cp-R nesting
- **Terminology unification** (`docs/plans/2026-03-01-terminology-unification-design.md`) — unified referential terms across all files
- **grep-c feedback loop MVP** (`docs/plans/2026-03-01-grep-c-feedback-loop-mvp-design.md`) — first complete feedback loop closure: 0227 O-001 + OAE audit → Nurse → template fix
- Cross-colony feedback loop design (`docs/plans/2026-02-28-cross-colony-feedback-loop-*`)
- Claude Code plugin integration with 7 hooks (`docs/plans/2026-02-28-claude-code-hook-integration-*`)
- OpenAgentEngine agent experience audit (`audit-analysis/optimization-proposals/2026-03-01-agent-experience-report-oae.md`)

## Operations (协议源仓库的工作模式)

> **协议源仓库不是宿主项目。** 这里没有 field-arrive.sh / .birth / 心跳循环。
> 这里的驱动力是：**审计包到达** 和 **人类指令**。

### "白蚁协议"在这里的含义

在宿主项目中，"白蚁协议"= 心跳触发 → 自主代谢。
在协议源仓库中，"白蚁协议"= **Nurse 自检** → 读审计登记簿 → 识别待处理项 → 执行。

### 你能做的三件事

| 操作 | 触发方式 | 输入 | 输出 |
|------|---------|------|------|
| **Nurse 审计分析** | 人类说"白蚁协议"或"Nurse 分析" | `audit-analysis/REGISTRY.yaml` + `audit-packages/*/metadata.yaml` | 优化提案写入 `audit-analysis/optimization-proposals/` |
| **协议演化** | 人类描述需求 | `templates/` 中的规范和脚本 | 修改模板 + 版本号更新 |
| **反馈闭环处理** | Nurse 发现跨蚁丘重复模式 | 宿主项目观察 (O-xxx) + 审计 findings | 模板修复 + REGISTRY.yaml 记录 |

### Nurse 自检流程

```
0. git pull origin main                       ← 拉取最新（其他白蚁通过 PR 提交审计包）
1. 读 audit-analysis/REGISTRY.yaml           ← 你的工作台面，从这里开始
2. 检查 status: open 的条目                    ← 有未处理的审计或未修复的问题吗？
3. 读对应的 audit-packages/*/metadata.yaml    ← 了解宿主项目蚁丘的健康指标
4. 跨蚁丘比对                                  ← 不同宿主项目是否报告了相同的模式？
5. 如果发现问题 → 定位到 templates/ 中的源码    ← 问题出在哪个模板脚本？
6. 修复 → 更新 REGISTRY.yaml → 更新 Known Issues
```

### 审计登记簿

`audit-analysis/REGISTRY.yaml` 是协议源仓库的**唯一结构化状态文件**。
每次审计到达、模板修复、协议演化都追加一条记录。Nurse 从这里开始工作。

## Development Conventions

- Field scripts must work under `set -euo pipefail`
- All script changes should pass `shellcheck`
- Protocol spec changes (`TERMITE_PROTOCOL.md`) require a version bump
- Entry file template changes require kernel version sync between `CLAUDE.md` and `AGENTS.md`
- Do NOT run `field-arrive.sh`, `field-cycle.sh`, or other field scripts in the protocol source repo — they are designed for host projects
- **Keep this file current**: When your work changes the protocol version, fixes a known issue, or shifts the project focus, update the Current State section of this file before ending your session
- **Record human prompts**: When writing design documents (`docs/plans/`), always include a "思维过程" or "Prompt Chain" section that records the human user's original prompts in order, with brief notes on what each prompt led to. The thinking process is as valuable as the conclusion — future readers need to see how the ideas evolved, not just the final result.

## Impact Awareness

| You change... | Impact |
|---|---|
| `templates/TERMITE_PROTOCOL.md` | All host projects on next `install.sh --upgrade` |
| `templates/scripts/*.sh` | Runtime behavior of all host project colonies |
| `templates/UPGRADE_NOTES.md` | Upgrade guidance for all host projects (updated during --upgrade) |
| `templates/CLAUDE.md` or `AGENTS.md` | New installations only (existing entry files are preserved on upgrade) |
| `install.sh` | Installation and upgrade flow for all future adopters |
| `0227/` | Reference colony only — do not modify without understanding it is a live production snapshot |
