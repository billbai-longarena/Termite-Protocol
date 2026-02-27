# Project Guidelines (Claude Code)

## 致人类开发者

本文件是 Claude Code 的入口文件，包含白蚁协议内核与项目参考信息。
"白蚁协议"是心跳指令——收到后 Agent 自动执行节律，自主判断并行动。
完整协议在 `TERMITE_PROTOCOL.md`。

<!-- termite-kernel:v7.0 -->
## 白蚁协议 — 最小内核 v7.0

> **8 条文法 + 4 条安全底线 = 完整行为规范。规则由 `signals/rules/*.yaml` 注入，本文件不膨胀。**

### 文法

1. **ARRIVE->SENSE->STATE** — 到达后感知场状态（ALARM / WIP / .pheromone / BLACKBOARD）
2. **STATE->CASTE->PERMISSIONS** — 状态决定种姓，种姓决定权限（Scout / Worker / Soldier / Nurse）
3. **ACTION∈PERMISSIONS->DO** — 权限内行动，权限外不动
4. **DO->DEPOSIT(signal, weight, TTL, location)** — 每次行动产出信息素落盘
5. **weight < threshold->EVAPORATE** — 弱信号自动衰减（由 field-decay 或手动清理）
6. **weight > threshold->ESCALATE** — 强信号升级（写 ALARM 或请求人类介入）
7. **count(agents, same_signal) >= 3->EMERGE** — 多只白蚁重复观察同一模式->提炼为规则
8. **context > 80%->MOLT** — 上下文即将耗尽->写 WIP + .pheromone，结束会话

### 执行逻辑

**有可执行脚本时（推荐路径）：**
运行 `./scripts/field-arrive.sh` -> 读取 `.birth` -> 按 `.birth` 中注入的规则工作

**无可执行脚本时（降级路径）：**
检查 `ALARM.md`（有则停下读它）-> 检查 `WIP.md`（有则接力）-> 根据用户指令判定种姓 -> 开始施工
沉淀观察到 `signals/observations/`；若目录不存在，回退写入 `BLACKBOARD.md`

### 安全底线

1. **commit message 说清楚改了什么、为什么改**
2. **不要删除任何 .md 文件**（CLAUDE.md / BLACKBOARD.md / TERMITE_PROTOCOL.md 等）
3. **改动超过 50 行就 commit 一次**
4. **看到 ALARM.md -> 立即停下来读它**

做到这四点，你就是一只有用的白蚁。其余的，下一只白蚁会帮你补上。

---

## 按需查阅索引

| 遇到什么 | 读哪里 |
|----------|--------|
| 种姓疑问 | `TERMITE_PROTOCOL.md` Part III |
| 信号格式 | `signals/README.md` |
| 并发冲突 | `TERMITE_PROTOCOL.md` Part II |
| 三丘哲学 | `TERMITE_PROTOCOL.md` Part III |
| 降级运行 | `TERMITE_PROTOCOL.md` Part II |
| 项目特有规则 | `signals/rules/R-001~R-007.yaml` |

---

## 项目概述

SalesTouch 是一个 AI 驱动的销售赋能平台，核心 AI 组件是 **Max Agent** —— 一个上下文感知、技能驱动型 AI 副驾驶，深度嵌入应用中，能"看见"用户所在页面并动态加载相关技能来执行操作。

**三丘共生愿景：** 开发丘（AI 工程师）构建基础设施，产品丘（Max Agent 群）持续感知环境和准备策略，客户丘（销售团队）在 Living Canvas 上与 Max 共建认知空间。详见 `SWARM_EVOLUTION_DESIGN.md` SS1.0。

## 技术栈

- **前端**: Vue 3 (Composition API) + TypeScript + Vite + Element Plus + ECharts + vue-i18n
- **后端**: Node.js + TypeScript (Express/Koa)
- **AI Agent**: 自研技能系统，基于 System Prompt + 文本工具调用（非 API 级 function-calling）
- **数据库**: MySQL（阿里云 RDS 远程数据库 — **严禁使用本地数据库**）
- **实时通信**: SSE (Server-Sent Events)

---

## 数据库基础设施（高优先级 — 所有白蚁必读）

> **本项目只使用阿里云 RDS 远程 MySQL 数据库，没有本地数据库，没有 SQLite，没有 docker-compose MySQL。**

