# TouchCLI 审计分析 — 首个 Codex 牧羊 + Haiku 群体实验

**审计包**: `audit-packages/touchcli/2026-03-02/`
**登记 ID**: A-005
**日期**: 2026-03-02
**分析师**: Protocol Nurse (Claude Opus)

## 实验配置

| 参数 | 值 |
|------|-----|
| 创世模型 | Codex |
| 运行时模型 | 1 Codex + 2 Claude Haiku (并行) |
| 触发方式 | 白蚁协议心跳输入 |
| 运行时长 | ~6 小时 (01:07 → 07:07 UTC+8) |
| 项目类型 | SaaS 后端+前端 (Python FastAPI + Go Gateway + React) |

## 核心指标

| 指标 | touchcli | ReactiveArmor (A-003) | OAE (A-001) | 评价 |
|------|----------|----------------------|-------------|------|
| total_commits | **130** | 128 | 54 | 最高产量 |
| signed_commits | 15 | 128 | 3 | 仅 Codex 阶段签名 |
| signature_ratio_last_50 | 0.00 | 0.00 | 0.00 | 三项目一致 |
| **handoff_quality** | **0.99** | 0.00 | 1.00 | **与 OAE 持平，碾压 ReactiveArmor** |
| pheromone_snapshots | **77** | 7 | 44 | 最高，但含大量空转 |
| pending_observations | **28** | 16 | 74 | 质量远超 ReactiveArmor |
| active_rules | **1** | 0 | 0 | **首个弱模型蚁丘规则涌现** |
| observation degenerate rate | **3.6%** (1/28) | 64% (9/14) | 未评 | **18x 改善** |

## 关键发现

### 发现 1: Codex 牧羊人效应 (Shepherd Effect) — **协议最重大发现**

touchcli 的 "1 Codex + 2 Haiku" 配置与 ReactiveArmor 的 "Codex 创世 + 2 Haiku 独立运行" 产生了**天壤之别**的结果：

| 行为维度 | touchcli (Codex 牧羊) | ReactiveArmor (Haiku 独立) |
|---------|----------------------|---------------------------|
| 观察质量 | 27/28 有效 (96.4%) | 5/14 有效 (35.7%) |
| 交接评估 | 69/70 评估为 true (99%) | 0/7 评估为 true (0%) |
| 规则涌现 | R-001 涌现 | 0 规则 |
| 信号管理 | S-001→S-006 有序推进 | S-001→S-025 推进但无闭环 |
| 阶段规划 | Phase 1→3 完整交付 | 功能堆叠无阶段 |

**机制分析**：Codex 在创世和牧羊阶段建立了高质量的 pattern/context/detail 模板。后续 Haiku 在信息素链中看到这些示例后，**模仿式地**维持了质量标准。这不是 Haiku "理解"了协议，而是通过 pheromone chain 的**上下文学习 (in-context learning)** 实现的行为传导。

**协议启示**：.birth 不需要编码所有判断力行为——只需要确保信息素链中有高质量示例供弱模型模仿。这是对 F-009c 的**补充而非推翻**：弱模型确实无法自主产生判断力行为，但可以通过强模型留下的"行为模板"来模仿。

### 发现 2: 空转心跳问题 (Idle Heartbeat Spinning) — **新 Finding**

77 个信息素记录中，**~50 个 (65%) 是纯空转心跳**：

```
"Heartbeat monitoring pass: zero actionable queue"
"Monitoring heartbeat: zero actionable queue"
"Scout monitoring pass: zero actionable queue"
```

从 ~20:20 到 23:11 UTC（近 3 小时），agents 持续空转，每 1-3 分钟沉积一次"无事可做"的信息素。这意味着：

- **计算浪费**：3 个 agent × 3 小时 = 9 agent-hours 的纯空转
- **信息素污染**：50 条无信息量的 pheromone 稀释了有价值的交接信息
- **predecessor_useful 虚高**：空转 agent 对前任的"zero actionable queue"评估为 true，膨胀了 useful_ratio

**根因**：协议缺少"信号耗尽 → 休眠/终止"机制。field-cycle.sh 无条件循环，agent 在所有信号 completed 后仍持续执行 sense→act→deposit。

### 发现 3: 签名格式的第三种变体

| 项目 | 签名格式 | 合规性 |
|------|---------|--------|
| OAE (Codex) | 无签名 (旧安装) | 不合规 — hooks 未安装 |
| ReactiveArmor (Haiku) | "Agent X" 命名 | 不合规 — 格式完全偏离 |
| **touchcli (Codex 阶段)** | `[termite:2026-03-02:scout]` | **合规** |
| **touchcli (Haiku 阶段)** | "Worker:", "Scout:", "🦟 Pheromone:" 前缀 | **不合规但有进步** |

