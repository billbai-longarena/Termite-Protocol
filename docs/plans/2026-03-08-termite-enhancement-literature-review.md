# 白蚁协议增强方向论文调研（2026-03-08）

## 结论先行

有，而且不止一篇。

如果目标是**在不破坏白蚁协议核心约束**的前提下提升效用和效果——即继续坚持：

- agent 无状态
- 协调主要通过环境而不是对话
- `.birth` 预算严格受限
- 弱模型可以参与，但不能让其污染环境

那么最值得吸收的论文方向不是“让 agent 更会聊天”，而是下面五类：

1. **连续行为偏置 + 自适应分工**：替代过硬的离散 caste / 固定角色
2. **效用驱动的任务推荐**：替代纯“先到先得”的 claim 视角
3. **可靠性加权的知识沉积**：降低弱模型噪声对涌现和规则提升的污染
4. **强弱模型路由 / 升级策略**：把 Shepherd Effect 机制化，而不是靠经验
5. **分层记忆压缩**：在 800 token 左右预算内，让 `.birth` 更像“有层次的检索结果”而不是“扁平摘要”

我对这些方向的总体判断：

- **应优先试验**：Gerkey & Matarić 2004、Theraulaz et al. 1998、Dawid & Skene 1979、FrugalGPT / RouteLLM
- **应谨慎试验**：RAPTOR、Reflexion
- **主要用于确认架构方向正确**：Nii 1986、Salemi et al. 2025/2026

---

## 研究问题

这次调研不是泛泛地找“multi-agent 很厉害”的论文，而是限定在下面这个问题：

> **哪些论文能直接强化白蚁协议已经暴露出的真实瓶颈？**

对照当前协议源仓库里的问题画像，重点瓶颈有五个：

1. **signal claim 仍偏“先到先得”**，对 agent-signal 匹配度利用不足
2. **弱模型沉积噪声会污染 pheromone / observation 环境**
3. **强模型的高价值时间会被机械任务吞掉**，Shepherd Effect 还没有机制化
4. **`.birth` 有严格 token 预算**，但需要承载任务、情境、模板、恢复提示
5. **失败经验沉淀不够结构化**，容易重复踩同一类坑

筛选标准也因此非常明确：

- 不能依赖 agent 之间高带宽对话
- 最好能映射到 SQLite / `.birth` / pheromone / signal 这些现有构件
- 最好支持弱模型参与，但不把协议变成“全靠强模型硬撑”
- 最好能设计成**推荐/加权/门禁**，而不是引入中心化调度器

---

## 论文候选总表

| 优先级 | 论文 | 可迁移核心 | 对白蚁协议的直接价值 |
|---|---|---|---|
| P1 | Theraulaz, Bonabeau, Deneubourg (1998) | response threshold / 连续阈值分工 | 用连续行为偏置替代离散 caste，改善探索-执行平衡 |
| P1 | Gerkey & Matarić (2004) | utility-based task allocation | 把 signal 推荐从“最紧急”扩展到“最适合 + 最紧急” |
| P1 | Dawid & Skene (1979) | latent reliability estimation | 给 observation / rule emergence 做可靠性加权 |
| P1 | Chen, Zaharia, Zou (FrugalGPT) | cost-quality cascade | 把 Shepherd Effect 变成正式的强弱模型升级策略 |
| P1 | Ong et al. (RouteLLM) | learned routing between weak/strong LLMs | 用 signal 风险特征决定是否升级到强模型 |
| P2 | Sarthi et al. (RAPTOR) | hierarchical summarization + retrieval | 改造 `.birth` 的压缩方式，提升 800 token 利用率 |
| P2 | Shinn et al. (Reflexion) | verbal reinforcement / episodic memory | 把 stale / parked / failed attempt 转成高价值失败记忆 |
| P3 | Nii (1986) | blackboard architecture | 理论上确认“环境承载智慧”路线是对的 |
| P3 | Salemi et al. (2025/2026) | LLM blackboard outperforming master-slave baselines | 说明黑板式多 agent 架构在 LLM 时代仍有增益 |

---

## 方向 1：连续行为偏置，优于硬角色切换

### 相关论文

- Theraulaz, Bonabeau, Deneubourg, **Response threshold reinforcement and division of labour in insect societies** (1998)

### 论文给出的核心启发

这篇论文的关键不是“白蚁/蚂蚁很会协作”这种泛结论，而是一个更具体的机制：

