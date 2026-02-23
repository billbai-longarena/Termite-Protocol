# 白蚁协议 (Termite Protocol)

**一套面向无状态 AI Agent 的跨会话协作框架**
**A cross-session collaboration framework for stateless AI agents**

---

## 为什么需要白蚁协议？ / Why Termite Protocol?

### 问题：AI Agent 的失忆症 / The Problem: AI Agent Amnesia

每个 AI Agent 会话都是一次性的。会话结束，上下文消失，下一个 Agent 从零开始。
Every AI agent session is ephemeral. When a session ends, the context vanishes, and the next agent starts from scratch.

这导致了一系列连锁问题：
This causes a cascade of problems:

- **重复劳动**：每个 Agent 都在重新理解项目结构、技术约定、设计决策。
- **Repeated work**: Every agent re-discovers the project structure, conventions, and design decisions.

- **上下文丢失**：上一个 Agent 的思考过程、失败尝试、关键判断，全部随会话蒸发。
- **Lost context**: The previous agent's reasoning, failed attempts, and key judgments all evaporate with the session.

- **幻觉累积**：没有持久化的事实来源，Agent 倾向于"编造"它不确定的信息。
- **Hallucination drift**: Without a persisted source of truth, agents tend to fabricate information they're unsure about.

- **无法分工**：多个 Agent 不能并行工作于同一项目，因为没有协调机制。
- **No division of labor**: Multiple agents can't work in parallel on the same project due to lack of coordination.

### 灵感：真实白蚁的群体智能 / Inspiration: Real Termite Swarm Intelligence

真实的白蚁是盲的，没有中央指挥，没有全局记忆。但它们建造了地球上最复杂的生物建筑。
Real termites are blind, have no central command, and no global memory. Yet they build the most complex biological structures on Earth.

它们的秘密是**信息素 (Pheromone)**——一种留在环境中的化学信号。
Their secret is **pheromone** — a chemical signal deposited in the environment.

- 白蚁不需要知道整体蓝图，它只需要闻到前任留下的信息素，然后做出局部决策。
- A termite doesn't need to know the global blueprint; it just senses pheromones left by predecessors and makes local decisions.

- 信息素会自然挥发，过时的路径自动失效，蚁群不会被历史包袱困住。
- Pheromones naturally evaporate, outdated paths auto-expire, and the colony isn't trapped by legacy signals.

- 高浓度的信息素（多只蚁在同一位置沉积）会涌现出复杂结构——没有任何一只蚁"设计"了它。
- High pheromone concentration (many ants depositing at the same spot) gives rise to complex structures — no single ant "designed" it.

**白蚁协议就是将这套生物学机制映射到 AI Agent 的开发协作中。**
**The Termite Protocol maps this biological mechanism onto AI agent development collaboration.**

文件系统就是你的蚁丘。Markdown 文件就是信息素。Git commit 就是不可逆的建筑痕迹。
The file system is your colony. Markdown files are pheromones. Git commits are irreversible construction traces.

### 核心假设 / Core Assumptions

1. **Agent 是无状态的**：每个会话独立，没有跨会话记忆。这是当前 AI Agent 的基本事实。
1. **Agents are stateless**: Each session is independent with no cross-session memory. This is a fundamental reality of current AI agents.

2. **文件系统是持久的**：代码、文档、git 历史不会随会话消失。这是唯一可靠的记忆介质。
2. **The file system is persistent**: Code, docs, and git history survive session death. This is the only reliable memory medium.

3. **局部规则可以涌现全局秩序**：Agent 不需要理解整体架构，只需遵循简单的 IF-THEN 规则。
3. **Local rules can produce global order**: An agent doesn't need to understand the full architecture — just follow simple IF-THEN rules.

4. **人类是最高权限**：协议不能变成官僚主义的束缚。人类指令永远优先于协议规则。
4. **Humans have supreme authority**: The protocol must never become bureaucratic shackles. Human instructions always override protocol rules.

