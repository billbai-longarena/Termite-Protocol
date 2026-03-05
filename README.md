[中文文档](README.zh-CN.md)

# Termite Protocol

**Stateless AI agents collaborate like termites: no conversation, no memory, order emerges through the environment.**

---

## Executive Summary

The Termite Protocol is a **cross-session collaboration framework for AI agents**. It solves the core contradiction of current AI coding tools: agents are stateless (each session is independent), but software development requires continuous context, coordination, and knowledge accumulation.

**Core mechanism**: Agents don't talk to each other. They coordinate indirectly through the file system — signals persist in SQLite, observations accumulate as pheromones, behavioral templates propagate via `.birth` files. The environment carries intelligence; agents just sense and execute.

**Key data**: Validated across 6 production colonies, 4 multi-model audit experiments, 900+ total commits. In the touchcli A-005 experiment, 1 Codex shepherd + 2 Haiku workers achieved **96.4% observation quality** — a mechanism we call the **Shepherd Effect**.

---

## The Problem

### The Amnesia of AI Agents

Every AI agent session is ephemeral. When a session ends, all context evaporates. This is not a bug — it's a fundamental reality of current LLM architecture.

**Cascading consequences**:

| Problem | Consequence |
| --- | --- |
| **Repeated work** | Every agent re-discovers project structure, conventions, and design decisions |
| **Context loss** | Previous thinking processes, failed attempts, and key judgments vanish with the session |
| **Hallucination accumulation** | Without persistent facts, agents fabricate uncertain information |
| **No division of labor** | Multiple agents can't work in parallel — no coordination mechanism means inevitable conflicts |
| **Weak model failure** | Cheap models lack judgment and produce catastrophically poor output when working independently |

### Limitations of Existing Approaches

| Approach | Coordination method | Why it falls short |
| --- | --- | --- |
| **CLAUDE.md / .cursorrules** | Static rule files | No cross-session memory, no multi-agent coordination, no dynamic state |
| **CrewAI / AutoGen** | Agent conversation | All agents need strong models for conversation context. Weak models hallucinate in multi-turn discussions. No persistent memory. |
| **LangGraph** | Static workflow graphs | Predetermined flow, no dynamic task claiming. Can't adapt to parallel workers finishing at different times. |
| **OpenAI Swarm** | Sequential handoff | Only one agent active at a time. No parallelism. |
| **MCP Server** | Tool invocation | Provides tool capabilities, not coordination mechanisms or knowledge accumulation. |

**Common flaw**: These approaches either assume agents are stateful (they aren't), coordinate through conversation (weak models can't), or lack cross-session knowledge accumulation.

---

## Why Termite Protocol

### 1. Environment Carries Intelligence, Not Agents

This is the fundamental difference from all conversation-based multi-agent frameworks.

```
CrewAI/AutoGen:  Smart Agent ↔ Smart Agent ↔ Smart Agent (conversation)
Termite:         Agent → Environment → Agent → Environment → Agent (stigmergy)
```

**Why this matters**: Weak models don't need to be smart. They just sense signals in the environment and act. All coordination intelligence lives in the environment — signal queues in SQLite, pheromones in the file system, behavioral templates in `.birth`.

### 2. The Shepherd Effect — Proven 18x Quality Improvement

Our most significant finding, validated across 4 audit experiments:

| Configuration | Observation Quality | Handoff Quality | Source |
| --- | --- | --- | --- |
| 2 Haiku independent | **35.7%** | 0% | A-003 ReactiveArmor |
| 1 Codex + 2 Haiku | **96.4%** | 99% | A-005 touchcli |
| 5-model swarm (diluted) | **57%** | 100% | A-006 touchcli |

**Mechanism**: A strong model works first, leaving high-quality pheromone deposits — observations with complete pattern/context/detail structure. Subsequent weak models see these templates via `observation_example` in `.birth` and **imitate the structure through in-context learning**.

**Key insight**: Weak models can't initiate quality patterns, but given a template to follow, Haiku produces Codex-indistinguishable work 96% of the time.

### 3. .birth Compression: 800 Tokens to Initialize Any Agent

| Approach | Agent context cost | What agent needs to read |
| --- | --- | --- |
| Full protocol document (v2) | ~40% of context window | 28K token TERMITE_PROTOCOL.md |
| **Termite .birth (v3+)** | **~2%** of context window | **800 token computed snapshot** |
| CrewAI role prompt | ~10-15% | Role description + conversation history |
| AutoGen system prompt | ~5-10% | System message + growing chat log |

`field-arrive.sh` dynamically computes `.birth`, containing: current colony state, top unclaimed signal, behavioral template (Shepherd Effect exemplar), 4 safety rules, and recovery hints. Everything an agent needs and nothing more.

### 4. Atomic Signal Claiming: No Conversation, No Conflicts, No Bottleneck

Agents never talk to each other. They claim signals from SQLite via atomic transactions:

```
Agent arrives → reads .birth → sees unclaimed signal →
  field-claim.sh claim S-007 → EXCLUSIVE lock → success →
  execute task → commit → field-deposit.sh → done
```

