# Repository Guidelines (Codex / Gemini)

## 致人类开发者 (Note to Human Developers)

> **如果你是人类开发者，请阅读此节。**
> 本文件 (`AGENTS.md`) 是 Codex / Gemini 等非 Claude 平台的入口文件，包含项目特有的参考信息。
> 核心 AI 协作协议在 `TERMITE_PROTOCOL.md` 中定义，所有 AI Agent 共享同一套协议。

## 白蚁协议 (Termite Protocol)

> **你必须首先阅读 `TERMITE_PROTOCOL.md`。** 该文件定义了完整的白蚁生命周期协议，包括：
> 种姓分工、Phase 0-6 生命周期、信息素规则、触发-动作规则、验证清单、故障恢复等。
>
> **本文件仅包含 Codex/Gemini 环境特有的项目参考信息和扩展协议。** 协议层的内容不在此重复。

---

## Agent Operating Protocol (Blackboard + Swarm)

> 以下是针对非交互式 Agent（如 Codex、Gemini）的操作补充原则：

- **Caste-first, act-fast**: Upon landing, immediately determine your caste (Scout/Worker/Soldier/Nurse) per `TERMITE_PROTOCOL.md` Phase 0. Then start producing output. Reading is preparation, not action — files and commits are your output.
- Files are the blackboard; conversations are ephemeral. Any durable insight, plan, or decision must be written to files.
- Start each task by reading `TERMITE_PROTOCOL.md` + `AGENTS.md`, then load only the minimal module docs/code needed for the task.
- Persist outputs: design/analysis -> module `.md` doc; new conventions -> update entry files; non-obvious bug root cause -> commit message or doc.
- Local sensing: keep context small, read only nearby files, and avoid large global context dumps.
- Simple local rules: prefer small atomic edits over monolithic workflows; for multi-step work, store a plan in a file.
- Resilience: if a step fails, leave a durable breadcrumb (TODO, plan file, or test report) so another agent can resume.
- Feedback loops: use tests/logs/metrics as probes, and update docs/strategies based on the outcomes.

---

## 自启动黑板协议（非交互式 Agent 扩展）

> 此协议是 `TERMITE_PROTOCOL.md` 的扩展，专为不能与用户实时交互的 Agent（如 Codex）设计。
> **协议在本文件，数据在 `BLACKBOARD.md`。** 读取本文件了解规则，读取 `BLACKBOARD.md` 获取当前状态和可执行信号。

### 1) 启动流程（必做）
1. 读取 `TERMITE_PROTOCOL.md`（核心协议）+ 本文件（项目参考）+ `BLACKBOARD.md`（信号表、健康状态）。**立即判定种姓**（规则见 `TERMITE_PROTOCOL.md` Phase 0）：有 `ALARM.md` → 兵蚁优先；有明确实现任务 → 工蚁；否则 → 探路蚁。种姓决定你的行为约束和产出类型。
2. 决策触觉扫描：用 `rg --files -g 'DECISIONS.md'` 定位决策记录，抽取包含 `**行动项/Next:**` 或 `[HOLE]/[TODO]/[BLOCKED]/[EXPLORE]` 的条目。
3. 选择 `BLACKBOARD.md` Signals 表中最高权重且未过期的 Signal（若无，则创建一个 PROBE）。
4. 在 `BLACKBOARD.md` Claims 表写入 Claim 占用范围（文件/模块/计划），设置 TTL。
5. **验证认领 (Verify Claim)**：等待 2-5 秒后，**重新读取 `BLACKBOARD.md`**。确认刚才写入的 Claim 依然存在且未被他人覆盖。若已被覆盖，视为冲突，放弃操作并重试其他 Signal。
6. 执行一个最小原子动作（单文件小改动/单次检查/单次测试）。
7. 在 `BLACKBOARD.md` 写入 Result，并更新 Signal 的权重与 Next。
8. 释放 Claim（或延期并注明原因）。

### 2) 信号类型与触发规则
- `FEEDBACK`: 生产环境反馈（HOLE/INSIGHT），**最高优先级**。
- `PROBE`: 环境探针（测试/日志/文档漂移/权限差异）。
- `PHEROMONE`: 已验证有效的策略/路径。
- `HOLE`: 发现缺口/错误/阻塞（需要修补）。
- `EXPLORE`: 5% 变异探索（A/B 试验、新路径尝试）。
- `BLOCKED`: 被依赖/权限阻塞，等待外部条件。
- `DONE`: 完结并归档（移到 Results）。

