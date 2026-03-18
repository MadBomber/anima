---
tags:
  - getting-started
  - configuration
---

# Configuration

Anima is configured through `~/.anima/config.toml`. All settings are **hot-reloadable** — changes take effect immediately without restarting the brain.

## Full Configuration Reference

```toml
# ─── LLM ─────────────────────────────────────────────────────────

[llm]

# Primary model for conversations.
model = "claude-opus-4-6"

# Lightweight model for fast tasks (session naming, analytical brain).
fast_model = "claude-haiku-4-5"

# Maximum tokens per LLM response.
max_tokens = 8192

# Maximum consecutive tool execution rounds per request.
max_tool_rounds = 500

# Context window budget — tokens reserved for conversation history.
# Set this based on your model's context window minus system prompt overhead.
token_budget = 190_000

# ─── Timeouts (seconds) ─────────────────────────────────────────

[timeouts]

# LLM API request timeout.
api = 300

# Shell command execution timeout.
command = 30

# MCP server response timeout.
mcp_response = 60

# Web fetch request timeout.
web_request = 10

# ─── Shell ──────────────────────────────────────────────────────

[shell]

# Maximum bytes of command output before truncation.
max_output_bytes = 100_000

# ─── Tools ──────────────────────────────────────────────────────

[tools]

# Maximum file size for read/edit operations (bytes).
max_file_size = 10_485_760

# Maximum lines returned by the read tool.
max_read_lines = 2_000

# Maximum bytes returned by the read tool.
max_read_bytes = 50_000

# Maximum bytes from web GET responses.
max_web_response_bytes = 100_000

# ─── Environment ────────────────────────────────────────────────

[environment]

# Files to scan for in the working directory (root and up to max_depth subdirs).
project_files = ["CLAUDE.md", "AGENTS.md", "README.md", "CONTRIBUTING.md"]

# Maximum directory depth for project file scanning.
project_files_max_depth = 3

# ─── GitHub ─────────────────────────────────────────────────────

[github]

# Repository for agent feature requests (owner/repo format).
# Falls back to parsing git remote origin when unset.
repo = "hoblin/anima"

# Label applied to agent-created feature request issues.
label = "anima-wants"

# ─── Paths ──────────────────────────────────────────────────────

[paths]

# The agent's self-authored identity file.
soul = "{{ANIMA_HOME}}/soul.md"

# ─── Session ────────────────────────────────────────────────────

[session]

# Regenerate session name every N messages.
name_generation_interval = 30

# ─── Analytical Brain ───────────────────────────────────────────

[analytical_brain]

# Maximum tokens per analytical brain response.
# Must accommodate multiple tool calls (rename + goals + skills + ready).
max_tokens = 4096

# Run the analytical brain synchronously before the main agent on user messages.
# Ensures activated skills are available for the current response.
blocking_on_user_message = true

# Run the analytical brain asynchronously after the main agent completes.
blocking_on_agent_message = false

# Number of recent events to include in the analytical brain's context window.
event_window = 20

# ─── Workflows ──────────────────────────────────────────────────

[workflows]

# Set to false to suppress built-in workflows and use only ~/.anima/workflows/.
load_builtin = true

# ─── Sub-agent ──────────────────────────────────────────────────

[sub_agent]

# Maximum fraction of the token budget that parent-session events may consume
# when a sub-agent assembles its context window. Prevents the sub-agent from
# inheriting the entire parent conversation and leaving no headroom for its
# own work. Range: 0.0–1.0.
parent_context_ratio = 0.5
```

## Key Settings Explained

### `token_budget`

The context window budget controls how many tokens of conversation history the agent can see at any one time. Setting this appropriately for your model prevents the agent from hitting hard limits:

| Model | Context Window | Recommended `token_budget` |
|---|---|---|
| claude-opus-4-6 | 200k | 190_000 |
| claude-sonnet-4-6 | 200k | 190_000 |
| claude-haiku-4-5 | 200k | 190_000 |

Leave headroom for the system prompt (soul, active skills, goals) — typically 5k–15k tokens depending on how many skills are active.

### `max_tool_rounds`

The maximum number of consecutive tool executions per request. The agent stops and responds to the user after this many tool calls, even if it hasn't finished a task. The default of 500 is generous — most tasks complete in under 50 rounds.

### `blocking_on_user_message` vs `blocking_on_agent_message`

The analytical brain can run in two modes:

- **`blocking_on_user_message = true`** (default) — runs synchronously before the main agent processes a user message. This means skills are activated *before* the agent responds, so the agent gets the benefit immediately.
- **`blocking_on_agent_message = false`** (default) — the analytical brain does not run after every agent message, only after user messages. Setting this to `true` gives the brain more opportunities to update goals and workflows during long tool-use sequences, at the cost of additional latency.

### `parent_context_ratio`

Controls how much of a sub-agent's token budget can be consumed by parent-session events. At the default of `0.5`, half the budget is reserved for the sub-agent's own work. Increase this if sub-agents need more parent context; decrease it if they're running out of budget for their own output.

## TOML Number Formatting

TOML supports underscores in numeric literals for readability:

```toml
token_budget = 190_000    # Same as 190000
max_file_size = 10_485_760  # Same as 10485760
```

## MCP Configuration

MCP servers are configured separately in `~/.anima/mcp.toml`. See [MCP Integration](../capabilities/mcp-integration.md) for details.
