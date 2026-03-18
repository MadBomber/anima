---
tags:
  - getting-started
  - installation
---

# Installation

## Requirements

- Ruby >= 3.2.0
- Bundler
- `systemd` (Linux) or Foreman-compatible process manager (macOS)
- Git (optional, for running from source)

## Install from RubyGems

```bash
gem install anima-core
```

## Set Up the State Directory

Run the installer to create `~/.anima/`, initialize the SQLite databases, and register the brain as a systemd user service:

```bash
anima install
```

The installer will:

1. Create `~/.anima/` with all required subdirectories
2. Copy the default `config.toml` and `mcp.toml` templates
3. Run `db:prepare` to create and migrate all three databases
4. Register and enable a systemd user service (Linux only)

## Start the Brain

=== "Linux (systemd)"

    The installer registers the brain as a systemd user service that starts automatically on login:

    ```bash
    systemctl --user start anima      # Start now
    systemctl --user status anima     # Check status
    journalctl --user -u anima -f     # Follow logs
    ```

=== "macOS / Manual"

    Use Foreman to start both the web server and background worker:

    ```bash
    cd $(gem contents anima-core | grep Procfile | head -1 | xargs dirname)
    foreman start
    ```

    Or start the processes individually:

    ```bash
    # Web server (port 42134)
    bundle exec puma -C config/puma.rb

    # Background worker
    bundle exec rake solid_queue:start
    ```

## Connect the TUI

Once the brain is running, connect the terminal interface:

```bash
anima tui
```

On first connection, Anima will walk through its initial session — the agent wakes up, explores its environment, and writes its `soul.md`.

## Running From Source

```bash
git clone https://github.com/hoblin/anima.git
cd anima
bin/setup      # Installs dependencies, prepares databases
```

Start in development mode (port 42135, separate from any production brain):

```bash
# Terminal 1 — brain server + background worker
bin/dev

# Terminal 2 — TUI connecting to development brain
./exe/anima tui --host localhost:42135
```

!!! tip
    Use `./exe/anima` (not `bundle exec anima`) when testing local source changes. The exe loads `lib/` directly via `require_relative` rather than the installed gem.

## Updating

```bash
anima update                 # Upgrade gem + add new config keys
anima update --migrate-only  # Only merge config changes, skip gem upgrade
```

The updater merges new settings into your existing `config.toml` without overwriting any values you have customized.
