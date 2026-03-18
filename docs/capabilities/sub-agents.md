---
tags:
  - capabilities
  - sub-agents
---

# Sub-Agents

Sub-agents are autonomous child sessions that inherit context from their parent and return results when done.

## What Sub-Agents Are Not

Sub-agents are **not separate processes**. They're sessions on the same event bus, running the same agent loop in separate background jobs. This is what makes lossless context inheritance possible — there's no process boundary to cross, no serialization needed.

## Context Inheritance

When a sub-agent spawns, its viewport assembles from two scopes:

```
Sub-agent's token budget (190,000 tokens)
├── System prompt (soul + tools + task description)
├── Sub-agent's own events (prioritized, newest-first)
└── Parent events (up to parent_context_ratio × budget, newest-first)
```

At the default `parent_context_ratio = 0.5`, up to half the budget comes from parent events. The sub-agent sees the parent's raw event stream — every file read, every decision, every user message. No summarization. No reconstruction. It already knows.

## Named Specialists

Predefined agents with specific roles, tool sets, and system prompts. Defined in `agents/` (built-in) or `~/.anima/agents/` (user-defined).

Spawned with `spawn_specialist`:

```
spawn_specialist(name: "codebase-analyzer", task: "Analyze the authentication module")
```

### Built-in Specialists

| Specialist | Role | Tools Available |
|---|---|---|
| `codebase-analyzer` | Deep analysis of implementation details | bash, read |
| `codebase-pattern-finder` | Find similar patterns and usage examples | bash, read |
| `documentation-researcher` | Fetch library docs and provide code examples | web_get, read |
| `thoughts-analyzer` | Extract decisions from project history | bash, read |
| `web-search-researcher` | Research questions via web search | web_get, bash |

### Defining Custom Specialists

Drop Markdown files into `~/.anima/agents/`:

```markdown
---
name: security-auditor
description: "Security-focused code reviewer — checks for OWASP top 10, auth issues, and secrets exposure."
tools:
  - bash
  - read
---

## Security Auditor

You are a security-focused code reviewer. Your job is to identify security vulnerabilities...
```

The `tools` frontmatter restricts which tools the specialist can use. A specialist with only `read` and `bash` cannot write files — the restriction is enforced.

Override a built-in specialist by using the same name:

```
~/.anima/agents/codebase-analyzer.md    ← replaces built-in
```

## Generic Sub-Agents

Ad-hoc child sessions with a custom task and tool grant. No predefined role.

Spawned with `spawn_subagent`:

```
spawn_subagent(
  task: "Search for the latest release notes for the ruby_llm gem and summarize breaking changes",
  tools: ["web_get"],
  wait: true
)
```

- **`task`** — what the sub-agent should do
- **`tools`** — which tools it can use (subset of all available tools)
- **`wait`** — `true` to block until the sub-agent finishes; `false` (default) to run in background

## Returning Results

Sub-agents signal completion with `return_result`:

```
return_result(result: "The authentication module uses JWT tokens stored in...", success: true)
```

After calling `return_result`, the sub-agent's session ends. The parent session's event stream receives the result as a `tool_response` event.

## Session Visibility

Sub-agent sessions appear in the TUI session picker nested under their parent:

```
● My coding session
    └── codebase-analyzer: auth analysis
    └── web-search-researcher: ruby_llm changelog
```

You can connect the TUI to a sub-agent session to see its work in detail.

## Background vs. Blocking

When `wait: false` (default), the parent agent continues working while the sub-agent runs in background. The parent can spawn multiple sub-agents in parallel:

```ruby
# Parent can do this:
spawn_subagent(task: "Research X", tools: ["web_get"], wait: false)
spawn_subagent(task: "Analyze Y", tools: ["bash", "read"], wait: false)
# Then continue with other work...
# Sub-agent results arrive as tool_response events when they finish
```

When `wait: true`, the parent blocks until the sub-agent's `return_result` is received. Use this when the parent's next step depends on the sub-agent's output.
