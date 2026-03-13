# 白蚁协议增强计划验证与实验排序（2026-03-08）

Date: 2026-03-08
Status: Validation complete
Scope:
- `docs/plans/2026-03-08-termite-enhancement-literature-review.md`
- `docs/plans/2026-03-08-adaptive-task-recommendation-experiment-design.md`
- `docs/plans/2026-03-08-escalation-router-experiment-design.md`
- `docs/plans/2026-03-08-reliability-weighted-emergence-experiment-design.md`
Repro script: `audit-analysis/scripts/summarize-audit-readiness.py`

---

## Prompt Chain

> **Prompt 1** — 拉取最新协议文档
>
> "拉一下白蚁协议最新的，应该增加了4个plan"
>
> → 更新 `TermiteProtocol` 到最新 `origin/main`，确认新增 4 份 2026-03-08 文档

> **Prompt 2** — 设计验证并形成结论
>
> "不用，pdf忽略，然后根据文档，你设计合理的实验测试验证一下这几个plan，并形成结论"
>
> → 基于新增文档 + 既有 audit 证据 + 审计包可用数据，设计验证路径、判断实验顺序，并给出 go/hold 结论

---

## 结论先行

四份文档里，**方向判断是对的，但不该并行硬推**。

最终建议顺序：

1. **先做 `E-TR1`（adaptive task recommendation）**
2. **再做 `E-ER1`（escalation router）**
3. **`E-RWE1`（reliability-weighted emergence）先 hold，先补数据卫生和反馈标签**
4. **论文调研文档保留为方向性总图，不单独作为实现项推进**

原因很简单：

- `E-TR1` 改动最局部，主要落在 `.birth` 推荐与轻量事件埋点，最容易做出可解释结果
- `E-ER1` 历史证据最强（Shepherd Effect、弱模型退化、强模型时间浪费都已在审计中出现），但必须依赖 mixed-model live run
- `E-RWE1` 理论方向是对的，但**当前仓库里的历史数据还不够支撑一个可信的 Dawid-Skene 式实验**

换句话说：

> **TR1 = 现在就能做的低风险高收益实验；ER1 = 第二阶段机制化增强；RWE1 = 需要先补实验地基的数据工程项。**

---

## 验证方法

这次不是重新写一版 plan，而是对现有 plan 做四层验证：

1. **协议适配性检查**
   - 是否保持 v5.1 的核心约束：无中央调度、advisory-first、可回退、环境承载智慧
2. **历史证据交叉验证**
   - 是否已经有 audit 事实支持该实验值得做
3. **数据可用性检查**
   - 现有 audit package 能否支撑离线回放 / shadow / live 指标解释
4. **实验性价比排序**
   - 谁先做，谁后做，谁先补埋点再说

---

## 可复现的数据快照

运行：

```bash
python3 audit-analysis/scripts/summarize-audit-readiness.py
```

基于当前仓库中的 audit package，可得到如下结论：

| 审计包 | 可用于什么 | 主要限制 |
|---|---|---|
| `touchcli/2026-03-03` | `TR1` / `ER1` 的历史背景验证 | signal/claim 事件链不完整，不能直接算首次完成率或推荐采纳率 |
| `touchcli/2026-03-02` | `ER1` 的 A-005 牧羊效应对照 | 样本太小，适合做案例，不适合做主统计 |
| `ReactiveArmor/2026-03-01` | `ER1` / `RWE1` 的负例背景（弱模型退化） | 无 active signals、无 rule labels，无法做推荐或可靠性主实验 |
| `OpenAgentEngine/2026-03-01` | handoff / audit 流程背景 | 几乎不提供推荐或涌现实验所需结构化标签 |
| `Adam/2026-03-06` | v5.1 数据形状抽样 | 样本小，且 observation 导出的 `quality_score` 不是数值，说明当前 schema 还不稳定 |

### 数据层关键发现

1. **`TR1` / `ER1` 有历史背景数据，但没有完整的 claim 事件事实源**
   - 现有 audit package 里最有用的是 `touchcli/2026-03-03`：272 条 observations、41 个 signal 文件、21 条 rules、141 次 handoffs
   - 但这些包并不包含 `birth_viewed → claim → done/park/stale` 的完整事件链
   - 所以可以做**特征 sanity check**、案例回放、risk calibration，但**不能直接替代 live shadow**

2. **`RWE1` 当前最大问题不是公式，而是标签贫弱**
   - 当前 rule-health 中大部分 rule 都是 `hit_count = 0`、`disputed_count = 0`
   - 只有极少数历史 rule 带有可用于监督的命中/争议信号
   - 这意味着目前很难构造 40 个以上高质量 cluster/rule labels 来做离线 benchmark

3. **observation schema 仍有漂移，直接阻塞 `RWE1`**
   - `Adam/2026-03-06` 的 observation 中，`quality_score` 导出为 `deposit` / `trace` 这类字面量，而不是数值
   - 多个较早 audit package 甚至没有稳定的 `source_type`
   - 这说明 `RWE1` 所依赖的“数值质量 + 来源 profile + 后续反馈”三件套，目前还没有同时稳定存在