- 个体不需要天生就被分成固定角色
- 只要不同任务对应不同刺激强度（stimulus）
- 再加上个体对刺激的**响应阈值（threshold）**会随行为历史变化
- 就会从一群初始相同的个体中，涌现出稳定但可变化的分工

这对白蚁协议非常关键，因为它天然支持：

- **不对 agent 做硬分类**
- 但又允许环境通过信号密度、停滞率、模块覆盖度，持续改变 agent 倾向

### 对协议的直接映射

这基本就是 KB-003 里 `β` 行为参数的更强理论支撑，而且可以进一步具体化：

```text
stimulus(signal) = urgency + stale_bonus + dependency_bonus + coverage_gap

response_tendency(agent, module) =
  f(recent_success,
    recent_stale,
    module_familiarity,
    colony_phase)
```

不是给 agent 打上“探索者 / 执行者 / 判断者”的永久标签，而是在 `.birth` 里给出：

- 当前蚁丘对“探索”的刺激有多高
- 当前 signal 对该 agent 历史行为有多匹配
- 该轮建议偏探索还是偏执行

### 我对落地价值的判断

**高价值，且与白蚁协议哲学高度兼容。**

最重要的一点是：它支持**连续偏置**，而不是重新引入 v4 那种重角色分层。这比“strength-based participation 的硬模板分叉”更符合 v5 的环境驱动方向。

### 建议实验

保留 claim 自主性不变，只新增推荐：

- `.birth` 同时显示 `top_urgent_task` 和 `recommended_task`
- `recommended_task` 由 `stimulus × affinity × recovery_probability` 决定
- 对照指标：首次完成率、park/stale 率、模块覆盖均匀度

### 采用建议

- **建议状态**：`pilot`
- **原因**：理论贴合度高，且与仓库中已有 KB-003 方向同向，不是另起炉灶

---

## 方向 2：任务分配应从“抢到”升级到“适配 + 紧急”

### 相关论文

- Gerkey & Matarić, **A Formal Analysis and Taxonomy of Task Allocation in Multi-Robot Systems** (2004)

### 论文给出的核心启发

这篇论文的重要性在于它把任务分配从经验主义，提升成了一个可分析的“最优分配 / utility”问题。

对白蚁协议来说，可迁移的不是“机器人”本身，而是两个思想：

1. **任务分配应显式优化 utility，而不是默认谁先拿到算谁的**
2. utility 不只看 task urgency，也要看 worker-task fit

白蚁协议现在的 atomic claim 已经很好地解决了“冲突”和“双重领取”，但还没充分解决“**谁更适合领这个 signal**”。

### 对协议的直接映射

可以不引入中央调度器，只在 `.birth` 增加一个推荐分数：

```text
recommend_score(signal) =
  urgency_weight
  × affinity(agent, signal)
  × dependency_readiness
  × expected_finish_probability
```

其中：

- `urgency_weight`：沿用现有 signal weight / stale / blocked 信息
- `affinity(agent, signal)`：复用 KB-003 提议的 module affinity
- `dependency_readiness`：依赖图中是否已具备执行条件
- `expected_finish_probability`：来自该类 signal 的历史首次完成率

### 我对落地价值的判断

**非常高。**

这是当前协议最值得补的一块，因为它不改变协议核心机制，却能明显改善：

- 错配 claim
- signal 反复 park
- 热门 signal 被争抢、冷门 signal 长期积压

### 建议实验

- 处理组：`.birth` 显示 `top_urgent_task` + `best_fit_task`
- 对照组：只显示当前最高权重 signal
- 观察：首次完成率、领取后 30 分钟内 park/stale 率、冷门 signal 出清速度

### 采用建议

- **建议状态**：`pilot`
- **原因**：低侵入、高收益、与现有 SQLite / signal schema 兼容

---

## 方向 3：涌现与规则提升，需要“可靠性加权”而不是只看数量

### 相关论文

- Dawid & Skene, **Maximum Likelihood Estimation of Observer Error-Rates Using the EM Algorithm** (1979)

### 论文给出的核心启发

这篇论文原始场景不是 LLM，而是多个观察者在没有真值标签时，如何估计各自误差率。

对白蚁协议的启发非常直接：

- 不同沉积源的可靠性不同
- 即使没有人工真值标签，也能从长期一致性里估计“谁更常错”
- 聚合结论时，不应把每条 observation 当成同等票权

这正好对应当前协议的难点：

- 弱模型 observation 数量可能很多
- 但若把它们与高质量 observation 等权对待，会污染 rule emergence

### 对协议的直接映射

当前 v5 已经有 `quality_score`，下一步可以从“单条 observation 的静态质量分”升级到“**质量分 × 可信度后验**”：

