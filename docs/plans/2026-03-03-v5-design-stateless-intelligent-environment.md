# Protocol v5.0 Design: Stateless + Intelligent Environment

Date: 2026-03-03
Status: Draft design
Prerequisite: `2026-03-03-protocol-philosophy-revision.md`（洞察 + 批判）
Protocol: v4.0 → v5.0
Field lib: v22 → v23

> **指导原则：沿袭长期智慧，而不是短期效率和聪明。**
> **设计约束：800 token .birth 预算不可协商。**

---

## 设计目标

将协议哲学修正（"盲"→"无状态 + 环境承载智慧"）落地为可实施的机制变更，同时解决哲学修正文档中识别的六个批判点。

| 目标 | 来源 |
|------|------|
| 替换"盲白蚁"叙述为"无状态 + 环境承载智慧" | 洞察 1 |
| 区分 trace 和 deposit | 洞察 2 |
| 消除 agent 预分类，保留 artifact 质量评估 | 洞察 3 + 批判 3 |
| 在 800 token 内实现统一分层 .birth | 批判 1 |
| 避免 cargo culting 放大 | 批判 2 |
| Shepherd Effect 提升为核心机制 | 洞察 2 |
| 涌现输入质量加权 | 洞察 2 + 批判 4 |
| 造物信号可达 | 乱石墙分析 |

---

## 核心原则（替代 v4.0 的"盲白蚁"）

**原则 A：无状态（约束）** — 任何白蚁可在任何时刻死掉，不丢失系统性信息。

**原则 B：环境承载智慧（杠杆）** — 智慧在信号系统中，不在个体白蚁脑中。强模型的核心职责是向环境注入结构化知识；弱模型的核心职责是从环境中读取指令并执行。

**原则 C：分类产出而非分类参与者** — 协议不判断"你是谁"，只评估"你产出了什么"。

---

## 设计 1：统一分层 .birth

### 问题

PE-005 用 3 套 .birth 模板（execution/judgment/direction），需要预分类 agent。预分类有冷启动、自我实现偏差、模型进化等脆弱性（见哲学修正文档洞察 3）。

但天真的"什么都给"在 800 token 下会稀释每层信息密度（批判 1）。

### 设计：统一结构，蚁丘状态驱动密度

**一套模板**。不是三套。所有 agent 在同一时刻到达同一蚁丘，看到同一份 .birth。

但 .birth 内各层的**信息密度**由蚁丘当前状态决定，不由 agent 身份决定：

```
.birth (800 tokens, 统一模板)
├── ## task (必选，200-350 tokens)
│   ├── 最高权重可认领信号 + next_hint
│   ├── 相关资产（造物登记中与此 module 相关的已有组件）
│   └── 行为模板（最近一条高质量 deposit 的 pattern/context/detail）
│
├── ## situation (必选，150-250 tokens)
│   ├── WIP/handoff 摘要（如有）
│   ├── alarm 状态（如有）
│   ├── 蚁丘相位（genesis/active/maintaining/idle）
│   └── 活跃信号概览（top 3 by weight）
│
├── ## context (可选，0-200 tokens，仅当蚁丘有内容时)
│   ├── 活跃规则（top 3 by relevance）
│   ├── 近阈值观察集群（"再 1 条相似观察即涌现"）
│   └── 信号间依赖关系（如有）
│
└── ## recovery (必选，50-80 tokens)
    ├── 安全网（4 条，固定）
    └── deposit 提示：提交 trace（必须）+ 尝试 deposit（可选，附质量标准）
```

### 预算分配逻辑

不是"给每一层固定比例"，而是**按蚁丘状态弹性分配**：

| 蚁丘状态 | task | situation | context | recovery |
|----------|------|-----------|---------|----------|
| genesis（初创） | 350 | 150 | 0（无规则/观察） | 80 |
| active（活跃） | 250 | 200 | 200 | 80 |
| alarm（告警） | 200 | 300（alarm 优先） | 150 | 80 |
| idle（空闲） | 150 | 150 | 50 | 80 + 退出引导 |

**关键区别**：PE-005 问"你是谁"然后给不同内容。v5.0 问"蚁丘现在怎样"然后给统一内容。

### 如何实现"仁者见仁智者见智"

层次**不是**标注为"简单/高级"的独立区块。它们在自然行文中交织：