4. **已有证据足以证明“问题是真的”，但不足以证明“RWE1 公式现在就能被可信验证”**

---

## 文档逐项验证

## 1. 论文调研文档：方向判断成立，但它是路线图，不是独立实验

`docs/plans/2026-03-08-termite-enhancement-literature-review.md` 的价值在于：

- 它没有把协议改回 central scheduler / master-slave
- 它把增强方向约束在“推荐 / 加权 / 路由 / 压缩”这类环境侧机制
- 它与现有 audit 事实高度一致：
  - A-005 / A-006 已经验证 Shepherd Effect 的存在
  - ReactiveArmor 已经验证弱模型会机械 deposit、不会稳定地产出判断性 observation
  - A-006 已经验证 observation noise 会污染 rule emergence

### 验证结论

这份调研文档的**方向性判断成立**，而且给出的实验优先级基本合理：

- `recommended_task`
- `reliability_weighted_emergence`
- `escalation_router`

但结合当前数据现状，执行顺序应调整为：

1. `TR1`
2. `ER1`
3. `RWE1`

原因不是 `RWE1` 不重要，而是它**更依赖高质量标签**。

### 结论

- **状态**：`validated as strategic map`
- **动作**：保留为上层路线图，不单独立项实现

---

## 2. `E-TR1`：最适合先做，且应该把“离线验证”改成“特征体检 + shadow”为主

这份设计文档的优点：

- 不改 claim 原子性
- 不引入中心调度器
- 推荐保持 advisory
- 回滚极其简单（只关 `TERMITE_EXPERIMENT`）

这些都非常符合 v5.1 的哲学。

### 历史证据支持度

虽然当前没有直接的“推荐采纳率”历史指标，但已有审计已经证明两件事：

1. **claim 错配 / 尾部空转是真问题**
   - A-006 出现了 63 分钟 claim starvation 尾巴
2. **环境中的高质量提示会显著改变弱模型行为**
   - A-005 里高质量 pheromone template 让 Haiku observation 质量达到 96.4%

这说明：

- 即使只改 `.birth` 文案和排序，不改 claim 权限，也很可能出现可测行为变化
- 因而 `TR1` 的 H3（recommendation can remain advisory）是可信的

### 我建议的验证测试

把原文档的“Phase 0/1/2/3”收敛成三个更务实的测试：

#### Test TR1-A — 特征体检（离线，不判胜负）

目标：验证 scorer 所需字段在历史数据里是否可计算。

做法：

- 用历史 signal 快照跑一次 `urgency / module / type / readiness` 特征提取
- 统计缺失率，尤其是 `module`、`status`、`weight`
- 要求：候选 signal 中关键特征缺失率 < 10%

注意：

- 这一步**不能**拿来证明 H1/H2 成立
- 它只验证“推荐函数算得出来”

#### Test TR1-B — Shadow ranking（第一个关键验证）

目标：验证 recommendation 是否优于默认 top-task。

做法：

- 在一个新 v5.1 宿主项目里只记录，不展示 `recommended_task`
- 必须记录：`birth_viewed`、`recommended_presented`、`claim`、`done`、`parked`、`stale`
- 连续收集至少 **30 次 claim** 或 **7 天**

通过线：

- shadow recommendation 的后验完成率高于同批 `top_task` 至少 **10%**
- 事件匹配率 > **90%**

#### Test TR1-C — Advisory live（真正判定是否推进）

目标：验证 H1/H3。

做法：

- `.birth` 同时展示 `top_task` 和 `recommended_task`
- 不做 `β`
- 至少 **40 次 claim** 或 **2 个完整 colony 周期**

判定：沿用原文档成功线。

### 结论

- **状态**：`go first`
- **原因**：问题真实、改动局部、数据需求最低、收益最可解释
- **前置条件**：先把 `signal_events` 做成唯一事实源

---

## 3. `E-ER1`：问题最真实、收益可能很高，但必须放在 `TR1` 之后

`E-ER1` 的理论和历史证据都很强。

### 历史证据支持度

这份设计最强的一点是：它不是论文驱动的空想，而是对已有审计事实的机制化总结。

现有仓库已经有三条强证据链：

1. **Shepherd Effect 已被反复观察到**
   - A-005：1 Codex + 2 Haiku 时，弱模型可模仿高质量模板
2. **弱模型会污染 observation 环境**
   - A-006：272 observations 中约 43% 退化，质量率降到 57%
3. **强模型时间会被浪费在低风险事务上**
   - 这在 mixed colony 中是显性成本问题，router 正是要解决这个问题

所以 `ER1` 不是“要不要试一试”的级别，而是：

> **问题已经存在，下一步只是在决定用多保守的方式把它机制化。**

### 我建议的验证测试

#### Test ER1-A — 风险回放校准（离线）

目标：验证 risk score 至少能把“高风险失败样本”排到前面。

正例来源：