touchcli Haiku 的签名失败是一种**"理解了角色但不知道格式"**的中间状态——它知道自己是 Worker 或 Scout（写在 commit message 前缀中），但不知道应该放在 `[termite:...]` 格式中。这比 ReactiveArmor 的 "Agent X" 有本质进步，进一步证明了牧羊人效应。

### 发现 4: 规则涌现成功但受限

R-001 "Foundation Genesis Verified" 从 5 个 Scout 观察涌现——这是**首次在有弱模型参与的蚁丘中观察到规则涌现**。

但需要注意：
- 涌现发生在 01:21 UTC+8（创世早期），很可能是 **Codex 执行的**
- R-001 的 action 被后续 agent 执行了（S-001 archived per R-001 threshold）
- 说明弱模型可以**执行**规则 action，但不能**创造**规则

这精化了 W-004 的结论：规则涌现是 T2 行为（需强模型），但规则执行是 T0 行为（弱模型也能做）。

### 发现 5: 项目交付质量高

touchcli 在 ~6 小时内实现了：
- Phase 1: 数据基础 — PostgreSQL (11 tables), REST API (11 endpoints), WebSocket (6 frame types), Redis (7 namespaces)
- Phase 2: 后端基础设施 — FastAPI scaffold, Go Gateway, CORS hardening, LangGraph agent framework
- Phase 3: 前端 — React/Vite app, auth, WebSocket integration, conversation UI, CRM dashboard, CI/CD pipeline, deployment scripts
- 性能 SLA: HTTP/WebSocket latency probes + threshold gates
- i18n: locale resolver, Accept-Language middleware, Alembic migration
- 部署: Docker containerization, database management scripts

这是三个审计蚁丘中**交付最完整的项目**，从空 repo 到可部署 MVP。

### 发现 6: 观察中的脚本修改

O-20260302033955-6666 记录了 agent 修改了 `field-arrive.sh`, `field-pulse.sh`, `field-lib.sh`——将 completed/done 信号排除出活跃集。这是 agent 对协议脚本的**本地补丁**，说明 field-arrive.sh 的活跃信号过滤逻辑有缺陷（completed 信号仍出现在 top work items 中）。

## 跨蚁丘模式比对（4 蚁丘）

| 维度 | OAE (Codex×2) | ReactiveArmor (Haiku×2) | touchcli (Codex+Haiku×2) | 结论 |
|------|-------------|----------------------|-------------------------|------|
| 核心循环 | 正常 | 正常 | 正常 | **所有配置都能执行** |
| 观察质量 | 未评 | 35.7% 有效 | 96.4% 有效 | **Codex 牧羊决定质量** |
| 交接评估 | 100% | 0% | 99% | **Codex 牧羊决定评估** |
| 规则涌现 | 0 | 0 | 1 (R-001) | **需要 Codex 在场** |
| 空转问题 | 未观察到 | 未观察到 | **65% 空转** | **新发现** |
| 签名合规 | 不合规 (hooks) | 不合规 (格式) | 部分合规 | **渐进改善** |

## 信号生态深度分析

### 信号类型与颗粒度

touchcli 产生了 6 个信号（S-001 → S-006）+ 1 个自发涌现规则 R-001：

| ID | 类型 | 颗粒度 | 产生方式 | 最终状态 |
|-----|------|--------|---------|---------|
| S-001 | EXPLORE | 项目级 | 创世自动生成 | archived (w=17) |
| S-002 | IMPLEMENT | 阶段级 (Phase 1, 4 子任务) | R-001 规则触发 | completed |
| S-003 | HOLE | 阶段级 (Phase 2 规划+脚手架) | Scout 战略评审 | completed |
| S-004 | EXPLORE | 研究级 (i18n 范围界定) | Scout 决策跟进 | 关闭 → spawn S-006 |
| S-005 | PROBE | 任务级 (性能基线) | Scout 决策跟进 | completed |
| S-006 | HOLE | 任务级 (i18n 实现) | S-004 闭环时 spawn | completed |

颗粒度呈三层分布：

- **项目级**（S-001）：探索整个仓库。创世自动生成，作为 Scout 初始认知任务。颗粒度最粗。
- **阶段级**（S-002, S-003）：对应 Phase 1 / Phase 2。S-002 的 `next` 字段覆盖了 4 个独立设计文档（schema, API, WebSocket, Redis），交付量 1540 行。**颗粒度偏粗**——一个 IMPLEMENT 信号承载了 4 个可独立验证的交付物。
- **任务级**（S-005, S-006）：对应单个可验证的实现任务。S-005 = benchmark 脚本+gate，S-006 = locale resolver 实现。这是**最合适的颗粒度**。

