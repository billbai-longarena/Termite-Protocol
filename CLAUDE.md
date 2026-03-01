# Termite Protocol — Source Repository

This is the **协议源仓库 (protocol source repo)** for the Termite Protocol (白蚁协议), a cross-session collaboration framework for stateless AI agents.

**This is NOT a 宿主项目 (host project). This is the protocol source repo itself.** Your work here evolves the protocol spec and field scripts that all host project colonies depend on.

## Terminology (权威术语表)

| 中文 | English | Meaning |
|------|---------|---------|
| **白蚁协议** | **Termite Protocol** | The framework as a whole (generic reference only) |
| **协议规范** | **protocol spec** | The `TERMITE_PROTOCOL.md` document and its 9+4 rules |
| **协议源仓库** | **protocol source repo** | This Git repo (`billbai-longarena/Termite-Protocol`) |
| **宿主项目** | **host project** | Any project that installed the protocol via `install.sh` |
| **蚁丘** | **colony** | The runtime signal ecosystem (signals/ + rules/ + .pheromone + .birth) inside a host project |
| **协议模板** | **protocol template(s)** | Files in `/templates/` that get copied to host projects |
| **反馈回路** | **feedback loop** | Colony → audit package → protocol source repo → Nurse → template fix → host project upgrade |

## Repository Map

```
templates/
  TERMITE_PROTOCOL.md   ← Canonical protocol spec (v3.4). Changes here propagate to all host projects on next upgrade.
  CLAUDE.md / AGENTS.md ← Entry file templates installed into host projects.
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
install.sh              ← One-click installer for host projects (copies protocol templates, creates dirs, installs hooks)

0227/                   ← Production reference colony (SalesTouch). Contains live signals, observations, and rules from real usage.
audit-packages/         ← Cross-colony audit data submitted from host projects.
audit-analysis/         ← Analysis reports and optimization proposals derived from audit data.
docs/plans/             ← Design documents for major features.
```

## Current State

- **Protocol version**: v3.4 (SQLite WAL-mode, drift robustness)
- **Field lib version**: v20.0
- **Entry kernel versions**: Claude v10.0, Agents v8.0
- **Host project colonies validated**: 0227/SalesTouch (production stable), OpenAgentEngine (audited, 7 findings)

### Known Issues

1. ~~`grep -c` returns exit code 1 when count is 0 under `set -euo pipefail`~~ **FIXED** — grep-c double-output, pipe-subshell variable loss, and SIGPIPE bugs fixed across field-export-audit.sh, field-cycle.sh, field-deposit.sh (first feedback loop closure: 0227 O-001 + OAE audit → Nurse → template fix)
2. `install.sh` does not auto-run `scripts/hooks/install.sh` — git hooks sit in `scripts/hooks/` but never reach `.git/hooks/` unless manually installed
3. `field-submit-audit.sh` is not included in the standard install flow
4. `.gitignore` blocks `audit-packages/` directory, requiring `git add -f`
5. `field-export-audit.sh` does not match BLACKBOARD section headers correctly
6. Observation → template fix feedback loop is entirely manual (no automated path from host project O-xxx to protocol template patches)

### Recent Work

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

## Impact Awareness

| You change... | Impact |
|---|---|
| `templates/TERMITE_PROTOCOL.md` | All host projects on next `install.sh --upgrade` |
| `templates/scripts/*.sh` | Runtime behavior of all host project colonies |
| `templates/CLAUDE.md` or `AGENTS.md` | New installations only (existing entry files are preserved on upgrade) |
| `install.sh` | Installation and upgrade flow for all future adopters |
| `0227/` | Reference colony only — do not modify without understanding it is a live production snapshot |
