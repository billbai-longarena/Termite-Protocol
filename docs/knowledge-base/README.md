# Discovery Knowledge Base（发现型锦囊库）

目标：把 `docs/plans/` 里的“发现型文档”沉淀成可回查的知识卡，在审计遇到问题时优先检索已有思路；不满足激活条件时先存档，不急于落地，防止过度迭代。

## 适用对象

- 非紧急、探索性、假设驱动的设计发现。
- 目前证据不足以直接改模板/改规则，但未来可能复用。
- 跨蚁丘可能重复出现的问题模式与候选机制。

## 目录结构

```text
docs/knowledge-base/
  README.md
  INDEX.md
  CARD_TEMPLATE.md
  cards/
    KB-001-signal-amplification-over-noise-filtering.md
    KB-002-stateful-guidance-without-agent-classification.md
```

## 使用流程

1. 在 `docs/plans/` 完成发现型文档（分析/实验设计/比较研究）。
2. 若不紧急：创建一张知识卡到 `docs/knowledge-base/cards/`，状态设为 `parked`。
3. 写清楚“激活条件 / 冷却条件 / 规模化风险 / 最小实验”。
4. 更新 `INDEX.md`，并在审计流程中优先检索知识卡。
5. 只有当激活条件满足时，才升级为 `candidate` 或 `activated` 并进入模板迭代。

## 防过度迭代机制

- `activation_gates`：未达门槛不实施。
- `cooldown_days`：同类想法短期内不重复折腾。
- `evidence_required`：没有跨蚁丘证据，不做协议层变更。
- `rollback_condition`：规模化回归即退回 `parked`。

## 检索

```bash
# 按知识卡 ID
./audit-analysis/scripts/find-knowledge.sh KB-001

# 按审计问题关键词
./audit-analysis/scripts/find-knowledge.sh "noise filtering"
./audit-analysis/scripts/find-knowledge.sh "W-013 quality regression"
```

## 与 Prevention Kit 的分工

- `audit-analysis/prevention-kit/`：已发生问题的标准修复卡（偏“应急/纠偏”）。
- `docs/knowledge-base/`：发现型、前瞻型锦囊卡（偏“储备/决策支持”）。

