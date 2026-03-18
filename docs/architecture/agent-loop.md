---
tags:
  - architecture
  - agent-loop
---

# Agent Loop

The agent loop (`AgentLoop`) is the core execution engine. It handles a single request: assemble context, call the LLM, execute tools, repeat until done, then respond.

## Turn Lifecycle

```
User message received
        │
        ▼
Claim processing lock
(prevents concurrent runs for same session)
        │
        ▼
Run analytical brain (blocking, if configured)
— activates/deactivates skills
— updates goals
— renames session if needed
        │
        ▼
Assemble system prompt
— soul.md
— active skills (as injected context)
— active workflow (if any)
— current goals
        │
        ▼
Assemble viewport
— own events, newest-first, up to token budget
        │
        ▼
Call LLM (Anthropic API via ruby_llm)
        │
        ├── Text response ──────────────────────────────────────┐
        │                                                       │
        └── Tool calls ───────────────────────────────────────┐ │
                │                                             │ │
                ▼                                             │ │
        Execute tool                                          │ │
        (bash, read, write, edit, web_get, think, etc.)       │ │
                │                                             │ │
                ▼                                             │ │
        Emit tool_call + tool_response events                 │ │
                │                                             │ │
                └── Loop (up to max_tool_rounds) ─────────────┘ │
                                                                 │
        ◄──────────────────────────────────────────────────────┘
        │
        ▼
Emit agent_message event
        │
        ▼
Broadcast to TUI via Action Cable
        │
        ▼
Release processing lock
        │
        ▼
Run analytical brain (async, if configured)
— updates goals based on completed work
— potentially deactivates completed workflow
```

## Processing Lock

Each session has a processing lock — a boolean column on the `Session` model that prevents concurrent agent runs. This matters because:

- Multiple TUI clients could be connected to the same session
- Background job retries could overlap with an in-progress run
- The lock is claimed at the start of `perform` in `AgentRequestJob` and released in an `ensure` block

`StaleSessionLockJob` runs on a schedule to release locks that have been held longer than the stale threshold — recovery from crashes without needing a restart.

## Tool Execution Loop

The loop continues until one of these conditions is met:

1. The LLM produces a response with no tool calls (it's done)
2. The `max_tool_rounds` limit is reached
3. The session's interrupt flag is set (user pressed the interrupt key)
4. An unrecoverable error occurs

When `max_tool_rounds` is reached, the agent is forced to respond with whatever it has, even if it hasn't finished.

## Interrupt Handling

Users can interrupt a running agent. The interrupt flag is set on the session and checked between tool calls. When detected:

1. The current tool call completes (no mid-call interruption)
2. The loop exits
3. A synthetic tool result is injected to maintain the required tool_use/tool_result pairing that Anthropic's API requires
4. The agent is notified that it was interrupted

This ensures the conversation history remains valid even after an interrupt.

## Background Jobs

The agent loop runs inside `AgentRequestJob`, a Solid Queue background job. This means:

- Agent execution is **non-blocking** for the web server
- The TUI receives events as they're broadcast — not in one batch at the end
- Job retries are handled by Solid Queue with configurable backoff

`AnalyticalBrainJob` runs the analytical brain as a separate job, either before (`blocking_on_user_message`) or after (`blocking_on_agent_message`) the main agent job.
