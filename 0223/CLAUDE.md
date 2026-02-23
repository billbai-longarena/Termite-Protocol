# Project Guidelines (Claude Code)

## 🛑 致人类开发者 (Note to Human Developers)

> **如果你是人类开发者，请阅读此节。**
> 本文件 (`CLAUDE.md`) 是 Claude Code 的入口文件，包含项目特有的参考信息。
> 核心 AI 协作协议在 `TERMITE_PROTOCOL.md` 中定义，所有 AI Agent 共享同一套协议。

## ⚠️ 白蚁协议 (Termite Protocol)

> **你必须首先阅读 `TERMITE_PROTOCOL.md`。** 该文件定义了完整的白蚁生命周期协议，包括：
> 三丘模型、种姓分工、Phase 0-6 生命周期、信息素规则、触发-动作规则、验证清单、故障恢复等。
>
> **本文件仅包含 Claude Code 环境特有的项目参考信息。** 协议层的内容不在此重复。

## ⚡ Boot Sequence（交互式 Agent 快速启动）

> **你不需要先读完 `TERMITE_PROTOCOL.md` 再行动。** 以下是内联的快速启动流程，让你立即进入工作状态。

1. **种姓判定（立即）**：根据用户的第一句话 + 环境信号（有无 `ALARM.md`），确定你是 Scout / Worker / Soldier / Nurse（判定规则见 `TERMITE_PROTOCOL.md` Phase 0）。
2. **路由**：用户任务匹配下方路由表中的哪个模块？去读对应的局部黑板。不匹配则留在本文件。
3. **行动**：开始施工。白蚁的本能是产出，不是讨论——直接写代码/文档/测试。不要在对话中罗列你"打算做什么"。
4. **深度扫描（施工间隙）**：在施工间隙按需执行 `TERMITE_PROTOCOL.md` Phase 1 的检查项（信息素验毒、决策扫描等）。

---

## 蚁丘健康状态

> 动态状态已迁移到根目录 `BLACKBOARD.md`。去那里查看和更新蚁丘健康、热点区域、已知限制。
> Dynamic state has moved to `BLACKBOARD.md` in the root directory.

---

## 项目概述

SalesTouch 是一个 AI 驱动的销售赋能平台，核心 AI 组件是 **Max Agent** —— 一个上下文感知、技能驱动型 AI 副驾驶，深度嵌入应用中，能"看见"用户所在页面并动态加载相关技能来执行操作。

**三丘共生愿景：** SalesTouch 的终极设计目标是实现三丘共生——开发丘（AI 工程师）构建基础设施，产品丘（Max Agent 群）持续感知环境和准备策略，客户丘（销售团队）在 Living Canvas 上与 Max 共建认知空间。Max 不是"为用户服务的工具"，而是两个丘之间的**共生界面和翻译层**，将人类白蚁的非结构化行为翻译为系统信息素，将系统策略翻译为人类可感知的 UI 表达。详见 `SWARM_EVOLUTION_DESIGN.md` §1.0。

## 技术栈

- **前端**: Vue 3 (Composition API) + TypeScript + Vite + Element Plus + ECharts + vue-i18n
- **后端**: Node.js + TypeScript (Express/Koa)
- **AI Agent**: 自研技能系统，基于 System Prompt + 文本工具调用（非 API 级 function-calling）
- **数据库**: MySQL
- **实时通信**: SSE (Server-Sent Events) 用于桌面/移动端同步

---

## 路由表：任务 → 局部黑板

**读完此表后，去读对应的局部黑板获取模块细节。不要在本文件里找。**