```text
evidence_weight(obs) = quality_score(obs) × reliability_posterior(source)

emergence_score(pattern) = Σ evidence_weight(obs_i)
```

关键点：

- `source` 不应是永久 agent caste
- 更适合定义为短周期、可衰减的证据来源画像，例如：
  - 平台 + trigger_type
  - 最近 N 次被后继验证/否定的比例
  - 是否伴随具体路径、命令、失败输出、修复结果

### 我对落地价值的判断

**非常高，但要小心哲学回退。**

它能显著降低“低质量 observation 数量多 → 假规则涌现”的风险；但如果把它实现成永久性的 agent 分级，就会和 v5 “分类产出而非分类参与者”原则冲突。

### 建议实验

- 先做离线回放：用 A-006 / touchcli 等已有审计包回算规则提升
- 对比：
  - `count >= threshold`
  - `sum(quality_score) >= threshold`
  - `sum(quality_score × reliability_posterior) >= threshold`
- 主要看：误触发率、漏报率、规则后续被证伪率

### 采用建议

- **建议状态**：`pilot`
- **原因**：如果实现成“短期后验 + 可衰减画像”，就兼容当前协议哲学；否则风险很高

---

## 方向 4：把 Shepherd Effect 机制化为“升级路由”

### 相关论文

- Chen, Zaharia, Zou, **FrugalGPT: How to Use Large Language Models While Reducing Cost and Improving Performance**
- Ong et al., **RouteLLM: Learning to Route LLMs with Preference Data**

### 论文给出的核心启发

这两条线共同说明一件事：

- 不是所有 query / task 都值得直接交给强模型
- 但也不是所有 query / task 都适合便宜模型
- 更优策略通常是**按任务特征路由**，在成本和质量之间做动态平衡

对白蚁协议来说，这与 Shepherd Effect 高度同构：

- 强模型最有价值的时刻，不是去做机械提交
- 而是去做：高风险决策、模板播种、规则判断、复杂恢复、跨模块新探索
- 弱模型则继续做大部分标准执行和局部修补

### 对协议的直接映射

可以把“强模型是否应接管 / 先手”变成一个显式 router，而不是口口相传的经验：

```text
escalate_to_strong_model if any:
  - signal 涉及新模块或新模式
  - signal 依赖深度高
  - 已 stale / parked 超过阈值
  - 该任务可能产出可提升为 rule 的 observation
  - 当前 .birth 缺少高质量 behavioral_template
```

弱模型优先处理：

- 已有模板的执行型任务
- 局部修补
- 已知模式复用
- 低依赖、低风险 signal

### 我对落地价值的判断

**极高，而且是最能把既有实证（A-005 / A-006）升格为协议机制的一步。**

当前协议已经知道 Shepherd Effect 存在，但还没有一个明确的“何时升级到强模型”的规则。FrugalGPT / RouteLLM 提供的不是现成代码，而是一个非常合适的决策框架。

### 建议实验

三组对照：

1. **always-weak**：全部弱模型
2. **always-strong**：关键阶段和执行都由强模型做
3. **router**：只在高风险/高杠杆 signal 升级

指标：

- cost-adjusted completion rate
- 高质量 observation 产出率
- rule-worthy observation 产出率
- 平均 signal 完成时延

### 采用建议

- **建议状态**：`pilot`
- **原因**：这方向最能直接提升“效果/成本比”，而且完全契合仓库现有 Shepherd Effect 叙事

---

## 方向 5：`.birth` 应从扁平摘要升级为“分层检索”

### 相关论文

- Sarthi et al., **RAPTOR: Recursive Abstractive Processing for Tree-Organized Retrieval** (2024)

### 论文给出的核心启发

RAPTOR 的价值不在于“又一种 RAG”，而在于它证明了一点：

- 当语料又长又杂时
- 只做扁平 chunk 检索，容易丢掉整体结构
- 用**分层摘要树**，可以在不同抽象层级之间切换，兼顾全局和局部

这对白蚁协议正中要害，因为 `.birth` 正在做的事情本质上就是：

- 在很小的 token 预算里
- 从 signals / rules / pheromone / handoff / recovery hints 中
- 选出“此刻最该看的少量上下文”

### 对协议的直接映射

不是要真的上复杂向量数据库，而是借 RAPTOR 的思想，把 `.birth` 生产改成三层：

1. **root summary**：当前蚁丘状态（phase / alarm / top risks）
2. **module summary**：与当前 signal 最相关的模块摘要
3. **leaf evidence**：一条最有模仿价值的 behavioral_template / observation_example