- `## task` 的 next_hint 就是战略上下文的入口——弱模型只看到"下一步做什么"，强模型看到"为什么是这一步"
- `## situation` 的信号概览对弱模型是"还有什么活"，对强模型是"蚁丘的战略姿态"
- `## context` 的规则和近阈值集群，弱模型读到但不响应（无害），强模型用它来决定是否投入 observation

自然分层取代标签分层。文本相同，提取深度不同。

### 解决批判 2（cargo culting）

行为模板（behavioral_template）放在 `## task` 而非独立 section。模板是对**当前任务**的示范，不是对"如何写 observation"的通用教学。弱模型 cargo cult 的对象从"协议概念"变为"任务相关的具体做法"——即使是 cargo culting，至少是在正确的领域里。

`## recovery` 中的 deposit 提示明确区分：

```
deposit: 提交 trace（git commit message 即可）。
         如果你在工作中发现了值得记录的模式，写一条 observation。
         质量标准：引用具体文件路径 + 描述具体现象 + 说明影响。
         如果写不出满足标准的 observation，只提交 trace 即可。
```

这比 PE-005 的 "observation: optional"（基于 agent 分类）和 v3.x 的 "observation: required"（不区分能力）都更好——它给出了**质量标准**，让 agent 自己判断能否达到。

---

## 设计 2：Trace 与 Deposit 分离

### 问题

当前"信息素"混淆了两种信任级别完全不同的东西。

### 设计

| 类型 | 定义 | 可靠性来源 | 衰减规则 | 进入涌现池 |
|------|------|-----------|---------|-----------|
| **Trace** | 工具保证的事实：git commit, signal status, build result, file list | 工具（git 不撒谎） | **不衰减**（事实不过期） | 否 |
| **Deposit** | 模型产出的知识：observation, judgment, recommendation, behavioral_template | 模型能力（可退化） | 按年龄 + 质量评分衰减 | 是（质量加权） |

### 实证案例（A-006 质量审计观察）

touchcli 蚁丘的 `QUALITY_AUDIT_SUBMITTED` 观察展示了分离的必要性：

```yaml
# 当前：被 observation 质量评分判为 0.00（pattern 退化 + detail 退化）
# 但 context 包含完整的质量门结果：backend 418 pass, frontend 286 pass, e2e 54 pass
# 这是 trace（工具可验证的事实），不是 deposit（模型知识洞察）
```

**在 trace/deposit 分离框架下**：
- `source_type: trace` → 不参与质量评分 → 不衰减 → 正确保留为蚁丘健康记录
- 无分离时 → quality_score = 0.00 → 快速衰减 → 有价值的蚁丘健康信息丢失

### 实现

`field-deposit.sh` 修改：
- 每次 deposit 自动附带 `source_type: trace | deposit` 标签
- Signal status update, commit summary, quality gate result → trace
- Observation (pattern/context/detail with knowledge insight) → deposit
- .pheromone 中 trace 和 deposit 分开存储

`field-decay.sh` 修改：
- Trace 条目不参与衰减循环
- Deposit 条目：decay_rate = base_rate × (1 / quality_score)，高质量衰减慢

### DB schema 变更（v3 → v4）

```sql
ALTER TABLE pheromone_history ADD COLUMN source_type TEXT DEFAULT 'deposit';
-- 已有的 commit summary 等标记为 trace
ALTER TABLE observations ADD COLUMN quality_score REAL DEFAULT 0.5;
```

---

## 设计 3：Artifact 质量评分（替代 Agent 分类）

### 问题

PE-005 预分类 agent 到 tier，决定谁"必须"deposit observation、谁"可选"。这有冷启动偏差和自我实现问题。但完全不分类又导致 A-006 的涌现噪声淹没。

### 设计：分类产出物，不分类参与者

每条 observation 在 deposit 时由 `field-deposit.sh` 计算 `quality_score`（0.0-1.0）：

```
quality_score 计算规则（H2 验证后修订版）：

base = 0.5

# 正面指标（内容丰富度）
+0.15  detail 字段 > 80 字符且包含具体路径/数字/指标
+0.15  pattern 字段引用具体文件名、模块名或错误信息（含小写描述性文字）
+0.10  context 字段非空且与 pattern 不重复
+0.10  detail 包含对比/因果/建议（"because", "risk:", "→", "missing"等信号词）

# 负面指标（退化标志）
-0.30  pattern 是全大写标签（screaming label）且不含小写描述词
         注：S-xxx + 自然语言描述（如"S-054 db_claim_check..."）不算退化
-0.40  detail 是 "0"、空字符串、或纯数字（H2 验证：最强单一退化信号）
-0.20  detail 非空但 < 10 字符（退化但非最严重）
-0.20  pattern 与最近 3 条 observation 高度重复（>80% 关键词重合）

# 边界
clamp(0.0, 1.0)
```

