# E-ER1: Escalation Router Experiment Design

Date: 2026-03-08
Status: Proposed experiment
Prerequisite:
- `docs/plans/2026-03-08-termite-enhancement-literature-review.md`
- `audit-analysis/optimization-proposals/2026-03-02-touchcli-audit-analysis.md`
- `audit-analysis/optimization-proposals/2026-03-03-touchcli-multimodel-audit.md`
- `docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md`
Protocol baseline: v5.1 unified `.birth` + Shepherd Effect via `behavioral_template`
Experiment flag:
- `TERMITE_EXPERIMENT=ER1-shadow`
- `TERMITE_EXPERIMENT=ER1-advisory`
- `TERMITE_EXPERIMENT=ER1-soft-reserve`

---

## Goal

把当前“Shepherd Effect 已被观察到，但主要靠经验触发”的状态，升级为一个**可计算、可回退、可实验**的 escalation router：

- 哪些 signal 适合弱模型直接执行
- 哪些 signal 需要强模型先播种模板或先做 decomposition
- 哪些 signal 应优先等待强能力参与者

目标不是做一个中央调度官，而是让环境用更明确的风险信号来**分配强模型的稀缺注意力**。

本实验吸收两类论文思路：

- **FrugalGPT**：并非所有任务都值得直接上强模型，路由能同时提升质量与成本效率
- **RouteLLM**：可以根据任务特征决定是否升级到更强模型

---

## Problem

现有协议已经知道一个强事实：

- A-005 中，强模型先播种高质量模板后，弱模型表现显著提升
- A-006 中，弱模型数量一多、模板播种不足或被噪声稀释，质量就明显回落

但目前还缺失一个关键机制：

> **何时应该让强模型先手？何时可以让弱模型直接执行？**

没有这个机制，就会出现两种浪费：

1. **强模型浪费**：被用去做低风险机械任务
2. **弱模型误投**：在高风险任务上反复 stale / 沉积退化 observation

---

## Hypotheses

### H1 — Router improves quality on risky signals

如果对 signal 计算 `risk_score` 并做 advisory routing，那么：

- 高风险 signal 的首次完成率应提升至少 **20%**
- 高风险 signal 上的高质量 observation 率应提升至少 **25%**

### H2 — Router reduces strong-model waste

如果强模型被优先引导到高风险、高杠杆 signal，那么：

- 强模型在低风险 signal 上的 claim 占比应下降至少 **50%**
- 同时总体完成 throughput 不应下降超过 **5%**

### H3 — Advisory routing is enough for first experiment

在第一轮实验中，即使不做强制调度，只通过 `.birth` 提示和 soft reserve，也应有可测效果。

---

## Non-Goals

本实验**不做**以下事情：

1. 不引入 master-slave orchestrator
2. 不要求所有 agent 上报 token 成本或外部 API 账单
3. 不把平台/模型能力写入协议核心语义
4. 不把所有高风险 signal 永久锁给强模型
5. 不在第一轮实验中新增复杂训练型 router

---

## Routing Levels

### L0 — `weak_ok`

定义：

- 风险低
- 模板充分
- 局部改动
- 依赖浅
- 历史完成率稳定

环境行为：

- 弱模型可直接 claim
- 不提示升级

### L1 — `seed_then_swarm`

定义：

- 风险中等
- 需要高质量模板或 decomposition
- 弱模型可执行，但更适合在强模型播种后跟进

环境行为：

- `.birth` 标记“strong seed preferred”
- 强能力参与者优先看到它
- 若已有高质量模板生成，可降回 L0

### L2 — `strong_first`

定义：

- 高风险 / 高新颖 / 高停滞
- 多轮 stale / parked
- 无现成模板且 blast radius 较大

环境行为：

- 强能力参与者优先推荐该 signal
- 弱能力参与者默认看到替代任务
- 若等待超过阈值，可自动降为 L1，避免饥饿

---

## Risk Model

### Feature set

对每个候选 signal 计算以下归一化特征：

```text
novelty = 1 if module has no high-quality observation example in last 14d else 0

stagnation =
  normalized(touch_count + reopen_count + recent_park_count)

dependency_complexity =
  normalized(depth + active_child_count + blocked_neighbors)

blast_radius =
  heuristic(core_module | auth | db | build | migration | infra)

template_gap =
  1 if no behavioral_template with quality_score >= 0.7 for same module else 0
```

### `risk_score`

```text
risk_score =
  0.30 * novelty +
  0.25 * stagnation +
  0.20 * blast_radius +
  0.15 * dependency_complexity +
  0.10 * template_gap
```

### Mapping to routing level