这样 `.birth` 就不再是“把所有东西压扁后截断”，而是：

- 先给全局框架
- 再给局部任务上下文
- 最后给一个具体模仿样本

### 我对落地价值的判断

**中高价值，但实现复杂度高于前几项。**

它解决的是 `.birth` 信息组织效率，而不是 signal 选择或 observation 质量本身。因此收益会比较“间接”，需要更精细的实验设计才能看到差异。

### 建议实验

- 对照组：当前 `.birth` 生成逻辑
- 处理组：root / module / leaf 三层压缩
- 观察：
  - `.birth` token 数
  - agent 首次 claim 成功率
  - behavioral_template 跟随质量
  - “读了但没用上”的无效内容比例

### 采用建议

- **建议状态**：`investigate`
- **原因**：方向正确，但实现和评估都更复杂，优先级低于 task routing 和 reliability weighting

---

## 方向 6：失败经验应显式沉淀，而不是只留下模糊 handoff

### 相关论文

- Shinn et al., **Reflexion: Language Agents with Verbal Reinforcement Learning**

### 论文给出的核心启发

Reflexion 的可迁移点不在“自我反思”这个口号，而在它把失败反馈转成了可复用的语言记忆：

- 为什么失败
- 哪一步有问题
- 下次应避免什么

对白蚁协议来说，这意味着：

- stale / parked / failed command / wrong diagnosis
- 不应该只体现在散落的 WIP 或下一任自己重看日志
- 而应当有一条被结构化沉积的 `failure_memory`

### 对协议的直接映射

可新增一种低频高价值沉积，而不是让所有 trace 都进入 `.birth`：

```text
failure_memory:
  trigger: "stale-after-claim"
  context: "src/auth + token refresh"
  failed_attempt: "patched middleware only"
  why_failed: "real bug was retry loop in client"
  avoid_next_time: "不要先改 middleware；先检查 refresh caller"
```

`.birth` 只在当前 signal 与该失败记忆高度相关时注入 1 条。

### 我对落地价值的判断

**中高价值，但一定要严控格式和准入。**

如果没有强门禁，这类“反思”很容易退化成空话、废话、鸡汤式总结，反而污染环境。

### 建议实验

- 只允许从 `parked` / `stale` / `build failed` 三类事件生成 failure memory
- 必须包含具体路径、命令、失败现象、下一步禁忌
- 观测：重复错误率、同类 signal 二次修复时延、failure memory 复用率

### 采用建议

- **建议状态**：`investigate`
- **原因**：潜力很大，但对沉积质量门槛要求很高

---

## 架构层结论：白蚁协议的大方向是对的，不需要回到 master-slave

### 相关论文

- Nii, **The Blackboard Model of Problem Solving and the Evolution of Blackboard Architectures** (1986)
- Salemi et al., **LLM-Based Multi-Agent Blackboard System for Information Discovery in Data Science** (2025/2026)

### 结论

这两篇论文组合起来，给出一个很清楚的判断：

1. **经典 AI 时代**就已经知道，blackboard 适合处理：
   - 问题结构复杂
   - 多知识源异步贡献
   - 不能提前精确定义谁负责什么

2. **LLM 时代**的新论文又重新证明：
   - 当文件多、上下文大、异构性强时
   - blackboard / shared environment 路线比 rigid master-slave 更有伸缩性

所以对白蚁协议最重要的结论不是“要不要改成对话式多 agent”。相反，调研结果支持：

> **应继续坚持环境承载智慧、agent 通过环境间接协作的路线。**

真正该补的是：

- 推荐机制
- 可靠性加权
- 升级路由
- 分层压缩

而不是重新引入高带宽 agent 对话。

### 采用建议

- **建议状态**：`keep`
- **原因**：这是架构确认，不是新功能提案

---

## 不建议直接照搬的方向

这次调研也反向排除了几类“看上去先进、实际上不适合白蚁协议”的路线：

### 1. 不要回到强中心化调度

拍卖式、master-slave、中央规划器在很多文献里有效，但对白蚁协议代价太高：

- 会重新引入单点瓶颈
- 要求中心节点知道所有 agent 能力
- 不符合“环境驱动、自组织 claim”的基本哲学

### 2. 不要把可靠性加权实现成永久身份等级

Dawid-Skene 启发很强，但如果落地成：

- “这个 agent 永远是低级”
- “这个平台永远不可信”

就会违背 v5 的方向。更合理的是：

- 短期后验
- 可衰减
- 基于证据表现而不是 agent 身份标签

