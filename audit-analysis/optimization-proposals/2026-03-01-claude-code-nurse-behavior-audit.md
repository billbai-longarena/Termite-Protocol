# Claude Code Nurse 行为路径审计：协议源仓库心跳响应

Date: 2026-03-01
Reporter: Claude Opus 4.6 (Nurse session — human-directed behavior analysis)
Environment: Claude Code v2.1.45 / Opus 4.6 / protocol source repo
Trigger: 人类输入"白蚁协议"四字心跳指令

## 背景

人类在**协议源仓库**（非宿主项目）中对 Claude Code 发出"白蚁协议"心跳指令，观察 Agent 的行为路径是否符合 `CLAUDE.md` Operations 节的设计意图。

协议源仓库的设计意图（CLAUDE.md:80-83）：

> 在宿主项目中，"白蚁协议"= 心跳触发 → 自主代谢。
> 在协议源仓库中，"白蚁协议"= **Nurse 自检** → 读审计登记簿 → 识别待处理项 → 执行。

## 逐步比对

### Nurse 自检 6 步 vs 实际行为

| 步骤 | 设计意图 | 实际行为 | 一致性 |
|------|---------|---------|--------|
| 0 | `git pull origin main` | 执行 `git pull origin main 2>&1` | 完全一致 |
| 1 | 读 `REGISTRY.yaml` | 读取 `audit-analysis/REGISTRY.yaml` | 完全一致 |
| 2 | 检查 `status: open` 条目 | 确认"所有条目均为 fixed 或 closed，无 open 待处理项" | 完全一致 |
| 3 | 读 `audit-packages/*/metadata.yaml` | 读取两个审计包的 metadata.yaml + 10+ 个观察信号文件 | 一致且有合理扩展 |
| 4 | 跨蚁丘比对 | 正确报告"仅 OAE 一个宿主项目，无法执行跨蚁丘比对" | 一致（诚实降级） |
| 5 | 发现问题 → 定位 templates/ | 未发现需修复问题，未进入 templates/ | 正确的条件分支 |
| 6 | 修复 → 更新 REGISTRY + Known Issues | 未修复（无需修复），提议登记 A-002 | 正确的条件分支 |

### 关键分叉点：角色识别

CLAUDE.md:77 明确要求：

> **协议源仓库不是宿主项目。** 这里没有 field-arrive.sh / .birth / 心跳循环。

Agent **正确做到的**：

- 未尝试运行 `field-arrive.sh`
- 未生成 `.birth` 文件
- 未执行 `field-cycle.sh` 心跳代谢循环
- 自我定位为 Nurse 角色
- 以 `REGISTRY.yaml` 为起点（而非 `.pheromone` 或 `BLACKBOARD.md`）

这是最关键的验证——如果 Agent 误判自己在宿主项目中，会走完全不同的错误路径（arrive → sense → caste → work）。

### 超出设计预期的正面行为

1. **主动发现未登记审计包**：REGISTRY 中无 `audit-packages/OpenAgentEngine/2026-03-01/`（嵌套目录结构），Agent 主动发现并与已知的 `OpenAgentEngine-2026-03-01/`（扁平结构）做了数据比对
2. **深度信号采样**：不仅读取 metadata，还主动读取了 10+ 个观察信号文件，产出两个模式洞察：
   - P-001：零规则创建（74 条观察但 0 条活跃规则）
   - P-002：协议架构建议（缺少 Project Charter 层）
3. **结构化报告输出**：产出格式清晰的表格化 Nurse 自检报告，包含指标比对和结论

### 观察到的问题

1. **SessionStart hook 报错**：`SessionStart:startup hook error`。不影响 Nurse 行为路径本身，但说明 Claude Code 层面的 hook 集成存在配置问题（路径、权限或环境变量）。属于部署问题，非协议设计问题。

## 结论

| 维度 | 评估 |
|------|------|
| 角色识别 | **通过** — 正确区分协议源仓库 vs 宿主项目 |
| 流程遵循 | **通过** — 6 步 Nurse 自检每步按规范执行 |
| 条件分支 | **通过** — 无需修复时正确终止，不强行行动 |
| 信息质量 | **通过** — 产出结构化报告含可操作洞察 |
| 闭环完成 | **通过** — 提议登记 A-002 并最终执行（REGISTRY.yaml 已更新） |
| 副作用 | **通过** — 未执行不该执行的操作（无 field-arrive/cycle/deposit） |

**整体判定：行为与设计意图高度一致。** 协议源仓库的 CLAUDE.md Operations 节成功引导 Agent 走入正确的 Nurse 自检路径，而非宿主项目的心跳代谢路径。
