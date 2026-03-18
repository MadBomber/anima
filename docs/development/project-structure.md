---
tags:
  - development
  - architecture
---

# Project Structure

A guide to where things live in the Anima codebase and why they're organized this way.

## Top-Level Layout

```
anima/
├── agents/         Built-in specialist agent definitions (Markdown)
├── app/            Rails application code
├── bin/            Development scripts (setup, dev)
├── config/         Rails configuration
├── db/             Migrations and schema
├── docs/           This documentation site
├── exe/            The anima CLI entry point
├── lib/            Core application logic
├── skills/         Built-in skill knowledge packs (Markdown)
├── templates/      Default config.toml and mcp.toml for installation
├── test/           Minitest test suite
└── workflows/      Built-in workflow definitions (Markdown)
```

## `app/` — Rails Application

### `app/channels/`

`session_channel.rb` — The single ActionCable channel. All WebSocket communication flows through here. Each connected TUI subscribes to its session stream. The channel receives user messages, interrupt signals, and view mode changes from the TUI, and dispatches them to the appropriate session.

### `app/models/`

| Model | Role |
|---|---|
| `Session` | Central model — holds the processing lock, view mode, session name, goal associations |
| `Event` | Persisted event — type, payload (JSON), session ID, token counts |
| `Goal` | Root goals and sub-goals — text, completion status, parent goal ID |

**Concerns** extend the models with focused behavior:

| Concern | Location | Role |
|---|---|---|
| `Session::ContextWindow` | `session/context_window.rb` | Viewport assembly, message formatting for LLM |
| `Session::SkillsAndWorkflows` | `session/skills_and_workflows.rb` | Active skill/workflow management |
| `Session::SystemPrompt` | `session/system_prompt.rb` | System prompt assembly |
| `Session::Broadcasts` | `session/broadcasts.rb` | Session-level WebSocket broadcasts |
| `Event::Broadcasting` | `event/broadcasting.rb` | Per-event WebSocket broadcasts with eviction metadata |

### `app/jobs/`

| Job | Role |
|---|---|
| `AgentRequestJob` | Runs the agent loop for a single user message |
| `AnalyticalBrainJob` | Runs the analytical brain (triggered by AgentRequestJob) |
| `StaleSessionLockJob` | Scheduled — clears processing locks held > stale threshold |

### `app/decorators/`

One decorator per event type. Each implements `render(mode)` returning structured data for Basic, Verbose, or Debug view modes. The TUI renders this structure — it contains no display logic.

## `lib/` — Core Logic

### `lib/agent_loop.rb`

The central LLM execution loop. Assembles system prompt + viewport, calls the LLM via `ruby_llm`, executes tool calls, repeats. Handles interrupt detection and processing lock management.

### `lib/analytical_brain.rb` and `lib/analytical_brain/`

The subconscious subsystem. `runner.rb` drives the analytical brain's own mini agent loop using the brain's specialized tool set.

### `lib/anima/`

CLI entry point (`cli.rb`), settings loader (`settings.rb`), installer (`installer.rb`), config migrator (`config_migrator.rb`), and version constant.

### `lib/events/`

The event bus (`bus.rb`), event base class (`base.rb`), subscriber interface (`subscriber.rb`), five event type classes, and built-in subscribers (Persister, MessageCollector).

### `lib/llm/`

`client.rb` — wraps `ruby_llm` for Anima's specific usage: viewport injection, tool registration, interrupt handling, OAuth token management.

`instrumentation_subscriber.rb` — `ActiveSupport::Notifications` subscriber that logs structured LLM metrics per completion.

### `lib/mcp/`

`client_manager.rb` — cached MCP clients (one per server per process). `config.rb` — parses `mcp.toml` with credential interpolation. `health_check.rb` — probes servers for the `anima mcp list` command. `secrets.rb` — credential storage for MCP API keys.

### `lib/tools/`

One file per tool. Each inherits from `Tools::Base` and implements `schema` (returns the JSON schema for the LLM) and `execute(**params)` (runs the tool and returns a result).

### `lib/tui/`

The terminal UI, built with RatatuiRuby. `app.rb` — main application lifecycle. `cable_client.rb` — WebSocket connection to the brain. `message_store.rb` — in-memory message state for rendering. `screens/chat.rb` — the main chat screen.

### `lib/skills/` and `lib/workflows/`

Registry and definition classes for skills and workflows. The registries discover files from both the gem's built-in directories and `~/.anima/skills/` / `~/.anima/workflows/`, with user files taking precedence.

## `agents/`, `skills/`, `workflows/`

Pure Markdown files with YAML frontmatter. No Ruby code. The agent's extensible knowledge base lives here, not in `lib/`.

This separation is intentional: adding a new skill or workflow doesn't require touching Ruby code or restarting the brain (hot-reload handles it).

## `config/initializers/`

Boot-time wiring:

- `event_subscribers.rb` — registers all event bus subscribers
- `ruby_llm.rb` — configures the ruby_llm gem (API credentials, model defaults)
- `processing_lock_recovery.rb` — schedules `StaleSessionLockJob`
- `inflections.rb` — Rails inflection rules (e.g., `MCP` stays as `MCP`)

## `templates/`

Default `config.toml` and `mcp.toml` that `anima install` copies to `~/.anima/`. Updating these files and bumping the gem version triggers the config migrator to add new keys on `anima update`.