| 任务关键词                              | 局部黑板                                           |
| --------------------------------------- | -------------------------------------------------- |
| Max / 技能 / 记忆 / APL / 主动式 / 通知 | `backend/src/aiApps/max/BLACKBOARD.md`             |
| B2C / 医美 / 客户管理 / 销售流程        | `backend/src/aiApps/b2c/BLACKBOARD.md`             |
| Opportunity / 商机 / B2B / 联系人       | `backend/src/aiApps/opportunity/BLACKBOARD.md`     |
| 测试 / Layer / 场景 / YAML / 断言       | `backend/src/tests/BLACKBOARD.md`                  |
| 前端 / 页面 / 组件 / 路由 / i18n / 权限 | `frontend/BLACKBOARD.md`                           |
| 三丘共生 / Living Canvas / 信息素 UX / 销售种姓 / 群体智能 / 架构哲学 | `backend/src/aiApps/max/SWARM_EVOLUTION_DESIGN.md` |

**任何模块都不匹配？** 留在本文件，用下方的全局信息工作。

---

## 项目特有触发-动作规则

> 协议层的通用触发-动作规则在 `TERMITE_PROTOCOL.md` 中。以下是本项目特有的规则：

| 我观察到……                           | 我必须做……                                                                  |
| ------------------------------------ | --------------------------------------------------------------------------- |
| 前端新增 AI 调用入口                 | 前置 `queryIsCanAiUse()` 余额检查                                           |
| 后端 AI 流式响应结束                 | 调用 `addAiTokenUseLog()` 记录 token 用量                                   |
| 前端组件需要 Agent 交互              | 添加 `data-max-id` + `data-max-action` 属性                                 |

---

## AI 计费与余额检查

三方服务链：Touch 后端 → LLM Gateway `node.ningshen.net` → SSO 服务（余额 + 计费）

**前端余额检查**（每个 AI 入口必须调用）：
```typescript
import { queryIsCanAiUse } from '@/api/aiApi';
const canUse = await queryIsCanAiUse();
if (!canUse) return; // 余额不足，已弹窗
```

**后端记录 Token 用量**（AI 流式响应结束后，非阻塞）：
```typescript
import { addAiTokenUseLog } from '../utils/addAiTokenUseLog';
addAiTokenUseLog({
  inputTokenCount, outTokenCount,
  aiModelType: 'claude-sonnet-4-5', // 实际模型名
  token: req.headers['token']       // SSO token
});
// 固定: productId=3 (Touch), channelId=1 (自有平台)
```

**关键文件**: `frontend/src/api/aiApi.ts` | `backend/src/utils/addAiTokenUseLog.ts` | `backend/src/utils/llmUtils.ts` | `backend/src/llm/streamGateway.ts`

**注意**: 后端 `/api/ai-apps/*` 路由**无余额检查中间件**，完全依赖前端拦截。

---

## 已知限制（全局）

> 已迁移到根目录 `BLACKBOARD.md` 的"已知限制"段。

---

## 黑板索引

### 局部黑板

| 黑板        | 路径                                           |
| ----------- | ---------------------------------------------- |
| Max Agent   | `backend/src/aiApps/max/BLACKBOARD.md`         |
| B2C 助手    | `backend/src/aiApps/b2c/BLACKBOARD.md`         |
| Opportunity | `backend/src/aiApps/opportunity/BLACKBOARD.md` |
| 测试框架    | `backend/src/tests/BLACKBOARD.md`              |
| 前端        | `frontend/BLACKBOARD.md`                       |

### 设计文档

| 文档                       | 路径                                                     |
| -------------------------- | -------------------------------------------------------- |
| Max 架构设计规范           | `backend/src/aiApps/max/AGENT_DESIGN_PRACTICE.md`        |
| APL 完整设计               | `backend/src/aiApps/max/APL_DESIGN.md`                   |
| 生态演进设计（三丘共生模型） | `backend/src/aiApps/max/SWARM_EVOLUTION_DESIGN.md`       |
| Opportunity 实现说明       | `backend/src/aiApps/opportunity/AGENT_IMPLEMENTATION.md` |

## Custom Commands

- `/add-org-id` - 给接口加上 organization_id 支持，实现多租户数据隔离
