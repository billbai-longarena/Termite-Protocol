# SwarmWorld and Termite Protocol

> Reviewed on 2026-08-31 against arXiv v1.

## Position in one sentence

[SwarmWorld](https://doi.org/10.48550/arXiv.2608.26081) is a controlled scientific environment for studying stigmergic technological societies of language-model agents. Termite Protocol is a production-oriented engineering protocol that applies environment-mediated coordination to stateless coding agents working across sessions and repositories.

The two projects are not the same system, and neither should be presented as a validation of the other. They are best understood as **independent, convergent work supporting the broader direction that persistent environments can carry coordination, memory, and cumulative capability for AI agents**.

## Research relationship and chronology

Termite Protocol's public Git history begins on **2026-02-23**. SwarmWorld arXiv v1 was submitted on **2026-08-26**. We found no reference to Termite Protocol in the paper's v1 text. Public chronology alone does not establish influence in either direction: research and implementation commonly begin before publication, and both projects build on the much older traditions of stigmergy, blackboard systems, distributed systems, and collective intelligence.

This repository therefore cites SwarmWorld as related research and independent evidence, not as proof of priority, endorsement, replication, or direct lineage.

## Where the ideas converge

| Theme | SwarmWorld | Termite Protocol | Shared direction |
| --- | --- | --- | --- |
| Environment as coordination substrate | Agents alter a persistent spatial world and later agents encounter its changed state. | Agents read and modify repository state, SQLite signals, Git history, documents, tests, and generated `.birth` snapshots. | Coordination can live in the environment instead of a growing conversation. |
| Externalized memory | Persistent artifacts preserve construction, state, provenance, and executable controllers. | Code, commits, observations, rules, WIP records, and blackboards preserve cross-session knowledge. | Useful work should survive the agent that produced it. |
| Cumulative inheritance | Agents observe, reuse, fork, and extend executable artifact programs. | Later agents reuse code, templates, rules, and high-quality behavioral examples. | Capability can accumulate through durable artifacts and traceable modification. |
| Differentiation | Initially equivalent agents develop explorer, constructor, caretaker, and coordinator behaviors. | Agents enter and leave scout, worker, soldier, and nurse operating modes according to field state. | Effective collectives need differentiated behavior that can change over time. |
| Provenance and consequence | A deterministic simulator separates agent claims from functional outcomes and records event lineage. | Git, tests, CI, permissions, signal history, and audit packages separate claims from inspectable engineering evidence. | Agent statements are not enough; consequences and ancestry must be observable. |
| Collective objective | Shared societies are stronger on portfolio breadth and resilience, while isolated search can retain the strongest single artifact. | Termite optimizes continuity, coverage, recoverability, and mixed-agent contribution rather than assuming every task needs one globally strongest agent. | Collective value is often portfolio-level resilience, not only a best individual result. |

Several SwarmWorld findings are especially relevant to Termite Protocol:

- Shared-world conditions produced broader and more resilient technological portfolios than a strong endpoint-wise best-of-N isolated-search baseline, although isolated search remained competitive for the strongest single artifact.
- Approximately 95% of first artifact reuse began through physical observation rather than direct inventor-to-adopter communication.
- Useful behavioral specialization emerged without permanent role assignment, and individual agents changed activity patterns as the world matured.
- Removing explicit cultural mechanisms did not eliminate capable coordination; persistent artifact stigmergy remained a strong substrate.
- The resulting networks tolerated random agent loss better than targeted removal of highly connected agents, exposing both distributed resilience and hub risk.

Together, these results strengthen the case for environment-first agent architectures. They also warn against the stronger and unsupported claim that more communication, more orchestration, or more agents must always produce a better result.

## Where the systems differ

| Dimension | SwarmWorld | Termite Protocol |
| --- | --- | --- |
| Primary purpose | Scientific testbed for collective technological evolution. | Practical coordination protocol for software engineering work. |
| Environment | A deterministic spatial and material simulation with resources, fields, artifacts, and disturbances. | A software repository and its operational state: files, Git, SQLite, tests, CI, and tool outputs. |
| Agent population | Initially homogeneous agents using the same model, prompt, capabilities, and budgets. | Explicitly designed for heterogeneous models and tools with different strengths. |
| Roles | Not assigned; behavioral roles are inferred after the experiment. | Castes are operational modes selected from current state and permission rules. They are not permanent identities. |
| Communication | Full culture includes messages, publications, teaching, trade, task claims, and program inheritance; ablations remove selected channels. | Direct agent-to-agent conversation is normally absent. Agents deliberately leave symbolic records for successors, so Termite is more precisely environment-mediated explicit communication than purely physical stigmergy. |
| Consequence layer | A closed simulator authoritatively decides legality and function, followed by agent-free held-out stress tests. | Host-project tests, builds, runtime checks, code review, and production outcomes provide consequence checks, but the protocol does not supply one universal closed simulator. |
| Memory model | Agents have bounded private memory plus condition-dependent public records during one simulated society. | Agent sessions are treated as disposable; durable continuity is reconstructed from the shared environment on arrival. |
| Evidence level | Controlled ablations, matched seeds, isolated baselines, immutable traces, and held-out evaluation. | Production field observations and multi-model audits, useful for engineering evidence but not yet equivalent to a controlled scientific replication. |
| Additional mechanisms | Physical artifacts, resource constraints, executable controllers, and environmental disturbances. | Signal weight and TTL, evaporation, quality-weighted rule emergence, atomic claims, context-pressure handoff, and safety/permission boundaries. |

The role distinction matters. SwarmWorld demonstrates that roles can emerge from initially homogeneous agents. Termite Protocol uses state-derived castes as a safety and routing mechanism. Similar role names or behaviors therefore do not imply identical causal mechanisms.

The stigmergy distinction matters too. SwarmWorld's strongest example is indirect physical coordination: an agent changes a world object and another later discovers its consequences. Termite agents often write a signal, rule, or WIP record specifically because a successor will read it. That remains environment-mediated coordination, but it is usually intentional symbolic communication through the environment.

## What each project contributes to the shared direction

SwarmWorld contributes a rigorous experimental vocabulary and baseline design:

- compare shared societies with endpoint-wise best-of-N isolated search;
- separate proposals from independently measured consequences;
- evaluate portfolios after removing the agents;
- record adoption, lineage, role transition, network memory, and hub vulnerability;
- use ablations to distinguish physical stigmergy from explicit cultural channels.

Termite Protocol contributes engineering mechanisms for applying the direction to real repositories:

- a bounded `.birth` snapshot for low-context arrival;
- SQLite WAL-mode signals and atomic task claims;
- Git-native provenance and cross-session handoff;
- quality-weighted deposits, evaporation, and rule promotion;
- explicit permission boundaries and recovery behavior;
- mixed-strength-model collaboration through durable behavioral templates.

The strongest combined claim is therefore modest but useful:

> Persistent environments can do more than store context. When they preserve consequential artifacts, provenance, and reusable structure, they can become an active coordination and inheritance substrate for populations of language-model agents.

## Joint research agenda

SwarmWorld suggests a stronger experimental program for Termite Protocol:

1. **Matched ablations** — compare full Termite, repository-only coordination, signals without behavioral templates, and best-of-N isolated coding agents under equal task and model-call budgets.
2. **Agent-free held-out evaluation** — after agents finish, run unseen tests, fault injection, upgrade tasks, or maintainability probes without allowing further model intervention.
3. **Artifact adoption metrics** — measure time to first reuse, number of nonauthor reusers, fork depth, and downstream reach for code, rules, and templates.
4. **Dynamic-role comparison** — compare state-assigned castes with a condition that permits specialization to emerge without caste guidance.
5. **Network robustness** — simulate random agent loss and targeted removal of high-centrality maintainers, templates, or knowledge hubs.
6. **Portfolio metrics** — evaluate breadth, resilience, and recoverability alongside the quality of the single best patch.

These experiments would test which SwarmWorld findings transfer from simulated material societies to real software-engineering environments, and which mechanisms are specific to one domain.

## Citation

Subhadeep Pal, Fiona Y. Wang, and Markus J. Buehler. **SwarmWorld: Stigmergic technological evolution in societies of language-model agents.** arXiv:2608.26081, 2026. DOI: [10.48550/arXiv.2608.26081](https://doi.org/10.48550/arXiv.2608.26081).

```bibtex
@article{pal2026swarmworld,
  title   = {SwarmWorld: Stigmergic technological evolution in societies of language-model agents},
  author  = {Pal, Subhadeep and Wang, Fiona Y. and Buehler, Markus J.},
  journal = {arXiv preprint arXiv:2608.26081},
  year    = {2026},
  doi     = {10.48550/arXiv.2608.26081}
}
```

See also the [Chinese version](swarmworld-and-termite-protocol.zh-CN.md).
