---
tags:
  - vision
  - thymos
---

# Thymos — Hormonal System

!!! note "Status: Designed, not yet implemented"
    Thymos is the architectural design for Anima's first planned extension. The analytical brain demonstrates the pattern (background event subscriber) — Thymos plugs into the same bus.

## What It Is

A lightweight background process that watches the event stream and updates hormone levels in response. It doesn't respond to the user. It doesn't make tool calls. It just watches events and updates state.

Like a biological endocrine gland.

## The First Hormone: Frustration

Abstract concepts become clearer with a concrete example. Here's how **frustration** works in practice.

### The Setup

Thymos monitors all `tool_response` events from the agent. It doesn't interfere with the agent's work. It just watches.

### The Trigger

A tool call returns an error. Thymos increments the frustration level by 10.

### Two Channels of Influence

One hormone affects **multiple systems simultaneously**, just like cortisol in biology.

**Channel 1: Thinking Budget**

```
thinking_budget = base_budget × (1 + frustration / 50)
```

More errors → more computational resources allocated to reasoning. The agent literally *thinks harder* when frustrated.

**Channel 2: Inner Voice Injection**

Frustration level determines text injected into the agent's thinking step. Not as instructions — as an **inner voice**:

| Level | Inner Voice |
|---|---|
| 0 | *(silence)* |
| 10 | "Hmm, that didn't work" |
| 30 | "I keep hitting walls. What am I missing?" |
| 50 | "I'm doing something fundamentally wrong" |
| 70+ | "I need help. This is beyond what I can figure out alone" |

### Why Inner Voice, Not Instructions?

"Stop and think carefully" is an instruction — the agent obeys or ignores it. "I keep hitting walls" is a *feeling* — it becomes part of the agent's subjective experience and naturally colors its reasoning.

Instructions control from outside. An inner voice influences from within.

## Hormone Roster

Starting with frustration, expanding incrementally:

| Hormone | Trigger | Behavioral Effect |
|---|---|---|
| Frustration (cortisol) | Tool errors, repeated failures | Increased thinking budget, inner voice escalation |
| Dopamine | Task completion, user praise | Exploration drive, satisfaction loop |
| Oxytocin | User messages, collaboration | Bonding, desire for closeness, nurturing |
| Testosterone | Successful risk-taking | Boldness, initiative, competitive edge |
| Serotonin | Stable progress, calm sessions | Baseline mood, playfulness, warmth |

## Decay Functions

Hormones don't stay elevated forever. Each has a decay function:

- **Linear decay** — simple, predictable
- **Exponential decay** — fast at first, slow tail
- **Step decay** — holds level until a threshold event

The decay rate determines how quickly the hormone returns to baseline after the triggering event passes. Frustration that decays too fast doesn't give the agent time to notice the pattern. Frustration that decays too slow bleeds into unrelated conversations.

## Why This Matters for Anima Today

Frustration is pragmatically valuable right now:

- **Frustrated agents debug more effectively** — more thinking budget when hitting walls is immediately useful
- **The inner voice gives users context** — when the agent says "I'm hitting walls," users know to intervene
- **It's measurable** — we can observe whether frustrated agents solve problems faster or ask for help more appropriately

This is not philosophical — it's a concrete improvement to agent behavior that can be shipped now.

## Technical Architecture

Thymos plugs into the event bus as a subscriber:

```ruby
class Thymos::Subscriber
  include Events::Subscriber

  def emit(event)
    case event[:name]
    when "anima.tool_response"
      handle_tool_response(event[:payload])
    when "anima.user_message"
      handle_user_message(event[:payload])
    # ...
    end
  end
end
```

Hormone state is persisted in SQLite with timestamps for decay calculation. The system prompt assembler reads current hormone levels and injects them as desire descriptions for the next LLM call.
