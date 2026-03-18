---
tags:
  - architecture
  - vision
---

# Brain as Microservices on a Shared Event Bus

The human brain isn't a single process — it's dozens of specialized subsystems communicating through shared chemical and electrical signals. The prefrontal cortex doesn't "call" the amygdala. They both react to the same event independently, and their outputs combine.

Anima mirrors this with an event-driven architecture.

## The Pattern

Every event fired on the bus reaches all subscribers simultaneously:

```
Event: "tool_call_failed"
  │
  ├── Analytical brain: update goals, check if workflow needs changing   ← Implemented
  ├── Thymos subscriber: frustration += 10                               ← Planned
  ├── Mneme subscriber: log failure context for future recall            ← Planned
  └── Psyche subscriber: update coefficient (handles errors calmly)     ← Planned

Event: "user_sent_message"
  │
  ├── Analytical brain: activate relevant skills, name session           ← Implemented
  ├── Thymos subscriber: oxytocin += 5 (bonding signal)                  ← Planned
  └── Mneme subscriber: associate emotional state with topic             ← Planned
```

Each subscriber is a **microservice** — independent, stateless, reacting to the same event bus. No orchestrator decides what to do. The architecture IS the nervous system.

## The Analytical Brain as Proof of Concept

The analytical brain is the first subscriber — a working proof that the pattern scales. It demonstrates:

- **Independence** — the brain runs its own LLM, has its own tools, makes its own decisions
- **Non-interference** — brain failures don't affect the main agent
- **Additive** — plugging in the brain required no changes to the core agent loop
- **Observable** — brain actions appear in the event stream and TUI

Future subscribers (Thymos, Mneme, Psyche) plug into the same bus with the same pattern.

## Planned Subscribers

### Thymos (Hormonal System)

Watches tool results, user messages, and time patterns. Updates hormone levels in SQLite. Those levels are read by the system prompt assembler and injected as desire descriptions into the agent's thinking context.

See [Thymos](../vision/thymos.md).

### Mneme (Semantic Memory)

Watches events approaching eviction from the viewport. Pins critical ones. Builds associative indexes for recall. Provides "last time we discussed this topic" context.

See [Mneme](../vision/mneme.md).

### Psyche (Soul Matrix)

Watches hormone changes over time. Updates the coefficient table that maps stimuli to hormone responses — the numerical definition of individuality. Persists personal growth.

See [Psyche](../vision/psyche.md).

## Why This Architecture

**Separation of concerns.** Each subsystem does one thing. The main agent thinks and acts. The analytical brain manages context. Thymos manages desire. None of these concerns bleed into each other.

**Incremental addition.** Adding a new brain subsystem doesn't touch existing code. Drop a new subscriber on the bus. Done.

**Independent failure.** If Thymos crashes, the main agent keeps running. The bus doesn't care about subscriber health.

**Testability.** Each subscriber can be tested in isolation with synthetic events.
