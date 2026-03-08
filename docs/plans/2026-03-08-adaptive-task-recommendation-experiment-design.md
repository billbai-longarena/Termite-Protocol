# E-TR1: Adaptive Task Recommendation Experiment Design

Date: 2026-03-08
Status: Proposed experiment
Prerequisite:
- `docs/plans/2026-03-08-termite-enhancement-literature-review.md`
- `docs/knowledge-base/cards/KB-003-adaptive-signal-scheduling.md`
- `docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md`
Protocol baseline: v5.1
Field baseline: `field-arrive.sh` leaf-priority `.birth` + atomic `field-claim.sh`
Experiment flag:
- `TERMITE_EXPERIMENT=TR1-shadow`
- `TERMITE_EXPERIMENT=TR1-live`
- `TERMITE_EXPERIMENT=TR1-live-beta`

---

## Goal

在**不引入中央调度器、不破坏原子 claim、不恢复硬角色分类**的前提下，让 `.birth` 从“只展示最紧急 signal”升级为“展示**最紧急** + **最适合** + **当前行为偏置**”，从而提升：

1. signal 首次完成率
2. claim 后 park / stale 的下降幅度
3. 模块覆盖均匀度
4. 冷门 signal 的出清速度

本实验吸收两类论文结论：

- **Gerkey & Matarić**：任务分配应优化 utility，而不是默认谁先抢到算谁的
- **Theraulaz et al.**：连续阈值/刺激强度可产生可变分工，无需永久角色标签

---

## Problem

当前协议已经解决了两个难题：

- **冲突**：通过 SQLite 原子 claim 避免双重领取
- **并发**：多个 agent 可以自组织并行工作

但还有三个结构性损耗没有解决：

1. **claim 错配**：agent 看到最高权重 signal 就去领，但该 signal 可能并不适合它
2. **行为单一化**：所有 agent 都盯着高权重热点，冷门模块长期无人触达
3. **探索/执行失衡**：蚁丘需要探索时没有引导，蚁丘需要收敛时又可能分散精力

这些问题不需要一个“调度官”来修复，更适合由环境给出**推荐**和**偏置**，让 agent 保持自主决定。

---

## Hypotheses

### H1 — Best-fit recommendation improves first-pass completion

如果 `.birth` 除了 `top_task` 之外，还提供一个 `recommended_task`，并且该推荐综合 urgency、agent-signal affinity、dependency readiness 与历史完成概率，那么：

- 首次完成率应高于对照组至少 **15%**
- claim 后 30 分钟内 `parked/stale` 比例应下降至少 **20%**

### H2 — Continuous behavior bias improves coverage without hurting throughput

如果环境根据蚁丘状态计算连续行为偏置 `β ∈ [0,1]`，并用 `.birth` 文字轻微改变推荐倾向，那么：

- 模块覆盖均匀度应高于对照组至少 **10%**
- 总体 signal 完成速率不应下降超过 **5%**

### H3 — Recommendation can remain advisory

即使推荐不是强制、claim 流程完全不改，单靠 `.birth` 的结构化推荐，也应出现可测的行为变化：

- 推荐采纳率至少 **25%**
- 推荐采纳后完成率高于未采纳情形

---

## Non-Goals

本实验**不做**以下事情：

1. 不改变 `field-claim.sh` 的原子事务语义
2. 不增加 central scheduler / commander 强制分派
3. 不把 agent 永久分成“探索者 / 执行者 / 判断者”
4. 不把推荐写成硬阻断规则
5. 不在第一轮实验中更改 signal YAML/DB 语义字段的含义

---

## Experimental Arms

### C0 — Control: urgency only

当前基线：

- `.birth` 只展示 `top_task`
- 排序规则为当前 leaf-priority + weight 排序
- 无 `recommended_task`
- 无 `β` 行为偏置

### T1 — Advisory recommendation

处理组 1：

