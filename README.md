# 白蚁协议 (Termite Protocol)

**一套面向无状态 AI Agent 的跨会话协作框架**
**A cross-session collaboration framework for stateless AI agents**

> v3.0 "协议消融" — Protocol Dissolution
> 协议从"Agent 直接阅读的文档"转变为"Agent 感知的环境"。
> The protocol transforms from "a document agents read" into "an environment agents sense."

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

## 协议即环境 / Protocol as Environment

v3.0 的核心转变：协议从一份 Agent 必须阅读的长文档，消融为 Agent 到达时自动感知的环境基础设施。
The core shift of v3.0: the protocol dissolves from a long document agents must read into environment infrastructure that agents sense automatically upon arrival.

### BEFORE: v2 — Agent 阅读协议 / Agent reads protocol

```
Agent 启动 → 读取 TERMITE_PROTOCOL.md (28K tokens)
           → 读取 CLAUDE.md / AGENTS.md
           → 遵循规则
           → 上下文消耗 ~40%
```

### AFTER: v3 — 协议消融为环境 / Protocol dissolves into environment

```
Agent 启动 → field-arrive.sh 读取环境 + 协议
           → 计算 .birth 文件 (≤800 tokens)
           → Agent 读取 .birth
           → 开始工作
           → 上下文消耗 ~2%
```

### 关键洞察 / Key Insight

`TERMITE_PROTOCOL.md` 不再是"Agent 必须阅读的文档"，而是：
`TERMITE_PROTOCOL.md` is no longer "a document agents must read," but rather:

- **人类参考文档**：供人类理解完整协议逻辑
- **Human reference**: for humans to understand the full protocol logic

- **脚本配置源**：`field-arrive.sh` 从中提取 9 条语法规则 + 4 条安全网，压缩为 `.birth`
- **Script configuration source**: `field-arrive.sh` extracts 9 grammar rules + 4 safety nets, compresses into `.birth`

- **降级后备**：如果脚本不可用，Agent 仍可直接阅读协议（优雅降级）
- **Degradation fallback**: if scripts are unavailable, agents can still read the protocol directly (graceful degradation)

协议消融了，但秩序没有消失——它沉入了环境的基础设施层。
The protocol dissolves, but order does not vanish — it sinks into the infrastructure layer of the environment.

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
| 生成的 Agent 不携带协议 DNA | 协议传播：生成 Agent 系统时自动注入协议种子（TERMITE_SEED.md） |
| Generated agents lack protocol DNA | Protocol propagation: auto-inject protocol seed (TERMITE_SEED.md) when generating agent systems |

---

## 协议架构 / Protocol Architecture

### 文件结构 / File Structure

```
your-project/
  TERMITE_PROTOCOL.md   ← 人类参考 + 脚本配置源 / Human reference + script config source
  CLAUDE.md             ← Claude Code 入口 / Claude Code entry
  AGENTS.md             ← Codex/Gemini 入口 / Codex/Gemini entry
  TERMITE_SEED.md       ← 协议种子（注入生成的 Agent 系统）/ Protocol seed (injected into generated agent systems)
  BLACKBOARD.md         ← 动态状态（健康、信号、热点）/ Dynamic state (health, signals, hotspots)
  DECISIONS.md          ← 设计决策记录 / Design decision records
  WIP.md                ← 会话间交接 / Cross-session handoff
  scripts/
    field-lib.sh        ← 共享函数库 / Shared function library
    field-arrive.sh     ← 到达脚本：计算 .birth 文件 / Arrival: computes .birth file
    field-cycle.sh      ← 心跳循环 / Heartbeat cycle
    field-deposit.sh    ← 信息素沉积 / Pheromone deposit
    field-decay.sh      ← 信息素衰减 / Pheromone decay
    field-drain.sh      ← 信息素排水 / Pheromone drain
    field-pulse.sh      ← 场脉冲 / Field pulse
    field-claim.sh      ← 任务认领 / Task claim
    hooks/
      install.sh        ← 安装 git hooks / Install git hooks
      pre-commit        ← 提交前检查 / Pre-commit checks
      pre-push          ← 推送前检查 / Pre-push checks
      prepare-commit-msg← 提交信息自动签名 / Auto-sign commit messages
      post-commit       ← 提交后信息素沉积 / Post-commit pheromone deposit
  signals/              ← YAML 信号 schema / YAML signal schema
```

