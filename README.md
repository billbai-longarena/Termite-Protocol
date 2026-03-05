# 白蚁协议 Termite Protocol

**让无状态的 AI Agent 像白蚁一样协作：无需对话，无需记忆，通过环境自发涌现秩序。**
**Stateless AI agents collaborate like termites: no conversation, no memory, order emerges through the environment.**

---

## Executive Summary

白蚁协议是一套 **AI Agent 跨会话协作框架**。它解决了当前 AI 编码工具的核心矛盾：Agent 是无状态的（每次会话独立），但软件开发需要持续的上下文、协调和知识积累。

**核心机制**：Agent 不互相对话，而是通过文件系统间接协调——信号持久化在 SQLite，观察沉淀为信息素，行为模板通过 `.birth` 文件传递。环境承载智能，Agent 只需感知和执行。

**关键数据**：经过 6 个生产蚁丘验证，4 次多模型审计实验，累计 900+ commits。在 touchcli A-005 实验中，1 个 Codex 牧羊人 + 2 个 Haiku 工人的配置实现了 **96.4% 的观察质量** —— 我们称之为 **Shepherd Effect（牧羊效应）**。

The Termite Protocol is a **cross-session collaboration framework for AI agents**. It solves the core contradiction of current AI coding tools: agents are stateless (each session is independent), but software development requires continuous context, coordination, and knowledge accumulation.

**Core mechanism**: Agents don't talk to each other. They coordinate indirectly through the file system — signals persist in SQLite, observations accumulate as pheromones, behavioral templates propagate via `.birth` files. The environment carries intelligence; agents just sense and execute.

**Key data**: Validated across 6 production colonies, 4 multi-model audit experiments, 900+ total commits. In the touchcli A-005 experiment, 1 Codex shepherd + 2 Haiku workers achieved **96.4% observation quality** — a mechanism we call the **Shepherd Effect**.

---

## The Problem

### AI Agent 的失忆症

每个 AI Agent 会话都是一次性的。会话结束，上下文蒸发。这不是 bug，而是当前 LLM 架构的基本事实。

Every AI agent session is ephemeral. When a session ends, all context evaporates. This is not a bug — it's a fundamental reality of current LLM architecture.

**连锁问题**：

| 问题 | 后果 |
|------|------|
| **重复劳动** | 每个 Agent 重新理解项目结构、技术约定、设计决策 |
| **上下文丢失** | 前任的思考过程、失败尝试、关键判断随会话蒸发 |
| **幻觉累积** | 没有持久化事实来源，Agent 编造不确定的信息 |
| **无法分工** | 多 Agent 不能并行——没有协调机制，必然冲突 |
| **弱模型失能** | 便宜模型缺乏判断力，独立工作时质量灾难性下降 |

### 现有方案的局限

| 方案 | 协调方式 | 为什么不够 |
|------|---------|-----------|
| **CLAUDE.md / .cursorrules** | 静态规则文件 | 无跨会话记忆，无多 Agent 协调，无动态状态 |
| **CrewAI / AutoGen** | Agent 对话 | 所有 Agent 都需要强模型来维持对话上下文。弱模型在多轮讨论中幻觉。无持久记忆。 |
| **LangGraph** | 静态工作流图 | 预定义流程，无法动态认领任务，不适应并行工人的不同完成速度 |
| **OpenAI Swarm** | 顺序移交 | 一次只有一个 Agent 工作，无并行 |
| **MCP Server** | 工具调用 | 提供工具能力，不提供协调机制和知识积累 |

**共同缺陷**：这些方案要么假设 Agent 是有状态的（它不是），要么通过对话协调（弱模型做不到），要么缺少跨会话知识积累机制。

---

## Why Termite Protocol

### 1. 环境承载智能，而非 Agent 承载智能

这是与所有对话式多 Agent 框架的根本区别。

```
CrewAI/AutoGen:  聪明Agent ↔ 聪明Agent ↔ 聪明Agent (对话协调)
白蚁协议:        Agent → 环境 → Agent → 环境 → Agent (环境协调)
```

**为什么这很重要**：弱模型不需要"聪明"。它只需要能感知环境中的信号（`.birth` 文件）并执行。所有的协调智能都在环境里——SQLite 里的信号队列、文件系统里的信息素、`.birth` 里的行为模板。

This is the fundamental difference from all conversation-based multi-agent frameworks. Weak models don't need to be smart. They just sense signals in the environment and act. All coordination intelligence lives in the environment — signal queues in SQLite, pheromones in the file system, behavioral templates in `.birth`.

