---
tags:
  - getting-started
  - quick-start
---

# Quick Start

This guide walks through your first Anima session.

## 1. Start the Brain

=== "Linux (systemd)"

    ```bash
    systemctl --user start anima
    systemctl --user status anima     # confirm it's running
    ```

=== "macOS / Development"

    ```bash
    bin/dev     # starts web server + background worker on port 42135
    ```

## 2. Connect the TUI

```bash
anima tui
```

The TUI connects to the brain over WebSocket and displays the session interface.

## 3. First Session — Birth

On the very first connection, Anima runs its birth sequence. The agent:

1. Wakes up and explores its environment (tools, skills, workflows available)
2. Reads the `soul.md` template (empty at first)
3. Has an initial conversation with you to understand who you are and what you do
4. Writes its own `soul.md` — a self-authored identity document that lives in context forever

This typically takes a few minutes. After birth, every subsequent session starts with the agent already knowing who it is and who you are.

## 4. The TUI Interface

```
┌─────────────────────────────────────────────────────────┐
│ 🧠 Anima  [session name]              [Ctrl+a for menu] │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [Chat area — messages scroll here]                     │
│                                                         │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ Skills: activerecord draper │ Workflow: feature  🔄     │
│ Goals: ● Implement login    │ Sub-goals: ○ Write tests  │
├─────────────────────────────────────────────────────────┤
│ > [your input here]                             [Enter] │
└─────────────────────────────────────────────────────────┘
```

**Key bindings:**

| Shortcut | Action |
|---|---|
| `Enter` | Send message |
| `Ctrl+a → v` | Cycle view mode (Basic → Verbose → Debug) |
| `Ctrl+a → a` | Open token setup popup |
| `Ctrl+a → s` | Open session picker |
| `Ctrl+c` | Disconnect TUI (brain keeps running) |

## 5. Try Some Tasks

Once the agent is alive, try asking it to:

```
Explore this directory and tell me what kind of project this is.
```

```
Create a plan for adding user authentication.
```

```
Research the RubyLLM gem and give me a summary.
```

The analytical brain will activate relevant skills automatically (e.g., activating the `activerecord` skill if you're working with database models).

## 6. View Modes

Switch view modes with `Ctrl+a → v` to see more detail:

- **Basic** (default) — user + assistant messages; tool calls summarized as `🔧 Tools: 2/2 ✓`
- **Verbose** — adds timestamps, tool call previews, system messages
- **Debug** — full X-ray: token counts, complete tool arguments and responses, tool use IDs

## 7. Working With MCP Servers

To add external tools via Model Context Protocol:

```bash
# Add an HTTP MCP server
anima mcp add sentry https://mcp.sentry.dev/mcp

# Add a stdio MCP server
anima mcp add fs -- mcp-server-filesystem --root /

# Check server health
anima mcp list
```

See [MCP Integration](../capabilities/mcp-integration.md) for full details.

## What's Next

- [Configuration](configuration.md) — Tune models, timeouts, token budgets
- [Tools](../capabilities/tools.md) — All 10 built-in tools explained
- [Skills](../capabilities/skills.md) — Add your own knowledge packs
- [Workflows](../capabilities/workflows.md) — Browse and extend built-in workflows