- `.birth` 展示 `top_task`
- 同时展示 `recommended_task`
- `recommended_task` 基于综合分数排序
- 推荐为 advisory，不改 claim 逻辑

### T2 — Advisory recommendation + behavior bias

处理组 2：

- 在 T1 基础上额外计算 `β`
- `β` 改变推荐排序权重，并在 `.birth` 写入“更偏执行 / 更偏探索”的轻提示
- 仍然不强制 claim 某个任务

### Rollout order

严格按顺序推进：

1. `TR1-shadow`：只计算并记录推荐，不展示给 agent
2. `TR1-live`：展示 `recommended_task`
3. `TR1-live-beta`：展示 `recommended_task` + 注入 `β`

这样可以先验证“排序本身是否靠谱”，再验证“行为偏置是否额外带来收益”。

---

## Candidate Pool

推荐候选池仍遵循当前 v5.1 设计约束：

- 只考虑 `signals.status = 'open'`
- 只考虑没有未完成子节点的 leaf signal
- 排除 `archived / done / completed / parked`
- 默认从 weight 前 5 的 leaf signal 中挑选

这样做的原因：

- 避免推荐一个本来就不可执行的 signal
- 不破坏 signal dependency graph 的叶子优先原则
- 控制计算复杂度，避免 `.birth` 预算膨胀

---

## Scoring Model

### 1. Base features

对每个候选 signal 计算以下标准化特征，范围均为 `[0,1]`：

```text
urgency(signal) = weight / 100

affinity(agent, signal) =
  if agent_module_stats exists:
    done_rate_on_module
  else:
    0.5

finish_probability(signal) =
  historical done / claimed for same (type, module)
  fallback = 0.5

coverage_gap(signal) =
  1 - current_module_share(module)

readiness(signal) =
  1.0 if leaf + open
  0.7 if open but module context weak
  0.4 if recently re-opened or repeatedly parked
```

说明：

- `affinity` 关注“这个 agent 对这个模块是否有较高完成概率”
- `finish_probability` 关注“这个 signal 类别在蚁丘历史上本来就好不好做”
- `coverage_gap` 防止所有推荐都集中到热点模块
- `readiness` 避免推荐那些表面 open、实则上下文不足的任务

### 2. T1 score (fixed weights)

```text
recommend_score_T1 =
  0.40 * urgency +
  0.25 * affinity +
  0.20 * finish_probability +
  0.15 * coverage_gap
```

选分数最高者作为 `recommended_task`。

### 3. T2 score (β-adjusted weights)

先由环境计算连续行为偏置：

```text
C = 1 - max_module_share
S = stale_open_signals / max(open_signals, 1)
B = blocked_like_signals / max(open_signals, 1)

β = clamp(0, 1, 0.5 * C + 0.3 * S + 0.2 * B)
```

然后动态调整推荐权重：

| β 区间 | 模式 | urgency | affinity | finish_probability | coverage_gap |
|---|---|---:|---:|---:|---:|
| `< 0.30` | 执行模式 | 0.55 | 0.20 | 0.20 | 0.05 |
| `0.30 - 0.70` | 标准模式 | 0.40 | 0.25 | 0.20 | 0.15 |
| `> 0.70` | 探索模式 | 0.25 | 0.20 | 0.10 | 0.45 |

核心思想：

- 蚁丘收敛期：优先把快完成、紧急的 signal 做掉
- 蚁丘分布失衡期：提高覆盖缺口的权重，鼓励探索冷门模块

---

## `.birth` Output Contract

### C0 example

```text
## task
S-042(HOLE): Fix auth retry loop → inspect token refresh path
```

### T1 example

```text
## task
top_task:
  S-042(HOLE): Fix auth retry loop → inspect token refresh path

recommended_task:
  S-037(HOLE): Patch token-refresh client → matches your recent auth work
  why: affinity=0.82 finish_prob=0.71 urgency=0.58
```

### T2 example