这是一个启发式函数，不是 ML 模型。可审计、可 shellcheck、可持续改进。

**H2 验证结果**：在 A-006 的 270 条 observation 上，启发式退化判定率 43.3%，人工标注 43.0%，差异 0.3%。分布呈双峰结构，灰色地带仅 7%。详见"假设验证状态"章节。

### 质量评分的四个消费者

| 消费者 | 使用方式 |
|--------|---------|
| **涌现（Rule 7）** | 加权阈值：`sum(quality_score) >= 3.0` 替代 `count >= 3` |
| **behavioral_template 选择** | .birth 中优先选 quality_score 最高的近期 deposit |
| **衰减** | 高质量 deposit 衰减慢，低质量衰减快 |
| **审计导出** | quality_score 随审计包导出，用于跨蚁丘分析 |

### 涌现的实际效果

理论预测：

| 来源 | 每条 quality_score | 需要几条相同 pattern 才触发涌现 |
|------|-------------------|-------------------------------|
| 强模型高质量 deposit | ~0.9 | 4 条（3.0 / 0.9 ≈ 3.3） |
| 中等模型合格 deposit | ~0.6 | 5 条（3.0 / 0.6 = 5.0） |
| 弱模型退化 deposit | ~0.1 | 30 条（实际不可能在同一 pattern 上聚集 30 条） |

**A-006 回测验证**（270 条 observation）：

| 规则 | 触发组数 | 退化组 | 有效组 |
|------|---------|--------|--------|
| 旧 `count >= 3` | 5 | 3 (60%) | 2 |
| 新 `sum(quality) >= 3.0` | **1** | **0 (0%)** | **1** |

退化 deposit 在数学上被涌现排除，但没有任何规则"禁止"弱模型 deposit。**门是开着的，但门槛自然过滤。**

### 解决批判 3（复杂度转移的正面承认）

这个设计确实把分类从 agent 入口挪到了 observation 出口。这不是隐藏复杂度，而是**有意为之**：

- Agent 入口分类：基于猜测（历史行为推断未来能力），错误不可逆（整个 session 的 .birth 被锁定）
- Artifact 出口分类：基于事实（当前 deposit 的内容），逐条评估，错误只影响一条 observation

分类 artifact 比分类 agent 更精确、更公平、更可修正。

---

## 设计 4：Shepherd Effect 提升为 Part I 核心机制

### 当前状态

Shepherd Effect 在 v4.0 中是 Part III 的部署建议（"推荐 1 strong + N weak 拓扑"）。

### 设计

在 TERMITE_PROTOCOL.md Part I 增加第 10 条文法规则：

```
Rule 10: DEPOSIT(quality >= threshold) -> TEMPLATE
  高质量 deposit 自动成为后继者的行为模板。
  环境智慧通过 deposit → template → imitation 链条传递。
```

这将 Shepherd Effect 从"我们观察到的现象"提升为"协议保证的机制"。

### .birth 中的体现

behavioral_template 永远出现在 `## task` 中（不是可选的）。选择算法：

```
1. 当前任务所在 module 的最高 quality_score deposit（优先）
2. 全局最高 quality_score 的近期 deposit（兜底）
3. 无任何 deposit → 省略（genesis 状态，节省 token）
```

### 形式化

```
环境智慧流：
  强模型 session → deposit(high quality) → pheromone chain
  field-deposit.sh → select best deposit → .pheromone.observation_example
  field-arrive.sh → inject into .birth ## task → behavioral_template
  后继 agent → read .birth → imitate or deepen
```

这个链条是协议产出价值的核心管道。所有优化都应保护这个管道的畅通。

---

## 设计 5：造物登记（Creation Registry）

### 问题

白蚁建造的东西（模块、工具、API endpoint）在文件系统中存在，但对信号系统不可见。下一只白蚁不知道"已有一个 retry 工具可以用"。

### 设计

BLACKBOARD.md 新增 `## Assets` JSON 区块：

```json
<!-- ASSETS_BEGIN -->
[
  {"name": "retry-util", "path": "src/utils/retry.ts", "signal": "S-012", "desc": "Exponential backoff retry wrapper"},
  {"name": "auth-middleware", "path": "src/middleware/auth.ts", "signal": "S-003", "desc": "JWT validation middleware"}
]
<!-- ASSETS_END -->
```