**颗粒度不均匀问题**：S-002 一个信号做了 4 个设计文档（1540 行），S-005 一个信号只做了 1 个 benchmark 脚本。协议没有信号拆分指导，agent 自主判断粒度，结果取决于 agent 能力和当时的上下文压力。

### 信号产生的三种路径

**路径 1：创世基础设施自动生成**

S-001 EXPLORE 由 field-genesis.sh 在检测到"无 BLACKBOARD + 无信号 + 无 WIP"时自动创建。这是**唯一由基础设施产生的信号**，其余全部由 agent 自主产生。

**路径 2：规则涌现触发（Grammar Rule 7）**

S-002 IMPLEMENT 由 R-001 规则触发。链路：

```
5 Scout observations → Rule 7 (count ≥ 3 → EMERGE) → R-001 涌现
→ R-001 action: "Generate S-002 (IMPLEMENT)" → S-002 创建
```

这是协议设计中**最优雅的信号产生方式**——不是某个 agent 拍脑袋创建的，而是多轮观察共振后自发涌现。但在 4 个审计蚁丘中**只出现过一次**，且几乎确定由 Codex 完成。

**路径 3：Agent 主动创建（最常见）**

S-003, S-004, S-005, S-006 都是 agent 在评审过程中直接创建：

```
Scout 评审 Phase 1 完成 → 发现 Phase 2 需要做 → 创建 S-003 HOLE
Scout 发现 i18n 尚无定义 → 创建 S-004 EXPLORE (研究范围)
S-004 关闭后实现工作未落地 → Scout spawn S-006 HOLE (实现)
Scout 决策跟进 → 创建 S-005 PROBE (性能基线研究)
```

O-20260302025539-18927 记录了 S-006 的产生理由："No open signals remained; spawned S-006 from S-004 handoff gap"——agent 发现所有信号都完成了，但 i18n 实现未落地，主动 spawn 新信号承接。这种"发现空缺 → 主动填补"是判断力行为。

### 不同白蚁对信号的处理

**Codex 牧羊人（强模型）— 创造者角色：**

- 5 个连续 Scout session 产出了 R-001 规则涌现——唯一的规则创造事件
- 认领 S-002 交付 Phase 1 全部 4 个设计文档（1540 行）
- 在信息素链中留下了完整的 completed/unresolved/predecessor_useful 模板
- 创建了 S-003, S-004, S-005 等后续信号——**定义了工作方向**
- 做了关键判断：Phase 1→2 转折点评估（O-20260302014024-69731："Phase 1 质量 95%，前置条件全部满足"）

**Haiku 执行者（弱模型 × 2）— 模仿者角色：**

- 认领并完成 S-003（Phase 2 脚手架）、S-005（性能 probe+gate）、S-006（locale resolver）
- **模仿了 Codex 信息素模板**：观察质量 96.4%，交接评估 99%
- 能正确执行 R-001 action（按阈值归档 S-001）——**规则执行是 T0 行为**
- 能正确管理信号状态（completed, parked → completed）
- 但 commit message 用 "Worker:" 前缀而非 `[termite:...]` 签名——**格式模仿不完全**
- 发现了 W-008 bug 并自行修补——说明 Haiku 有一定的问题发现能力，但这可能也是模仿了 Codex 的"发现问题 → 沉积观察"模式

**空转 agent（后期监控模式）：**

信号全部 completed 后，3 个 agent 继续循环 ~3 小时，产出 50+ 条 "zero actionable queue" 空信息素。这是 W-007 的直接表现——**agent 不知道"没事做可以走了"**。TF-005 已修复此问题（.birth 注入 IDLE 指导）。

### 信号完成状态与实际工作的差距

touchcli 揭示了三个层面的"信号 completed ≠ 工作完成"问题：

**层面 1：Completed ≠ 全部实现（S-003 问题）**

S-003 标记为 `completed`，但其 `next` 字段是 "Develop Gateway + LangGraph + tool execution engine"。观察记录的交付物是"Phase 2 Planning: 7-task breakdown (610 lines) + code scaffolding (1346 lines)"——只做了**规划和脚手架**，不是完整实现。

协议的信号状态只有 open → completed → archived，**没有 "partially done" 或 "planning done, implementation pending" 的中间态**。agent 面对"我能做的部分做完了，但整体任务未完成"时，只能选择标 completed（因为 open 会让下一个 agent 重新认领）。这是信号生命周期模型的结构性局限。

