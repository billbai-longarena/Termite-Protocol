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

## 对协议演化的建议

### 立即行动 (本次分析驱动)

1. **W-007: 空转心跳防护** — field-cycle.sh 需要检测"连续 N 次无可执行信号"后 exit 或 sleep-extend。建议阈值：连续 3 次空转后 sleep 翻倍，连续 10 次后 agent 退出并沉积 HOLE signal "new work needed"。

2. **W-008: completed 信号泄漏到活跃集** — touchcli agent 自行修补了这个 bug。需要检查 field-arrive.sh 和 field-pulse.sh 的 SQL/YAML 过滤逻辑，将 completed/done 排除。

### 更新现有 Findings

3. **W-001 (观察退化) 精化** — 不再是"弱模型通病"，而是"无牧羊人的弱模型通病"。有 Codex 牧羊时退化率从 64% 降到 3.6%。

4. **W-003 (交接跳过) 精化** — 同上。Codex 牧羊时 handoff_quality 从 0% 升到 99%。

5. **W-004 (规则涌现) 精化** — 规则**创造**是 T2 (需强模型)，规则**执行**是 T0 (弱模型可做)。

### 协议设计方向

6. **PE-003: 部署模式推荐** — 协议应明确推荐"1 强模型 + N 弱模型"的 shepherd 配置，而非纯弱模型或纯强模型。这是成本效益最优的配置。

7. **PE-004: 信息素链作为 in-context learning 载体** — 当前信息素链的设计无意中成为了弱模型的行为模板。这个属性应被正式文档化并强化——信息素链不仅是交接信息，更是行为规范的传导通道。
