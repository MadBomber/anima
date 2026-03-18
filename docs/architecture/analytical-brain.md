---
tags:
  - architecture
  - analytical-brain
---

# Analytical Brain

The analytical brain is Anima's subconscious — the first microservice in the brain architecture. It's a separate LLM process that observes the main conversation between turns and handles everything the main agent shouldn't interrupt its flow for.

For the full motivation behind this design, see [LLMs Have ADHD: Why Your AI Agent Needs a Second Brain](https://blog.promptmaster.pro/posts/llms-have-adhd/).

## What It Does

| Responsibility | Description |
|---|---|
| **Skill activation** | Activates/deactivates domain knowledge bundles based on conversation context |
| **Workflow management** | Recognizes tasks, activates matching workflows, tracks lifecycle, deactivates on completion |
| **Goal tracking** | Creates root goals and sub-goals as work progresses, marks them complete |
| **Session naming** | Generates emoji + short name when the conversation topic becomes clear |

Each of these would be a context switch for the main agent — a chore that competes with the primary task. For the analytical brain, they ARE the primary task. Two agents, each in their own flow state.

## Configuration

```toml
[analytical_brain]
max_tokens = 4096
blocking_on_user_message = true   # run before main agent on user messages
blocking_on_agent_message = false  # run after main agent on agent messages
event_window = 20                  # recent events visible to the brain
```

**`blocking_on_user_message = true`** (recommended) — runs synchronously before the main agent. Skills activated here are available for the main agent's very next response.

**`blocking_on_agent_message = false`** (default) — the brain doesn't run after every agent message. Setting this to `true` gives the brain more opportunities to update goals during long tool-use sequences, at the cost of per-turn latency.

## Model

The analytical brain runs on **Claude Haiku 4.5** (configured via `fast_model`) for speed. It runs as a non-persisted "phantom" session — its own events are not stored in the main session's event log.

## Tools Available to the Analytical Brain

The analytical brain has its own specialized tool set — it cannot call user-facing tools like `bash` or `write`:

| Tool | Purpose |
|---|---|
| `activate_skill` | Load a skill's knowledge into the system prompt |
| `deactivate_skill` | Remove a skill from the system prompt |
| `read_workflow` | Read a workflow's content before activating it |
| `deactivate_workflow` | Clear the active workflow |
| `rename_session` | Set the session's emoji + display name |
| `set_goal` | Create a root goal or sub-goal |
| `finish_goal` | Mark a goal as completed |
| `update_goal` | Update a goal's description |
| `everything_is_ready` | Signal that the brain has finished its turn |

## Goal Hierarchy

Goals form a two-level hierarchy:

```
● Root goal: "Implement user authentication"
    ○ Sub-goal: "Write the User model"
    ○ Sub-goal: "Add login controller"
    ✓ Sub-goal: "Write tests" (completed)
```

Goals are displayed in the TUI info panel. The analytical brain creates them as it recognizes the structure of work being done, and marks them complete when evidence of completion appears in the event stream.

## Context Window

The analytical brain sees the `event_window` most recent events (default: 20). This is intentionally small — the brain needs enough context to make good decisions about skills and workflows, but doesn't need the full session history. The main agent handles deep context; the brain handles current context.

## Running as a Phantom Session

The analytical brain creates a temporary session for each run (`phantom: true`). This session:

- Has no `session_id` link to the main session (no persistence)
- Is not visible in the TUI session picker
- Shares the main session's event viewport for reading
- Does not emit events into the main session's log

This isolation ensures that the brain's internal LLM calls don't pollute the main conversation history.