### 3. 不要把 Reflexion 类机制做成泛化空话池

失败记忆只有在**高度具体**时才有价值。凡是下面这类都不该进入环境：

- “注意多思考”
- “要更小心”
- “先理解需求再动手”

这些不是记忆，是噪声。

---

## 最值得立刻启动的 3 个实验

如果只做最小而高杠杆的下一步，我建议顺序如下：

### 实验 A：`recommended_task`（Gerkey + Theraulaz）

目标：提升首次完成率，降低错配 claim。

最小实现：

- `.birth` 保留 `top_task`
- 新增 `recommended_task`
- 评分由 `urgency × affinity × readiness × finish_probability` 组成

判定指标：

- 首次完成率
- claim 后 park/stale 率
- 冷门 signal 清空速度

### 实验 B：`reliability_weighted_emergence`（Dawid-Skene）

目标：降低弱模型 observation 对规则涌现的污染。

最小实现：

- 不改 deposit 接口
- 只改 emergence / promotion 打分
- `weight = quality_score × posterior_reliability`

判定指标：

- 假规则触发率
- 后续被证伪率
- 高价值规则的保留率

### 实验 C：`escalation_router`（FrugalGPT / RouteLLM）

目标：把 Shepherd Effect 从经验现象变成正式机制。

最小实现：

- 为 signal 计算 `risk_score`
- 高风险 signal 在 `.birth` 中明确标记“优先强模型 / 需要播种模板”
- 低风险 signal 继续开放给弱模型抢占

判定指标：

- 成本/质量比
- 高质量 observation 率
- signal 完成时延

---

## 最终判断

### 适合白蚁协议、且最值得吸收的论文结论

1. **Gerkey & Matarić 2004**：最适合直接强化 signal 推荐和 claim 适配度
2. **Theraulaz et al. 1998**：最适合强化连续行为偏置和非硬分类分工
3. **Dawid & Skene 1979**：最适合强化 observation / rule emergence 的抗噪能力
4. **FrugalGPT + RouteLLM**：最适合把 Shepherd Effect 机制化，提升效果/成本比
5. **RAPTOR**：最适合下一阶段优化 `.birth` 压缩结构
6. **Reflexion**：适合做失败记忆，但必须高门槛准入

### 不建议的结论

- 不建议把白蚁协议改造成 conversation-first multi-agent framework
- 不建议回到 central scheduler / master-slave
- 不建议重新引入永久 agent tier/caste 判断来替代环境侧评分

### 一句话总结

> **这次调研的答案不是“找一篇论文把白蚁协议推翻重做”，而是：继续保留白蚁协议的黑板/环境路线，用“连续分工 + 效用推荐 + 可靠性加权 + 升级路由 + 分层压缩”这五个机制，把它从经验有效推进到机制上更稳。**

---

## 参考文献

1. H. Penny Nii. **The Blackboard Model of Problem Solving and the Evolution of Blackboard Architectures**. *AI Magazine*, 1986. DOI: `10.1609/aimag.v7i2.537`
2. Guy Theraulaz, Eric Bonabeau, Jean-Louis Deneubourg. **Response threshold reinforcement and division of labour in insect societies**. *Proceedings of the Royal Society B*, 1998. DOI: `10.1098/rspb.1998.0299`
3. Brian P. Gerkey, Maja J. Matarić. **A Formal Analysis and Taxonomy of Task Allocation in Multi-Robot Systems**. *International Journal of Robotics Research*, 2004. DOI: `10.1177/0278364904045564`
4. A. P. Dawid, A. M. Skene. **Maximum Likelihood Estimation of Observer Error-Rates Using the EM Algorithm**. *Journal of the Royal Statistical Society Series C*, 1979. DOI: `10.2307/2346806`
5. Lingjiao Chen, Matei Zaharia, James Zou. **FrugalGPT: How to Use Large Language Models While Reducing Cost and Improving Performance**. arXiv:2305.05176
6. Isaac Ong et al. **RouteLLM: Learning to Route LLMs with Preference Data**. arXiv:2406.18665 / ICLR 2025
7. Parth Sarthi et al. **RAPTOR: Recursive Abstractive Processing for Tree-Organized Retrieval**. arXiv:2401.18059
8. Noah Shinn et al. **Reflexion: Language Agents with Verbal Reinforcement Learning**. arXiv:2303.11366 / NeurIPS 2023
9. Alireza Salemi et al. **LLM-Based Multi-Agent Blackboard System for Information Discovery in Data Science**. arXiv:2510.01285