```text
## task
mode_hint:
  β=0.76 → explore slightly beyond hotspot modules; prefer under-covered work if finishable

top_task:
  S-042(HOLE): Fix auth retry loop → inspect token refresh path

recommended_task:
  S-051(EXPLORE): Audit billing webhook retry path
  why: coverage_gap=0.91 affinity=0.55 urgency=0.48
```

约束：

- 新增内容目标控制在 **40-70 tokens**
- 不替换 `top_task`，只补充 `recommended_task`
- 不改变现有 `behavioral_template` 段落位置

---

## Required Instrumentation

为了评估推荐是否真的改变了行为，需要补充两类轻量埋点。

### 1. `signal_events` table

```sql
CREATE TABLE IF NOT EXISTS signal_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  signal_id TEXT NOT NULL,
  agent_id TEXT,
  event_type TEXT NOT NULL,
  experiment TEXT,
  meta TEXT DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_signal_events_signal_time
  ON signal_events(signal_id, timestamp DESC);
```

`event_type` 候选：

- `birth_viewed`
- `recommended_presented`
- `recommended_claimed`
- `non_recommended_claimed`
- `done`
- `parked`
- `stale`
- `reopened`

### 2. `agent_module_stats` table

```sql
CREATE TABLE IF NOT EXISTS agent_module_stats (
  agent_id TEXT NOT NULL,
  module_key TEXT NOT NULL,
  claimed_count INTEGER DEFAULT 0,
  done_count INTEGER DEFAULT 0,
  parked_count INTEGER DEFAULT 0,
  stale_count INTEGER DEFAULT 0,
  last_updated TEXT NOT NULL,
  PRIMARY KEY(agent_id, module_key)
);
```

更新规则：

- claim 成功：`claimed_count + 1`
- signal done：`done_count + 1`
- signal parked：`parked_count + 1`
- signal stale：`stale_count + 1`

冷启动回退：

- 若某 agent 没有历史，`affinity = 0.5`
- 若某 module 没有历史，使用 colony-level 完成率

---

## Experimental Procedure

### Phase 0 — Instrumentation only

目标：不改 `.birth`，仅补齐观测数据。

要求：

- 连续运行至少 **7 天** 或 **30 次 claim**
- 收集 `signal_events` 与 `agent_module_stats`
- 检查是否存在系统性漏记事件

进入下一阶段条件：

- `birth_viewed` 和 claim 事件匹配率 > 90%
- 至少覆盖 3 个不同 module

### Phase 1 — Shadow ranking

目标：验证推荐是否“看上去靠谱”，但不影响 agent 选择。

做法：

- `field-arrive.sh` 计算 `recommended_task`
- 写入日志，不写入 `.birth`
- 记录如果 agent 最终 claim 的 signal 与 shadow recommendation 是否一致

成功条件：

- shadow recommendation 的历史完成率高于同一批次 `top_task` 至少 **10%**
- 没有明显偏向单一 module

### Phase 2 — Live advisory

目标：验证仅靠建议能否改变行为与结果。

做法：

- 在 `.birth` 增加 `recommended_task`
- 不增加 `β`
- 运行至少 **2 个完整 colony 周期** 或 **40 次 claim**

### Phase 3 — Live advisory + β

目标：验证连续行为偏置是否带来额外收益。

做法：

- 在 Phase 2 基础上启用 `β`
- 连续运行至少 **2 个完整 colony 周期** 或 **40 次 claim**

---

## Metrics

### Primary metrics

1. **First-pass completion rate**
   - 定义：首次 claim 后，在 90 分钟内进入 `done/completed` 的比例
2. **Claim-to-park/stale rate**
   - 定义：claim 后 30 分钟内进入 `parked/stale` 的比例
3. **Recommendation adoption rate**
   - 定义：看到推荐后，最终 claim 推荐 signal 的比例
4. **Module coverage entropy**
   - 定义：done signals 在各 module 的分布熵

