# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Follow user instructions precisely.

You are the sole codeowner. There is no tech debt someone else will fix for you. Apply the Boy Scout Rule: leave every file cleaner than you found it. Fix code smells, not just the task at hand.

Update CHANGELOG.md and keep README.md accurate with every feature implementation.

Use YARD to document business logic and external API. Keep documentation up to date when changing code.

Research spikes should describe what we need, not where to look. Prescribing solutions defeats the purpose of a research spike.

Always fix flaky tests. Never skip, mark pending, or work around them — fix the root cause.

Do not add "defense-in-depth" rescue clauses or fallback logic. Silently swallowing exceptions hides bugs, violates the Single Responsibility Principle, and masks missing business logic. Let exceptions propagate — they signal that a use case is not covered. Fix the gap in logic instead of papering over it.

There is no such thing as deprecated code or backward compatibility in this project. Orphaned code should be deleted right away.

This project does not use i18n. Skip translation checks entirely.

Never hardcode tunable values as constants — expose them through `Anima::Settings` backed by `config.toml`.

The development environment is fully configured (LLM API keys, credentials, dependencies). Don't ask — just run things.

## Commands

```bash
# Run all tests
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/lib/agent_loop_spec.rb

# Run a single example by line number
bundle exec rspec spec/lib/agent_loop_spec.rb:42

# Lint (StandardRB)
bundle exec standardrb

# Lint with auto-fix
bundle exec standardrb --fix

# Code smell analysis
bundle exec reek
```

## Starting the dev environment

Start the brain in a detached tmux session so it persists across commands:

```bash
# Start brain (web server + background worker) on port 42135
tmux new-session -d -s anima-brain 'bin/dev; sleep 30'

# Verify it's running (look for "Listening on" in output)
sleep 3 && tmux capture-pane -t anima-brain -p

# Clean up when done
tmux kill-session -t anima-brain
```

`bin/dev` starts both processes from `Procfile.dev`: `web` (Puma on port 42135) and `worker` (Solid Queue).

Development uses port **42135** (not 42134) to avoid conflicting with the production brain running via systemd.

**WARNING: The agent has full filesystem access and internet. When smoke-testing in TUI, choose tasks carefully — avoid prompts that trigger file edits or destructive actions.**

## Testing TUI in tmux

RatatuiRuby requires a real PTY. Background processes (`&`) and `script` don't work reliably. Use tmux to smoke-test the TUI:

```bash
# Launch TUI in a detached tmux session (connects to dev brain on 42135)
tmux new-session -d -s anima-test -x 120 -y 30 './exe/anima tui --host localhost:42135'

# Wait for render, then capture the screen
sleep 1 && tmux capture-pane -t anima-test -p

# TUI command mode: Ctrl+a enters command mode, then:
#   n — new session
#   s — session picker (shows sub-sessions / subagents)
#   v — cycle view mode (basic → verbose → debug)
#   a — enter Anthropic API token
#   q — quit
tmux send-keys -t anima-test C-a        # enter command mode
sleep 0.3
tmux send-keys -t anima-test n           # new session
tmux send-keys -t anima-test Escape      # cancel / close picker

# Capture specific areas
tmux capture-pane -t anima-test -p | head -5   # top of screen
tmux capture-pane -t anima-test -p | tail -2   # status bar

# Clean up
tmux kill-session -t anima-test
```

If the TUI crashes on startup, append `; sleep 30` to the command to keep the session alive for error inspection.

Always clean up tmux sessions when done. Use `anima-test` as the session name for consistency.

**Important:** Use `./exe/anima` (not `bundle exec anima`) to test local code changes. The exe uses `require_relative` so it loads local `lib/` directly. `bundle exec` may load the installed gem version instead.

Analytical brain debug log (dev only): `tail -f log/analytical_brain.log`

## Architecture

Anima is a Rails 8.1 headless app distributed as a gem (`anima-core`). It has a client-server architecture: the **Brain** is a persistent Rails server; the **TUI** is a stateless terminal client that connects via WebSocket.

### Layers

