# Repository Guidelines (Codex / Gemini)

## 🛑 致人类开发者 (Note to Human Developers)

> **如果你是人类开发者，请阅读此节。**
> 本文件 (`AGENTS.md`) 是 Codex / Gemini 等非 Claude 平台的入口文件，包含项目特有的参考信息。
> 核心 AI 协作协议在 `TERMITE_PROTOCOL.md` 中定义，所有 AI Agent 共享同一套协议。

## ⚠️ 白蚁协议 (Termite Protocol)

> **你必须首先阅读 `TERMITE_PROTOCOL.md`。** 该文件定义了完整的白蚁生命周期协议，包括：
> 三丘模型、种姓分工、Phase 0-6 生命周期、信息素规则、触发-动作规则、验证清单、故障恢复等。
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
- 每天衰减 `*0.980`（或每次触达时手动下调）。实际代码见 `strategy/weights.ts`。
- TTL 到期自动归档为 DONE（写入 Results）。

### 4) 冲突与容错
- 同一文件/模块出现 Claim 时，其他 agent 必须跳过或选择不同信号。
- 失败必须写 HOLE，并给出 Next 指引（可复用/恢复）。
- 多步任务必须先写 Plan，再逐步执行。

### 5) 微探索配额
- 至少 5% 行动预算用于 `EXPLORE`。
- 结果必须回写到黑板（成功则提升权重，失败则衰减）。

### 6) 破洞修补反射
- 任何"客户异议/合规缺口/技术疑问"视为 HOLE，优先触发专职修补。

---

## 蚁丘健康状态

> 动态数据（健康状态、信号表、热点区域、认领表、结果表）统一在根目录 `BLACKBOARD.md` 中维护。

---

## Project Overview
- SalesTouch is an AI-driven sales enablement platform; core AI is Max Agent (context-aware, skill-driven).
- Primary UI area is AIsalesAssist under `frontend/src/views/AIsalesAssist/` (route base `/ai-sales-assist`).
- **Three-Colony Symbiosis:** SalesTouch's design goal is inter-swarm co-evolution — the Dev Colony (engineers) builds infrastructure, the Max Colony (AI agents) senses environments and prepares strategies, and the Customer Colony (sales teams) collaborates with Max on a shared Living Canvas. Max serves as the translation layer between colonies, encoding human unstructured behavior into system pheromones and rendering system signals as human-perceivable UI. See `backend/src/aiApps/max/SWARM_EVOLUTION_DESIGN.md` §1.0.

## Product Feature Map (SalesTouch)
- Sales operations: workbench, customer/opportunity CRM, manager dashboard, AI assistant chat (ChatView/ChatLLM), sales scheme generator, SPIN planner, WeChat message generator, WeChat conversation assistant.
- Product knowledge: product entry/browse, product files/media, FAB generation, product agent assistance.
- Training & enablement: AI Drill (task/practice/review/report), voice bots (create/chat/student list + stats chat), SalesNail outline, training outline, PPT workbench + history.
- Process configuration: B2B sales process config, B2C process config, B2C sales assist, B2C manager dashboard.
- Medical compliance: hospital/department info, product library, task squares (manufacturer/sales), commission settlement + rules, daily check-in agent.
- Case Assist: case library/detail/learning flows with reading, mindmap, NPC, and test agents.
- Org/account flows: login/register, org create/invite/join, user profile edit, order view.
- Free trial + debug: voice practice landing and debug tooling under `frontend/src/views/Debug/`.

