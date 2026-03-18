---
tags:
  - architecture
  - tui
---

# TUI View Modes

The TUI has three switchable view modes that control how much detail is shown. Cycle with `Ctrl+a → v`.

## Modes

| Mode | What you see |
|---|---|
| **Basic** (default) | User + assistant messages only. Tool calls are hidden but summarized as an inline counter: `🔧 Tools: 2/2 ✓` |
| **Verbose** | Everything in Basic, plus timestamps `[HH:MM:SS]`, tool call previews (`🔧 bash` / `$ command` / `↩ response`), and system messages |
| **Debug** | Full X-ray view — timestamps, token counts per message (`[14 tok]`), full tool call arguments, full tool responses, tool use IDs |

## Implementation

View modes are implemented via **Draper decorators** that operate at the transport layer. Each event type has a dedicated decorator:

| Decorator | Event Type |
|---|---|
| `UserMessageDecorator` | `user_message` |
| `AgentMessageDecorator` | `agent_message` |
| `ToolCallDecorator` | `tool_call` |
| `ToolResponseDecorator` | `tool_response` |
| `SystemMessageDecorator` | `system_message` |

Each decorator implements a `render(mode)` method that returns structured data for the current view mode. The TUI renders whatever structure it receives — it has no mode-specific logic.

## Persistence

The active view mode is stored on the `Session` model server-side. This means:

- View mode persists across TUI reconnections
- Multiple TUI clients connected to the same session see the same mode
- Changing mode in the TUI updates the session record immediately

## Broadcast Rendering

When an event is broadcast to connected clients, the payload includes a `rendered` key containing the decorator output for the current mode:

```json
{
  "type": "agent_message",
  "content": "Here is the implementation...",
  "id": 42,
  "action": "create",
  "rendered": {
    "basic": {
      "role": "assistant",
      "content": "Here is the implementation..."
    }
  }
}
```

For update broadcasts (e.g. when token counts arrive after the event is saved), the `rendered` key uses the debug mode to include token count data:

```json
{
  "type": "agent_message",
  "id": 42,
  "action": "update",
  "rendered": {
    "debug": {
      "role": "assistant",
      "content": "Here is the implementation...",
      "tokens": 347
    }
  }
}
```

This architecture means the server always renders at the client's requested fidelity — the TUI never requests re-rendering.
