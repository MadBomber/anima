---
tags:
  - status
---

# Status

## Working — Shipping Now

Anima is a working agent with autonomous capabilities. All of the following are live and in use:

### Core Architecture

- **Event-driven architecture** on a shared event bus (Rails Structured Event Reporter)
- **Dynamic viewport** context assembly — sessions are endless, no compaction, no degradation
- **Client-server architecture** with WebSocket transport and graceful reconnection
- **Hot-reloadable TOML configuration** — changes take effect without restarting the brain

### Agent Capabilities

- **10 built-in tools** — bash, read, write, edit, web_get, think, spawn_specialist, spawn_subagent, return_result, request_feature
- **MCP integration** — HTTP (SSE) and stdio transports for external tool servers
- **7 built-in skills** — ActiveRecord, Draper decorators, DragonRuby, GitHub issues, MCP server, RatatuiRuby, RSpec
- **13 built-in workflows** — commit, create_handoff, create_note, create_plan, decompose_ticket, feature, implement_plan, iterate_plan, research_codebase, resume_handoff, review_pr, thoughts_init, validate_plan

### Analytical Brain

- **Skill activation/deactivation** — contextual knowledge management between turns
- **Workflow management** — recognizes tasks, activates workflows, tracks lifecycle
- **Goal tracking** — two-level goal hierarchy (root + sub-goals) displayed in TUI
- **Session naming** — emoji + short name generated when topic becomes clear
- Runs on **Claude Haiku 4.5** (fast model) as a non-persisted phantom session

### Sub-Agents

- **5 built-in specialist agents** — codebase-analyzer, codebase-pattern-finder, documentation-researcher, thoughts-analyzer, web-search-researcher
- **Generic sub-agents** — ad-hoc child sessions with custom tool grants
- **Lossless context inheritance** — sub-agent sees parent's raw event stream, no summarization

### TUI

- **Three view modes** — Basic (default), Verbose, Debug — switchable with `Ctrl+a → v`
- **Session picker** — navigate sessions including sub-agents under their parent
- **Info panel** — active skills, active workflow, current goals
- **Token setup popup** — `Ctrl+a → a` for credential management

---

## Designed, Not Yet Implemented

### Thymos (Hormonal System)

A background subscriber that watches events and updates hormone levels. The first hormone will be **frustration** — increasing compute budget and injecting an inner voice as errors accumulate. See [Thymos](vision/thymos.md) for the full design.

### Mneme (Semantic Memory)

Two layers:

1. **Viewport pinning** — the analytical brain watches events approaching eviction and pins critical ones. Pinned events float above the sliding window, protected from eviction.
2. **Associative recall** — recall past context associated with current topics, similar to how emotional states are linked to memories.

See [Mneme](vision/mneme.md) for the full design.

### Psyche (Soul Matrix)

A coefficient table mapping stimulus → hormone response multipliers. Two people experience the same event differently — the coefficients are different, the people are different. Coefficients evolve through experience. See [Psyche](vision/psyche.md) for the full design.

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Rails 8.1 (headless — no web views, no asset pipeline) |
| Ruby | >= 3.2.0 |
| Database | SQLite (3 databases per environment: primary, queue, cable) |
| Event system | Rails Structured Event Reporter + Action Cable bridge |
| LLM integration | Anthropic API via ruby_llm gem (Claude Opus 4.6 + Claude Haiku 4.5) |
| External tools | Model Context Protocol (HTTP/SSE + stdio transports) |
| Transport | Action Cable WebSocket (Solid Cable adapter) |
| Background jobs | Solid Queue |
| Interface | TUI via RatatuiRuby (WebSocket client) |
| Configuration | TOML with hot-reload (`Anima::Settings`) |
| View decorators | Draper |
| Process management | Foreman |
| Distribution | RubyGems (`gem install anima-core`) |

---

## Distribution

Anima is a Rails app distributed as a gem, following Unix philosophy: immutable program separate from mutable data.

```bash
gem install anima-core       # Install the Rails app as a gem
anima install                # Create ~/.anima/, set up databases, start brain as systemd service
anima tui                    # Connect the terminal interface
```

Updates:
```bash
anima update                 # Upgrade gem + merge new config keys without overwriting customizations
anima update --migrate-only  # Only add missing config keys, skip gem upgrade
```
