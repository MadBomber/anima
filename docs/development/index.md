---
tags:
  - development
---

# Development

Setting up Anima for local development.

## Prerequisites

- Ruby >= 3.2.0
- Bundler
- Git
- Foreman (for `bin/dev`)
- SQLite3

## Setup

```bash
git clone https://github.com/hoblin/anima.git
cd anima
bin/setup
```

`bin/setup` installs gem dependencies and runs `db:prepare` to create and migrate all three databases (primary, queue, cable) for the development environment.

## Starting the Dev Server

Development uses port **42135** to avoid conflicting with a production brain running on port 42134:

```bash
# Terminal 1 — brain server (Puma) + background worker (Solid Queue)
bin/dev

# Terminal 2 — TUI connecting to dev brain
./exe/anima tui --host localhost:42135
```

`bin/dev` uses Foreman and the `Procfile.dev` configuration.

!!! tip "Use `./exe/anima`, not `bundle exec anima`"
    `./exe/anima` loads local `lib/` directly via `require_relative`, so you see your code changes without reinstalling the gem. `bundle exec anima` loads the installed gem version.

## Dev vs. Production Brain

| | Development | Production |
|---|---|---|
| Port | 42135 | 42134 |
| Start command | `bin/dev` | `systemctl --user start anima` |
| Database | `db/development.sqlite3` | `~/.anima/db/production.sqlite3` |
| Credentials | `config/credentials/development.yml.enc` | `~/.anima/config/credentials/production.yml.enc` |

## Key Directories

```
anima/
├── app/
│   ├── channels/       — WebSocket channel (SessionChannel)
│   ├── decorators/     — Draper view decorators per event type
│   ├── jobs/           — Background jobs (agent, analytical brain, lock recovery)
│   └── models/         — Session, Event, Goal + concerns
├── lib/
│   ├── agent_loop.rb   — Core LLM loop
│   ├── analytical_brain.rb — Subconscious subsystem
│   ├── anima/          — CLI, settings, installer
│   ├── events/         — Event bus, types, subscribers
│   ├── llm/            — LLM client + instrumentation
│   ├── mcp/            — MCP client management
│   ├── tools/          — All 10 built-in tools
│   ├── tui/            — Terminal UI (RatatuiRuby)
│   └── workflows/      — Workflow registry + definition
├── agents/             — Built-in specialist agent definitions
├── skills/             — Built-in skill knowledge packs
├── workflows/          — Built-in workflow definitions
├── config/
│   └── initializers/   — Boot-time subscriber registration
└── templates/          — Default config.toml, mcp.toml
```

## Detailed Guides

- [Project Structure](project-structure.md) — Where everything lives and why
- [Running Tests](testing.md) — Test suite and how to run it
- [Contributing](contributing.md) — How to contribute
