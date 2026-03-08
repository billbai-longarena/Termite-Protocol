# E-RWE1: Reliability-Weighted Emergence Experiment Design

Date: 2026-03-08
Status: Proposed experiment
Prerequisite:
- `docs/plans/2026-03-08-termite-enhancement-literature-review.md`
- `docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md`
- `audit-analysis/optimization-proposals/2026-03-03-h2-quality-score-validation.md`
Protocol baseline: v5.1 quality-weighted emergence (`sum(quality_score) >= 3.0`)
Experiment flag:
- `TERMITE_EXPERIMENT=RWE1-offline`
- `TERMITE_EXPERIMENT=RWE1-shadow`
- `TERMITE_EXPERIMENT=RWE1-live`

---

## Goal

在现有 `quality_score` 机制之上，进一步引入**可靠性后验（reliability posterior）**，让 rule emergence 从：

```text
sum(quality_score) >= threshold
```

升级为：

```text
sum(quality_score × reliability_posterior(profile)) >= threshold
```

目标不是重新对 agent 做永久等级划分，而是解决一个更具体的问题：

> **当低质量 observation 数量很多、但高质量 observation 数量较少时，如何让涌现更抗噪，同时不扼杀新来源与弱来源的贡献？**

本实验吸收 **Dawid & Skene** 的核心思想：没有真值标签时，也能从长期一致性和后续验证结果中推断“哪类观察更可靠”。

---

## Problem

v5.0 已经用 `quality_score` 解决了一个大问题：

- 不是所有 observation 都等权
- 退化 observation 更难触发 rule promotion

但仍有两个残留问题：

1. **同样是 0.7 的 observation，不同来源的实际可靠性仍可能不同**
2. **仅靠单条 artifact 形状打分，无法利用“后续被验证/证伪”的信息**

换句话说，`quality_score` 目前主要回答：

- “这条 observation 看起来像不像一条像样的 observation？”

而本实验要补的是：

- “这类 observation **历史上**有多常在后续被证实有用？”

---

## Hypotheses

### H1 — Reliability posterior reduces false promotions

如果 rule promotion 的证据权重加入可靠性后验，那么：

- 假规则触发率应相对当前基线下降至少 **50%**
- 规则被 dispute / 证伪的比例应下降至少 **30%**

### H2 — Reliability posterior does not significantly hurt recall

如果后验设计得当，那么：

- 有价值规则的召回率不应下降超过 **10%**
- 平均 time-to-promotion 不应增加超过 **20%**

### H3 — Non-identity profiles are enough

如果 profile 使用“证据画像”而非永久 agent 身份，那么仍能获得稳定增益：

- 只用 `platform + trigger_type + evidence_shape` 的 profile，就应接近更复杂模型的效果

---

## Non-Goals

本实验**不做**以下事情：

1. 不恢复 strength tier 作为核心决策依据
2. 不把某个 agent 或平台永久标记为“不可信”
3. 不在第一轮 live 实验里改变 observation deposit 接口
4. 不把所有 trace / handoff 都纳入规则涌现
5. 不要求完整实现 Dawid-Skene EM 才能进入 shadow/live 阶段

---

## Experimental Variants

### C0 — Current baseline

当前规则：

```text
emergence_score = sum(quality_score)
promote if emergence_score >= 3.0
```

### T1 — Online posterior weighting

候选 live 方案：

```text
effective_weight(obs) = quality_score(obs) × posterior_mean(profile_key)
promote if sum(effective_weight) >= 3.0
```

特点：

- 可以在线更新
- 计算成本低
- 不需要中心化标注流程

### T2 — Offline Dawid-Skene benchmark

离线对照方案：

- 使用审计包与人工复盘标签做 benchmark
- 用 Dawid-Skene / EM 估计 profile 的错误率
- 作为 T1 的“上界参考”，验证简化 online posterior 是否足够接近

结论标准：

- 若 T1 与 T2 在 precision/recall 上接近，则 live 采用 T1
- 若差距过大，再考虑更复杂的离线校准流程

---

## Profile Design

### Why profile instead of agent identity

如果直接按 agent 身份加权，会带来三类问题：

1. 冷启动时极不稳定
2. 容易形成永久偏见
3. 与 v5 的“分类产出而非分类参与者”原则冲突

因此 profile 必须是**可衰减、可重算、与证据形状相关**的键。

### Proposed `profile_key`

```text
profile_key =
  platform
  + trigger_type
  + path_specificity
  + detail_bucket
  + source_type
```

其中：

- `platform`: `codex-cli` / `claude-code` / `opencode` / `unknown`
- `trigger_type`: `heartbeat` / `directive`
- `path_specificity`: `path-rich` / `path-poor`
- `detail_bucket`: `degenerate` / `short` / `substantive`
- `source_type`: `deposit` / `trace`

