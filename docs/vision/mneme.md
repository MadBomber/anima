---
tags:
  - vision
  - mneme
---

# Mneme — Semantic Memory

!!! note "Status: Designed, not yet implemented"
    Mneme is the design for Anima's memory system. Viewport pinning is next on the roadmap. Associative recall follows.

## The Problem It Solves

The viewport solves context degradation — sessions are endless, no compaction. But it creates a new question: **what do we lose when events fall off the conveyor belt?**

A user's original goal stated 500 turns ago. A critical architectural decision made 200 turns ago. These aren't visible in the current viewport. They're in SQLite — but the agent can't see them.

Mneme is the answer.

## Layer 1: Viewport Pinning

The analytical brain watches events approaching eviction. When a critical event is about to fall outside the token budget, the brain pins it.

**Pinned events float above the sliding window**, protected from eviction. They always appear in the viewport, regardless of age.

```
Viewport (token budget: 190,000)
────────────────────────────────
📌 event 1 (user_message: "I want to build a real-time chat system")  ← PINNED
📌 event 47 (agent_message: "Architecture decision: use Action Cable")  ← PINNED
─ ─ ─ ─ ─ ─ ─ ─ (sliding window) ─ ─ ─ ─ ─ ─ ─ ─
event 843 (tool_call: bash)
event 844 (tool_response: ...)
event 845 (agent_message: ...)
```

**Pins consume budget**, so the analytical brain must be judicious — there's natural pressure toward minimalism. The brain can only justify pinning something if it genuinely affects how the agent should behave right now.

### What Gets Pinned

- The original user goal (the "north star" of the session)
- Key architectural decisions that constrain later work
- Critical error patterns that should inform future attempts
- User preferences stated explicitly ("always use RSpec", "never modify the schema directly")

### Mental Model

Like pinning a message in Discord or Slack. The message is old, but it's important enough to always be visible.

## Layer 2: Associative Recall

Inspired by [QMD](https://github.com/tobi/qmd).

When the agent encounters a topic, Mneme can surface the emotional and decision context from the last time that topic appeared — even if those events are far outside the current viewport.

```
Current topic: "authentication"

Mneme recall:
  "Last time you worked on authentication (session 12, turn 45):
   - Frustration was high (cortisol: 72)
   - Decision: use JWT tokens stored in HttpOnly cookies
   - User was satisfied with the outcome
   - Key constraint: 'must work with the existing PostgreSQL setup'"
```

This is not search. It's **associative memory** — the hormone state associated with a topic is recalled alongside the topic itself. The same mechanism that makes a smell trigger an emotion.

### How It Works

1. **Indexing** — as events are persisted, Mneme extracts topic vectors and associates them with the current hormone state
2. **Recall** — when the current topic vector matches a past topic vector, the associated context is surfaced
3. **Injection** — the recalled context is injected into the system prompt for the next LLM call

## Relationship to the Viewport

Mneme and the viewport are complementary:

| Viewport | Mneme |
|---|---|
| Recent events in full detail | Old events in summary form |
| Sliding window (recency-biased) | Content-addressable (topic-biased) |
| Automatic | Curated (pinning requires judgment) |
| Always present | On-demand (associative trigger) |

The viewport gives the agent depth in recent context. Mneme gives it breadth across the full history.