| `risk_score` | Level | Meaning |
|---|---|---|
| `< 0.40` | `weak_ok` | 直接开放给弱模型 |
| `0.40 - 0.69` | `seed_then_swarm` | 先播种模板更好 |
| `>= 0.70` | `strong_first` | 优先等待强能力参与者 |

---

## Capability Model

### Why capability is experimental only

v5 的协议哲学不希望核心协议回到永久的参与者分类。因此本实验中“强/弱”只是**实验辅助标签**，不进入协议常规语义层。

实验层面允许使用一个最小配置：

```yaml
strong_capable_platforms:
  - codex-cli
  - claude-code

weak_capable_platforms:
  - opencode
  - unknown
```

重要约束：

- 这是实验配置，不是协议规范
- 一旦实验结束，应评估是否能替换为更中性的 capability signal

---

## `.birth` Contract Changes

### Advisory mode

对所有参与者都显示 route level，但文本不同。

#### Strong-capable arrival

```text
## task
priority_route:
  S-042(HOLE): auth retry loop
  route: strong_first
  why: novel module + no template + stale_count=3
  suggested_action: seed template or decompose before broad swarm claim
```

#### Weak-capable arrival

```text
## task
recommended_task:
  S-037(HOLE): token-refresh client patch
  why: route=weak_ok

avoid_for_now:
  S-042(HOLE): strong_first because novel module + no template + stale_count=3
```

### Soft reserve mode

在 advisory 基础上加一条弱约束：

- 对弱能力参与者，`strong_first` signal 不作为首推荐
- 若超过 `reserve_timeout` 仍无人处理，则自动降级为 `seed_then_swarm`

建议超时：

```text
reserve_timeout = 20 minutes
```

避免高风险 signal 因等待强模型而长期饥饿。

---

## Action Policy by Level

### `weak_ok`

- 弱模型直接 claim
- 若完成后出现高质量 observation，正常进入 pheromone chain

### `seed_then_swarm`

优先动作：

1. 强模型先到：
   - 写 high-quality observation / behavioral template
   - 必要时做 decomposition
   - 释放更多可执行 child signals
2. 弱模型后到：
   - 读取模板
   - 执行叶子任务

### `strong_first`

优先动作：

1. 强模型先做：
   - 新模块侦察
   - 关键判断
   - 恢复 blocked/stale 任务
   - 写 recovery-oriented template
2. 弱模型默认避开，除非：
   - timeout 到期
   - 没有其他 `weak_ok` 候选任务

---

## Required Instrumentation

### 1. `router_decisions` table

```sql
CREATE TABLE IF NOT EXISTS router_decisions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  signal_id TEXT NOT NULL,
  risk_score REAL NOT NULL,
  route_level TEXT NOT NULL,
  reasons TEXT DEFAULT '[]',
  template_available INTEGER DEFAULT 0,
  experiment TEXT NOT NULL,
  meta TEXT DEFAULT '{}'
);
```

### 2. Reuse `signal_events`

与 E-TR1 共用如下事件：

- `birth_viewed`
- `claimed`
- `done`
- `parked`
- `stale`
- `reopened`

新增建议事件：

- `escalation_advised`
- `escalation_followed`
- `soft_reserve_expired`
- `template_seeded`
- `decomposed_after_escalation`

### 3. Optional observation tags

若 live 阶段需要更好分析，可为 observation 附加实验标签：

- `seeded=true|false`
- `route_level_at_claim=L0|L1|L2`

---

## Experimental Arms

### C0 — Current mixed colony

当前基线：

- 无 explicit router
- 由各 agent 自己理解 `.birth`
- Shepherd Effect 是否发生取决于偶然的强模型先手

### T1 — Shadow router

目标：校准 risk model。

做法：

- 计算 `risk_score` 与 `route_level`
- 不写入 `.birth`
- 仅记录日志

### T2 — Advisory router

目标：验证纯提示是否有效。

做法：

- `.birth` 展示 route level 与原因
- 强弱能力参与者看到不同建议文案
- 不阻止 claim

### T3 — Soft reserve router

目标：验证轻约束是否进一步提升质量。

做法：

- 对 `strong_first` signal，弱能力参与者优先看到替代任务
- 20 分钟超时后自动降级
- 仍不做强制锁定

---

## Experimental Procedure

### Phase 0 — Risk calibration from historical audits

先用已有审计数据校准风险特征：

- A-005：哪些强模型先手信号后来质量高
- A-006：哪些信号因模板缺失/停滞而退化

目标：验证 `novelty / stagnation / template_gap` 是否真的能预测失败风险。

进入 shadow 条件：

- 至少 60% 的高失败 signal 被路由到 L1/L2
- 至少 60% 的平稳 signal 被路由到 L0

### Phase 1 — Shadow mode