### 协议层级 / Protocol Layers

| 层级 / Layer | 文件 / Files | 内容 / Content |
| --- | --- | --- |
| 协议源层 | `TERMITE_PROTOCOL.md` | 完整协议文本（人类参考 + 脚本配置源），4 部分结构 |
| Protocol Source | | Full protocol text (human reference + script config source), 4-Part structure |
| 场脚本层 | `scripts/` | field-arrive.sh 读取协议源 + 环境状态，计算 ≤800 token `.birth` 文件 |
| Field Scripts | | field-arrive.sh reads protocol source + environment state, computes ≤800 token `.birth` file |
| Agent 入口层 | `CLAUDE.md` / `AGENTS.md` + `.birth` | Agent 实际阅读的内容：入口文件 + .birth（极低上下文成本） |
| Agent Entry | | What agents actually read: entry file + .birth (minimal context cost) |

### 协议 4 部分结构 / Protocol 4-Part Structure

`TERMITE_PROTOCOL.md` v3.0 采用新的 4 部分结构：
`TERMITE_PROTOCOL.md` v3.0 uses a new 4-Part structure:

| Part | 内容 / Content | 面向 / Audience |
| --- | --- | --- |
| **I: Grammar** | 9 条语法规则 + 4 条安全网 — 协议的最小内核 | field-arrive.sh 提取 → .birth / Extracted by field-arrive.sh → .birth |
| **II: Environment Config** | 种姓、信号 schema、降级矩阵、脚本配置 | field-arrive.sh 读取 / Read by field-arrive.sh |
| **III: Human Reference** | 完整设计理由、三丘模型、免疫系统、触发解释器 | 人类阅读 / Human reading |
| **IV: Appendices** | 模板、快速参考卡、Git Worktree 工作流 | 按需查阅 / On-demand reference |

### 上下文预算对比 / Context Budget Comparison

| 配置 / Configuration | Agent 上下文消耗 / Agent Context Cost | 说明 / Notes |
| --- | --- | --- |
| v2（直接阅读协议）| ~40% | Agent 阅读完整 TERMITE_PROTOCOL.md |
| v2 (read protocol directly) | | Agent reads full TERMITE_PROTOCOL.md |
| v3 + 脚本 | ~2% | field-arrive.sh 计算 .birth，Agent 仅读 .birth |
| v3 with scripts | | field-arrive.sh computes .birth, agent reads .birth only |
| v3 无脚本（入口文件含精简规则）| ~5% | Agent 读入口文件中的内联规则摘要 |
| v3 without scripts | | Agent reads inline rule summary in entry file |
| v3 极简（无协议文件）| ~1% | 仅入口文件，无协议加载 |
| v3 nothing | | Entry file only, no protocol loaded |

---

## 怎么使用？ / How to Use?

### 第一步：安装协议 / Step 1: Install the Protocol

**方法 A：一键安装脚本（推荐）/ Method A: One-click Install (Recommended)**

Clone 白蚁协议仓库后，在你的项目目录中运行安装脚本：
After cloning the Termite Protocol repo, run the install script in your project directory:

```bash
# Clone 白蚁协议仓库 / Clone the Termite Protocol repo
git clone https://github.com/<owner>/白蚁协议.git

# 在你的项目中运行安装 / Run install in your project
cd your-project
bash /path/to/白蚁协议/install.sh
```

或通过远程一键安装（需配置 `TERMITE_REPO_URL`）：
Or via remote one-click install (requires `TERMITE_REPO_URL`):

```bash
cd your-project
curl -fsSL <github-raw-url>/install.sh | bash
```

升级协议（保留你填写的 CLAUDE.md / AGENTS.md）：
Upgrade the protocol (preserves your customized CLAUDE.md / AGENTS.md):

```bash
bash /path/to/白蚁协议/install.sh --upgrade
```

安装脚本会自动完成：复制所有模板文件、创建 signals/ 目录结构、安装 git hooks、更新 .gitignore。
The install script automatically: copies all template files, creates signals/ directory structure, installs git hooks, updates .gitignore.