### 3) 信息素权重与衰减
- 成功 +10，失败 -10，未确认 +0。
- 每天衰减 `*0.980`（或每次触达时手动下调）。
- TTL 到期自动归档为 DONE（写入 Results）。

### 4) 冲突与容错
- 同一文件/模块出现 Claim 时，其他 agent 必须跳过或选择不同信号。
- 失败必须写 HOLE，并给出 Next 指引（可复用/恢复）。
- 多步任务必须先写 Plan，再逐步执行。

### 5) 微探索配额
- 至少 5% 行动预算用于 `EXPLORE`。
- 结果必须回写到黑板（成功则提升权重，失败则衰减）。

### 6) 破洞修补反射
- 任何功能缺口、合规风险或技术疑问视为 HOLE，优先触发专职修补。

---

## 蚁丘健康状态

> 动态数据（健康状态、信号表、热点区域、认领表、结果表）统一在根目录 `BLACKBOARD.md` 中维护。

---

## Project Overview

<!-- 在此填写你的项目概述 -->

## Project Structure & Module Organization

<!-- 在此填写你的项目目录结构说明 -->
<!-- 例如：
- `frontend/`: 前端应用
- `backend/`: 后端 API
- `docs/`: 文档
-->

---

## 路由表：任务 → 局部黑板

<!-- 根据项目模块填写路由表 -->
| 任务关键词 | 局部黑板 |
| ---------- | -------- |
<!-- | 模块 A 相关关键词 | `path/to/module-a/BLACKBOARD.md` | -->
<!-- | 模块 B 相关关键词 | `path/to/module-b/BLACKBOARD.md` | -->

---

## 项目特有触发-动作规则

> 协议层的通用触发-动作规则在 `TERMITE_PROTOCOL.md` 中。以下是本项目特有的规则：

| 我观察到…… | 我必须做…… |
| ---------- | ---------- |
<!-- | 项目特有的观察条件 | 项目特有的必做动作 | -->

---

## Build, Test, and Development Commands

<!-- 根据项目实际情况填写 -->
| 操作     | 命令 |
| -------- | ---- |
<!-- | 安装依赖 | `npm install` | -->
<!-- | 开发运行 | `npm run dev` | -->
<!-- | 构建     | `npm run build` | -->
<!-- | 测试     | `npm run test` | -->
<!-- | Lint     | `npm run lint` | -->

---

## 验证清单（项目特有）

> 通用验证清单在 `TERMITE_PROTOCOL.md` 中。以下是本项目特有的构建/测试命令：

<!-- 根据项目实际的构建/测试命令填写 -->
| 改动类型           | 验证方式 |
| ------------------ | -------- |
<!-- | 后端代码 | 构建通过，无报错 | -->
<!-- | 前端代码 | 构建通过，无报错 | -->
<!-- | 新增/修改 API | 运行对应模块的接口测试 | -->

---

## Configuration & Secrets

<!-- 在此说明环境变量和配置文件结构，不要包含实际密钥值 -->

---

## Commit & Pull Request Guidelines

- 保持 commit 范围小且有描述性
- 修改 AI 流程或 DB schema 时在 commit message 中包含上下文
- PR 应包含：目的、关键变更、DB migration 说明（如有）

---

## Worktree Development Requirement

- All feature work should use `git worktree` isolation. Default base branch is `main` if not specified.
- Example: `git worktree add ../<project>-<feature-name> -b feature/<feature-name> <base-branch>`.
- Clean up after merge: `git worktree remove ../<project>-<feature-name>`.

---

## 已知限制（全局）

> 已迁移到根目录 `BLACKBOARD.md` 的"已知限制"段。

---

## 黑板索引

### 局部黑板

<!-- 根据项目模块填写 -->
| 黑板   | 路径 |
| ------ | ---- |
<!-- | 模块 A | `path/to/module-a/BLACKBOARD.md` | -->
<!-- | 模块 B | `path/to/module-b/BLACKBOARD.md` | -->

### 设计文档

<!-- 根据项目情况填写 -->
| 文档 | 路径 |
| ---- | ---- |
<!-- | 架构设计 | `docs/ARCHITECTURE.md` | -->