说明：

- 第一轮实验默认只对 `source_type = deposit` 生效
- `trace` 保持事实记录角色，不进入 rule promotion

---

## Evidence Feedback Model

### Positive evidence

某条 observation 或其所属 profile 得到正反馈，如果满足以下任一条件：

1. 它所属的 pattern 形成 rule 后，在 **14 天内**达到：
   - `hit_count >= 2`
   - `disputed_count = 0`
2. 同一 pattern 在 **7 天内**被至少 **2 个独立来源**再次 corroborate
3. 该 observation 被强模型/人工复盘明确认定为“有用且具体”

### Negative evidence

某条 observation 或其所属 profile 得到负反馈，如果满足以下任一条件：

1. 它触发的 rule 在首次命中前就被 dispute
2. 其后续形成的 rule 在 **14 天内** `disputed_count >= 1`
3. 该 observation 在审计复盘中被标注为明显误导或退化

### Unresolved evidence

未被验证也未被否定的 observation 不更新 posterior，仅保留当前先验。

---

## Posterior Update Rule

### T1 online rule

使用 Beta 先验作为可在线更新的简化方案：

```text
posterior_mean(profile) =
  (α + positive_events)
  / (α + β + positive_events + negative_events)
```

建议初始先验：

```text
α = 3
β = 2
prior_mean = 0.60
```

然后定义：

```text
effective_weight = quality_score × clamp(0.40, 1.00, posterior_mean)
```

关键设计：

- **只降权，不上浮**
- 这样能抑制噪声，但不会让某类来源因“历史表现好”而无限放大

### T2 offline benchmark rule

离线阶段允许更复杂：

- 人工给一批 pattern/rule cluster 打 `valid / invalid / uncertain` 标签
- 用 Dawid-Skene / EM 推断各 profile 的混淆情况
- 输出 profile 级错误率估计，作为 T1 的 benchmark

---

## Required Schema / Instrumentation

### 1. `source_reliability` table

```sql
CREATE TABLE IF NOT EXISTS source_reliability (
  profile_key TEXT PRIMARY KEY,
  alpha REAL DEFAULT 3.0,
  beta REAL DEFAULT 2.0,
  positive_events INTEGER DEFAULT 0,
  negative_events INTEGER DEFAULT 0,
  posterior_mean REAL DEFAULT 0.6,
  samples INTEGER DEFAULT 0,
  updated_at TEXT NOT NULL
);
```

### 2. `observation_feedback` table

```sql
CREATE TABLE IF NOT EXISTS observation_feedback (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  observation_id TEXT NOT NULL,
  profile_key TEXT NOT NULL,
  outcome TEXT NOT NULL,
  source_rule_id TEXT,
  recorded_at TEXT NOT NULL,
  meta TEXT DEFAULT '{}'
);
```

`outcome` 候选：

- `corroborated`
- `rule_hit`
- `disputed`
- `audit_rejected`
- `manual_confirmed`

### 3. Observation-side metadata

如果 live 阶段缺少 profile 计算信息，允许增量加列：

```sql
ALTER TABLE observations ADD COLUMN reporter_platform TEXT DEFAULT 'unknown';
ALTER TABLE observations ADD COLUMN reporter_trigger_type TEXT DEFAULT 'heartbeat';
ALTER TABLE observations ADD COLUMN evidence_shape TEXT DEFAULT 'unknown';
```

这三列都是**实验辅助字段**，不是协议核心语义。

---

## Offline Dataset Plan

### Candidate sources

优先使用已经有审计数据的蚁丘：

- `touchcli` A-005 / A-006
- `ReactiveArmor`
- `OpenAgentEngine`
- `0227` 生产参考蚁丘（如果可抽样）

### Labeling unit

标注单位不是单条 observation，而是：

- pattern cluster
- 或由 cluster 提升出的 rule

标签定义：

- `valid`: 后续命中且未 dispute，或复盘确认为有用规律
- `invalid`: 明显退化、误导、 tautology、被 dispute
- `uncertain`: 信息不足，不用于主指标

### Minimum sample

最低样本要求：

- 至少 **40 个 cluster/rule units**
- 其中 `valid` 与 `invalid` 各不少于 **10**
- 至少覆盖 **3 个平台** 或 **2 类 trigger_type**

---

## Experimental Procedure

### Phase 0 — Offline replay

在 live 之前必须先完成离线回放。

步骤：

1. 提取历史 observation cluster 与其后续 rule outcome
2. 运行 C0 / T1 / T2 三种打分
3. 比较 precision / recall / false promotion rate
4. 记录各类 profile 的 posterior 分布

进入 shadow 条件：

- T1 相对 C0 的 false promotion rate 下降至少 **30%**
- recall 不下降超过 **10%**

