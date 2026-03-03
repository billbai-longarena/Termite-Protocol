# Signal Migration v5.0 设计文档

**日期**: 2026-03-03
**状态**: 已批准
**影响范围**: `templates/scripts/field-migrate.sh` (新建), `install.sh` (提示集成)

## 思维过程 (Prompt Chain)

1. **用户**: "刚升级了5.0，需要考虑升级的时候把老的信号转化为5.0的信号" → 提出问题：老信号缺少 v5.0 的 quality_score 和 source_type 字段
2. **探索**: 分析现有 lazy migration 实现（默认 0.5/deposit），发现不够——老信号应该根据实际内容重新计算分数
3. **用户选择**: 迁移 + 清理（主动迁移 + 低分归档）、独立脚本触发、不自动删除只标记、归档到 signals/.archive/
4. **方案对比**: 三方案（直接写入 / dry-run+确认 / 完整回滚），用户选择方案 B（dry-run + 确认执行）

## 问题

v5.0 引入了两个新的 observation 字段：
- `quality_score` (0.0-1.0): 由 `compute_quality_score()` 计算的制品质量分
- `source_type` (trace|deposit): 由 `classify_source_type()` 分类的信号来源类型

现有实现是 lazy migration：读取时默认 `quality_score=0.5, source_type=deposit`。这意味着：
- 老信号永远不会获得基于内容的真实质量评分
- trace 类型的老信号（如 build/test 结果）被错误标记为 deposit
- 质量加权涌现（Rule 7: sum ≥ 3.0）的计算基于虚假的 0.5 默认值

## 方案

### 脚本定位

**文件**: `templates/scripts/field-migrate.sh`

**接口**:
```bash
# 预览模式（默认）—— 只输出报告，不改任何文件
./scripts/field-migrate.sh

# 执行模式 —— 实际写入 + 归档
./scripts/field-migrate.sh --apply

# 强制重算（覆盖已有 quality_score）
./scripts/field-migrate.sh --apply --force

# 只迁移特定信号
./scripts/field-migrate.sh --apply O-001 O-003
```

**依赖**: source `field-lib.sh`（复用 `compute_quality_score`, `classify_source_type`, `yaml_read`, `yaml_write`, `db_*` 系列函数）

**归档阈值**: quality_score < 0.3 → 移到 `signals/.archive/observations/`

**幂等性**: 已有 `quality_score` 字段的信号跳过（除非 `--force`）

### 迁移逻辑流程

```
field-migrate.sh 执行流程：

1. source field-lib.sh（获取所有工具函数）
2. 解析参数：--apply / --force / 具体信号 ID 列表
3. 确定信号目录：signals/observations/*.yaml
4. 对每个 observation YAML 文件：
   a. yaml_read id, pattern, context, detail, quality_score
   b. 如果已有 quality_score 且非 --force → 跳过（已迁移）
   c. 调用 compute_quality_score(pattern, context, detail) → score
   d. 调用 classify_source_type(pattern, context) → type
   e. 预览模式：打印结果
   f. --apply 模式：
      - yaml_write quality_score, source_type 到文件
      - 如果 score < 0.3：mkdir -p signals/.archive/observations/ && mv
5. 如果有 DB：
   a. UPDATE observations SET quality_score=?, source_type=?
      WHERE id=? AND (quality_score IS NULL OR quality_score = 0.5)
   b. --force 时去掉 WHERE 条件中的限制
6. 打印汇总报告
```

**关键决策**:
- DB 和 YAML 双写（保持一致性）
- 归档只移 YAML 文件，DB 中标记 `quality = 'archived'`（不删行）
- 归档目录保持原始子目录结构

### install.sh 集成

在 `install.sh --upgrade` 流程末尾添加提示（不自动执行）：
```
[MIGRATE] 检测到旧版本信号。运行以下命令预览迁移：
  ./scripts/field-migrate.sh
确认后执行：
  ./scripts/field-migrate.sh --apply
```

### 输出格式

**dry-run（默认）**:
```
=== 信号迁移预览 (v5.0) ===

  O-001  score=0.75  type=deposit  [保留]
  O-002  score=0.60  type=trace    [保留]
  O-003  score=0.85  type=deposit  [保留]
  O-004  score=0.20  type=deposit  [→ 归档]
  O-005  score=0.10  type=deposit  [→ 归档]

--- 汇总 ---
  总计: 5 个 observation
  保留: 3  归档: 2
  trace: 1  deposit: 4
  平均 quality_score: 0.50

运行 ./scripts/field-migrate.sh --apply 执行迁移
```

**--apply 执行**:
```
=== 执行信号迁移 (v5.0) ===

  ✓ O-001  score=0.75  type=deposit
  ✓ O-002  score=0.60  type=trace
  ✓ O-003  score=0.85  type=deposit
  → O-004  score=0.20  → signals/.archive/observations/
  → O-005  score=0.10  → signals/.archive/observations/

--- 完成 ---
  迁移: 3  归档: 2  跳过: 0
```

## 边界条件

- 空的 signals/observations/ 目录 → 打印 "无信号需要迁移" 退出
- YAML 文件格式损坏 → 跳过并警告
- detail 字段是多行文本 → yaml_read 只读首行，compute_quality_score 会根据可获取的内容打分
- DB 不存在 → 只处理 YAML 文件
- --apply 指定的 ID 不存在 → 警告并跳过
