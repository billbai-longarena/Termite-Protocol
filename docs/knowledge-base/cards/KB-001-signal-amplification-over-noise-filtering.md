---
id: KB-001
title: "信号放大优先于噪声过滤"
status: parked
urgency: low
cooldown_days: 30
last_updated: 2026-03-06
source_docs:
  - "docs/plans/2026-03-04-environment-filter-insight.md"
related_findings:
  - "F-009d"
  - "W-013"
tags: [signal-amplification, noise-filtering, weak-models, quality]
summary: "当观测质量下滑时，先考虑放大高质量模板，再考虑重过滤。"
---

# 背景

环境过滤分析显示：仅靠“过滤噪声”对弱模型收益有限，而“高质量行为模板/示例放大”对结果质量提升更直接。

## 问题信号（When to Consult）

- 异构群体中观察质量明显下滑（如 W-013 场景）。
- 新增过滤规则后复杂度上升，但质量提升不显著。
- 弱模型可执行性尚可，判断质量偏低。

## 候选机制（Candidate Mechanism）

优先在 `.birth` 与信号中放大高质量范例（behavioral template / observation example），过滤机制仅做底线防护。

## 激活条件（Activation Gates）

- [ ] 至少 1 个宿主项目出现质量回落，且已确认不是脚本 bug。
- [ ] 现有模板可抽取出“高质量示例”并结构化注入。
- [ ] 可量化指标定义完成（如 observation quality rate、degenerate ratio）。

## 冷却条件（Cooldown Guards）

- 30 天内不重复尝试“重过滤大改”。
- 若一次实验后提升 < 10%，退回 `parked`，等待新证据。

## 最小实验（Minimal Experiment）

1. 仅对一个宿主项目开启“高质量模板注入”。
2. 对照组维持现状，实验组启用示例放大。
3. 比较两组 observation quality 与 degenerate 率。

## 规模化风险（Scale Risks）

- 并发放大风险：模板同质化过强，可能抑制探索。
- 噪声/误判风险：错误模板被放大，后果会被复制。
- 行为投机风险：Agent 按模板“抄格式”但不解决问题。

## 采用建议（Adoption Recommendation）

- 当前建议：`parked`
- 建议原因：洞察可信，但需要更多跨蚁丘实证来确定阈值与注入方式。
- 下次复审时间：2026-04-06

## 参考

- 相关提交 / 文档：`docs/plans/2026-03-04-environment-filter-insight.md`
- 对应修复卡（如出现具体故障）：`audit-analysis/prevention-kit/`