### Phase 1 — Shadow mode

目标：不改变 live promotion，只额外计算 proposed score。

做法：

- `field-cycle.sh` 继续使用当前 promotion 逻辑
- 同时记录若使用 T1，哪些 cluster 会被 promote / 不会被 promote
- 连续观察至少 **2 个完整 colony 周期**

检查项：

- T1 是否大量压制新 profile
- T1 是否明显延迟真正高价值 rule 的生成

### Phase 2 — Limited live mode

目标：在单一宿主项目或单一实验 run 上开启 live。

做法：

- `field-cycle.sh` promotion 改为 T1
- 仅对 `deposit` observation 生效
- 连续运行至少 **14 天** 或形成 **10 条以上候选 rules**

---

## Metrics

### Primary metrics

1. **Promotion precision**
   - `valid_promotions / all_promotions`
2. **False promotion rate**
   - `invalid_promotions / all_promotions`
3. **Rule dispute rate**
   - 规则生成后 14 天内发生 `disputed_count > 0` 的比例
4. **Useful rule recall**
   - 应该被提升的有效 cluster 中，实际被提升的比例

### Guardrail metrics

1. **Time to promotion**
   - cluster 首次出现到 rule 生成的时间
2. **Promotion volume**
   - 每周期新 rule 生成数
3. **New-profile contribution share**
   - 新 profile 的 observation 对 promotion 的贡献占比
4. **Strong-profile dominance**
   - 是否被少数 profile 垄断所有 promotion

### Diagnostic metrics

1. posterior 分布是否极端两极化
2. `quality_score` 与 `posterior_mean` 的相关性
3. T1 和 T2 的排序一致率
4. 被压制但后来被证实有效的 false negative 案例

---

## Success Criteria

满足以下全部条件才进入候选实施：

1. false promotion rate 相对 C0 下降 **≥ 50%**
2. promotion precision 相对 C0 提升 **≥ 20%**
3. useful rule recall 相对 C0 下降 **≤ 10%**
4. time-to-promotion 增加 **≤ 20%**
5. 新 profile contribution share 不低于 **5%**

---

## Failure / Stop Conditions

出现以下任一情况立即停止 live：

1. valid rule 生成量下降超过 **30%**
2. 新 profile 连续 2 周几乎无法贡献 promotion
3. posterior 分布塌陷到极端低值，导致实际“只剩强来源能说话”
4. shadow/live 结果差异过大，说明反馈定义不稳定

---

## Risks

### 1. Identity leakage through profile

即使不用 agent_id，profile 仍可能变相映射到某类平台标签。

缓解：

- 不直接使用 agent_id
- posterior 只用于降权，不用于永久屏蔽
- 定期衰减历史样本影响

### 2. Starving novel but correct observations

新模式往往样本少，容易被低估。

缓解：

- 先验保持 0.60，而不是过低
- `samples < 5` 的 profile 不允许 posterior 跌破 0.55
- 对新 pattern 保留人工/强模型复查通道

### 3. Feedback loops become circular

如果“被 promote 了所以更可信”，“更可信所以更容易被 promote”，可能形成自强化偏差。

缓解：

- 正反馈不只看被 promote，还看后续 `hit/dispute`
- 保留独立 corroboration 作为第二条正反馈路径

### 4. Label noise in offline benchmark

人工复盘本身可能不一致。

缓解：

- 标注单位放大到 cluster/rule，而非单条 observation
- `uncertain` 样本不进入主指标
- 保留 disagreement 样本单独分析

---

## Rollback Plan

回滚路径必须简单：

1. 关闭 `TERMITE_EXPERIMENT=RWE1-live`
2. `field-cycle.sh` 恢复当前 `sum(quality_score)` 阈值逻辑
3. 保留 `source_reliability` 和 `observation_feedback` 表用于离线复盘
4. 不改变 observation 原始写入逻辑

---

## Expected Deliverables

实验结束后应产出：

1. C0 / T1 / T2 离线对比报告
2. 一份 profile posterior 分布报告
3. 至少 10 个 false promotion / prevented promotion 案例
4. 对“是否值得把 reliability posterior 纳入 v5.x”的明确建议

---

## Adoption Recommendation

当前建议：`candidate`

原因：

- 与 v5.0 的 artifact-quality 路线自然衔接
- 方向正确，但若处理不当容易演化为隐性 agent 分级
- 因此必须先 offline，再 shadow，再 limited live

复审条件：

- 至少完成 1 次离线回放和 1 次 shadow 周期

---

## References

- `docs/plans/2026-03-08-termite-enhancement-literature-review.md`
- `docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md`
- `audit-analysis/optimization-proposals/2026-03-03-h2-quality-score-validation.md`
