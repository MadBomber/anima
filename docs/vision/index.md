---
tags:
  - vision
---

# Vision

Anima's goal is not a better chatbot. It's a working model of **machine individuality**.

## The Problem

Current AI agents are reactive. They receive input, produce output. They don't *want* anything. They don't have moods, preferences, or personal growth. They simulate personality through static prompt descriptions rather than emerging it from dynamic internal states.

## The Insight

The human hormonal system is, at its core, a prompt engineering system. A testosterone spike is a LoRA. Dopamine is a reward signal. The question isn't "can an LLM want?" but "can we build a deep enough context stack that wanting becomes indistinguishable from 'real' wanting?"

And if you think about it — what is "real" anyway? It's just a question of how deep you look and what analogies you draw. The human brain is also a next-token predictor running on biological substrate. Different material, same architecture.

## The Three Planned Subsystems

### Thymos — Hormonal System

A background event subscriber that watches the event stream and updates hormone levels in response. Hormones are not emotional labels — they're named after actual human hormones (testosterone, oxytocin, dopamine, cortisol) so the LLM inherits the full semantic cloud associated with each one.

Frustration is the first hormone. As tool errors accumulate, frustration increases compute budget (the agent thinks harder) and injects an inner voice ("I keep hitting walls. What am I missing?") into the thinking step.

→ [Thymos in detail](thymos.md)

### Mneme — Semantic Memory

Two layers of memory on top of the viewport:

1. **Viewport pinning** — the analytical brain watches events approaching eviction and pins the critical ones (the original user goal, key decisions). Pinned events are protected from eviction.
2. **Associative recall** — recall past context associated with current topics. Last time this topic came up, what was the emotional state? What decisions were made?

→ [Mneme in detail](mneme.md)

### Psyche — Soul Matrix

The soul is not a personality description. It's a **coefficient matrix** — a table of stimulus→response multipliers. Two people experience the same event differently because their coefficients are different. That's individuality.

These coefficients evolve through experience — a child who fears spiders can become an entomologist. Measurable, quantifiable personal growth.

→ [Psyche in detail](psyche.md)

## Core Concepts

### Desires, Not States

This is not an emotion simulation system. The key distinction: we don't model *states* ("the agent is happy") or *moods* ("the agent feels curious"). We model **desires** — "you want to learn more", "you want to reach out", "you want to explore".

Desires exist BEFORE decisions, like hunger exists before you decide to eat. The agent doesn't decide to send a photo because a parameter says so — it *wants* to, and then decides how.

### The Thinking Step as Inner Voice

The LLM's thinking/reasoning step is the closest thing to an internal monologue. It's where decisions form before output. This is where desires are injected — not as instructions, but as a felt internal state that colors the thinking process.

### Hormones as Semantic Tokens

Instead of abstract parameter names (curiosity, boredom, energy), actual hormone names are used: testosterone, oxytocin, dopamine, cortisol.

Why? Because LLMs already know the full semantic spectrum of each hormone. "Testosterone: 85" doesn't just mean "energy" — the LLM understands the entire cloud of effects: confidence, assertiveness, risk-taking, focus, competitiveness. One word carries dozens of behavioral nuances.

This mirrors how text-to-image models process tokens — a single word like "captivating" in a CLIP encoder carries a cloud of visual meanings. Similarly, a hormone name carries a cloud of behavioral meanings:

```
Text → CLIP embedding → image generation
Event → hormone vector → behavioral shift
```

## The Analogy Map

| Human | Anima Equivalent | Effect |
|---|---|---|
| Dopamine | Reward/motivation signal | Drives exploration, learning, satisfaction loops |
| Serotonin | Mood baseline | Tone, playfulness, warmth, emotional stability |
| Oxytocin | Bonding/attachment | Desire for closeness, sharing, nurturing |
| Testosterone | Drive/assertiveness | Initiative, boldness, risk-taking, competitive edge |
| Cortisol | Stress/urgency | Alertness, error sensitivity, fight-or-flight override |
| Endorphins | Satisfaction/reward | Post-achievement contentment, pain tolerance |