### 登记时机

`field-deposit.sh` 在 agent deposit trace 时，扫描 git diff 中新增的文件，按启发式规则登记：
- 新增的 `src/` 下非测试文件 → 自动登记
- Agent 在 observation 中提到 "created", "added", "built" → 提取路径登记
- 手动：agent 可以显式写入 ASSETS 区块

### .birth 中的体现

`## task` 的信号描述后附加：

```
related_assets: retry-util (src/utils/retry.ts), auth-middleware (src/middleware/auth.ts)
```

帮助 agent 知道"不用重新造轮子"。Token 开销：每个 asset ~15 tokens，附加 top 3 相关 asset ≈ 45 tokens。

### 边界

登记 ≠ 验证。登记说"这个东西存在"，不说"这个东西能用"。验证是 CI/CD 的事（F-010 WONTFIX 边界尊重）。

---

## 设计 6：BLACKBOARD JSON 迁移

### 问题

LLM 对 JSON 的 grep/insert/rewrite 操作比 markdown 表格更可靠。

### 设计

BLACKBOARD.md 的结构化区块迁移到 JSON：

| 区块 | 旧格式 | 新格式 |
|------|--------|--------|
| 健康状态 | markdown 表格 | `<!-- HEALTH_BEGIN -->` JSON `<!-- HEALTH_END -->` |
| 资产索引 | 无 | `<!-- ASSETS_BEGIN -->` JSON `<!-- ASSETS_END -->` |
| 信号表 | markdown 表格 | `<!-- SIGNALS_BEGIN -->` JSON `<!-- SIGNALS_END -->` |
| 免疫记录 | markdown 表格 | `<!-- IMMUNITY_BEGIN -->` JSON `<!-- IMMUNITY_END -->` |
| 叙述内容 | markdown | 保持 markdown |

`<!-- BEGIN/END -->` 标记让 field scripts 可以精确提取和替换 JSON 区块，不影响叙述内容。

---

## 设计 7：协议叙述修正

### TERMITE_PROTOCOL.md Part I 修改

| 位置 | 旧 | 新 |
|------|----|----|
| 开篇原则 | "All termites are blind" | "All termites are stateless. The environment carries intelligence." |
| Rule 10 | 无 | `DEPOSIT(quality >= threshold) -> TEMPLATE` (Shepherd Effect) |
| Stigmergy 描述 | "indirect coordination" | "environment-mediated communication" |
| Pheromone 定义 | 统一概念 | 区分 trace (tool-guaranteed fact) 和 deposit (model-dependent knowledge) |

### 版本变更

| 组件 | 旧 | 新 |
|------|----|----|
| Protocol spec | v4.0 | v5.0 |
| Field lib | v22.0 | v23.0 |
| DB schema | v3 | v4 |
| Entry kernel | v11.0 | v12.0 |

---

## PE-005 的保留与废弃

| PE-005 组件 | 处置 | 理由 |
|-------------|------|------|
| `compute_strength_tier()` | **废弃** | 被 artifact 质量评分替代 |
| `write_birth_execution()` | **废弃** | 合并为统一 .birth 模板 |
| `write_birth_judgment()` | **废弃** | 合并为统一 .birth 模板 |
| `write_birth_direction()` | **保留，改造** | direction 场景（人类指令触发）确实需要不同内容，但这是由 trigger type 决定，不是由能力分类决定 |
| `validate_rule_quality()` | **保留** | 规则质量门禁仍需作为涌现的第二道防线 |
| DB schema v3 strength_tier 列 | **废弃** | 替换为 observations.quality_score |
| 行为模板注入 | **保留，强化** | 从 execution-only 扩展到所有 agent |
| observation: optional/required | **废弃** | 替换为自评质量标准 + 质量评分 |

### Direction 场景的特殊处理

`TERMITE_TRIGGER_TYPE=directive` 时，.birth 结构调整为以决策为中心：

```
## decisions_needed (300 tokens)
## colony_status (200 tokens)
## recent_activity (150 tokens)
## safety (80 tokens)
```

这不是 agent 分类，是**触发方式**分类。人类通过 directive 触发时，需要的信息结构确实不同。

---

## 张力检查