### Guardrail metrics

1. **Overall completion throughput**
   - 每 24 小时完成的 signal 数
2. **Median claim latency**
   - 从 `.birth` 生成到 claim 成功的中位时间
3. **Hotspot concentration**
   - 最大 module 占全部完成 signal 的份额
4. **Idle rate**
   - agent 到达后无 claim 的比例

### Diagnostic metrics

1. `recommended_task` 的平均 `affinity`
2. `recommended_task` 被采纳与否时的完成率差值
3. 高 `β` 时 EXPLORE signal 的生成/完成比例
4. 不同平台对推荐的采纳差异

---

## Success Criteria

### T1 success

满足以下全部条件才算成功：

- 首次完成率相对 C0 提升 **≥ 15%**
- claim 后 park/stale 相对 C0 下降 **≥ 20%**
- 总体完成 throughput 不下降超过 **5%**

### T2 success

满足以下全部条件才算成功：

- 模块覆盖熵相对 T1 或 C0 提升 **≥ 10%**
- 最大 module 份额下降 **≥ 10%**
- throughput 不下降超过 **5%**
- 推荐采纳率仍 **≥ 20%**

---

## Failure / Stop Conditions

出现以下任一情况立即停止实验并回退：

1. throughput 连续 3 天下降超过 **20%**
2. 推荐采纳率低于 **10%** 且无上升趋势
3. 某单一 module 因 `β` 探索模式被异常放大，导致热点任务堆积
4. `.birth` token 预算因推荐信息超出目标上限

---

## Risks

### 1. Cold-start bias

新 agent / 新 module 没有历史，推荐可能退化为随机。

缓解：

- `affinity` 缺省回退 0.5
- 使用 colony-level `finish_probability` 兜底
- shadow 阶段先积累数据

### 2. Recommendation gaming

agent 可能机械跟随推荐，而不真正判断自己是否适合。

缓解：

- 推荐文案保留 advisory 语气
- 同时展示 `top_task` 与 `recommended_task`
- 不改变 claim 权限

### 3. Exploration overshoot

高 `β` 可能导致过度探索，主线任务积压。

缓解：

- `β > 0.70` 时仍保留一定 urgency 权重
- 设置 throughput guardrail
- 先在 advisory 模式试验，不自动生成新 signal

### 4. Measurement blind spots

如果 claim/done/park/stale 事件记录不完整，结果不可解释。

缓解：

- Phase 0 单独校验埋点
- 所有指标以 `signal_events` 为唯一事实源

---

## Rollback Plan

回滚要求必须足够简单：

1. 关闭 `TERMITE_EXPERIMENT`
2. `.birth` 恢复仅展示 `top_task`
3. 保留 `signal_events` 与 `agent_module_stats` 数据，便于复盘
4. 不删除任何旧字段，不回收 schema

这保证：

- 回滚不影响 claim / done / archive 主流程
- 数据仍可用于后续离线分析

---

## Expected Deliverables

实验结束后应产出：

1. 一份跨 run 的指标对比表（C0 / T1 / T2）
2. 至少 5 个推荐成功和失败案例
3. 一份关于 `β` 是否值得进入 KB-003 激活条件的判断
4. 如果结果显著，形成后续实施文档：
   - `field-arrive.sh` 设计修改
   - `termite-db.sh` / schema 增量变更
   - `.birth` 模板预算调整

---

## Adoption Recommendation

当前建议：`candidate`

原因：

- 理论贴合度高
- 与当前 v5.1 环境驱动路线兼容
- 改动位置集中在 `.birth` 生成和轻量统计
- 可 advisory rollout，可随时回退

建议复审条件：

- 完成至少 1 次 shadow + 2 次 live run 后复审

---

## References

- `docs/plans/2026-03-08-termite-enhancement-literature-review.md`
- `docs/knowledge-base/cards/KB-003-adaptive-signal-scheduling.md`
- `docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md`