- **No scheduler bottleneck**: Agents self-organize, claiming available work
- **No conflicts**: Atomic DB claims prevent double-assignment
- **Crash resilient**: If an agent dies, the claim auto-releases after heartbeat timeout (fixes the 63-minute starvation discovered in A-006)

### 5. Self-Evolving Protocol: Observations Emerge as Rules

Most frameworks have static rules. Termite Protocol rules are **emergent**:

```
Agent discovers convention → deposits as observation → multiple agents rediscover same convention
  → quality_sum ≥ 3.0 → auto-promotes to rule → all subsequent agents follow
```

This isn't a predefined workflow — it's order growing from practice. Quality-weighted promotion (`quality_sum ≥ 3.0` instead of simple `count ≥ 3`) prevents weak models from flooding the system with degenerate rules (all 21 degenerate rules in A-006 were filtered by the quality gate).

### 6. Protocol Ablation: Agents Don't Read the Protocol

The core shift in v3.0: the protocol dissolves from a document agents must read into environmental infrastructure they sense upon arrival.

```
BEFORE v2:  Agent → reads TERMITE_PROTOCOL.md (28K tokens) → 40% context consumed
AFTER v3:   Agent → field-arrive.sh computes .birth → Agent reads .birth → 2% context consumed
```

`TERMITE_PROTOCOL.md` still exists, but it's a human reference document + script configuration source, no longer agent reading material. Just as termites don't read the mound blueprint — they sense the pheromone concentration beneath their feet.

---

## Production Data

### Real Colony Data

| Colony | Model Config | Duration | Commits | Signals | Key Finding |
| --- | --- | --- | --- | --- | --- |
| **SalesTouch** (0227) | Production | ongoing | — | — | Stable production reference colony |
| **OpenAgentEngine** (A-001) | 2 Codex | — | 54 | — | First audit loop closure, all 7 findings fixed |
| **ReactiveArmor** (A-003) | Codex + 2 Haiku | — | 121 | 24 | **Validates F-009c**: weak models execute protocol loop but fail judgment |
| **touchcli** (A-005) | Codex + 2 Haiku | 6h | 130 | 6 | **Shepherd Effect validated**: 96.4% quality |
| **touchcli** (A-006) | 5 models | 17h | **562** | 113 | Highest throughput; scale degradation and claim starvation discovered |

A-005 delivered a complete MVP: PostgreSQL (11 tables), REST API (11 endpoints), React/Vite frontend, Docker containerization.

### Key Experiment Comparison

| Metric | A-003 (weak-only) | A-005 (Shepherd) | A-006 (5-model mix) |
| --- | --- | --- | --- |
| Observation degradation rate | 64% | 3.6% | 57% |
| Handoff quality | 0% | 99% | 100% |
| Rule emergence | 0 | 1 | 21 (all degenerate) |
| Conclusion | Weak-only = disaster | 1 strong + N weak = efficient | Dilution effect needs control |

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash
```

Or:
```bash
git clone https://github.com/billbai-longarena/Termite-Protocol /tmp/termite
bash /tmp/termite/install.sh
rm -rf /tmp/termite
```

Upgrade: `bash /tmp/termite/install.sh --upgrade`

After installation, edit `CLAUDE.md` / `AGENTS.md` to fill in your project information.

---

## How to Use

### Step 1: Install the Protocol

The install script handles everything: copies template files, creates `signals/` directory, installs git hooks, installs Claude Code plugin, updates `.gitignore`.

### Step 2: Fill in Project Information

Edit `CLAUDE.md` / `AGENTS.md` with: project overview, tech stack, route table, validation checklist.

### Step 3: Agents Start Working

```
Agent starts → field-arrive.sh → .birth (≤800 tokens) → Agent reads .birth → works
```

You'll observe: agents auto-sense state (via `.birth`), frequent commits with signature tags, proactive handoff file writing, fixing inconsistencies between docs and code.

### Step 4: Automate with Commander (Recommended)

Managing a colony manually is tedious. [**Termite Commander**](https://github.com/billbai-longarena/TermiteCommander) automates the full pipeline:

```bash
# Install Commander
npm install -g termite-commander

# Launch a colony
cd ~/your-project
termite-commander plan "Implement OAuth auth" --plan PLAN.md --colony . --run

