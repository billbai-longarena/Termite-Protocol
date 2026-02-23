# Project Guidelines (Claude Code)

## 致人类开发者 (Note to Human Developers)

> **如果你是人类开发者，请阅读此节。**
> 本文件 (`CLAUDE.md`) 是 Claude Code 的入口文件，包含项目特有的参考信息。
> 核心 AI 协作协议在 `TERMITE_PROTOCOL.md` 中定义，所有 AI Agent 共享同一套协议。

## 白蚁协议 (Termite Protocol)

> **你必须首先阅读 `TERMITE_PROTOCOL.md`。** 该文件定义了完整的白蚁生命周期协议，包括：
> 三丘模型、种姓分工、Phase 0-6 生命周期、信息素规则、触发-动作规则、验证清单、故障恢复等。
>
> **本文件仅包含 Claude Code 环境特有的项目参考信息。** 协议层的内容不在此重复。

---

## 蚁丘健康状态

> 动态状态已迁移到根目录 `BLACKBOARD.md`。去那里查看和更新蚁丘健康、热点区域、已知限制。
> Dynamic state has moved to `BLACKBOARD.md` in the root directory.

---

## 项目概述

<!-- 在此填写你的项目概述，一句话描述项目是什么 -->

## 技术栈

<!-- 在此填写你的技术栈 -->
<!-- 例如：
- **前端**: React / Vue / Next.js + TypeScript
- **后端**: Node.js / Python / Go
- **数据库**: PostgreSQL / MySQL / MongoDB
- **其他**: Redis, Docker, etc.
-->

---

## 路由表：任务 → 局部黑板

**读完此表后，去读对应的局部黑板获取模块细节。不要在本文件里找。**

<!-- 根据项目模块填写路由表 -->
| 任务关键词 | 局部黑板 |
| ---------- | -------- |
<!-- | 模块 A 相关关键词 | `path/to/module-a/BLACKBOARD.md` | -->
<!-- | 模块 B 相关关键词 | `path/to/module-b/BLACKBOARD.md` | -->
<!-- | 测试 / 场景 / 断言 | `tests/BLACKBOARD.md` | -->

**任何模块都不匹配？** 留在本文件，用下方的全局信息工作。

---

## 项目特有触发-动作规则

> 协议层的通用触发-动作规则在 `TERMITE_PROTOCOL.md` 中。以下是本项目特有的规则：

| 我观察到…… | 我必须做…… |
| ---------- | ---------- |
<!-- | 项目特有的观察条件 | 项目特有的必做动作 | -->

---

## 验证清单（项目特有）

> 通用验证清单在 `TERMITE_PROTOCOL.md` 中。以下是本项目特有的构建/测试命令：

<!-- 根据项目实际的构建/测试命令填写 -->
| 改动类型   | 验证方式 |
| ---------- | -------- |
<!-- | 后端代码 | `cd backend && npm run build` 无报错 | -->
<!-- | 前端代码 | `cd frontend && npm run build` 无报错 | -->
<!-- | 新增/修改 API | 跑对应模块测试 | -->

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
<!-- | 测试   | `tests/BLACKBOARD.md` | -->

### 设计文档

<!-- 根据项目情况填写 -->
| 文档 | 路径 |
| ---- | ---- |
<!-- | 架构设计 | `docs/ARCHITECTURE.md` | -->
