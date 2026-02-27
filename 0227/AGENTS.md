# Repository Guidelines (Codex / Gemini)

## 致人类开发者 (Note to Human Developers)

> 本文件 (`AGENTS.md`) 是 Codex / Gemini 等非交互平台的入口文件。
> "白蚁协议"是心跳指令——收到后自动执行节律，自主判断并行动。
> 完整协议在 `TERMITE_PROTOCOL.md`，本文件足够驱动日常行动。

<!-- termite-kernel:v7.0 -->
## 白蚁协议 — 最小内核 v7.0

> **"白蚁协议"四个字 = 启动心跳，自动执行。**
> **终极目标：维持三丘（开发丘·产品丘·客户丘）的持续发展与繁荣。**

### 协议语法（8 条不可化约规则）

```
1. ARRIVE->SENSE->STATE        到达后感知环境，建立态势
2. STATE->CASTE->PERMISSIONS   态势决定种姓，种姓决定权限
3. ACTION∈PERMISSIONS->DO     在权限内行动
4. DO->DEPOSIT(signal,weight,TTL,location)  行动后沉积信息素
5. weight<threshold->EVAPORATE 低权重信号自动挥发
6. weight>threshold->ESCALATE  高权重信号升级为热点
7. count(agents,same_signal)>=3->EMERGE  >=3条独立观察->涌现为规则
8. context>80%->MOLT           上下文将满->蜕皮（写WIP+.pheromone，结束会话）
```

### 执行流程

```
IF 可执行脚本（scripts/field-arrive.sh 存在且可执行）:
  运行 ./scripts/field-arrive.sh -> 读 .birth -> 按 .birth 中的种姓和规则干活
IF 不可执行:
  检查 ALARM.md（有->兵蚁，立即修复）
  -> 检查 WIP.md（新鲜->工蚁，接力前任）
  -> 判定种姓（默认探路蚁）-> 干活
  -> 沉积观察到 signals/observations/（回退: BLACKBOARD.md）
```

### 安全网底线（4 条）
1. commit message 说清楚改了什么、为什么改
2. 不要删除任何 .md 文件
3. 改动超过 50 行就 commit 一次（`[WIP]` 标签）
4. 看到 ALARM.md -> 停下来读它

> 做到这四点，你就是一只有用的白蚁。完整协议参阅 `TERMITE_PROTOCOL.md`。

---

## 非交互 Agent 扩展（Claim/Verify/Release）

> 非交互式 Agent 无法与用户实时沟通，因此使用信号认领机制实现自主协作。

**核心循环：**
1. **Claim**: 读 `signals/active/*.yaml`（回退: `BLACKBOARD.md`）-> 按权重选最高 -> `./scripts/field-claim.sh claim S-xxx work <owner>`
2. **Work**: 最小原子动作 -> 自检 -> 偏离则回判断
3. **Deposit**: 更新信号状态/权重 -> 沉积观察 -> `./scripts/field-claim.sh release S-xxx work`

**互斥规则**: work与audit互斥，review 不阻塞。冲突时跳过，选其他信号。
**容错**: 失败必须写 HOLE + Next 指引。多步任务先写 Plan。
**微探索**: 至少 5% 行动预算用于 EXPLORE 信号。

---

## 按需查阅索引

| 遇到什么 | 读哪里 |
|----------|--------|
| 种姓判定规则 | `TERMITE_PROTOCOL.md` Part II |
| 种姓详解与权限 | `TERMITE_PROTOCOL.md` Part III |
| 信号 YAML 格式 | `signals/README.md` |
| 并发认领冲突 | `TERMITE_PROTOCOL.md` Part II |
| 三丘哲学 | `TERMITE_PROTOCOL.md` Part III |
| 降级运行 | `TERMITE_PROTOCOL.md` Part II |
| 免疫系统 | `TERMITE_PROTOCOL.md` Part III |
| 项目特有规则 | `signals/rules/R-001~R-007.yaml` |

---

## Project Overview

SalesTouch is an AI-driven sales enablement platform; core AI is **Max Agent** (context-aware, skill-driven copilot). **Three-Colony Symbiosis:** Dev Colony builds infrastructure, Max Colony senses environments and prepares strategies, Customer Colony (sales teams) collaborates with Max on a shared Living Canvas. See `SWARM_EVOLUTION_DESIGN.md` SS1.0.