## Project Structure & Module Organization
- `frontend/`: Vue 3 + TypeScript app (Vite). Core areas in `frontend/src/views/`, `frontend/src/components/`, `frontend/src/stores/`, `frontend/src/composables/`, and `frontend/src/utils/`.
- `backend/`: Express + TypeScript API. Entry at `backend/src/index.ts`, routes in `backend/src/routes/`, controllers in `backend/src/controllers/`.
- Static assets: `frontend/public/` and `frontend/src/assets/`.
- AIsalesAssist UI: views in `frontend/src/views/AIsalesAssist/` (home, workbench, customer/opportunity, product, SPIN, WeChat tools, training outlines, B2C, AI Drill) with shared pieces in `frontend/src/views/AIsalesAssist/components/`.
- Other major UI areas: `frontend/src/views/MedicalCompliance/`, `frontend/src/views/PPT/`, `frontend/src/views/caseAssist/`, `frontend/src/views/FreeTrial/`, `frontend/src/views/login/`, `frontend/src/views/userInfo/`, `frontend/src/views/order/`, `frontend/src/views/Debug/`.
- Max Agent UI components live in `frontend/src/components/MaxAgent/`.
- Backend AI apps live in `backend/src/aiApps/` (aiDrill, b2c, manager, max, medicalCompliance, opportunity, productAgent, salesnailOutline, seller, spinCallPlanner, trainingOutline, voiceBot, voiceBotStats, wechat, wechatConversation).
- Max Agent backend lives in `backend/src/aiApps/max/` (handler/context/prompt/tools/skills/memory/proactive/sync).
- DB references and schemas: `DATABASE_SCHEMA.md` and `backend/src/services/aiSalesAssist/*.sql`.

## AI Agent & Tooling
- Text tool-call format uses `<tool_call>{...}</tool_call>` and is parsed via `extractToolCalls` in `backend/src/aiApps/*/tools.ts` (Max uses the opportunity parser).
- B2C agent supports native function calling with tools via the LLM gateway, plus text fallback in `backend/src/aiApps/b2c/handler.ts`.
- Max skills are defined under `backend/src/aiApps/max/skills/` and registered via `backend/src/aiApps/max/skills/registry.ts`.

## UI Markup Requirements
- Add `data-max-id` and `data-max-action` to important interactive elements so Max can locate actions (see `frontend/src/components/MaxAgent/` and `frontend/src/views/AIsalesAssist/` for examples).

## Permissions & Navigation
- AIsalesAssist home cards gate on `calculateHasAuth()`; update codes/routes in `frontend/src/views/AIsalesAssist/AIsalesAssistHome.vue` when adding features.
- Common permission codes include 6-9, 10-15, 16-18, 20-25, 1005-1006, 102-104 (see `frontend/src/composables/useSalesAssistAuth.ts`).
- Route map for exposed UI is in `frontend/src/router/index.ts`; some view folders are not wired to routes and should be treated as prototypes until routed.

## Permissions Summary (AIsalesAssist Home)
| Module                                | Doc ID | Code ID       |
| ------------------------------------- | ------ | ------------- |
| Sales Workbench                       | none   | 0 (default)   |
| Product Entry                         | 6      | 6             |
| Product Browse                        | 7      | 7             |
| Customer & Opportunity                | 8      | 8             |
| SPIN Planner                          | 9      | 9             |
| SalesNail Outline                     | 9      | 102           |
| Training Outline                      | 9      | 103           |
| WeChat Message Generator              | 9      | 104           |
| PPT Workbench                         | 10     | 10            |
| AI Assistant Chat                     | 11     | 11            |
| Trainer Resume Manager                | 12     | 12 (disabled) |
| Voice Bot Create                      | 13     | 13            |
| Manager Dashboard                     | 14     | 14            |
| B2B Process Config                    | 15     | 15            |
| B2C Process Config                    | 16     | 16            |
| B2C Sales Assist                      | 17     | 17            |
| B2C Manager                           | 18     | 18            |
| Compliance Hospital                   | 20     | 20            |
| Compliance Product                    | 21     | 21            |
| Compliance Task Square (Manufacturer) | 22     | 22            |
| Compliance Task Square (Sales)        | 23     | 23            |
| Compliance Commission                 | 24     | 24            |
| Compliance Daily Check-in Agent       | 25     | 25            |
| WeChat Conversation                   | n/a    | 1006          |
| Voice Bot Student List                | n/a    | 1005          |
- Doc IDs come from `AIsalesAssist_Module_List.md`; code IDs come from `frontend/src/composables/useSalesAssistAuth.ts`.
- Current auth logic: `id > 1000` always allowed, `id === 0` always allowed, else check `userRoleList` in localStorage.