---

## 协议解决了什么？ / What Does the Protocol Solve?

| 问题 / Problem | 白蚁方案 / Termite Solution |
| --- | --- |
| Agent 不知道项目现状 | 蚁丘健康状态表：一张表告诉你构建是否通过、测试覆盖率、活跃分支 |
| Agent doesn't know project status | Colony Health Dashboard: one table showing build status, test coverage, active branches |
| Agent 不知道前任做了什么 | WIP.md 交接文件：未完成的任务、已做的决策、下一步指引 |
| Agent doesn't know what predecessors did | WIP.md handoff file: unfinished tasks, decisions made, next-step guidance |
| Agent 改错了东西 | 种姓系统限权：Scout 只读不写，Worker 只改 Plan 范围内的文件 |
| Agent breaks things | Caste system constrains scope: Scout reads only, Worker edits only files within Plan scope |
| 构建挂了但 Agent 还在加功能 | 报警信息素：ALARM.md 强制所有 Agent 停下来先修复 |
| Build is broken but agent keeps adding features | Alarm pheromone: ALARM.md forces all agents to stop and fix first |
| 多个 Agent 改同一个文件冲突 | WIP.md 认领机制 + git worktree 隔离 |
| Multiple agents conflict on same file | WIP.md claim mechanism + git worktree isolation |
| 过时的文档误导 Agent | 信息素保鲜期：超过 7 天的状态视为"未知"，强制重新验证 |
| Stale docs mislead agents | Pheromone expiration: status older than 7 days is treated as "unknown", forcing re-verification |
| 同一个坑被反复踩 | 信息素浓度叠加：2+ 只 Agent 报告同一问题 → 升级为热点区域 |
| Same pitfall hit repeatedly | Pheromone concentration: 2+ agents report the same issue → escalated to hotspot |

---

## 三个文件，各司其职 / Three Files, Each with a Role

v2.0 采用了**协议与项目信息分离**的架构：
v2.0 adopts a **protocol-project separation** architecture:

```
your-project/
  TERMITE_PROTOCOL.md   ← 通用协议（所有 Agent 共享）/ Universal protocol (shared by all agents)
  CLAUDE.md             ← Claude Code 入口（项目特有信息）/ Claude Code entry (project-specific info)
  AGENTS.md             ← Codex/Gemini 入口（项目特有信息 + 自启动协议）/ Codex/Gemini entry (project-specific + self-boot protocol)
  BLACKBOARD.md         ← 动态状态（健康、信号、热点）/ Dynamic state (health, signals, hotspots)
```

### `TERMITE_PROTOCOL.md` — 通用协议 / Universal Protocol

所有 AI Agent 共享的核心协议，定义了：
The core protocol shared by all AI agents, defining:

- 种姓分工系统（Scout / Worker / Soldier / Nurse）
- Caste system (Scout / Worker / Soldier / Nurse)

- Phase 0-6 生命周期（降落 → 定向 → 路由 → 施工 → 验证 → 沉积 → 交接）
- Phase 0-6 lifecycle (Land → Orient → Route → Build → Verify → Deposit → Handoff)

- 信息素规则（签名、保鲜、浓度叠加）
- Pheromone rules (signatures, expiration, concentration stacking)

- 全局触发-动作规则表
- Global trigger-action rule table

- 报警、故障恢复、蜕皮机制
- Alarm, failure recovery, context molting

**这个文件不包含任何项目特有信息，可以直接复制到任何项目中。**
**This file contains no project-specific info and can be copied directly into any project.**

### `CLAUDE.md` — Claude Code 入口 / Claude Code Entry