要求：

- 在混合模型 colony 中运行至少 **2 个完整周期**
- 分析 router 输出与真实 outcome 的关系

目标：

- 校准阈值
- 防止 L2 过多造成饥饿

### Phase 2 — Advisory mode

要求：

- 至少 1 个强能力参与者 + 2 个弱能力参与者可用
- 运行至少 **20 个 signal claim opportunities**

目标：

- 验证显式升级建议是否改变 claim 行为
- 验证强模型是否更多流向 L1/L2 signal

### Phase 3 — Soft reserve mode

要求：

- advisory 结果显示有正向趋势
- 再连续运行至少 **20 个 signal claim opportunities**

目标：

- 测试弱约束是否在不引入饥饿的前提下进一步提高质量

---

## Metrics

### Primary metrics

1. **Risky-signal first-pass completion**
   - 仅看 L1/L2 signal 的首次完成率
2. **High-quality observation rate on risky signals**
   - L1/L2 signal 上 `quality_score >= 0.7` 的 observation 比例
3. **Strong-model waste rate**
   - 强能力参与者 claim L0 signal 的比例
4. **Template seeding rate**
   - L1/L2 signal 在首次弱模型 claim 前是否已有高质量模板

### Guardrail metrics

1. **Overall throughput**
2. **Queue starvation**
   - L2 signal 等待超过阈值的比例
3. **Weak-agent idle rate**
4. **Mean claim latency**

### Diagnostic metrics

1. `risk_score` 与失败/重开/stale 的相关性
2. L2 → L1 超时降级频率
3. `template_seeded` 后弱模型质量变化
4. 不同平台对 route 建议的遵循率

---

## Success Criteria

满足以下全部条件时，认为 router 值得进入下一轮设计：

1. L1/L2 signal 首次完成率相对 C0 提升 **≥ 20%**
2. L1/L2 signal 高质量 observation 率提升 **≥ 25%**
3. 强能力参与者在 L0 signal 上的 claim 占比下降 **≥ 50%**
4. 总体 throughput 不下降超过 **5%**
5. L2 饥饿率低于 **10%**

---

## Failure / Stop Conditions

出现以下任一情况立即停止：

1. 被标记为 L2 的 signal 超过全部 open signals 的 **20%**
2. weak-agent idle rate 连续 3 天显著升高
3. advisory 文案几乎无人遵循（follow rate < 10%）
4. 强模型仍大量消费 L0 任务，说明 router 无实际导向作用

---

## Risks

### 1. Hidden centralization

即使没有 scheduler，router 也可能变相成为中心调度。

缓解：

- 第一轮只做 advisory / soft reserve
- 不改 claim 权限
- 保留 agent 自主性

### 2. Capability labeling becomes sticky

实验配置中的“强/弱能力平台”可能被误当成长期真理。

缓解：

- 明确写为 experiment-only
- 结果复盘时优先分析任务特征，而非平台标签本身

### 3. Starvation of high-risk work

如果强能力参与者暂时不可用，L2 任务可能卡住。

缓解：

- `reserve_timeout = 20 minutes`
- timeout 后自动从 L2 降为 L1

### 4. Miscalibrated risk model

若 risk score 过于依赖少数特征，可能把大量普通任务误判成高风险。

缓解：

- 先做历史审计回放校准
- shadow 先观察分布，再启 live

---

## Rollback Plan

1. 关闭 `TERMITE_EXPERIMENT=ER1-*`
2. `.birth` 恢复当前统一模板，不显示 route level
3. 保留 `router_decisions` / `signal_events` 数据
4. 不回收任何实验表，便于后续复盘与再训练

---

## Expected Deliverables

实验结束后应产出：

1. 一份 risk score calibration 报告
2. C0 / T2 / T3 的指标对比表
3. 至少 5 个“强模型先播种后弱模型成功完成”的案例
4. 至少 5 个“误判为高风险或低风险”的失败案例
5. 对“是否值得把 Shepherd Effect 正式机制化”的判断

---

## Adoption Recommendation

当前建议：`candidate`

原因：

- 这是把 A-005/A-006 实证经验转成显式机制的最自然一步
- 但实验涉及 capability-aware routing，必须保持为 opt-in、可回退层
- 因此先 shadow，再 advisory，再 soft reserve

复审条件：

- 完成至少 1 次混合模型 shadow run 与 1 次 advisory run

---

## References

- `docs/plans/2026-03-08-termite-enhancement-literature-review.md`
- `audit-analysis/optimization-proposals/2026-03-02-touchcli-audit-analysis.md`
- `audit-analysis/optimization-proposals/2026-03-03-touchcli-multimodel-audit.md`
- `docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md`