## Route Map (UI -> Module -> Backend routes)
- API mounts: `/api/ai-sales-assist` -> `backend/src/routes/aiSalesAssist/index.ts`, `/api/ai-apps` -> `backend/src/routes/aiApps/index.ts`, `/api/medical-compliance` -> `backend/src/routes/medicalCompliance/index.ts`, `/api/max` -> `backend/src/routes/max.ts`.
| UI Route                                                                                                                 | Module                  | Backend Routes (files)                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------ | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/ai-sales-assist/workbench`                                                                                             | Sales Workbench         | `backend/src/routes/aiSalesAssist/workbenchRoutes.ts`                                                                                                                                                       |
| `/ai-sales-assist/products`, `/ai-sales-assist/products/:productId`                                                      | Product Entry/Detail    | `backend/src/routes/aiSalesAssist/productRoutes.ts`, `backend/src/routes/aiApps/productAgentRoutes.ts`                                                                                                      |
| `/ai-sales-assist/browse`, `/ai-sales-assist/browse/:productId`                                                          | Product Browse          | `backend/src/routes/aiSalesAssist/productRoutes.ts`                                                                                                                                                         |
| `/ai-sales-assist/customers`                                                                                             | Customer & Opportunity  | `backend/src/routes/aiSalesAssist/customerRoutes.ts`, `backend/src/routes/aiSalesAssist/chatRoutes.ts`, `backend/src/routes/aiSalesAssist/salesRoutes.ts`, `backend/src/routes/aiApps/opportunityRoutes.ts` |
| `/ai-sales-assist/spin-call-planner`                                                                                     | SPIN Planner            | `backend/src/routes/aiApps/spinCallPlannerRoutes.ts`, `backend/src/routes/aiSalesAssist/salesRoutes.ts`                                                                                                     |
| `/ai-sales-assist/wechat-generator`                                                                                      | WeChat Msg Generator    | `backend/src/routes/aiApps/wechatRoutes.ts`, `backend/src/routes/aiSalesAssist/wechatRoutes.ts`                                                                                                             |
| `/ai-sales-assist/wechat-conversation`                                                                                   | WeChat Conversation     | `backend/src/routes/aiApps/wechatConversationRoutes.ts`                                                                                                                                                     |
| `/ai-sales-assist/salesnailOutline`                                                                                      | SalesNail Outline       | `backend/src/routes/aiApps/salesnailOutlineRoutes.ts`, `backend/src/routes/aiSalesAssist/salesRoutes.ts`                                                                                                    |
| `/ai-sales-assist/training-outline`                                                                                      | Training Outline        | `backend/src/routes/aiApps/trainingOutlineRoutes.ts`                                                                                                                                                        |
| `/ai-sales-assist/ppt-workbench`                                                                                         | PPT Workbench + History | `backend/src/routes/ppt/pptRoutes.ts`, `backend/src/routes/ppt/pptTaskboardRoutes.ts`, `backend/src/routes/ppt/pptHistoryRoutes.ts`                                                                         |
| `/ai-sales-assist/voice-bot/create`, `/ai-sales-assist/voice-bot/student-list`, `/ai-sales-assist/voice-bot/chat/:token` | Voice Bots              | `backend/src/routes/aiSalesAssist/voiceBotRoutes.ts`, `backend/src/routes/aiApps/voiceBotRoutes.ts`, `backend/src/routes/aiApps/voiceBotStatsRoutes.ts`                                                     |
| `/ai-sales-assist/ai-drill/*`                                                                                            | AI Drill                | `backend/src/routes/aiSalesAssist/aiDrillRoutes.ts`, `backend/src/routes/aiApps/aiDrillRoutes.ts`                                                                                                           |
| `/ai-sales-assist/manager`                                                                                               | Manager Dashboard       | `backend/src/routes/aiSalesAssist/dashboardRoutes.ts`                                                                                                                                                       |
| `/ai-sales-assist/config/b2b-process`                                                                                    | B2B Process Config      | `backend/src/routes/aiSalesAssist/processConfigRoutes.ts`                                                                                                                                                   |
| `/ai-sales-assist/b2c/config`, `/ai-sales-assist/b2c/assist`, `/ai-sales-assist/b2c/manager`                             | B2C Module              | `backend/src/routes/aiSalesAssist/b2cRoutes.ts`, `backend/src/routes/aiApps/b2cRoutes.ts`                                                                                                                   |
| `/medical-compliance/*`                                                                                                  | Medical Compliance      | `backend/src/routes/medicalCompliance/index.ts`, `backend/src/routes/aiApps/medicalComplianceRoutes.ts`                                                                                                     |
| `/case-assist/*`                                                                                                         | Case Assist             | `backend/src/routes/aiSalesAssist/caseRoutes.ts`, `backend/src/routes/aiSalesAssist/audioRoutes.ts`                                                                                                         |
| `/chat`                                                                                                                  | Legacy Chat             | `backend/src/index.ts` (`/api/chat`)                                                                                                                                                                        |
| `/chat2`                                                                                                                 | LLM Chat                | `backend/src/index.ts` (`/api/conversations`), `frontend/src/api/aiApi.ts` (LLM gateway stream)                                                                                                             |
| Max floating UI                                                                                                          | Max Agent               | `backend/src/routes/max.ts`                                                                                                                                                                                 |
| `/debug/*`                                                                                                               | Debug Tools             | `backend/src/routes/aiSalesAssist/debugRoutes.ts`                                                                                                                                                           |

## Reference Docs (Feature Scope)
- High-level product overview: `docs/PRODUCT_INTRODUCTION.md`.
- AIsalesAssist modules + permissions: `AIsalesAssist_Module_List.md` and `AIsalesAssist_Permissions.md`.
- WeChat conversation assistant details: `README.md` (feature section).
- Swarm evolution design (v2.0 Three-Colony Symbiosis): `backend/src/aiApps/max/SWARM_EVOLUTION_DESIGN.md`.

## Build, Test, and Development Commands
- Install: `cd frontend && npm install` and `cd backend && npm install`.
- Frontend dev: `cd frontend && npm run dev` (also `dev:uat`, `dev:prd`).
- Frontend build: `cd frontend && npm run build` (includes type-check).
- Frontend lint: `cd frontend && npm run lint`.
- Frontend tests: `cd frontend && npm run test` or `npm run test:run`.
- Backend dev: `cd backend && npm run dev` (http://localhost:3100).
- Backend build/start: `cd backend && npm run build` then `npm run start`.
- Backend tests: `cd backend && npm run test:layer1|test:layer2|test:layer3|test:all` or `npm run test:max` (+ layer flags).
- Convenience scripts: `./front.sh` and `./backend.sh` start each app and will `kill -9` any process on the default port first.

## Testing Guidelines
- Multi-layer test framework lives under `backend/src/tests/` (YAML scenarios in `backend/src/tests/scenarios/`, evaluators in `backend/src/tests/evaluators/`).
- Layer 2/3 tests require LLM access and `.env` vars like `SSO_TEST_KEY` and `LLM_BASE_URL`.
- B2C manual script: `backend/src/tests/b2c-agent-test.sh`.

## Configuration & Secrets
- Backend uses `.env` via `dotenv`. Core DB vars: `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`; auth: `JWT_SECRET`.
- LLM/Gateway vars used in backend/tests: `LLM_BASE_URL`, `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_KEY`, `AZURE_ANTHROPIC_ENDPOINT`, `AZURE_ANTHROPIC_API_KEY`, `SSO_API_KEY`, `COZE_API_TOKEN`, `SSO_TEST_KEY`.
- Frontend gateway base is `VITE_APP_LLM_URL` (used in `frontend/src/api/index.ts`, `frontend/src/api/aiApi.ts`, `frontend/src/utils/freeTrialTracking.ts`).

## AI Gateway & Billing Notes
- Frontend balance checks use `queryIsCanAiUse()` in `frontend/src/api/aiApi.ts` before AI calls.
- Backend token usage logging uses `backend/src/utils/addAiTokenUseLog.ts` with streaming in `backend/src/llm/streamGateway.ts`.
- Legacy local route `/api/chat` remains in `backend/src/index.ts`; primary UI calls go through the gateway via frontend APIs.

## Commit & Pull Request Guidelines
- Recent commits are short and descriptive, sometimes with a version prefix (e.g., `0.311 ...`).
- Keep commits scoped; include context if you modify AI flows or DB schema.
- PRs should include: purpose, key changes, and DB migration notes. Add UI screenshots for frontend changes.

## Worktree Development Requirement
- All feature work should use `git worktree` isolation. Default base branch is `uat` if not specified.
- Example: `git worktree add ../SalesTouch-<feature-name> -b feature/<feature-name> uat`.
- Clean up after merge: `git worktree remove ../SalesTouch-<feature-name>`.