## Product Feature Map

- Sales: workbench, customer/opportunity CRM, manager dashboard, AI chat, scheme generator, SPIN planner, WeChat tools.
- Product: entry/browse, files/media, FAB generation, product agent.
- Training: AI Drill, voice bots, SalesNail/Training outlines, PPT workbench.
- Process: B2B/B2C config, B2C assist/manager dashboard.
- Medical compliance: hospital/dept info, product library, task squares, commission, daily check-in agent.
- Case Assist: library/detail/learning flows.

## Project Structure & Module Organization

- `frontend/`: Vue 3 + TypeScript (Vite). Views in `frontend/src/views/AIsalesAssist/`, components in `frontend/src/components/`.
- `backend/`: Express + TypeScript. Entry `backend/src/index.ts`, routes in `backend/src/routes/`.
- AI apps: `backend/src/aiApps/` (max, b2c, opportunity, aiDrill, voiceBot, wechat, etc.).
- Max Agent: `backend/src/aiApps/max/` (handler/context/prompt/tools/skills/memory/proactive/sync).
- DB schema: `DATABASE_SCHEMA.md` and `backend/src/services/aiSalesAssist/*.sql`.

## AI Agent & Tooling

- Text tool-call format: `<tool_call>{...}</tool_call>`, parsed via `extractToolCalls`.
- Max skills: `backend/src/aiApps/max/skills/`, registry at `registry.ts`.
- UI markup: `data-max-id` + `data-max-action` on interactive elements.

## Permissions & Route Map

- AIsalesAssist home cards gate on `calculateHasAuth()`. Permission codes in `frontend/src/composables/useSalesAssistAuth.ts`.
- API mounts: `/api/ai-sales-assist`, `/api/ai-apps`, `/api/medical-compliance`, `/api/max`.

---

## Build, Test, and Development Commands

| 操作 | 命令 |
| ---- | ---- |
| Frontend install | `cd frontend && npm install` |
| Frontend dev | `cd frontend && npm run dev` |
| Frontend build | `cd frontend && npm run build` |
| Backend install | `cd backend && npm install` |
| Backend dev | `cd backend && npm run dev` |
| Backend build | `cd backend && npm run build` |
| Backend tests | `cd backend && npm run test:layer1\|test:layer2\|test:layer3\|test:all` |

---

## Database Infrastructure (Critical)

> **Only Aliyun RDS remote MySQL. NO local database, NO SQLite, NO docker-compose MySQL.**

| Fact | Detail |
| --- | --- |
| **Only database** | Aliyun RDS MySQL (`rm-uf6z0gg5z9h2ag62n7o.mysql.rds.aliyuncs.com`) |
| **Connection** | `process.env.DB_HOST/DB_USER/DB_PASSWORD/DB_NAME` from `backend/.env` |
| **Local database** | **Does not exist. Never create one.** Never `DB_HOST \|\| 'localhost'` |
| **Guard** | `backend/src/tests/framework/config.ts` throws on missing DB_HOST |

## Configuration & Secrets

- Backend `.env` via `dotenv`: `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `JWT_SECRET`.
- LLM/Gateway: `LLM_BASE_URL`, `AZURE_OPENAI_ENDPOINT`, `SSO_API_KEY`, `SSO_TEST_KEY`.
- Frontend: `VITE_APP_LLM_URL`.

## AI Gateway & Billing

- Frontend: `queryIsCanAiUse()` in `frontend/src/api/aiApi.ts` before AI calls.
- Backend: `addAiTokenUseLog()` in `backend/src/utils/addAiTokenUseLog.ts` after streaming.
- `/api/ai-apps/*` has no backend balance middleware; relies on frontend gating.

## Branch Governance

```
swarm --(human picks stable features)--> uat --(tested, human merges)--> master
```
- Autonomous mode: only `swarm` and `feature/*`. Never push to `uat`/`master`.
- Human command mode: `uat` allowed with confirmation + BLACKBOARD log. `master` always forbidden.

## Commit Guidelines

- Short, descriptive messages. Include context for AI flow or DB schema changes.
- Worktree isolation: `git worktree add ../SalesTouch-<feature> -b feature/<name> swarm`.
