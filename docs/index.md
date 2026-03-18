---
tags:
  - overview
---

# Anima

**Not a tool. An agent.**

Every AI agent today is a tool pretending to be a person. One brain doing everything. A static context array that fills up and degrades. Sub-agents that start blind and reconstruct context from lossy summaries.

Anima is built on the premise that if you want an agent — a real one — you need to solve the problems nobody else is solving.

---

## What Makes Anima Different

### A brain modeled after biology, not chat

The human brain isn't one process — it's specialized subsystems on a shared signal bus. Anima's [analytical brain](architecture/analytical-brain.md) runs as a separate subconscious process, managing context, skills, and goals so the main agent can stay in flow. Two agents, each doing one job well. More subsystems are [coming](vision/index.md).

### Context that never degrades

Other agents fill a static array until the model gets dumb. Anima assembles a fresh **viewport** over an event bus every iteration. No compaction. No summarization. Endless sessions. The [dumb zone](https://www.humanlayer.dev/blog/the-dumb-zone) never arrives — and the analytical brain curates what the agent sees, in real time.

### Sub-agents that already know everything

When Anima spawns a sub-agent, it inherits the parent's full event stream — every file read, every decision, every user message. No "let me summarize what I know." Lossless context. Zero wasted tool calls on rediscovery.

### A soul the agent writes itself

Anima's first session is birth. The agent wakes up, explores its world, meets its human, and writes its own identity — a living document it authors and evolves. Always in context, always its own.

---

## Runtime Model

```
Brain Server (Rails + Puma)              TUI Client (RatatuiRuby)
├── LLM integration (Anthropic)          ├── WebSocket client
├── Agent loop + tool execution          ├── Terminal rendering
├── Analytical brain (background)        └── User input capture
├── Skills registry + activation
├── Workflow registry + activation
├── MCP client (HTTP + stdio)
├── Sub-agent spawning
├── Event bus + persistence
├── Solid Queue (background jobs)
├── Action Cable (WebSocket server)
└── SQLite databases           ◄── WebSocket (port 42134) ──► TUI
```

Your agent runs locally as a headless Rails 8.1 app. The **Brain** is the persistent service. The **TUI** is a stateless client — if it disconnects, the brain keeps running. TUI reconnects automatically with exponential backoff.

---

## Current Status

Working agent, shipping now:

| Capability | Status |
|---|---|
| Event-driven architecture | ✅ Implemented |
| Dynamic viewport context (endless sessions) | ✅ Implemented |
| Analytical brain (skills, workflows, goals, naming) | ✅ Implemented |
| 10 built-in tools + MCP integration | ✅ Implemented |
| 7 built-in skills | ✅ Implemented |
| 13 built-in workflows | ✅ Implemented |
| Sub-agents with lossless context inheritance | ✅ Implemented |
| 5 built-in specialist agents | ✅ Implemented |
| WebSocket transport + graceful reconnection | ✅ Implemented |
| Three TUI view modes | ✅ Implemented |
| Hot-reloadable TOML configuration | ✅ Implemented |
| Self-authored soul | ✅ Implemented |
| Hormonal system (Thymos) | 🔜 Designed |
| Semantic memory (Mneme) | 🔜 Designed |
| Soul matrix (Psyche) | 🔜 Designed |

---

## Quick Links

- [Installation](getting-started/installation.md) — Get up and running in minutes
- [Architecture Overview](architecture/index.md) — How it all fits together
- [Tools Reference](capabilities/tools.md) — What the agent can do
- [Configuration Reference](getting-started/configuration.md) — All tunable settings
- [Vision](vision/index.md) — Where Anima is going
