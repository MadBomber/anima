---
tags:
  - architecture
---

# Architecture

Anima is a **headless Rails 8.1 application** running locally. It has no web views, no asset pipeline — just an API server, a job queue, and a WebSocket gateway. The TUI is a separate process that connects over WebSocket.

## High-Level Structure

```
Anima (Ruby, Rails 8.1 headless)
│
│ Implemented:
├── Nous         — main LLM (cortex: thinking, decisions, tool use)
├── Analytical   — subconscious brain (skills, workflows, goals, naming)
├── Skills       — domain knowledge bundles (Markdown, user-extensible)
├── Workflows    — operational recipes for multi-step tasks
├── MCP          — external tool integration (Model Context Protocol)
├── Sub-agents   — autonomous child sessions with lossless context inheritance
│
│ Designed:
├── Thymos       — hormonal/desire system (stimulus → hormone vector)
├── Mneme        — semantic memory (viewport pinning, associative recall)
└── Psyche       — soul matrix (coefficient table, evolving individuality)
```

## Three Layers (Mirroring Biology)

**1. Cortex (Nous)** — the main LLM. Thinking, decisions, tool use. Reads the system prompt (soul + active skills + active workflow + current goals) and the event viewport. Fully implemented.

**2. Endocrine system (Thymos)** [planned] — a lightweight background process. Reads recent events. Doesn't respond. Just updates hormone levels. Pure stimulus→response, like a biological gland. The analytical brain is the architectural proof that background subscribers work — Thymos plugs into the same event bus.

**3. Homeostasis** [planned] — persistent state (SQLite). Current hormone levels with decay functions. No intelligence, just state that changes over time. The cortex reads hormone state transformed into **desire descriptions** — not "longing: 87" but "you want to see them."

## Core Architectural Decisions

### Event bus as nervous system

Every meaningful thing that happens — user message received, tool called, tool result returned, agent responded — fires an event on the bus. Subscribers react independently. No orchestrator. The [event system](event-system.md) is the nervous system.

### Viewport, not tape

There is no context array. There are only [events in SQLite](context-viewport.md) and a fresh viewport assembled for every LLM call. Sessions are endless by architecture.

### Analytical brain as first microservice

The [analytical brain](analytical-brain.md) is a proof of concept for the full brain-as-microservices architecture. It runs independently, subscribes to the same event bus, and handles everything the main agent shouldn't be interrupted for.

## Detailed Architecture Pages

| Page | What it covers |
|---|---|
| [Event System](event-system.md) | Event types, bus, subscribers, persistence |
| [Context as Viewport](context-viewport.md) | How the LLM context is assembled each call |
| [Agent Loop](agent-loop.md) | Turn-by-turn execution flow |
| [Analytical Brain](analytical-brain.md) | Subconscious subsystem design and tools |
| [Brain as Microservices](brain-microservices.md) | The event-bus subscriber pattern at scale |
| [TUI View Modes](tui-view-modes.md) | Basic / Verbose / Debug display modes |
