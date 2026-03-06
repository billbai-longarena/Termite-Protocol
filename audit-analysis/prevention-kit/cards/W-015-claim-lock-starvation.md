---
id: W-015
title: "Claim lock starvation：孤儿锁导致多智能体空转"
severity: medium
status: active
scope: host-project
tags: [claim, starvation, concurrency, heartbeat]
summary: "多白蚁并发时出现长时间 idle heartbeat，优先检查 claim 是否形成孤儿锁。"
last_updated: 2026-03-06
source:
  - "audit-analysis/REGISTRY.yaml (W-015, TF-008)"
  - "audit-analysis/optimization-proposals/2026-03-03-touchcli-multimodel-audit.md"
---

# 背景

在高并发场景下，部分 agent 会话提前结束，但 claim 仍占用信号，其他 agent 只能持续心跳等待 TTL 过期，造成可做工作被“锁死”。

## 症状（How to Recognize）

- 长时间连续出现“idle heartbeat”，但并非无任务状态。
- `active` 信号存在，且未完成，但多数都处于 `claimed`。
- 峰值并发越高，空转尾巴越长。

## 快速判断（2 分钟）

1. 查是否存在“已无活跃 owner 但 claim 仍有效”的记录。
2. 对比 claim 创建时间与最近心跳，确认是否超过超时阈值。
3. 统计 `claimed but stale` 的信号数量，若持续上升即进入锁饥饿。

## 根因模型

- Claim 回收依赖被动过期（TTL 到点才释放）。
- 会话中断时没有及时释放 claim。
- 并发竞争下，少量孤儿锁会放大为群体级空转。

## 标准修复（Standard Fix）

1. 在 claim 过期逻辑里加入主动超时回收（按心跳跨度，而非仅 wall-clock）。
2. 将“超时释放”与“owner 存活判断”结合，减少误释放。
3. 保留审计痕迹（何时、为何自动释放）便于回溯。

## 预防清单（Prevention Checklist）

- [ ] Claim 机制支持主动回收，不只靠 TTL 自然到期。
- [ ] 释放策略有最小保守阈值（避免过于激进抢锁）。
- [ ] 高并发测试覆盖“会话中断 + 锁遗留”场景。

## 回归验证（Regression）

1. 注入孤儿锁后，系统应在阈值内自动释放并恢复任务流动。
2. 正常长任务不应被误释放（需验证 owner 活跃信号）。
3. 多智能体并发下，idle tail 显著下降。

## 适用边界与副作用

- 适用边界：有 claim/lock 机制的并发蚁丘。
- 可能副作用：阈值过短会误释放真实长任务；需结合心跳强度动态调节。
- 不建议场景：单 agent 串行项目（收益很低）。

## 参考

- 修复记录：`TF-008`（`templates/scripts/termite-db.sh`）
- 审计来源：`W-015`