### 2. Shepherd Effect（牧羊效应）— 实测 18 倍质量提升

我们最重要的发现，经过 4 次审计实验验证：

| 配置 | 观察质量 | 交接质量 | 来源 |
|------|---------|---------|------|
| 2 Haiku 独立工作 | **35.7%** | 0% | A-003 ReactiveArmor |
| 1 Codex + 2 Haiku | **96.4%** | 99% | A-005 touchcli |
| 5 模型混合群 | **57%** | 100% | A-006 touchcli |

**机制**：强模型先工作，留下高质量的信息素沉积（观察，带完整的 pattern/context/detail 结构）。后续弱模型通过 `.birth` 文件中的 `observation_example` 字段看到这些模板，通过 **上下文学习（in-context learning）** 模仿同样的结构。

**关键洞察**：弱模型不是"不能"做高质量工作，而是不能"发起"高质量模式。给它一个模板来模仿，Haiku 在 96% 的情况下产出与 Codex 无法区分的工作。

**Mechanism**: A strong model works first, leaving high-quality pheromone deposits. Subsequent weak models see these templates via `observation_example` in `.birth` and **imitate the structure through in-context learning**. Weak models can't initiate quality patterns, but given a template, Haiku produces Codex-indistinguishable work 96% of the time.

### 3. .birth 压缩：800 Token 初始化任何 Agent

| 方案 | Agent 上下文消耗 | Agent 需要阅读什么 |
|------|-----------------|-------------------|
| 直接阅读协议 (v2) | ~40% | 28K token TERMITE_PROTOCOL.md |
| **白蚁 .birth (v3+)** | **~2%** | **800 token 动态计算的快照** |
| CrewAI role prompt | ~10-15% | 角色描述 + 对话历史 |
| AutoGen system prompt | ~5-10% | 系统消息 + 增长的聊天记录 |

`field-arrive.sh`（434 行）动态计算 `.birth`，包含：蚁丘当前状态、最高优先级未认领信号、行为模板（Shepherd Effect 示范）、4 条安全规则、恢复提示。Agent 需要知道的一切，不多不少。

### 4. 原子信号认领：无对话、无冲突、无瓶颈

Agent 之间从不交流。它们通过 SQLite 原子事务认领信号：

```
Agent 到达 → 读 .birth → 看到未认领信号 →
  field-claim.sh claim S-007 → EXCLUSIVE 锁 → 成功 →
  执行任务 → 提交 → field-deposit.sh → 完成
```

- **无调度器瓶颈**：Agent 自组织，自主认领可用工作
- **无冲突**：数据库原子认领，不会双重分配
- **崩溃恢复**：Agent 死亡后，认领超时自动释放（修复了 A-006 中发现的 63 分钟饥饿问题）

### 5. 自演化协议：观察涌现为规则

多数框架的规则是静态的。白蚁协议的规则是**涌现**的：

```
Agent 发现约定 → 沉积为观察 → 多 Agent 重复发现同一约定
  → quality_sum ≥ 3.0 → 自动晋升为规则 → 所有后续 Agent 遵循
```

这不是预定义的工作流，而是从实践中长出来的秩序。质量加权（`quality_sum ≥ 3.0` 而非简单 `count ≥ 3`）防止弱模型灌水产生垃圾规则（A-006 中 21 条退化规则全部被质量门过滤）。

### 6. 协议消融：Agent 不读协议

v3.0 的核心转变：协议从 Agent 必须阅读的文档，消融为 Agent 到达时自动感知的环境基础设施。

```
BEFORE v2:  Agent → 读 TERMITE_PROTOCOL.md (28K tokens) → 上下文消耗 40%
AFTER v3:   Agent → field-arrive.sh 计算 .birth → Agent 读 .birth → 上下文消耗 2%
```

`TERMITE_PROTOCOL.md` 仍然存在，但它是人类参考文档 + 脚本配置源，不再是 Agent 的阅读材料。如同白蚁不需要阅读蚁丘蓝图——它只需感知脚下的信息素浓度。

---

## Production Data

### 实测蚁丘数据

