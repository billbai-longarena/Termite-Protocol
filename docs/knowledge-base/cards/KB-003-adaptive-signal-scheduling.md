---
id: KB-003
title: "自适应信号调度：连续行为参数 + 亲和度推荐"
status: parked
urgency: low
cooldown_days: 45
last_updated: 2026-03-06
source_docs:
  - "docs/plans/2026-03-06-swarm-intelligence-comparative-analysis.md (Commander repo)"
  - "docs/plans/2026-03-06-adaptive-signal-experiment-design.md (Commander repo)"
related_findings:
  - "F-009c"
  - "W-013"
  - "W-015"
tags: [adaptive-scheduling, behavior-bias, affinity, game-theory, continuous-adaptation, swarm-intelligence]
summary: "当 agent 行为单一化或信号分配低效时，评估环境驱动的连续行为参数和亲和度推荐。"
---

# 背景

对比白蚁协议与经典群智能理论（Givigi & Schwartz, 群智能与性格特征的进化）发现两个可借鉴方向：

1. **连续适应空间**：论文用性格特征向量 γ ∈ ℝⁿ 让同构 agent 产生异构行为；白蚁协议当前依赖离散 caste 和已弃用的 T0/T1/T2 tier
2. **博弈论信号竞争**：论文的回报函数间接依赖其他 agent 行为；白蚁协议的 claim 是纯"先到先得"，未考虑 agent-signal 匹配度

两个方向已转化为可证伪的实验假设（H1、H2），详见 Commander 仓库的实验设计文档。当前先存档，等跨蚁丘实证再决定是否落地。

## 问题信号（When to Consult）

- 蚁群运行中 agent 行为单一化：所有 agent 都在执行模式，无人探索新模块（模块覆盖不均匀）。
- 信号 claim 后频繁 park/stale：agent 领取了不适合自己的 signal（首次完成率低）。
- 多 agent 争抢同类 signal 而冷门 signal 无人认领（信号争抢率高）。
- W-013 类观察质量回退：异构群体中弱模型占比升高时质量下滑。

## 候选机制（Candidate Mechanism）

### H1：行为参数 β（连续适应空间）

环境（field-arrive.sh）根据蚁群状态计算 β ∈ [0, 1]，通过 .birth 指令措辞引导 agent 行为：

```
β = clamp(0, 1, 0.4×C + 0.3×D + 0.3×S)

C = 1 - max_module_share    （信号集中度反面）
D = done_signals / total     （完成率）
S = stale_signals / open     （停滞比）
```

- β < 0.3：执行模式（优先高权重 signal，减少探索）
- β 0.3-0.7：标准模式（与当前行为一致）
- β > 0.7：探索模式（调查未覆盖模块，创建 EXPLORE signal）

### H2：Affinity 推荐（信号竞争最优分配）

从 pheromone_history 统计 agent 历史模块分布，对每个 candidate signal 计算匹配度：

```
affinity(agent, signal) = Σ min(agent_module_freq[m], signal_module_weight[m])
```

.birth 同时展示"最紧急"和"最匹配"两个 signal，agent 自行选择（推荐，非强制）。

### 协议层变更（最小侵入）

- signals 表新增 `module_affinity` TEXT
- pheromone_history 表新增 `module_stats` TEXT, `behavior_bias` REAL
- .birth 新增 4 行 YAML（~30 tokens，800 token 预算内）
- 通过环境变量 `TERMITE_EXPERIMENT=E1|E2` 开关，不改现有字段语义

## 激活条件（Activation Gates）

- [ ] 至少 1 个宿主项目出现模块覆盖不均匀或首次完成率低于 60%。
- [ ] E1 实验完成：β 处理组模块覆盖均匀度 > 对照组 10%，且信号完成速率不下降。
- [ ] E2 实验完成：affinity 处理组首次完成率 > 对照组 15%。
- [ ] 有回滚路径（忽略新字段即可回退，已确认）。

## 冷却条件（Cooldown Guards）

- 45 天内不重复调整 β 公式权重或 affinity 算法。
- E1 处理组信号完成速率下降 > 20% → 终止实验，退回 `parked`。
- E2 推荐采纳率 < 10% → 终止实验，退回 `parked`。
- 单次实验后无显著收益 → 记录负面结果，等待新证据。

## 最小实验（Minimal Experiment）

### E1：β 行为参数化

1. 对照组：标准 caste waterfall，无 β 注入。
2. 处理组：caste waterfall + β 计算 + .birth 探索/执行指令调整。
3. 项目要求：≥ 15 个 signal，≥ 3 个不同模块。
4. 最小样本：2 次对照 + 2 次处理。
5. 成功标准：模块覆盖均匀度 > 对照组 10%，信号完成速率不下降。

### E2：Affinity 推荐

1. 对照组：.birth 只显示 top_task（按 weight 排序）。
2. 处理组：.birth 同时显示 top_task + recommended_task（按 affinity）。
3. 前置条件：蚁群至少运行过 2 轮。
4. 最小样本：3 次对照 + 3 次处理。
5. 成功标准：首次完成率 > 对照组 15%。

时序：E1 先行（不依赖历史）→ E1 积累数据 → E2 后续（需要 module_stats）。

## 规模化风险（Scale Risks）

- 并发放大风险：β 导致过多 agent 同时进入探索模式，信号完成率下降。缓解：失败退出条件（速率下降 > 20%）。
- 噪声/误判风险：affinity 基于历史统计，新 agent 无历史数据时退化为纯 weight 排序（零回归风险）。错误的 module_affinity 可能误导推荐。
- 行为投机风险：agent 可能机械遵循 β 指令（β > 0.7 时盲目创建低质量 EXPLORE signal），而非真正理解探索意图。与 F-009c 同根：弱模型执行形式但不理解语义。

## 采用建议（Adoption Recommendation）

- 当前建议：`parked`
- 建议原因：理论洞察可信（经典群智能理论 + 白蚁协议实证数据），但机制从未在真实蚁群验证。需要至少完成 E1 实验才能判断连续适应空间是否优于离散 caste。
- 下次复审时间：2026-04-20

## 参考

- 相关卡片：[KB-001](KB-001-signal-amplification-over-noise-filtering.md)（信号放大 > 噪声过滤 — β 探索模式与信号放大互补）、[KB-002](KB-002-stateful-guidance-without-agent-classification.md)（环境侧引导 — β 是"环境侧引导"的具体实例）
- 对应修复卡（若已有）：[W-015](../../../audit-analysis/prevention-kit/cards/W-015-claim-lock-starvation.md)（claim 锁饥饿 — affinity 推荐可减少盲目 claim）
- 相关设计文档（Commander 仓库）：
  - `docs/plans/2026-03-06-swarm-intelligence-comparative-analysis.md`
  - `docs/plans/2026-03-06-adaptive-signal-experiment-design.md`
- 理论来源：Givigi & Schwartz, 《多智能体机器学习：强化学习方法》第6章