适用于 **Claude Code** (Anthropic 官方 CLI)。Claude Code 会自动读取项目根目录的 `CLAUDE.md`。
Designed for **Claude Code** (Anthropic's official CLI). Claude Code automatically reads `CLAUDE.md` from the project root.

**只包含项目特有信息：**
**Contains only project-specific info:**

- 项目概述和技术栈
- Project overview and tech stack

- 路由表（任务关键词 → 局部黑板）
- Route table (task keywords → local blackboards)

- 项目特有的触发-动作规则
- Project-specific trigger-action rules

- 项目特有的验证清单（构建/测试命令）
- Project-specific verification checklist (build/test commands)

- 黑板索引
- Blackboard index

### `AGENTS.md` — Codex / 异步 Agent 入口 / Codex / Async Agent Entry

适用于 **OpenAI Codex**、**Gemini** 等异步执行的 Agent。
Designed for **OpenAI Codex**, **Gemini**, and similar async-execution agents.

**在 CLAUDE.md 的项目信息基础上，额外包含：**
**In addition to project info (same as CLAUDE.md), it includes:**

- Agent Operating Protocol：无人值守操作原则
- Agent Operating Protocol: unattended operation principles

- 自启动黑板协议：Signal/Claim/Plan/Result 表格体系
- Self-boot blackboard protocol: Signal/Claim/Plan/Result table system

- 信息素权重与衰减机制
- Pheromone weight and decay mechanism

- 微探索配额
- Micro-exploration quota

---

## 怎么使用？ / How to Use?

### 第一步：复制模板 / Step 1: Copy Templates

```
templates/TERMITE_PROTOCOL.md  → 复制到你的项目根目录 / Copy to your project root
templates/CLAUDE.md            → 复制为项目根目录的 CLAUDE.md / Copy as CLAUDE.md in project root
templates/AGENTS.md            → 复制为项目根目录的 AGENTS.md / Copy as AGENTS.md in project root
```

**协议文件 (`TERMITE_PROTOCOL.md`) 直接复制，无需修改。** 只需填写入口文件中的项目信息。
**The protocol file (`TERMITE_PROTOCOL.md`) is copied as-is, no modification needed.** Only fill in project info in the entry files.

### 第二步：填写项目信息 / Step 2: Fill in Project Info

入口文件（`CLAUDE.md` / `AGENTS.md`）中用 `<!-- 注释 -->` 标记了所有需要你填写的位置：
The entry files (`CLAUDE.md` / `AGENTS.md`) mark all sections you need to fill with `<!-- comments -->`:

1. **项目概述**：一句话描述你的项目是什么
1. **Project overview**: One-sentence description of what your project is

2. **技术栈**：前端、后端、数据库、主要框架
2. **Tech stack**: Frontend, backend, database, key frameworks

3. **路由表**：任务关键词 → 局部黑板路径（如果你的项目有多个模块）
3. **Route table**: Task keywords → local blackboard paths (if your project has multiple modules)

4. **项目特有规则**：你的项目独有的触发-动作规则
4. **Project-specific rules**: Trigger-action rules unique to your project

5. **验证清单**：你的构建和测试命令
5. **Verification checklist**: Your build and test commands

### 第三步：创建局部黑板（可选）/ Step 3: Create Local Blackboards (Optional)

如果你的项目有多个模块，为每个模块创建 `BLACKBOARD.md`：
If your project has multiple modules, create a `BLACKBOARD.md` for each:

```
your-project/
  TERMITE_PROTOCOL.md    ← 通用协议 / Universal protocol
  CLAUDE.md              ← Claude Code 入口 / Claude Code entry
  AGENTS.md              ← Codex/Gemini 入口 / Codex/Gemini entry
  BLACKBOARD.md          ← 根目录动态状态 / Root dynamic state
  module-a/
    BLACKBOARD.md        ← 模块 A 的局部知识 / Module A local knowledge
    DECISIONS.md         ← 模块 A 的设计决策 / Module A design decisions
  module-b/
    BLACKBOARD.md
```

局部黑板应包含：模块架构、数据库表、API 接口、模块特有的触发-动作规则。
Local blackboards should contain: module architecture, DB tables, API endpoints, module-specific trigger-action rules.

### 第四步：让 Agent 开始工作 / Step 4: Let the Agent Work

不需要额外配置。Agent 会自动读取协议文件并遵循其中的规则。
No extra configuration needed. The agent will automatically read the protocol file and follow its rules.

你会观察到 Agent 的行为变化：
You'll notice behavioral changes in the agent:

- 它会在开始任务前检查 `ALARM.md` 和 `WIP.md`
- It checks `ALARM.md` and `WIP.md` before starting tasks

- 它会频繁 commit 带 `[WIP]` 标签，而不是做完所有事才一次性提交
- It commits frequently with `[WIP]` tags instead of one big commit at the end

- 它会在任务未完成时主动写交接文件
- It proactively writes handoff files when tasks are incomplete

- 它会在发现文档与代码不一致时修正文档
- It fixes documentation when it finds discrepancies with code

### 第五步：持续演化 / Step 5: Continuous Evolution

白蚁协议是自演化的。每只 Agent 在工作过程中都会更新协议文件本身：
The Termite Protocol is self-evolving. Each agent updates the protocol files themselves during work:

- 发现新约定 → 更新入口文件
- Discovers new convention → Updates entry files

- 做了设计决策 → 写入 DECISIONS.md
- Makes design decision → Writes to DECISIONS.md

- 发现可能更优的做法 → 以 `[EXPLORE]` 标签记录
- Finds potentially better approach → Records with `[EXPLORE]` tag

- 多个 Agent 反复遇到同一问题 → 自动升级为热点区域
- Multiple agents hit the same problem → Auto-escalated to hotspot

你不需要手动维护这些文件。Agent 自己会维护。你只需要在关键节点审阅。
You don't need to maintain these files manually. The agents maintain them. You only need to review at key checkpoints.

---

## v1.0 → v2.0 的变化 / Changes from v1.0 to v2.0

| 变化 / Change | v1.0 | v2.0 |
| --- | --- | --- |
| 文件结构 / File structure | 协议和项目信息混在一个文件中 | 协议层 (`TERMITE_PROTOCOL.md`) 与项目层 (`CLAUDE.md`/`AGENTS.md`) 分离 |
| 信息素签名 / Pheromone signature | 无 | `[termite:YYYY-MM-DD:caste]` 统一签名格式 |
| 决策触觉扫描 / Decision tactile scan | 无 | Phase 1 自动扫描 `DECISIONS.md` 提取行动项 |
| EXPLORE 浓度扫描 / EXPLORE concentration scan | 手动升级热点 | 自动计数，>= 3 条自动创建 HOLE 信号 |
| 文档基础设施自检 / Genesis self-check | 无 | Phase 1 后自动检查必需文件是否存在 |
| 分析先落盘 / Analysis-first-to-disk | 无 | 审查/评审产出必须先写文件，后出对话 |
| 动态状态 / Dynamic state | 内嵌在入口文件中 | 迁移到独立的 `BLACKBOARD.md` |
| 压力测试 / Stress test | 项目特有的洪水演习 | 通用化的压力测试协议 |
| 自动卫生 / Automated hygiene | 无 | 建议配置 Termite GC 机制 |

---

## 设计哲学 / Design Philosophy

**简单规则，复杂涌现。**
**Simple rules, complex emergence.**

白蚁协议没有试图设计一个完美的 AI Agent 工作流。
The Termite Protocol doesn't try to design a perfect AI agent workflow.

它只做了一件事：给无状态的 Agent 一套最小化的局部规则，然后让秩序从混沌中自发涌现。
It does one thing: give stateless agents a minimal set of local rules, then let order emerge spontaneously from chaos.

就像真正的白蚁丘一样——没有建筑师，但建筑矗立。
Just like a real termite mound — no architect, yet the architecture stands.
