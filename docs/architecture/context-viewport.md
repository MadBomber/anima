---
tags:
  - architecture
  - context
---

# Context as Viewport, Not Tape

Most agents treat context as an append-only array. Messages go in, they never come out (until compaction destroys them). Anima has no array.

## The Model

There are only **events persisted in SQLite** and a **viewport** assembled fresh for every LLM call.

```
SQLite (all events, forever)
─────────────────────────────
event 1  (user_message)
event 2  (agent_message)
event 3  (tool_call)
event 4  (tool_response)
event 5  (agent_message)   ← evicted from current viewport
event 6  (tool_call)       ← evicted from current viewport
event 7  (user_message)    ─────────────┐
event 8  (agent_message)               │  Current viewport
event 9  (tool_call)                   │  (token budget: 190,000)
event 10 (tool_response)               │
event 11 (agent_message)   ────────────┘
```

The viewport is a **live query**, not a log. It walks events newest-first until the token budget is exhausted. Events that fall out of the viewport aren't deleted — they're still in the database, just not visible to the model right now.

## Properties

**Sessions are endless.** No compaction. No summarization. No degradation. The model always operates in fresh, high-quality context. The [dumb zone](https://www.humanlayer.dev/blog/the-dumb-zone) never arrives.

**Context can shrink.** If the analytical brain marks a large accidental file read as irrelevant (not yet implemented — future Mneme feature), it's gone from the next viewport. Tokens recovered instantly.

**Context can grow.** After a long quiet period with no new events, older events drift back into the viewport as the token budget is under-utilized.

**No information loss.** Every event is in SQLite. If you need to recall something from 10,000 turns ago, it's there — it's just not currently in the LLM's active context.

## Token Budget Assembly

The viewport assembles from multiple event scopes, each contributing up to a budget slice:

1. **System prompt** — soul.md + active skills + active workflow + current goals
2. **Own events** (newest-first) — fills remaining budget
3. **Parent events** (for sub-agents only) — up to `parent_context_ratio` × budget

For a sub-agent with `parent_context_ratio = 0.5` and a 190,000-token budget:
- System prompt: ~5,000–15,000 tokens
- Sub-agent's own events: up to ~90,000 tokens (remaining after system prompt and parent share)
- Parent events: up to 95,000 tokens

## Why This Matters for Sub-Agents

When a sub-agent spawns, it doesn't receive a summary of the parent session. It inherits the parent's raw event stream — every file read, every decision, every user message — up to the budget limit. There's no "let me summarize what I know" prompt. Lossless inheritance by architecture, not by prompting.

```
Parent session events (100 events)
    │
    ├── Sub-agent viewport assembly
    │       ├── Sub-agent's own events (priority, newest-first)
    │       └── Parent events (filling remaining budget, newest-first)
    │
    └── Sub-agent already knows everything parent knows
        (up to the budget limit — most recent context wins)
```

## The System Prompt

The system prompt is assembled fresh for each LLM call from **live state**, not from the event stream:

- `soul.md` — the agent's self-authored identity (always included)
- Active skills — knowledge bundles the analytical brain has activated
- Active workflow — the current operational recipe (if any)
- Current goals — root goals and sub-goals tracked by the analytical brain

This means the agent's identity and capabilities are always current, never stale. If the analytical brain activates a new skill mid-session, the very next LLM call gets that skill's knowledge.
