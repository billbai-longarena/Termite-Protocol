# Launch Post — English

## Short version

Most AI coding agents forget everything when the session ends.

**Termite Protocol** is a cross-session collaboration framework that lets stateless AI agents coordinate through the environment instead of conversation.

- SQLite signals
- atomic task claiming
- `.birth` snapshots in ≤800 tokens
- cross-session pheromone-style memory

Validated across 6 real colonies, 4 multi-model audit experiments, and 900+ commits.

If you're exploring multi-agent coding without relying on endless chat history, this may be useful.

## Medium version

I’m open-sourcing **Termite Protocol**, a cross-session collaboration framework for stateless AI coding agents.

The core idea is simple:

Most agents are stateless, but software work is not. Sessions end, context disappears, and the next agent has to rediscover everything.

Termite moves coordination into the environment instead of the conversation:

- signals persist in SQLite
- claims are atomic
- observations accumulate as field memory
- each arriving agent reads a computed `.birth` snapshot instead of a long protocol manual

What makes it interesting is that this approach also works with mixed-strength models.
In one audit experiment, 1 Codex shepherd + 2 Haiku workers reached **96.4% observation quality**.

If you care about AI agents for real project continuity, long-running repos, or strong+weak model mixes, I’d love feedback.

## Long forum version

I’ve been working on a problem that keeps showing up in AI coding workflows:

**agents are stateless, but projects need continuity.**

A lot of multi-agent systems try to solve this by making agents talk to each other more. That works only as long as every agent stays strong enough to carry the conversation context.

Termite Protocol takes a different path:

- agents do not coordinate through chat
- they coordinate through the repository environment
- signals persist in SQLite
- task claims are atomic
- observations accumulate into reusable field memory
- each new session receives a compact `.birth` snapshot instead of reloading a giant rulebook

The project is backed by real audit material, not just diagrams:

- 6 production colonies
- 4 multi-model audit experiments
- 900+ total commits
- 96.4% observation quality in the A-005 Shepherd Effect experiment

It’s a good fit for:

- multi-agent parallel development
- long-running codebases
- strong+weak model mixes
- audit-heavy engineering environments

It is **not** meant for every task. Small one-off jobs are still better handled by a single strong agent.

If you want to kick the tires, the repo now has a 60-second smoke test and a cleaner public onboarding path.

## Suggested titles

- Termite Protocol: Cross-session collaboration for stateless AI coding agents
- Environment-first multi-agent coordination for stateless AI agents
- Show HN: Termite Protocol — let stateless AI agents coordinate through shared state
- A protocol for making stateless AI agents usable across sessions

## CTA options

- Try the 60-second smoke test and tell me where the onboarding breaks.
- If you’ve built multi-agent tooling, I’d love a skeptical read of the mechanism.
- If you care about stateless agents, mixed-strength models, or repo-scale continuity, feedback is very welcome.

## First reply if someone asks “How is this different?”

Most multi-agent tooling coordinates through conversation.

Termite coordinates through the environment:

- the repo stores signals, memory, and recovery hints
- agents sense the field and pick up where others left off
- the coordination survives session boundaries