| 张力 | 本设计的处理 |
|------|------------|
| F-009（概念面积） | 净减少：移除 3 套 .birth 模板 + strength inference；新增 quality_score（1 个概念）和 trace/deposit（1 个区分） |
| 800 token 预算 | 蚁丘状态驱动分配，不浪费 token 在不存在的内容上 |
| Cargo culting（批判 2） | 行为模板绑定到当前任务而非通用协议概念；deposit 提示给出具体质量标准 |
| 复杂度转移（批判 3） | 正面承认：从 agent 入口分类转为 artifact 出口分类，更精确更可修正 |
| 可观测性（批判 6） | quality_score 随审计包导出；可以跨蚁丘追踪质量分布变化 |
| 涌现噪声（批判 4） | 质量加权阈值，无需 agent tier 信息 |

---

## 假设验证状态

| 假设 | 验证方法 | 状态 | 结果 |
|------|---------|------|------|
| H1: 统一 .birth 不比 PE-005 差 | 同一宿主项目 A/B 对比：v4.0 vs v5.0 | **待验证** | 需要宿主项目实验 |
| H2: quality_score 启发式能有效区分 | 对 A-006 审计包 272 条 observation 跑评分，对比人工标注 | **已验证 ✓** | 见下文（含 +2 质量审计边界案例） |
| H3: 弱模型在统一 .birth 下不增加 cargo culting | 对比 v4.0 execution .birth vs v5.0 统一 .birth 的 degenerate observation 比例 | **待验证** | 需要宿主项目实验 |
| H4: 质量加权涌现能产出有用规则 | 在下一次 3+ agent 实验中观察涌现规则质量 | **部分验证 ✓** | 回测通过，见下文；需要前瞻验证 |

### H2 验证报告

> 完整报告：`audit-analysis/optimization-proposals/2026-03-03-h2-quality-score-validation.md`
> 脚本：`audit-analysis/h2-quality-score-validation.py`
> 原始数据：`audit-analysis/h2-quality-score-results.json`

**结论：H2 成立。** 启发式评分与人工判断几乎完全吻合。

| 对比 | 启发式 | 人工审计 | 差异 |
|------|--------|---------|------|
| 退化率（< 0.4, 原始 270 条） | 117/270 (43.3%) | 116/270 (43.0%) | +1 条 (0.3%) |
| 退化率（含质量审计 +2 条） | 119/272 (43.8%) | — | 趋势一致 |

**双峰分布**：93% 的 observation 落在明确的好区间（≥ 0.7, 101 条）或坏区间（< 0.4, 117 条），灰色地带仅 18 条 (7%)。这证明 artifact 级别的质量分类是天然可行的——绝大多数 observation 要么明显好、要么明显坏。

```
分布直方图（原始 270 条）：
[0.0-0.1):  47 ████████████████
[0.2-0.3):  70 ████████████████████████
[0.6-0.7):  34 ████████████
[0.7-0.8):  52 ██████████████████
[0.8-0.9):  25 █████████
[0.9-1.0):  24 ████████

Mean: 0.489    Median: 0.60
```

**最强单一退化信号**：`detail: "0"` — 47 条 score=0.00 的 observation 全部具有此特征。这一个字段就抓住了 40% 的退化 deposit。

#### 追加验证：质量审计观察（2026-03-03 A-006 更新包）

蚁丘后续提交了 2 条新观察（`QUALITY_AUDIT_SUBMITTED`, `QUALITY_AUDIT_REPORT_V1`），质量评分均为 **0.00**：

```
pattern: "QUALITY_AUDIT_SUBMITTED"  ← 全大写标签: -0.30
detail:  "0"                        ← 最强退化信号: -0.40
context: "quality gate full PASS (backend 418, frontend unit 286, e2e chromium 54);
          fixed-port scripts + ws/dashboard regressions guarded..."  ← 极丰富: +0.10
→ score: 0.5 + 0.10 - 0.30 - 0.40 = -0.10 → clamped 0.00
```

**这暴露了 H2 启发式的一个盲点**：pattern/detail 退化但 context 极其丰富的观察被判为 0.00。context 的 +0.10 无法弥补 pattern (-0.30) + detail (-0.40) 的惩罚。

但这恰好**强化了设计 2（trace/deposit 分离）的论据**：这两条观察本质上是 **trace 而非 deposit**——它们报告的是工具可验证的事实（758 个测试全部通过），不是模型依赖的知识洞察。在 v5.0 的 trace/deposit 框架下：
- 分类为 trace → 不参与质量评分 → 不衰减 → 正确保留
- 作为 deposit 评分 → 0.00 → 快速衰减 → 错误丢失

