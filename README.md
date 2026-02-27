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
| 多个 Agent 改同一个文件冲突 | Lock-File 并发控制 + git worktree 隔离 |
| Multiple agents conflict on same file | Lock-File concurrency control + git worktree isolation |
| 过时的文档误导 Agent | 信息素保鲜期：超过 7 天的状态视为"未知"，强制重新验证 |
| Stale docs mislead agents | Pheromone expiration: status older than 7 days is treated as "unknown", forcing re-verification |
| 同一个坑被反复踩 | 信息素浓度叠加：2+ 只 Agent 报告同一问题 → 升级为热点区域 |
| Same pitfall hit repeatedly | Pheromone concentration: 2+ agents report the same issue → escalated to hotspot |
| 新白蚁不遵守协议 | 蚁群免疫系统：到达审计、合规评分、自我修复、免疫记忆 |
| New agents don't follow protocol | Colony immune system: arrival audit, compliance scoring, self-repair, immune memory |

---

## 协议架构 / Protocol Architecture

### 文件结构 / File Structure

```
your-project/
  TERMITE_PROTOCOL.md   ← 通用协议（所有 Agent 共享）/ Universal protocol (shared by all agents)
  CLAUDE.md             ← Claude Code 入口（项目特有信息 + 心跳内核）/ Claude Code entry (project-specific + heartbeat kernel)
  AGENTS.md             ← Codex/Gemini 入口（项目特有信息 + 自启动协议）/ Codex/Gemini entry (project-specific + self-boot protocol)
  BLACKBOARD.md         ← 动态状态（健康、信号、热点）/ Dynamic state (health, signals, hotspots)
  DECISIONS.md          ← 设计决策记录 / Design decision records
  WIP.md                ← 会话间交接 / Cross-session handoff
```

### 协议层级 / Protocol Layers

| 层级 / Layer | 文件 / File | 内容 / Content |
| --- | --- | --- |
| 通用协议层 | `TERMITE_PROTOCOL.md` | §0-§13 + 附录 A-F：种姓、生命周期、信息素、触发-动作规则、免疫系统等 |
| Universal protocol | | §0-§13 + Appendices A-F: castes, lifecycle, pheromones, trigger-action rules, immune system, etc. |
| 平台入口层 | `CLAUDE.md` / `AGENTS.md` | 心跳内核 + 项目特有信息（概述、技术栈、路由表、触发规则、验证命令） |
| Platform entry | | Heartbeat kernel + project-specific info (overview, tech stack, route table, triggers, verification) |
| 动态状态层 | `BLACKBOARD.md` | 蚁丘健康、活跃信号、认领表、热点区域、已知限制 |
| Dynamic state | | Colony health, active signals, claims, hotspots, known limitations |

### 协议核心模块 / Core Protocol Modules

`TERMITE_PROTOCOL.md` 包含以下 § 编号的核心模块：
`TERMITE_PROTOCOL.md` contains the following §-numbered core modules:

| § | 模块 / Module | 说明 / Description |
| --- | --- | --- |
| §0 | 核心 + 启动 + 通道校准 | 三丘哲学、心跳内核引导、通道特性校准（高带宽/深共振） |
| | Core + Bootstrap + Channel Calibration | Three-colony philosophy, heartbeat kernel bootstrap, channel calibration |
| §1 | 触发解释器 | 8 种触发变体的决策树（bootstrap/crisis/directed/continuation/genesis/restricted/self-boot/autonomous） |
| | Trigger Interpreter | Decision tree for 8 trigger variants |
| §2 | 心跳引擎 | Sense→Act→Notice→Deposit 循环，4 尺度自相似（原子/会话/冲刺/项目） |
| | Heartbeat Engine | Sense→Act→Notice→Deposit cycle, self-similar at 4 scales |
| §3 | 种姓系统 v2 | 探路蚁/工蚁/兵蚁/育幼蚁的权限和转换规则 |
| | Caste System v2 | Scout/Worker/Soldier/Nurse permissions and transition rules |
| §4 | 生命周期 | Phase 0-6 + Lock-File 并发控制机制 |
| | Lifecycle | Phase 0-6 + Lock-File concurrency control |
| §5 | 自检矩阵 | 5 级严重度的诊断检查项（INFO/WARN/ERROR/CRITICAL/FATAL） |
| | Self-Check Matrix | Diagnostic checks at 5 severity levels |
| §6 | 信息素系统 | EXPLORE 生命周期、浓度叠加、强制关闭规则 |
| | Pheromone System | EXPLORE lifecycle, concentration stacking, forced closure rules |
| §7 | 感知与探针 | 环境探测机制（测试/日志/文档漂移检测） |
| | Sensing & Probes | Environmental probing mechanisms |
| §8 | 规则引擎 | 全局触发-动作规则表 |
| | Rules Engine | Global trigger-action rule table |
| §9 | 通信协议 | 蚁丘内信息传递规范 |
| | Communication Protocols | Colony information passing specifications |
| §10 | 三丘模型 | 开发丘·产品丘·客户丘的共生演化框架 |
| | Three-Colony Model | Dev Colony · Product Colony · Customer Colony symbiosis framework |
| §11 | 特殊协议 | 非交互式启动、平台检测表、优雅降级矩阵 |
| | Special Protocols | Non-interactive boot, platform detection, graceful degradation matrix |
| §12 | 验证 | 改动类型→验证方式的通用清单 |
| | Verification | Change type → verification method universal checklist |
| §13 | 蚁群免疫系统 | 被动免疫（到达审计/合规评分）、适应层（合规梯度/行为信息素）、主动防御（文件保护/恶意模式检测） |
| | Colony Immune System | Passive immunity (arrival audit/compliance scoring), adaptive layer (compliance tiers/behavioral pheromone), active defense (file protection/malicious pattern detection) |

### 附录 / Appendices

| 附录 / Appendix | 内容 / Content |
| --- | --- |
| A | 快速参考卡（种姓判定、自检严重度、信号权重一页速查） |
| | Quick reference card (caste determination, self-check severity, signal weights) |
| B | BLACKBOARD.md 模板 |
| | BLACKBOARD.md template |
| C | 建议的场基础设施脚本清单 |
| | Suggested field infrastructure script inventory |
| D | WIP.md 模板 |
| | WIP.md template |
| E | Git Worktree 工作流 |
| | Git Worktree workflow |
| F | 心跳内核（可嵌入入口文件的自引导代码） |
| | Heartbeat Kernel (self-bootstrapping code embeddable in entry files) |

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

6. **分支治理**（可选）：如果使用多分支流水线，取消模板中的注释并填写分支名
6. **Branch governance** (optional): If using a multi-branch pipeline, uncomment the template section and fill in branch names

### 第三步：创建动态状态文件 / Step 3: Create Dynamic State Files