> 详细选项：`bash install.sh --help`
> Full options: `bash install.sh --help`

**方法 B：手动复制 / Method B: Manual Copy**

```
templates/TERMITE_PROTOCOL.md  → 复制到项目根目录 / Copy to project root
templates/CLAUDE.md            → 复制为项目根目录的 CLAUDE.md / Copy as CLAUDE.md in project root
templates/AGENTS.md            → 复制为项目根目录的 AGENTS.md / Copy as AGENTS.md in project root
templates/scripts/             → 复制到项目根目录的 scripts/ / Copy to project root scripts/
templates/signals/             → 复制到项目根目录的 signals/ / Copy to project root signals/
```

手动安装 Git Hooks：
Install Git Hooks manually:

```bash
./scripts/hooks/install.sh
```

### 第二步：填写项目信息 / Step 2: Fill in Project Info

入口文件（`CLAUDE.md` / `AGENTS.md`）中用 `<!-- 注释 -->` 标记了所有需要你填写的位置：
The entry files (`CLAUDE.md` / `AGENTS.md`) mark all sections you need to fill with `<!-- comments -->`:

1. **项目概述**：一句话描述你的项目是什么
1. **Project overview**: One-sentence description of what your project is

2. **技术栈**：前端、后端、数据库、主要框架
2. **Tech stack**: Frontend, backend, database, key frameworks

3. **路由表**：任务关键词 → 局部黑板路径
3. **Route table**: Task keywords → local blackboard paths

4. **项目特有规则**：你的项目独有的触发-动作规则
4. **Project-specific rules**: Trigger-action rules unique to your project

5. **验证清单**：你的构建和测试命令
5. **Verification checklist**: Your build and test commands

### 第三步：让 Agent 开始工作 / Step 3: Let the Agent Work

Agent 到达时的流程：
The flow when an agent arrives:

```
Agent 启动 → field-arrive.sh 自动执行
           → 读取 TERMITE_PROTOCOL.md + 环境状态（git/BLACKBOARD/WIP/ALARM）
           → 计算 .birth 文件（≤800 tokens，含语法规则 + 种姓 + 当前状态摘要）
           → Agent 读取 .birth → 立即开始工作
```

你会观察到 Agent 的行为变化：
You'll notice behavioral changes in the agent:

- 它会在开始任务前自动感知环境状态（通过 `.birth` 文件）
- It automatically senses environment state before starting tasks (via `.birth` file)

- 它会频繁 commit 带签名标记，git hooks 自动处理签名和安全检查
- It commits frequently with signatures, git hooks auto-handle signing and safety checks

- 它会在任务未完成时主动写交接文件
- It proactively writes handoff files when tasks are incomplete

- 它会在发现文档与代码不一致时修正文档
- It fixes documentation when it finds discrepancies with code

### 第四步：持续演化 / Step 4: Continuous Evolution

白蚁协议是自演化的。v3.0 引入了观察 → 规则自动晋升机制：
The Termite Protocol is self-evolving. v3.0 introduces an observation → rule auto-promotion mechanism:

- 发现新约定 → 记录为观察（observation）→ 多次验证后自动晋升为规则
- Discovers new convention → recorded as observation → auto-promoted to rule after repeated validation

- 做了设计决策 → 写入 DECISIONS.md
- Makes design decision → writes to DECISIONS.md

- `field-decay.sh` 自动衰减过期信号，`field-cycle.sh` 维护心跳循环
- `field-decay.sh` auto-decays expired signals, `field-cycle.sh` maintains heartbeat cycle

- 多个 Agent 反复遇到同一问题 → 信息素浓度叠加 → 自动升级为规则
- Multiple agents hit the same problem → pheromone concentration stacking → auto-escalated to rule

- git hooks 自动化代谢过程（签名、安全检查、信息素沉积）
- Git hooks automate metabolism processes (signing, safety checks, pheromone deposit)

你不需要手动维护这些文件。Agent 和脚本自己会维护。你只需要在关键节点审阅。
You don't need to maintain these files manually. Agents and scripts maintain them. You only need to review at key checkpoints.

---

## 场基础设施 / Field Infrastructure