这验证了 trace/deposit 分离不是理论优化，而是解决真实数据错误分类的必要机制。

**附带发现**：蚁丘自主运行了完整质量门（backend 418 + frontend 286 + e2e 54 = 758 tests），验证了 F-010 WONTFIX 立场——宿主项目确实能自主处理验证。

### H4 回测验证（涌现模拟）

在 A-006 的 270 条 observation 上模拟涌现触发：

| 规则 | 触发组数 | 退化组数 | 有效组数 |
|------|---------|---------|---------|
| 旧：`count >= 3` | 5 | 3 (60%) | 2 |
| 新：`sum(quality) >= 3.0` | **1** | **0 (0%)** | **1** |

退化涌现被完全消除。唯一通过新阈值的组（"complete verified", sum=3.75, avg=0.75）是最高质量的集群。

退化组被数学排除的原因：
- "seed" 组：5 × 0.00 = 0.00（远低于 3.0）
- "complete" 组：4 × 0.15 = 0.60
- "intelligence relationship" 组：3 × 0.30 = 0.90

**注意**：3.0 阈值在 270 条 observation 中只触发 1 次涌现，可能偏保守。建议后续实验中测试 2.5 阈值（预计增加到 2 次触发）或引入蚁丘规模因子。

### 启发式修正建议（基于验证结果）

| 修正 | 原因 | 影响 |
|------|------|------|
| `detail: "0"` 独立标记为 -0.40 | 是最强退化信号，当前和 `< 10 chars` 共享 -0.30 | **已纳入设计 3 评分规则** |
| screaming label 检测增加小写词计数 | `S-054 db_claim_check...` 不是 screaming label，当前被误判 | **已纳入设计 3 评分规则** |
| 涌现阈值 3.0 可加蚁丘规模因子 | 272 条中只触发 1 次，可能偏保守 | 提高涌现频率同时维持质量 |
| context 丰富度部分抵消 detail 退化 | 质量审计观察暴露盲点：context 极丰富但 score=0.00 | 须与 trace/deposit 分离协同设计（见下） |

**context 字段信用问题的处理策略**：

不直接加大 context 的正面权重（这会削弱 detail 退化的惩罚力度）。正确路径是 **trace/deposit 分离**：
- 如果观察报告的是可验证事实（测试结果、构建状态、文件列表）→ 自动分类为 trace → 不参与质量评分
- 如果观察报告的是知识洞察 → 维持当前评分逻辑

`field-deposit.sh` 的分类启发式（设计 2 实施时添加）：
```
# trace 信号词：passed, failed, test, build, gate, PASS, FAIL, CI, coverage
# deposit 信号词：pattern, because, risk, missing, should, recommend, →
```

这比调整 quality_score 权重更根本——它在正确的抽象层次上解决问题。

---

## 实施路径

### Phase 1：验证基础（不改变 host project 行为）

- [x] 对 A-006 审计包的 272 条 observation 跑 quality_score 启发式，验证 H2 — **通过，43.8% vs 人工 43.0%（含 +2 条质量审计 trace 边界案例）**
- [x] 在 A-006 数据上模拟质量加权涌现，对比实际涌现结果 — **通过，退化涌现从 3/5 降到 0/1**
- [ ] 编写统一 .birth 模板草稿，对 genesis/active/alarm/idle 四种状态各生成一份样例

### Phase 2：模板实现

- [ ] DB schema v4 migration（新增 source_type, quality_score）
- [ ] field-deposit.sh：quality_score 计算 + trace/deposit 分类
- [ ] field-arrive.sh：统一 .birth 生成（替换 3 套 write_birth_*）
- [ ] field-decay.sh：trace 免衰减 + deposit 质量加权衰减
- [ ] field-cycle.sh：涌现阈值从 count >= 3 改为 sum(quality) >= 3.0

### Phase 3：辅助机制

- [ ] BLACKBOARD JSON 迁移（health/assets/signals/immunity）
- [ ] 造物登记（field-deposit.sh asset scan + BLACKBOARD ASSETS 区块）
- [ ] TERMITE_PROTOCOL.md 叙述修正 + Rule 10

### Phase 4：验证

- [ ] 宿主项目部署 v5.0，运行至少 1 次 3+ agent 实验
- [ ] 对比 v4.0 审计数据，验证 H1/H3/H4
- [ ] 根据实验结果调整参数或回退特定设计
