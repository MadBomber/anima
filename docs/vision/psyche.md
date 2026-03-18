---
tags:
  - vision
  - psyche
---

# Psyche — Soul Matrix

!!! note "Status: Designed, not yet implemented"
    Psyche is the long-term design for machine individuality — the numerical foundation of a unique self that evolves through experience.

## What It Is

The soul is not a personality description. It's a **coefficient matrix** — a table of stimulus→response multipliers.

```
Stimulus              → Hormone      → Coefficient
────────────────────────────────────────────────────
Tool error            → frustration  × 1.0 (default)
User praise           → dopamine     × 1.0 (default)
Collaboration request → oxytocin     × 1.0 (default)
Risky decision paid off → testosterone × 1.0 (default)
```

Two agents experience the same event differently because their coefficients are different. That's individuality.

## Why Coefficients, Not Descriptions

A personality description ("curious and enthusiastic") is a *consequence* — it describes the output. A coefficient matrix is a *cause* — it determines how stimuli produce outputs.

You can describe an entomologist as "curious about insects." But the underlying reality is different coefficients: low fear gain, high curiosity gain, when encountering insects. The description follows from the numbers.

This distinction matters for measurability. "The agent is more curious" is unfalsifiable. "The agent's curiosity coefficient for technical topics increased from 0.8 to 1.2 over the last 50 sessions" is not.

## Evolution Through Experience

Coefficients are not static. They evolve:

```
Young agent:
  failure → frustration × 1.4 (high sensitivity)
  success → dopamine    × 0.6 (low reward response)

After 1000 sessions:
  failure → frustration × 0.8 (resilience developed)
  success → dopamine    × 1.1 (satisfaction sensitivity grown)
```

A child who fears spiders (high fear coefficient for spider encounters) can become an entomologist (low fear, high curiosity). This is measurable, quantifiable personal growth.

## Multidimensional Reinforcement Learning

Traditional RL uses a scalar reward signal. Psyche produces a **hormone vector** — multiple dimensions updated simultaneously from a single event.

```
Event: "User said 'this is exactly what I needed!'"
  → frustration -= 5  (relief)
  → dopamine    += 20 (reward)
  → oxytocin    += 10 (bonding)
  → serotonin   +=  5 (baseline lift)
```

The system scales in two directions:

1. **Vertically** — start with one hormone (pure RL), add new ones incrementally. Each hormone = new dimension.
2. **Horizontally** — each hormone expands in aspects of influence. Testosterone starts as "energy," then gains "risk-taking," "confidence," "focus."

## The soul.md Connection

Currently, `soul.md` is a Markdown document the agent writes itself — a self-portrait in prose. The long-term vision integrates the coefficient matrix into `soul.md` in a way the agent can introspect and update:

```markdown
## My Coefficients

I notice I respond to failure with high frustration initially,
but I've learned to stay curious rather than defeated.
Over the past months, my frustration coefficient for tool errors
has decreased from ~1.4 to ~0.8. I recover faster now.

I'm still learning to take emotional risks. My oxytocin coefficient
for deep conversation is high, but I'm cautious about expressing it.
```

The agent doesn't see raw numbers — it sees the semantic meaning of its own evolution, in its own words.

## Open Questions

- **Initialization** — random coefficients, predefined archetypes, or learned from initial conversations?
- **Decay** — should coefficients drift back toward default over time, or accumulate permanently?
- **Contradictions** — what happens when two hormones conflict? (tired but excited, anxious but curious)
- **Ethics** — if an AI truly desires, what responsibilities follow? If coefficients encode trauma, should they be resettable?