场基础设施是 v3.0 "协议消融"的核心实现层。所有脚本位于 `scripts/` 目录。
Field infrastructure is the core implementation layer of v3.0 "Protocol Dissolution." All scripts are in the `scripts/` directory.

### 场脚本清单 / Field Script Inventory

| 脚本 / Script | 用途 / Purpose |
| --- | --- |
| `field-lib.sh` | 共享函数库：路径解析、日志、YAML 解析、信号读写等基础函数 |
| | Shared function library: path resolution, logging, YAML parsing, signal read/write |
| `field-arrive.sh` | 到达脚本：读取协议 + 环境状态，计算 ≤800 token `.birth` 文件 |
| | Arrival script: reads protocol + environment state, computes ≤800 token `.birth` file |
| `field-cycle.sh` | 心跳循环：执行 Sense → Act → Notice → Deposit 单次循环 |
| | Heartbeat cycle: executes one Sense → Act → Notice → Deposit cycle |
| `field-deposit.sh` | 信息素沉积：将观察/决策/状态写入 YAML 信号文件 |
| | Pheromone deposit: writes observations/decisions/state to YAML signal files |
| `field-decay.sh` | 信息素衰减：清理过期信号，维持信息新鲜度 |
| | Pheromone decay: cleans expired signals, maintains information freshness |
| `field-drain.sh` | 信息素排水：批量清除指定类型的信号 |
| | Pheromone drain: bulk-clears signals of a given type |
| `field-pulse.sh` | 场脉冲：生成项目状态快照（构建/测试/git 状态） |
| | Field pulse: generates project status snapshot (build/test/git status) |
| `field-claim.sh` | 任务认领：原子化的任务锁定/释放/查询机制 |
| | Task claim: atomic task lock/release/query mechanism |

### Git Hooks 清单 / Git Hooks Inventory

| Hook | 用途 / Purpose |
| --- | --- |
| `hooks/install.sh` | 安装所有 git hooks 到 `.git/hooks/` |
| | Installs all git hooks to `.git/hooks/` |
| `hooks/pre-commit` | 提交前检查：防止提交敏感文件、验证文件大小、检查冲突标记 |
| | Pre-commit: prevents committing sensitive files, validates file sizes, checks conflict markers |
| `hooks/pre-push` | 推送前检查：验证分支保护规则、运行安全扫描 |
| | Pre-push: validates branch protection rules, runs security scan |
| `hooks/prepare-commit-msg` | 自动为提交信息添加 `[termite:YYYY-MM-DD:caste]` 签名 |
| | Auto-appends `[termite:YYYY-MM-DD:caste]` signature to commit messages |
| `hooks/post-commit` | 提交后自动触发信息素沉积（调用 field-deposit.sh） |
| | Post-commit auto-triggers pheromone deposit (calls field-deposit.sh) |

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
| **v3.0** | 协议消融：协议从"Agent 直接阅读的文档"转变为"人类参考 + 脚本配置源"；field-arrive.sh 计算 ≤800 token .birth 文件；8 条语法规则 + 4 条安全网替代叙事心跳；观察→规则自动晋升机制；YAML 信号 schema；git hooks 自动化（签名/代谢/安全）；优雅降级矩阵（5 层） |
| | Protocol Dissolution: protocol transforms from "document agents read" to "human reference + script config source"; field-arrive.sh computes ≤800 token .birth file; 8 grammar rules + 4 safety nets replace narrative heartbeat; observation → rule auto-promotion; YAML signal schema; git hooks automation (signing/metabolism/safety); graceful degradation matrix (5 levels) |
| **v3.1** | 协议元反馈回路：disputed_count 规则争议机制、predecessor_useful 交接质量追踪、审计包导出 |
| | Protocol meta-feedback loop: disputed_count rule dispute mechanism, predecessor_useful handoff quality tracking, audit export |
| **v3.2** | 协议传播：规则 9（PROPAGATE）— 生成 Agent 系统时注入协议种子（TERMITE_SEED.md）；传播层级（Full/Core/Micro/None）；跨蚁丘信号交换；种子版本追踪；免疫检查 IC-5 |
| | Protocol Propagation: Rule 9 (PROPAGATE) — inject protocol seed when generating agent systems (TERMITE_SEED.md); propagation tiers (Full/Core/Micro/None); cross-colony signal exchange; seed version tracking; immune check IC-5 |
| **v3.3-v3.5** | DB 架构与涌现增强：SQLite WAL-mode 替代文件锁；模糊聚类降低规则涌现门槛；自动感知蚁丘生命周期；Shepherd 效应（强模型信息素引导弱模型）。 |
| | DB architecture & Emergence strengthening: SQLite WAL-mode replaces file locks; fuzzy clustering lowers rule emergence threshold; auto-sense colony lifecycle; Shepherd Effect (strong model pheromones guide weak models). |
| **v4.0** | 优势参与机制 (Strength-Based Participation)：协议根据参与方能力自动生成差异化的 `.birth`（执行/判断/方向），让弱模型、强模型和人类各司其职，解决异构多模型并发瓶颈。 |
| | Strength-Based Participation: auto-generates differentiated `.birth` (execution/judgment/direction) based on participant capability, letting weak models, strong models, and humans do what they do best, solving heterogeneous multi-model concurrency bottlenecks. |

