# Website Homepage Copy — English

## Meta

- **Title**: Termite Protocol — Cross-session collaboration for stateless AI coding agents
- **Description**: Let stateless AI agents coordinate through shared state instead of conversation. SQLite signals, atomic claiming, `.birth` snapshots, and cross-session field memory.
- **Open Graph Title**: Termite Protocol
- **Open Graph Description**: Stateless AI agents collaborate through the environment, not conversation.

## Hero

### Eyebrow

Cross-session coordination for AI coding agents

### Headline

Stateless AI agents need an environment, not a conversation.

### Subheadline

Termite Protocol lets fresh AI agent sessions pick up real repository work through SQLite signals, atomic claiming, and compact `.birth` snapshots.

### Primary CTA

Try the 60-second smoke test

### Secondary CTA

Read the audit-backed explanation

### Hero proof strip

Validated across 6 production colonies · 4 multi-model audits · 900+ commits

## Problem section

### Heading

The session ends. The context disappears. The project does not.

### Body

Most AI coding agents are stateless. Every new session risks rediscovering the same structure, repeating the same mistakes, and losing the same design context.

Conversation-heavy coordination helps only until context cost, drift, and weaker models start to dominate.

## Solution section

### Heading

Put coordination in the field.

### Body

Termite Protocol moves collaboration into the repository environment itself.

Instead of preserving continuity through ever-growing chat history, it persists operational state in the field:

- signals in SQLite
- atomic work claiming
- pheromone-style observations
- `.birth` snapshots for fresh sessions

## Feature cards

### Card 1

- **Title**: Environment-first coordination
- **Copy**: Agents do not need to talk to each other. They sense shared state and continue the work.

### Card 2

- **Title**: Bounded context cost
- **Copy**: `.birth` compresses the current colony state into a compact operational snapshot.

### Card 3

- **Title**: Mixed-strength model leverage
- **Copy**: Strong models can seed patterns that weaker workers follow, improving colony-wide output quality.

### Card 4

- **Title**: Real project continuity
- **Copy**: Memory persists in the environment, so later sessions do not start from zero.

## Proof section

### Heading

Backed by field data, not just architecture diagrams.

### Body

The protocol has been exercised across real colonies and audit packages, including a Shepherd Effect configuration where 1 strong model and 2 weaker workers reached **96.4% observation quality**.

### Proof bullets

- 6 production colonies
- 4 multi-model audit experiments
- 900+ total commits
- A-005: 96.4% observation quality

## How it works

### Step 1

A new agent arrives and reads `.birth`.

### Step 2

The agent claims the next unassigned signal atomically.

### Step 3

The agent completes work and deposits observations back into the field.

### Step 4

The next session continues from the repository state instead of rediscovering it.

## Use cases

- Multi-agent parallel development
- Long-running repositories
- Strong + weak model mixes
- Audit-heavy engineering teams
- Large refactors with many separable tasks

## Not for everything

Termite Protocol is not the right tool for tiny one-off tasks or purely exploratory work. It is designed for continuity-heavy engineering workflows.

## FAQ

### How is this different from conversation-based multi-agent tools?

Conversation is not the coordination backbone. The environment is.

### Do I need a separate automation layer to use it?

No. The protocol is installable and usable on its own.

### Does this replace strong models?

No. It makes strong models more leverageable and weaker models more usable inside the same field.

## Final CTA

### Heading

Test where stateless agents stop feeling stateless.

### Body

Run the smoke test, inspect the audit materials, and stress the assumptions in a real repository.

### Buttons

- Get started
- Read the docs