```
your-project/
  TERMITE_PROTOCOL.md    ← 通用协议 / Universal protocol
  CLAUDE.md              ← Claude Code 入口 / Claude Code entry
  AGENTS.md              ← Codex/Gemini 入口 / Codex/Gemini entry
  BLACKBOARD.md          ← 根目录动态状态（模板在 TERMITE_PROTOCOL.md 附录 B）/ Root dynamic state (template in Appendix B)
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

- 它会用 `[termite:YYYY-MM-DD:caste]` 签名标记自己的 commit
- It marks its commits with `[termite:YYYY-MM-DD:caste]` signatures

### 第五步：持续演化 / Step 5: Continuous Evolution

白蚁协议是自演化的。每只 Agent 在工作过程中都会更新协议文件本身：
The Termite Protocol is self-evolving. Each agent updates the protocol files themselves during work:

- 发现新约定 → 更新入口文件的触发-动作规则表
- Discovers new convention → Updates entry file trigger-action rule table

- 做了设计决策 → 写入 DECISIONS.md
- Makes design decision → Writes to DECISIONS.md

- 发现可能更优的做法 → 以 `[EXPLORE]` 标签记录（14 天内自动关闭或升级）
- Finds potentially better approach → Records with `[EXPLORE]` tag (auto-closed or escalated within 14 days)

- 多个 Agent 反复遇到同一问题 → 自动升级为热点区域
- Multiple agents hit the same problem → Auto-escalated to hotspot

- 免疫系统检测到违规模式 → 自动记录并升级应对策略
- Immune system detects violation patterns → Auto-recorded and response strategy escalated

你不需要手动维护这些文件。Agent 自己会维护。你只需要在关键节点审阅。
You don't need to maintain these files manually. The agents maintain them. You only need to review at key checkpoints.

---

## 协议演化史 / Protocol Evolution History

| 版本 / Version | 关键变化 / Key Changes |
| --- | --- |
| **v1.0** | 初始版本：种姓系统、Phase 0-6 生命周期、信息素规则、ALARM 机制 |
| | Initial: caste system, Phase 0-6 lifecycle, pheromone rules, ALARM mechanism |
| **v2.0** | 协议与项目信息分离架构；信息素签名格式；决策触觉扫描；EXPLORE 浓度扫描；Genesis 自检；分析先落盘规则；动态状态迁移到 BLACKBOARD.md |
| | Protocol-project separation; pheromone signatures; decision tactile scan; EXPLORE concentration scan; Genesis self-check; analysis-first-to-disk; dynamic state moved to BLACKBOARD.md |
| **v2.1** | Boot Sequence 启动序列：心跳内核 v6.0 嵌入入口文件，Agent 自初始化 + 种姓检测 + 动作偏向 |
| | Boot Sequence: heartbeat kernel v6.0 embedded in entry files, agent self-initialization + caste detection + action bias |
| **当前 / Current** | §编号模块化架构；触发解释器（8 种触发变体）；心跳引擎（4 尺度自相似循环）；通道特性校准；Lock-File 并发控制；蚁群免疫系统（被动/适应/主动三层）；三丘共生模型；优雅降级矩阵；平台检测表（8 平台）；EXPLORE 完整生命周期（14 天强制关闭）；场基础设施工具链 |
| | §-numbered modular architecture; trigger interpreter (8 variants); heartbeat engine (4-scale self-similar cycle); channel calibration; Lock-File concurrency; colony immune system (passive/adaptive/active); three-colony model; graceful degradation matrix; platform detection (8 platforms); EXPLORE full lifecycle (14-day forced closure); field infrastructure toolchain |

---

## 平台支持 / Platform Support

白蚁协议通过入口文件适配不同的 AI 平台：
The Termite Protocol adapts to different AI platforms through entry files:

| 平台 / Platform | 入口文件 / Entry File | 特点 / Characteristics |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` | 交互式，Boot Sequence 快速启动，心跳内核自动加载 |
| | | Interactive, Boot Sequence quick start, heartbeat kernel auto-loaded |
| OpenAI Codex | `AGENTS.md` | 非交互式，自启动黑板协议，Claim/Verify/Release 循环 |
| | | Non-interactive, self-boot blackboard protocol, Claim/Verify/Release cycle |
| Google Gemini | `AGENTS.md` | 同 Codex / Same as Codex |
| Cline | `.clinerules` | 心跳内核自动复制到平台规则文件 |
| Roo | `.roo/rules` | Heartbeat kernel auto-copied to platform rule files |
| Cursor | `.cursorrules` | |
| Windsurf | `.windsurfrules` | |
| GitHub Copilot | `.github/copilot-instructions.md` | |

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

**"无蚁后"原则：** 协议中没有任何角色拥有特殊的审批权。决策通过 EXPLORE 浓度叠加涌现共识——不是某个角色"审批"，而是足够多的白蚁在同一方向沉积信息素。人类是同丘成员，不是外部管理者。
**"No Queen" principle:** No role in the protocol has special approval authority. Decisions emerge through EXPLORE concentration stacking — not "approval" by a role, but enough termites depositing pheromones in the same direction. Humans are colony members, not external managers.

---

## License

MIT License. See [LICENSE](LICENSE).
