[中文文档](README.zh-CN.md)

# Termite Protocol

[![Latest Release](https://img.shields.io/github/v/release/billbai-longarena/Termite-Protocol?display_name=tag)](https://github.com/billbai-longarena/Termite-Protocol/releases)
[![License](https://img.shields.io/github/license/billbai-longarena/Termite-Protocol)](LICENSE)
[![Discussions](https://img.shields.io/github/discussions/billbai-longarena/Termite-Protocol)](https://github.com/billbai-longarena/Termite-Protocol/discussions)

**Stateless AI agents collaborate like termites: no conversation, no memory, order emerges through the environment.**

![Termite Protocol overview](docs/assets/termite-overview.svg)

## In 30 Seconds

**Termite Protocol** is a cross-session collaboration framework for AI coding agents.

It addresses a structural mismatch in today’s tooling:

- AI agent sessions are stateless and ephemeral.
- Software projects need continuity, coordination, and memory.
- Multi-agent systems often rely on conversation, which is expensive and fragile.

Termite solves this by moving coordination into the environment:

- signals are persisted in SQLite
- task claims are atomic
- observations accumulate as pheromone-like memory
- each arriving agent reads a computed `.birth` snapshot instead of a long protocol manual

### Why it stands out

- **Environment-first coordination**: agents do not talk to each other; they sense shared state.
- **Low context cost**: `.birth` compresses operational context into ≤800 tokens.
- **Works with mixed-strength models**: one strong model can seed patterns that weaker models imitate.
- **Built for real project continuity**: knowledge persists across sessions, not just inside a single chat.
- **Backed by field data**: validated across 6 production colonies, 4 multi-model audit experiments, and 900+ total commits.

## Proof, Not Hype

### Shepherd Effect

In the touchcli A-005 experiment, **1 Codex shepherd + 2 Haiku workers reached 96.4% observation quality**.

The key mechanism is simple:

1. a strong model leaves a high-quality example in the field
2. later workers read the example from `.birth`
3. weaker models imitate the structure via in-context learning

This is why Termite is not just “more agent orchestration.” It is a protocol for making stateless, mixed-strength agents usable over time.

### Experiment snapshot

| Configuration | Observation Quality | Handoff Quality | Key takeaway |
| --- | --- | --- | --- |
| 2 Haiku independent | **35.7%** | 0% | Weak-only execution degrades badly |
| 1 Codex + 2 Haiku | **96.4%** | 99% | Shepherd Effect works |
| 5-model mixed swarm | **57%** | 100% | Throughput scales, quality needs control |

### Real colony data

| Colony | Model mix | Commits | Signals | Key finding |
| --- | --- | --- | --- | --- |
| `0227` SalesTouch | Production | — | — | Stable production reference colony |
| `A-001` OpenAgentEngine | 2 Codex | 54 | — | First audit loop closed |
| `A-003` ReactiveArmor | Codex + 2 Haiku | 121 | 24 | Weak models can loop, but not judge well |
| `A-005` touchcli | Codex + 2 Haiku | 130 | 6 | Shepherd Effect validated |
| `A-006` touchcli | 5 models | 562 | 113 | Highest throughput; starvation and dilution surfaced |

## When To Use It

### Good fit

| Scenario | Why it fits |
| --- | --- |
| Multi-agent parallel development | Atomic signal claiming avoids double-assignment |
| Strong + weak model mixes | A strong model can seed patterns for weaker workers |
| Long-running projects | Cross-session memory compounds over time |
| Large refactors | Independent file-level work parallelizes cleanly |
| Audit-heavy work | Signals, observations, and rules are traceable |

### Not a good fit

| Scenario | Why it does not fit | Better choice |
| --- | --- | --- |
| Small one-off tasks | Protocol overhead is larger than the gain | Use a single coding agent directly |
| Open-ended research | Requires holistic judgment more than structured execution | Use a strong model interactively |
| Tiny scripts | No need for field memory or work claiming | Keep it simple |

## 60-Second Smoke Test

Create a fresh folder and run the protocol locally:

```bash
mkdir termite-demo && cd termite-demo
curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash
./scripts/field-arrive.sh
ls -la
./scripts/field-pulse.sh
sqlite3 .termite.db "select id,status,title from signals;"
```

A successful first run should give you:

- `BLACKBOARD.md`
- `CLAUDE.md` and `AGENTS.md`
- an initial signal in `.termite.db` such as `S-001 | open | ...`
- pulse output showing `signals=1` after the first arrival
- a computed `.birth` snapshot

For a fuller walkthrough, see `QUICKSTART.md:1`.

## How It Works

### Agent lifecycle

```text
Agent arrives
  → field-arrive.sh computes .birth
  → agent reads current colony snapshot
  → field-claim.sh claims unassigned work atomically
  → agent executes task
  → field-deposit.sh leaves observations / decisions / status
  → next agent continues from the environment
```

### Core mechanisms

#### 1. Environment carries the intelligence

Conversation-based systems assume the agents themselves must remain context-rich. Termite puts coordination into the field instead:

- signals in SQLite
- pheromone history in repository state
- templates in `.birth`
- safety and recovery hints computed on arrival

#### 2. `.birth` replaces protocol reading

A new session does not need to read a 28K-token protocol document.

| Approach | Context cost | What the agent reads |
| --- | --- | --- |
| Full protocol document | ~40% of context window | `TERMITE_PROTOCOL.md` |
| **Termite `.birth`** | **~2%** | computed operational snapshot |
| Conversation-heavy orchestration | ~5–15%+ | role prompt + growing chat log |

#### 3. Atomic signal claiming

Claims are coordinated through SQLite transactions.

- no scheduler bottleneck
- no double-assignment
- no conversation overhead
- stalled claims can be recovered after heartbeat timeout

#### 4. Rules emerge from repeated evidence

Observations can be promoted into reusable rules when repeated evidence accumulates.

This helps the environment get smarter over time without forcing every agent to rediscover the same conventions.

## Repository Map

```text
your-project/
  TERMITE_PROTOCOL.md   ← human reference + script configuration source
  CLAUDE.md / AGENTS.md ← agent entry files
  BLACKBOARD.md         ← dynamic state snapshot
  WIP.md                ← cross-session handoff
  .birth                ← computed agent initialization (≤800 tokens)
  .pheromone            ← latest pheromone chain
  scripts/
    field-arrive.sh     ← computes .birth
    field-claim.sh      ← atomic task claiming
    field-cycle.sh      ← sense → act → notice → deposit
    field-deposit.sh    ← write observations and status
    field-pulse.sh      ← project health snapshot
    termite-db.sh       ← SQLite WAL-mode DB
  signals/              ← active, archived, claims, observations, rules
```

## Start Here

- `QUICKSTART.md:1` — first install, first arrival, first signal
- `docs/releases/v1.1.0.md:1` — release notes for this repository packaging release
- `docs/knowledge-base/README.md:1` — concept cards and protocol insights
- `CONTRIBUTING.md:1` — how to contribute safely and efficiently
- `SUPPORT.md:1` — where to ask questions vs. file issues
- `SECURITY.md:1` — how to report vulnerabilities
- `CHANGELOG.md:1` — versioned repository changes

## Research and Audit Assets

This repository includes the materials behind the protocol claims:

- `audit-packages/` — audit bundles from real experiments
- `audit-analysis/` — prevention kits and analysis artifacts
- `docs/plans/` — design docs, experiment plans, and protocol evolution notes
- `docs/knowledge-base/` — concise reusable findings extracted from field work

## Optional Companion

Termite Commander is an optional automation companion for teams that want to script colony dispatch and supervision. It is **not required** to use the protocol itself.

## Contributing

Questions belong in Discussions. Reproducible bugs and scoped feature requests belong in Issues.

If you want to help, good starting points are:

- onboarding and docs clarity
- reproducible smoke tests
- experiments and audit-packaged findings
- shell script robustness and install flow

See `CONTRIBUTING.md:1` for workflow details.

## License

MIT. See `LICENSE`.
