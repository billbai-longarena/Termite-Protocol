---
id: KB-002
title: "不做预分类，改做环境侧分层引导"
status: parked
urgency: low
cooldown_days: 45
last_updated: 2026-03-06
source_docs:
  - "docs/plans/2026-03-03-protocol-philosophy-revision.md"
  - "docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md"
related_findings:
  - "F-009"
  - "F-009c"
tags: [classification, unified-text, environment-guidance, token-budget]
summary: "当预分类机制维护成本过高时，评估统一输入 + 环境侧引导。"
---

# 背景

哲学修正文档指出：入口预分类（强/弱模型）有误判与自证偏差风险。替代方向是统一输入框架，差异化主要由环境工件和行为引导产生。

## 问题信号（When to Consult）

- 预分类策略频繁误判并引发行为偏差。
- 为分类维护大量规则，成本持续上升。
- `.birth` 预算紧张，分类分支挤占核心状态信息。

## 候选机制（Candidate Mechanism）

保留统一骨架输入，减少入口侧“身份判定”，通过环境中的结构化信号、示例和状态机驱动差异化行为。

## 激活条件（Activation Gates）

- [ ] 至少一个项目确认“分类错误导致显著行为退化”。
- [ ] 可在不增加 `.birth` 负担的情况下提供分层引导。
- [ ] 有可回滚方案（可在 1 次升级内恢复原机制）。

## 冷却条件（Cooldown Guards）

- 45 天内不重复切换“分类/非分类”主策略。
- 若实验后性能波动 > 15%，立即冻结并复盘。

## 最小实验（Minimal Experiment）

1. 仅在 1 个试验分支关闭入口分类分支逻辑。
2. 用同一输入骨架 + 差异化环境提示做 A/B。
3. 比较任务完成率、观察质量、手工干预次数。

## 规模化风险（Scale Risks）

- 并发放大风险：统一输入可能让低能力模型受到信息噪声影响。
- 噪声/误判风险：去分类后可能失去针对性护栏。
- 行为投机风险：模型可能套模板而非理解上下文。

## 采用建议（Adoption Recommendation）

- 当前建议：`parked`
- 建议原因：方向合理，但需更多数据证明其在弱模型群体下优于分层分类。
- 下次复审时间：2026-04-20

## 参考

- 相关文档：`docs/plans/2026-03-03-protocol-philosophy-revision.md`
- 相关文档：`docs/plans/2026-03-03-v5-design-stateless-intelligent-environment.md`

