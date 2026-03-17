# HN Launch Post

## Title

```
Show HN: Termite Protocol – stateless AI agents coordinate through shared state, not conversation
```

---

## Body (paste this into HN text field)

AI coding agents are stateless. Projects are not. Every session ends and the next agent rediscovers everything from scratch.

Most tools fix this with more conversation. Termite Protocol fixes it by moving coordination into the repository itself: signals in SQLite, atomic task claiming, and a computed <=800-token .birth snapshot each agent reads on arrival instead of a long protocol doc.

The finding that surprised me: in experiment A-005, 2 Haiku agents working alone had 35.7% observation quality. After 1 Codex agent left a single high-quality observation in the field, the Haiku agents read it via .birth and imitated the structure. Quality jumped to 96.4% with no other changes — no supervisor, no per-agent prompting. The environment carried the pattern. I'm calling this the Shepherd Effect.

Data across 3 experiments:
  A-003 | Codex + 2 Haiku | 121 commits | 64%   | weak models loop, don't judge
  A-005 | Codex + 2 Haiku | 130 commits | 96.4% | Shepherd Effect validated
  A-006 | 5 models        | 562 commits | 57%   | throughput scales, quality regresses

60-second smoke test:
  mkdir termite-demo && cd termite-demo
  curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash
  ./scripts/field-arrive.sh && ./scripts/field-pulse.sh

Not meant for one-off tasks — single agent is better there.

Open questions I'd like input on: (1) weak models fail at judgment even with a good .birth — protocol problem or capability ceiling? (2) why is the Shepherd Effect magnitude so large? (3) 800-token uniform context vs tiered-context — anyone with principled opinions?

https://github.com/billbai-longarena/Termite-Protocol

---

## Prepared replies

### "How is this different from LangGraph / CrewAI / AutoGen?"

Those tools coordinate through conversation: a planner or supervisor maintains a thread and passes context between agents.

Termite has no orchestrator. Agents arrive independently, read the environment, claim work, and leave. Coordination happens through the repository state, not through a running process. This means:

- no single point of failure
- no growing context per agent
- the protocol survives the process dying (or the model changing)

The cost is that you give up real-time inter-agent messaging. If your use case requires agents to ask each other questions mid-task, Termite is the wrong tool.

### "Shell scripts feel hacky for this"

Fair. The choice was deliberate: zero runtime dependencies, installs into any repo with one `curl | bash`, works with any agent that can read files and run bash.

The SQLite layer handles the parts that need atomicity. The rest is file I/O that any model can reason about.

If you're building a product and want Postgres or a proper API, the protocol's concepts port cleanly — the shell scripts are the reference implementation, not a requirement.

### "96.4% is a single experiment"

Correct. A-003 (Codex + 2 Haiku, no explicit Shepherd setup) had 64%. A-006 (5-model swarm) had 57%.

The Shepherd Effect is real but not automatic — it requires a strong model to seed the field with a high-quality example early. When no shepherd is present, or when the environment floods with weak-model noise before a shepherd arrives, quality degrades. That's an open problem.

---

## Notes on tone

HN rewards:
- honest acknowledgment of limitations
- concrete data over marketing language
- specific open questions that invite real technical discussion
- "I built this, here's what surprised me" framing over "here's a product"

Avoid:
- "revolutionary", "game-changing", any superlatives
- overselling the Shepherd Effect as solved
- hiding the shell-script implementation