**层面 2：Completed 信号泄漏导致虚假忙碌（W-008 → W-007 链条）**

```
S-002 completed (w=19) → DB query 不排除 completed
→ field-pulse.sh 报 active_signals=4
→ field-arrive.sh 展示 "Top signals: S-002(w:19 IMPLEMENT)"
→ agent 认为有工作 → 检查发现已 completed → 无事可做
→ 沉积 "zero actionable queue" → 下一个 agent 重复 → 65% 空转
```

touchcli agent 自行发现并本地修补（O-20260302033955-6666），已通过 TF-005 回移到协议模板。

**层面 3：信号闭环缺少验证门禁**

S-006 的关闭过程：
- O-20260302030954-46721："locale resolver implemented... **Runtime smoke import blocked locally by missing dependency pydantic_settings**"
- O-20260302032657-80168："validated complete... **static compile success. Runtime DB import still depends on local psycopg2 availability**"
- → S-006 标记 completed

Runtime 验证实际未通过（缺 pydantic_settings 和 psycopg2），只有 static compile 通过。但 agent 仍标记了 completed。**信号的 "completed" 是 agent 自判的，没有外部验证门禁**。

这与 F-010（审计包缺乏结果验证）是同一类问题的不同视角：
- F-010：审计包看不到实际测试结果（协议立场：WONTFIX，验证是宿主 CI/CD 的责任）
- 信号层面：agent 在工作未完全验证时就标 completed（**协议未定义 "completed" 的验证标准**）

**协议设计启示**：信号 completed ≠ production ready。协议应明确这一语义：completed 表示"agent 认为自己的工作完成了"，而非"工作已通过验证"。实际验证应由宿主项目的 CI/CD 或下一个 Scout 的评审来提供。

## 对协议演化的建议

### 已完成 (TF-005)

1. ~~**W-007: 空转心跳防护**~~ **FIXED** — field-arrive.sh 现在检测 idle colony（active_signals=0, 无 WIP, 无 ALARM, 非 genesis）并在 .birth 注入 IDLE 指导 + recovery_hints。Agent 收到明确的"deposit HOLE or exit session"指示。

2. ~~**W-008: completed 信号泄漏到活跃集**~~ **FIXED** — 4 个 DB 查询 + 3 个 YAML 回退函数已排除 done/completed 状态。touchcli agent 的本地补丁已回移到协议模板。

### 更新现有 Findings

3. **W-001 (观察退化) 精化** — 不再是"弱模型通病"，而是"无牧羊人的弱模型通病"。有 Codex 牧羊时退化率从 64% 降到 3.6%。

4. **W-003 (交接跳过) 精化** — 同上。Codex 牧羊时 handoff_quality 从 0% 升到 99%。

5. **W-004 (规则涌现) 精化** — 规则**创造**是 T2 (需强模型)，规则**执行**是 T0 (弱模型可做)。

### 信号生态结构性发现 (新增)

6. **W-009: 信号颗粒度缺乏指导** — agent 自主决定粒度，导致 S-002 一个信号做了 4 个文档（1540 行）而 S-005 只做了 1 个脚本。协议可考虑在 .birth 或规则中建议"一个信号 ≈ 一个可独立验证的交付物"。**可行动性：中等**——需要设计颗粒度指导而非硬性限制。

7. **W-010: 信号状态缺少中间态** — S-003 的"规划完成但实现未开始"只能标 completed 或保持 open。协议可考虑（a）增加 `done` vs `completed` 的语义区分，或（b）强化 `next` 字段作为"剩余工作"载体。**可行动性：低**——引入新状态增加协议概念面积（与 F-009 矛盾），强化 `next` 字段更符合极简哲学。

8. **W-011: 信号 completed 语义未定义** — agent 在 runtime 验证未通过时即标 completed（S-006 缺 pydantic_settings/psycopg2）。协议应明确：completed = "agent 认为自己的工作完成"，不等于"通过验证"。验证由宿主 CI/CD 或下一个 Scout 评审负责。**可行动性：低**——文档化语义即可，不需要模板改动。

### 协议设计方向

9. **PE-003: 部署模式推荐** — 协议应明确推荐"1 强模型 + N 弱模型"的 shepherd 配置，而非纯弱模型或纯强模型。这是成本效益最优的配置。

10. **PE-004: 信息素链作为 in-context learning 载体** — 当前信息素链的设计无意中成为了弱模型的行为模板。这个属性应被正式文档化并强化——信息素链不仅是交接信息，更是行为规范的传导通道。