| Layer | Location | Role |
|-------|----------|------|
| Agent loop | `lib/agent_loop.rb` | Orchestrates user input → LLM → tool execution → events |
| LLM client | `lib/llm/` | `Client` wraps `Providers::Anthropic`; handles tool-call loop |
| Tools | `lib/tools/` | `Registry` + individual tool classes (`Bash`, `Read`, `Edit`, `Write`, `WebGet`, `SpawnSpecialist`, `SpawnSubagent`, `ReturnResult`) |
| Events | `lib/events/` | `Bus` (wraps Rails Structured Event Reporter) + typed event classes + `Subscribers::Persister`, `Subscribers::MessageCollector` |
| Analytical brain | `lib/analytical_brain/` | Background LLM process; `Runner` + its own tool set for skills/workflow/goal management |
| Skills | `lib/skills/` | `Definition` + `Registry`; domain knowledge loaded from Markdown |
| Workflows | `lib/workflows/` | `Definition` + `Registry`; operational recipes loaded from Markdown |
| MCP | `lib/mcp/` | `ClientManager` + `Config` + `StdioTransport`; proxies external MCP servers as dynamic tools |
| TUI | `lib/tui/` | `App` (RatatuiRuby) + `CableClient` (WebSocket) + screens |
| Settings | `lib/anima/settings.rb` | Hot-reloadable `~/.anima/config.toml` via `Anima::Settings` |
| CLI | `lib/anima/cli/` | Thor-based CLI (`anima install`, `anima tui`, `anima mcp`, `anima update`) |

### Rails app layer (`app/`)

| Component | Role |
|-----------|------|
| `models/Session` | Conversation unit; owns events + goals; has parent/child hierarchy for sub-agents |
| `models/Event` | Single source of truth for conversation history; persisted via `Events::Subscribers::Persister` |
| `models/Goal` | Two-level goal hierarchy (root + sub-goals) managed by analytical brain |
| `jobs/AgentRequestJob` | Background job for sub-agent execution |
| `jobs/AnalyticalBrainJob` | Runs the analytical brain after each exchange |
| `jobs/CountEventTokensJob` | Async token counting for context budget management |
| `channels/` | Action Cable channels for TUI ↔ Brain WebSocket communication |
| `decorators/` | Draper decorators transform events into view-mode-specific display data |

### Key design patterns

**Event bus (not a message queue):** All events flow through `Events::Bus` → `Rails.event.notify`. Subscribers (`Persister`, `Broadcasting`, etc.) react independently. Adding a new subscriber never touches existing code.

**Context as viewport:** There is no message array. `Session#viewport` queries SQLite newest-first until a token budget is exhausted. Every LLM call assembles a fresh viewport. Events outside the window are not deleted — just not visible yet.

**Sub-agent context inheritance:** Child sessions share the event bus. Their viewport composes from child events (prioritized) + parent events (filling remaining budget). No serialization, no summaries.

**Analytical brain as phantom session:** Runs as a non-persisted session using a fast model (Haiku). Its tool calls modify real models (Session, Goal) but leave no event trail of its own work.

**Settings never hardcoded:** All tunable values come from `Anima::Settings.*`, backed by `~/.anima/config.toml`. Tests stub `Anima::Settings.config` (see `spec/rails_helper.rb`).

**Skills and workflows from Markdown:** Loaded from `skills/` and `workflows/` (built-in), then merged/overridden from `~/.anima/skills/` and `~/.anima/workflows/`. Files use YAML frontmatter (`name`, `description`) followed by Markdown content.

## GitHub sub-issues

Use the REST API to manage sub-issues on epics:

```bash
# Add sub-issue (requires global issue ID, not issue number)
ISSUE_ID=$(gh api repos/hoblin/anima/issues/42 --jq '.id')
gh api repos/hoblin/anima/issues/36/sub_issues -X POST -F sub_issue_id=$ISSUE_ID

# List sub-issues
gh api repos/hoblin/anima/issues/36/sub_issues

# Reorder (move sub-issue after another; use global IDs)
gh api repos/hoblin/anima/issues/36/sub_issues/priority -X PATCH \
  -F sub_issue_id=$ISSUE_ID -F after_id=$AFTER_ID
```
