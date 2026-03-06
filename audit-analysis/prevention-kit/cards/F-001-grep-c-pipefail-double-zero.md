---
id: F-001
title: "grep -c 在 pipefail 下双零输出与管道异常"
severity: high
status: active
scope: both
tags: [grep-c, pipefail, subshell, sigpipe]
summary: "脚本在零匹配场景出现 0\\n0 或异常退出时，先查这张卡。"
last_updated: 2026-03-06
source:
  - "audit-analysis/REGISTRY.yaml (F-001, TF-001)"
  - "docs/plans/2026-03-01-grep-c-feedback-loop-mvp-design.md"
---

# 背景

在 `set -euo pipefail` 下，`grep -c` 的“零匹配返回码”为 1，容易触发脚本提前退出，或者在 `|| echo 0` 组合中输出双零，最终污染计数和分支逻辑。

## 症状（How to Recognize）

- 计数结果出现 `0` 和 `0` 两行（`0\n0`）。
- 零匹配本应是正常分支，却触发脚本失败退出。
- `grep | head` 在特定输入规模下出现 SIGPIPE 相关异常。

## 快速判断（2 分钟）

1. 搜索可疑模式：`rg -n "grep -c|\\|\\| echo 0|grep .*\\| head" templates/scripts`
2. 在零匹配样本上跑一次脚本，观察是否出现双零或退出码异常。
3. 检查是否存在“管道后在 subshell 内改变量”的写法（父 shell 读不到更新值）。

## 根因模型

- `grep -c` 零匹配时输出 `0` 但返回码是 `1`。
- `set -e` + `pipefail` 会把这个返回码当作失败传播。
- 用 `|| echo 0` 兜底可能导致“原本的 0 + 兜底的 0”双输出。

## 标准修复（Standard Fix）

1. 对零匹配分支显式处理，不依赖 `|| echo 0` 拼接。
2. 避免“管道内更新关键变量”；必要时改为重定向或临时文件。
3. 对 `grep | head` 这类链路加稳健处理，规避 SIGPIPE 误伤主流程。

## 预防清单（Prevention Checklist）

- [ ] 新脚本不再使用 `grep -c ... || echo 0` 模式。
- [ ] 所有计数逻辑在零匹配下有明确测试样例。
- [ ] `set -euo pipefail` 环境下脚本行为与预期一致。

## 回归验证（Regression）

1. 零匹配输入：脚本返回成功，计数仅一行 `0`。
2. 正常匹配输入：计数正确且无回归。
3. 大输入/截断输入：无 SIGPIPE 误退出。

## 适用边界与副作用

- 适用边界：Bash 脚本 + 严格错误模式。
- 可能副作用：修复后若吞掉真实错误，会降低告警灵敏度；需区分“零匹配”和“命令异常”。
- 不建议场景：无严格模式且仅一次性临时脚本（仍建议按标准写法）。

## 参考

- 修复记录：`TF-001`（`field-export-audit.sh` / `field-cycle.sh` / `field-deposit.sh`）
- 审计来源：`F-001`

