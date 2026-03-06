# Prevention Kit（锦囊预防库）

目标：把审计发现沉淀成可复用的“答案卡”，让后续审计或现场排障可以直接检索到标准处置方案，而不是重复踩坑。

## 适用场景

- Nurse 在 `audit-analysis/REGISTRY.yaml` 新增了 `finding-open` 条目。
- 宿主项目出现历史上已经处理过的同类问题。
- 多模型并发时出现“看起来随机，实则高频复现”的故障模式。

## 结构

```text
audit-analysis/prevention-kit/
  README.md
  INDEX.md
  CARD_TEMPLATE.md
  cards/
    F-001-grep-c-pipefail-double-zero.md
    W-015-claim-lock-starvation.md
```

## 工作流

1. 在 `REGISTRY.yaml` 记录发现（`finding-open`）。
2. 从 `CARD_TEMPLATE.md` 新建一张卡片，文件名建议 `ID-short-title.md`。
3. 把“症状 / 根因 / 标准修复 / 预防检查 / 回归验证”写完整。
4. 在 `INDEX.md` 增加一行索引，保证可浏览。
5. 后续同类问题优先检索卡片，再决定是否需要新增规则或脚本修复。

## 快速检索

```bash
# 按发现 ID 查
./audit-analysis/scripts/find-prevention.sh W-015

# 按关键词查
./audit-analysis/scripts/find-prevention.sh "claim starvation"
./audit-analysis/scripts/find-prevention.sh "grep -c pipefail"
```

## 设计原则

- 一卡一类问题：不要把多个不相关故障塞到同一张卡。
- 面向行动：必须有“可执行检查项”，不是只写分析结论。
- 可回归：必须给出验证步骤，避免“修了但没证据”。
- 可扩展：卡片允许追加“适用边界/副作用/规模化风险”。