- ReactiveArmor 的 W-001 ~ W-004
- touchcli A-006 的 W-013 / W-015 相关 signal 或 observation cluster

负例来源：

- A-005 中完成顺畅、弱模型可直接承接的执行型工作

通过线：

- risk score top quartile 至少覆盖 **60%** 的已知失败/退化案例
- L0 候选中明显高风险案例占比 < **20%**

#### Test ER1-B — Shadow router（关键验证）

目标：不改行为，只验证路由建议是否与实际效果相关。

做法：

- 在 mixed-model v5.1 run 中记录 `risk_score`、`route_level`、最终执行者、结果质量
- 样本要求：至少 **20 个 L1/L2 候选 signal**

通过线：

- 被标成 L1/L2 的 signal 在历史上确实更容易出现 stale / reopen / 低质量 observation

#### Test ER1-C — Advisory live（不要直接上 soft reserve）

目标：验证 advisory route 文案是否足够产生行为导向。

做法：

- 只显示 route 建议，不保留权限限制
- 连续运行至少 **1 次 mixed-colony 周期**

只有在满足以下条件后，才进入 soft reserve：

- advisory follow rate ≥ **20%**
- strong-model waste rate 出现下降趋势
- L2 starvation 没有明显抬头

### 结论

- **状态**：`go second`
- **原因**：问题最真实，历史证据最强，但必须依赖 mixed-model live run，且需要先共享 `signal_events` 这层埋点基础设施
- **注意**：第一轮只建议做到 advisory，不建议直接让 capability-aware 逻辑进入常规协议语义层

---

## 4. `E-RWE1`：设计方向正确，但当前不应直接开 live

这是四份文档里**理论上最漂亮、工程上最容易踩坑**的一份。

### 为什么方向是对的

已有证据已经证明“只看 observation 数量会被弱模型噪声污染”：

- A-006 的质量分数验证表明，272 条 observation 中约 **43%** 是退化记录
- 旧的 count-based emergence 会让退化 group 通过阈值
- `sum(quality) >= 3.0` 的思路已经在 `audit-analysis/optimization-proposals/2026-03-03-h2-quality-score-validation.md` 中得到过一次强验证

所以：

- “需要可靠性加权”这件事，本身没问题
- 真正的问题是：**当前仓库缺少支撑 posterior 学习的稳定反馈标签**

### 当前阻塞点

#### 阻塞 1：`quality_score` 历史字段不稳定

`Adam/2026-03-06` 的 observation 导出里，`quality_score` 不是数值，而是 `deposit` / `trace`。

这说明：

- 当前 audit export 链路对 `RWE1` 还不具备“可直接训练/回放”的稳定性

#### 阻塞 2：rule outcome 标签稀缺

大部分 `rule-health.yaml` 只有空 rule 集或 `0 hit / 0 disputed`。

这意味着：

- 没法稳定区分 `valid / invalid / uncertain`
- 也就无法可靠估计 posterior 是否真的减少了 false promotion

#### 阻塞 3：profile 维度还没稳定

文档设想使用：

- platform
- trigger_type
- evidence_shape

但当前历史 observation 里，这些字段并没有稳定齐全地存在。

### 我建议的验证测试

对 `RWE1`，先不要直接做 C0/T1/T2 主实验，而是先做一个 **RWE0 数据就绪实验**。

#### Test RWE0-A — Schema readiness

通过线必须同时满足：

- `quality_score` 数值覆盖率 ≥ **90%**
- `source_type` 覆盖率 ≥ **90%**
- profile 所需辅助字段覆盖率 ≥ **90%**

#### Test RWE0-B — Label readiness

通过线必须同时满足：

- 至少 **40 个** cluster/rule units
- `valid` 和 `invalid` 各不少于 **10**
- 至少 **5 条** rule 带真实 hit/dispute 反馈

#### Test RWE0-C — Offline benchmark rebuild

目标：先验证 `quality_score + corroboration` 就能不能把 false promotion 压下去。

如果这一步都过不了，再上 posterior 只会把复杂度抬高。

### 结论

- **状态**：`hold`
- **原因**：问题真实，公式方向正确，但当前数据卫生不足以支撑可信验证
- **先做什么**：先补 export/schema/feedback 标签，再回到 `RWE1`

---

## 最终排序与实施建议

### 最终排序

1. **TR1 — 立即启动**
2. **ER1 — 在 TR1 埋点稳定后启动**
3. **RWE0 — 作为数据准备项启动**
4. **RWE1 — 待 RWE0 通过后再启动**

### 不建议的做法

1. **不要三项并行开 live**
   - 会让指标互相污染，无法归因
2. **不要把 ER1 直接做成硬调度**
   - 第一轮必须 advisory-first
3. **不要在 RWE1 上先写复杂 posterior，再补标签**
   - 这会把问题从“实验验证”变成“用漂亮数学掩盖数据缺口”

---

## 一句话总结

> **这四份文档里，调研方向是对的，`TR1` 最值得先做，`ER1` 最值得第二个做，`RWE1` 现在先别急着上线，先把能支撑它的数据地基补齐。**
