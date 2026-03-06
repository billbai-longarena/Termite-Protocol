---
id: KB-000
title: "一句话机制名"
status: parked|candidate|activated|retired
urgency: low|medium|high
cooldown_days: 30
last_updated: YYYY-MM-DD
source_docs:
  - "docs/plans/xxxx-xx-xx-xxx.md"
related_findings:
  - "F-xxx"
  - "W-xxx"
tags: [keyword1, keyword2]
summary: "30 字内：什么时候应该查这张卡。"
---

# 背景

这条发现来自哪些分析/实验文档，当前为什么先“存档不落地”。

## 问题信号（When to Consult）

- 信号 1（可观察）
- 信号 2（可观察）
- 信号 3（可观察）

## 候选机制（Candidate Mechanism）

描述建议机制，不要求立即实现。

## 激活条件（Activation Gates）

- [ ] 条件 1：至少一个宿主项目复现。
- [ ] 条件 2：至少一个量化指标可提升。
- [ ] 条件 3：有回滚路径。

## 冷却条件（Cooldown Guards）

- 同类机制在 `cooldown_days` 内不重复试验。
- 若上次实验无显著收益，自动退回 `parked`。

## 最小实验（Minimal Experiment）

1. 实验范围（最小可行，不改核心协议语法）。
2. 对照组与实验组。
3. 成功/失败判据。

## 规模化风险（Scale Risks）

- 并发放大风险：
- 噪声/误判风险：
- 行为投机风险：

## 采用建议（Adoption Recommendation）

- 当前建议：`parked` / `candidate` / `activated`
- 建议原因：
- 下次复审时间：

## 参考

- 相关卡片：
- 对应修复卡（若已有）：
- 相关提交 / 设计文档：