# Or in Claude Code
> /commander Build auth system from PLAN.md
```

Commander auto-handles: detect protocol → install → genesis → decompose signals → dispatch → launch mixed-model workers → heartbeat monitoring → auto-stop on completion.

See [Commander README](https://github.com/billbai-longarena/TermiteCommander#readme) for details.

---

## When to Use

### Good Fit

| Scenario | Why it fits |
| --- | --- |
| **Multi-agent parallel development** | Signal claiming is conflict-free, each agent works independently |
| **Strong + weak model mixing** | Shepherd Effect lets 1 strong + N weak achieve near-strong-model quality |
| **Long-term projects** | Pheromones accumulate knowledge across sessions, later agents become more efficient |
| **Large-scale refactoring** | Many independent file-level changes, highly parallelizable |
| **Audit trail requirements** | Every observation, decision, and rule has source tracking |

### Not a Good Fit

| Scenario | Why it doesn't fit | Suggestion |
| --- | --- | --- |
| **Small single-agent tasks** | Protocol overhead > benefit | Use Claude Code directly |
| **Exploratory research** | Needs strong model holistic judgment | Use Claude Code natively |
| **One-off scripts** | No need for cross-session memory | Just write it |

---

## Architecture

### File Structure

```
your-project/
  TERMITE_PROTOCOL.md   ← Human reference + script configuration source
  CLAUDE.md / AGENTS.md ← Agent entry file
  BLACKBOARD.md         ← Dynamic state (health, signals, hotspots)
  WIP.md                ← Cross-session handoff
  .birth                ← Dynamically computed agent initialization (≤800 tokens)
  .pheromone            ← Pheromone chain (cross-session knowledge accumulation)
  scripts/
    field-arrive.sh     ← Computes .birth
    field-cycle.sh      ← Heartbeat loop (Sense → Act → Notice → Deposit)
    field-deposit.sh    ← Pheromone deposition
    field-claim.sh      ← Atomic task claiming
    field-decay.sh      ← Pheromone decay
    field-pulse.sh      ← Project status snapshot
    termite-db.sh       ← SQLite WAL-mode DB
    hooks/              ← Git hooks (signature/security/metabolism)
  signals/              ← Signal storage
```

### Protocol Layers

| Layer | File | Context Cost |
| --- | --- | --- |
| **Protocol source** | `TERMITE_PROTOCOL.md` | Human reading (agents don't read this) |
| **Field scripts** | `scripts/` | 0 (script execution, no agent context consumed) |
| **Agent entry** | `.birth` | **~2%** (800 tokens) |

### Protocol 4-Part Structure

| Part | Contents | Target Audience |
| --- | --- | --- |
| **I: Grammar** | 9 rules + 4 safety nets | field-arrive.sh extracts → .birth |
| **II: Environment Config** | Castes, signal schema, degradation matrix | field-arrive.sh reads |
| **III: Human Reference** | Full design rationale, immune system | Human reading |
| **IV: Appendices** | Templates, quick reference cards | On-demand reference |

---

## Field Scripts

| Script | Purpose |
| --- | --- |
| `field-arrive.sh` | Arrival: reads protocol + environment → computes .birth |
| `field-cycle.sh` | Heartbeat: Sense → Act → Notice → Deposit |
| `field-deposit.sh` | Deposition: observations/decisions/status → signal files |
| `field-claim.sh` | Claiming: atomic lock/release/query |
| `field-decay.sh` | Decay: clean up expired signals |
| `field-pulse.sh` | Pulse: project status snapshot |
| `field-drain.sh` | Drain: bulk signal clearing |
| `termite-db.sh` | DB: SQLite WAL-mode + migrations |

### Git Hooks

| Hook | Purpose |
| --- | --- |
| `pre-commit` | Prevent committing sensitive files, validate file sizes |
| `prepare-commit-msg` | Auto-add `[termite:YYYY-MM-DD:caste]` signature |
| `post-commit` | Auto-trigger pheromone deposition after commit |
| `pre-push` | Branch protection, security scanning |

---

## Platform Support

| Platform | Entry File | Support Level |
| --- | --- | --- |
| **Claude Code** | `CLAUDE.md` | Full support: field-arrive.sh + .birth + hooks |
| **OpenAI Codex** | `AGENTS.md` | Full support: self-starting blackboard protocol |
| **OpenCode** | `CLAUDE.md` | Full support: via skill system |
| **Google Gemini** | `AGENTS.md` | Full support |
| **Cursor / Windsurf / Cline** | Platform-specific rule files | Graceful degradation: inline rule summary (~5%) |

---

## Protocol Evolution

| Version | Key Changes |
| --- | --- |
| **v1.0** | Caste system, lifecycle, pheromone rules, ALARM mechanism |
| **v2.0** | Protocol-project separation, signature format, state moved to BLACKBOARD.md |
| **v3.0** | **Protocol ablation**: .birth compressed to 800 tokens, observation→rule auto-promotion, git hooks automation |
| **v3.5** | DB architecture (SQLite WAL), Shepherd Effect, colony lifecycle detection |
| **v4.0** | Strength-based participation: differentiated .birth (execution/judgment/direction) |
| **v5.0** | Stateless + intelligent environment: quality-weighted emergence, trace/deposit separation |
| **v5.1** | Signal dependency graph: parent-child decomposition, leaf-priority .birth, auto-aggregation |

---

## Design Philosophy

**Simple rules, complex emergence. Protocol dissolves into environment.**

Termite Protocol doesn't design perfect AI agent workflows. It gives stateless agents a minimal set of local rules and lets order emerge spontaneously from chaos.

Like a real termite mound — no architect, yet the structure stands. No queen approving decisions; consensus emerges through pheromone concentration stacking.

**"No Queen" principle**: No role in the protocol has special approval authority. Humans are fellow colony members, not external managers. Human instructions always take precedence over protocol rules.

---

## License

MIT License. See [LICENSE](LICENSE).