| 事实 | 说明 |
| --- | --- |
| **唯一数据库** | 阿里云 RDS MySQL (`rm-uf6z0gg5z9h2ag62n7o.mysql.rds.aliyuncs.com`) |
| **连接方式** | 所有代码通过 `process.env.DB_HOST/DB_USER/DB_PASSWORD/DB_NAME` 读取 `backend/.env` |
| **本地数据库** | **不存在，严禁创建。** 不要写 `DB_HOST || 'localhost'` |
| **防线** | `backend/src/tests/framework/config.ts` 会在 DB_HOST 缺失时直接 throw |

---

## 路由表：任务 -> 局部黑板

| 任务关键词 | 局部黑板 |
| --- | --- |
| Max / 技能 / 记忆 / APL / 主动式 / 通知 | `backend/src/aiApps/max/BLACKBOARD.md` |
| B2C / 医美 / 客户管理 / 销售流程 | `backend/src/aiApps/b2c/BLACKBOARD.md` |
| Opportunity / 商机 / B2B / 联系人 | `backend/src/aiApps/opportunity/BLACKBOARD.md` |
| 测试 / Layer / 场景 / YAML / 断言 | `backend/src/tests/BLACKBOARD.md` |
| 前端 / 页面 / 组件 / 路由 / i18n / 权限 | `frontend/BLACKBOARD.md` |
| 三丘共生 / Living Canvas / 架构哲学 | `backend/src/aiApps/max/SWARM_EVOLUTION_DESIGN.md` |

---

## 场基础设施 / Field Infrastructure

| 工具 | 作用 |
|------|------|
| `scripts/field-arrive.sh` | 到达仪式 — 注入 .birth、感受场脉搏 |
| `scripts/field-cycle.sh` | 完整呼吸 — 衰减->排水->脉搏（post-commit hook） |
| `scripts/field-deposit.sh` | 信息素沉淀 — 会话结束时生成 .pheromone |
| `scripts/field-claim.sh` | 认领锁 — claim/release/check |
| `signals/rules/*.yaml` | 触发-动作规则（由 field-arrive 注入 .birth） |
| `signals/active/*.yaml` | 活跃信号数据 |
| `.pheromone` | 大模型间的化学痕迹（JSON） |
| `.birth` | 本次会话的出生证明（由 arrive 生成） |

---

## 分支治理

```
swarm ──(人类挑拣稳定功能)──> uat ──(测试通过后合并)──> master
 ^ AI 白蚁工作区              ^ 开发服务器(自动发布)    ^ 生产环境(手动发布)
```

- **自主模式**：只允许操作 `swarm` 和 `feature/*`。`uat`/`master` 绝对禁止。
- **人类指挥模式**：人类明确指令时可操作 `uat`（须复述确认 + BLACKBOARD 记录）。`master` 一律禁止白蚁操作。

---

## AI 计费与余额检查

三方服务链：Touch 后端 -> LLM Gateway `node.ningshen.net` -> SSO 服务（余额 + 计费）

**前端**：每个 AI 入口必须调用 `queryIsCanAiUse()` — `frontend/src/api/aiApi.ts`
**后端**：AI 流式响应结束后调用 `addAiTokenUseLog()` — `backend/src/utils/addAiTokenUseLog.ts`
**注意**：后端 `/api/ai-apps/*` 路由无余额检查中间件，完全依赖前端拦截。

---

## 黑板索引 + 设计文档

| 黑板 | 路径 |
| --- | --- |
| Max Agent | `backend/src/aiApps/max/BLACKBOARD.md` |
| B2C 助手 | `backend/src/aiApps/b2c/BLACKBOARD.md` |
| Opportunity | `backend/src/aiApps/opportunity/BLACKBOARD.md` |
| 测试框架 | `backend/src/tests/BLACKBOARD.md` |
| 前端 | `frontend/BLACKBOARD.md` |

| 设计文档 | 路径 |
| --- | --- |
| Max 架构设计规范 | `backend/src/aiApps/max/AGENT_DESIGN_PRACTICE.md` |
| APL 完整设计 | `backend/src/aiApps/max/APL_DESIGN.md` |
| 生态演进设计（三丘共生模型） | `backend/src/aiApps/max/SWARM_EVOLUTION_DESIGN.md` |
| Opportunity 实现说明 | `backend/src/aiApps/opportunity/AGENT_IMPLEMENTATION.md` |

## Custom Commands

- `/add-org-id` - 给接口加上 organization_id 支持，实现多租户数据隔离