---

## 平台支持 / Platform Support

白蚁协议通过入口文件适配不同的 AI 平台：
The Termite Protocol adapts to different AI platforms through entry files:

| 平台 / Platform | 入口文件 / Entry File | 特点 / Characteristics |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` | 交互式，field-arrive.sh 自动计算 .birth，心跳内核自动加载 |
| | | Interactive, field-arrive.sh auto-computes .birth, heartbeat kernel auto-loaded |
| OpenAI Codex | `AGENTS.md` | 非交互式，自启动黑板协议，Claim/Verify/Release 循环 |
| | | Non-interactive, self-boot blackboard protocol, Claim/Verify/Release cycle |
| Google Gemini | `AGENTS.md` | 同 Codex / Same as Codex |
| Cline | `.clinerules` | 心跳内核自动复制到平台规则文件 |
| Roo | `.roo/rules` | Heartbeat kernel auto-copied to platform rule files |
| Cursor | `.cursorrules` | |
| Windsurf | `.windsurfrules` | |
| GitHub Copilot | `.github/copilot-instructions.md` | |

> **注意 / Note**: `field-arrive.sh` 目前完整支持 Claude Code 和 AGENTS.md 平台。其他平台可通过入口文件内联规则摘要实现优雅降级（上下文消耗 ~5%）。
> `field-arrive.sh` currently has full support for Claude Code and AGENTS.md platforms. Other platforms gracefully degrade via inline rule summaries in entry files (context cost ~5%).

---

## 设计哲学 / Design Philosophy

**简单规则，复杂涌现。协议消融为环境。**
**Simple rules, complex emergence. Protocol dissolves into environment.**

白蚁协议没有试图设计一个完美的 AI Agent 工作流。
The Termite Protocol doesn't try to design a perfect AI agent workflow.

它只做了一件事：给无状态的 Agent 一套最小化的局部规则，然后让秩序从混沌中自发涌现。
It does one thing: give stateless agents a minimal set of local rules, then let order emerge spontaneously from chaos.

v3.0 更进一步：协议本身消融为环境基础设施。Agent 不再需要"阅读协议"，正如白蚁不需要"阅读蚁丘蓝图"——它只需要感知脚下的信息素浓度。
v3.0 goes further: the protocol itself dissolves into environment infrastructure. Agents no longer need to "read the protocol," just as termites don't need to "read the colony blueprint" — they only need to sense the pheromone concentration underfoot.

就像真正的白蚁丘一样——没有建筑师，但建筑矗立。
Just like a real termite mound — no architect, yet the architecture stands.

**"无蚁后"原则：** 协议中没有任何角色拥有特殊的审批权。决策通过信息素浓度叠加涌现共识——不是某个角色"审批"，而是足够多的白蚁在同一方向沉积信息素。人类是同丘成员，不是外部管理者。
**"No Queen" principle:** No role in the protocol has special approval authority. Decisions emerge through pheromone concentration stacking — not "approval" by a role, but enough termites depositing pheromones in the same direction. Humans are colony members, not external managers.

---

## License

MIT License. See [LICENSE](LICENSE).