| 蚁丘 | 模型配置 | 时长 | Commits | 信号 | 关键发现 |
|------|---------|------|---------|------|---------|
| **SalesTouch** (0227) | 生产环境 | 持续 | — | — | 稳定生产参考蚁丘 |
| **OpenAgentEngine** (A-001) | 2 Codex | — | 54 | — | 首个审计闭环，7 findings 全部修复 |
| **ReactiveArmor** (A-003) | Codex + 2 Haiku | — | 121 | 24 | **验证 F-009c**：弱模型执行协议循环成功，判断行为失败 |
| **touchcli** (A-005) | Codex + 2 Haiku | 6h | 130 | 6 | **Shepherd Effect 验证**：96.4% 质量 |
| **touchcli** (A-006) | 5 模型 | 17h | **562** | 113 | 最高吞吐，发现规模退化和认领饥饿 |

A-005 交付了完整 MVP：PostgreSQL（11 表）、REST API（11 端点）、React/Vite 前端、Docker 容器化。

### 关键实验对比

| 指标 | A-003（纯弱模型） | A-005（Shepherd） | A-006（5 模型混合） |
|------|------------------|------------------|---------------------|
| 观察退化率 | 64% | 3.6% | 57% |
| 交接质量 | 0% | 99% | 100% |
| 规则涌现 | 0 | 1 | 21（全部退化） |
| 结论 | 弱模型独立=灾难 | 1 强+N 弱=高效 | 稀释效应需控制 |

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash
```

或 / Or:
```bash
git clone https://github.com/billbai-longarena/Termite-Protocol /tmp/termite
bash /tmp/termite/install.sh
rm -rf /tmp/termite
```

升级 / Upgrade: `bash /tmp/termite/install.sh --upgrade`

安装后编辑 `CLAUDE.md` / `AGENTS.md` 填入你的项目信息即可。

---

## How to Use

### Step 1: 安装协议

安装脚本自动完成：复制模板文件、创建 `signals/` 目录、安装 git hooks、安装 Claude Code 插件、更新 `.gitignore`。

### Step 2: 填写项目信息

编辑 `CLAUDE.md` / `AGENTS.md`，填写：项目概述、技术栈、路由表、验证清单。

### Step 3: Agent 开始工作

```
Agent 启动 → field-arrive.sh → .birth (≤800 tokens) → Agent 读 .birth → 工作
```

你会观察到：Agent 自动感知状态（via `.birth`）、频繁 commit 带签名标记、主动写交接文件、修正文档与代码的不一致。

### Step 4: 用 Commander 自动化（推荐）

手动管理蚁群很累。[**Termite Commander**](https://github.com/billbai-longarena/TermiteCommander) 自动化全链路：

```bash
# 安装 Commander
git clone https://github.com/billbai-longarena/TermiteCommander.git
cd TermiteCommander/commander && npm install && npm run build && npm link

# 一键启动蚁群
cd ~/your-project
termite-commander plan "实现OAuth认证" --plan PLAN.md --colony . --run

# 或在 Claude Code 中
> /commander 按照设计开始施工
> 让蚁群干活
```

Commander 自动：检测协议 → 安装 → 创世 → 分解信号 → 发布 → 启动混合模型工人 → 心跳监控 → 完成后自动停止。

详见 [Commander README](https://github.com/billbai-longarena/TermiteCommander#readme)。

---

## When to Use

### 适合白蚁协议

| 场景 | 为什么适合 |
|------|-----------|
| **多 Agent 并行开发** | 信号认领无冲突，每个 Agent 独立工作 |
| **强弱模型混合** | Shepherd Effect 让 1 强+N 弱达到近强模型质量 |
| **长期项目** | 信息素跨会话积累知识，后来的 Agent 越来越高效 |
| **大规模重构** | 大量独立文件级改动，高度并行 |
| **需要审计溯源** | 每个观察、决策、规则都有来源追踪 |

### 不适合白蚁协议

| 场景 | 为什么不适合 | 建议 |
|------|-------------|------|
| **单人单 Agent 小任务** | 协议开销 > 收益 | 直接用 Claude Code |
| **探索性调研** | 需要强模型的整体判断 | Claude Code 原生能力 |
| **一次性脚本** | 无需跨会话记忆 | 直接写 |

---

## Architecture

### 文件结构

```
your-project/
  TERMITE_PROTOCOL.md   ← 人类参考 + 脚本配置源
  CLAUDE.md / AGENTS.md ← Agent 入口
  BLACKBOARD.md         ← 动态状态（健康、信号、热点）
  WIP.md                ← 会话间交接
  .birth                ← 动态计算的 Agent 初始化（≤800 tokens）
  .pheromone            ← 信息素链（跨会话知识积累）
  scripts/
    field-arrive.sh     ← 计算 .birth
    field-cycle.sh      ← 心跳循环 (Sense → Act → Notice → Deposit)
    field-deposit.sh    ← 信息素沉积
    field-claim.sh      ← 原子任务认领
    field-decay.sh      ← 信息素衰减
    field-pulse.sh      ← 项目状态快照
    termite-db.sh       ← SQLite WAL-mode DB
    hooks/              ← git hooks (签名/安全/代谢)
  signals/              ← 信号存储
