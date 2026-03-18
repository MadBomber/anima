---
tags:
  - getting-started
---

# Getting Started

Anima runs locally as a headless Rails 8.1 app distributed as a Ruby gem. Your machine runs the brain; the TUI connects to it over WebSocket.

## Prerequisites

- **Ruby >= 3.2.0**
- **A Claude Pro or Max subscription** — Anima uses your Claude Code OAuth token, not a paid API key
- **Linux or macOS** — systemd service management on Linux; manual process management on macOS

## Steps

1. [**Install**](installation.md) — Install the gem, run `anima install` to set up the state directory and database, configure the brain as a systemd service
2. [**Authenticate**](authentication.md) — Connect your Claude Pro/Max subscription via the Claude Code setup token
3. [**Quick Start**](quick-start.md) — Start the brain, connect the TUI, meet your agent for the first time
4. [**Configure**](configuration.md) — Tune model settings, timeouts, MCP servers, and more

## The Two-Process Model

Understanding the client-server split is key to understanding Anima:

```
Brain (persistent service)          TUI (stateless client)
─────────────────────────           ─────────────────────
Runs all LLM calls                  Renders events to terminal
Executes tools                      Captures keyboard input
Manages sessions & history          Connects via WebSocket
Runs background jobs                Reconnects automatically
Persists events to SQLite
```

If the TUI disconnects — network hiccup, terminal closed, `Ctrl+C` — **the brain keeps running**. Your agent continues any in-progress work. When you reconnect, the full session history is there.

## State Directory

After installation, `~/.anima/` holds all mutable state:

```
~/.anima/
├── soul.md          # Agent's self-authored identity (always in context)
├── config.toml      # Main settings (hot-reloadable)
├── mcp.toml         # MCP server configuration
├── agents/          # User-defined specialist agents (override built-ins)
├── skills/          # User-defined skills (override built-ins)
├── workflows/       # User-defined workflows (override built-ins)
├── db/              # SQLite databases (production, development, test)
├── config/
│   └── credentials/ # Rails encrypted credentials per environment
├── log/
└── tmp/
```

The gem itself is immutable — only `~/.anima/` changes between sessions.