```

### 协议层级

| 层级 | 文件 | 上下文成本 |
|------|------|-----------|
| **协议源** | `TERMITE_PROTOCOL.md` | 人类阅读（Agent 不读） |
| **场脚本** | `scripts/` | 0（脚本执行，不消耗 Agent 上下文） |
| **Agent 入口** | `.birth` | **~2%**（800 tokens） |

### 协议 4 部分结构

| Part | 内容 | 面向 |
|------|------|------|
| **I: Grammar** | 9 条规则 + 4 条安全网 | field-arrive.sh 提取 → .birth |
| **II: Environment Config** | 种姓、信号 schema、降级矩阵 | field-arrive.sh 读取 |
| **III: Human Reference** | 完整设计理由、免疫系统 | 人类阅读 |
| **IV: Appendices** | 模板、快速参考卡 | 按需查阅 |

---

## Field Scripts

| 脚本 | 用途 |
|------|------|
| `field-arrive.sh` | 到达：读取协议 + 环境 → 计算 .birth |
| `field-cycle.sh` | 心跳：Sense → Act → Notice → Deposit |
| `field-deposit.sh` | 沉积：观察/决策/状态 → 信号文件 |
| `field-claim.sh` | 认领：原子锁定/释放/查询 |
| `field-decay.sh` | 衰减：清理过期信号 |
| `field-pulse.sh` | 脉冲：项目状态快照 |
| `field-drain.sh` | 排水：批量清除信号 |
| `termite-db.sh` | DB：SQLite WAL-mode + migrations |

### Git Hooks

| Hook | 用途 |
|------|------|
| `pre-commit` | 防止提交敏感文件、验证文件大小 |
| `prepare-commit-msg` | 自动添加 `[termite:YYYY-MM-DD:caste]` 签名 |
| `post-commit` | 提交后自动触发信息素沉积 |
| `pre-push` | 分支保护、安全扫描 |

---

## Platform Support

| 平台 | 入口文件 | 支持级别 |
|------|---------|---------|
| **Claude Code** | `CLAUDE.md` | 完整支持：field-arrive.sh + .birth + hooks |
| **OpenAI Codex** | `AGENTS.md` | 完整支持：自启动黑板协议 |
| **OpenCode** | `CLAUDE.md` | 完整支持：via skill system |
| **Google Gemini** | `AGENTS.md` | 完整支持 |
| **Cursor / Windsurf / Cline** | 各自规则文件 | 优雅降级：内联规则摘要（~5%） |

---

## Protocol Evolution

| 版本 | 关键变化 |
|------|---------|
| **v1.0** | 种姓系统、生命周期、信息素规则、ALARM 机制 |
| **v2.0** | 协议-项目分离、签名格式、状态迁移到 BLACKBOARD.md |
| **v3.0** | **协议消融**：.birth 压缩到 800 tokens、观察→规则自动晋升、git hooks 自动化 |
| **v3.5** | DB 架构（SQLite WAL）、Shepherd Effect、蚁丘生命周期检测 |
| **v4.0** | 优势参与机制：差异化 .birth（执行/判断/方向） |
| **v5.0** | 无状态 + 智能环境：质量加权涌现、trace/deposit 分离 |
| **v5.1** | 信号依赖图：parent-child 分解、叶优先 .birth、自动聚合 |

---

## Design Philosophy

**简单规则，复杂涌现。协议消融为环境。**

白蚁协议不设计完美的 AI Agent 工作流。它给无状态的 Agent 一套最小化的局部规则，让秩序从混沌中自发涌现。

如同真正的白蚁丘——没有建筑师，但建筑矗立。没有蚁后审批，决策通过信息素浓度叠加涌现共识。

**"无蚁后"原则**：协议中没有任何角色拥有特殊审批权。人类是同丘成员，不是外部管理者。人类指令永远优先于协议规则。

---

## License

MIT License. See [LICENSE](LICENSE).
