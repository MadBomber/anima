---
tags:
  - getting-started
  - authentication
---

# Authentication

Anima uses your **Claude Pro or Max subscription** for API access — no separate API key purchase required. Authentication goes through the Claude Code CLI OAuth flow.

## Setup

### Step 1 — Get a setup token

In any terminal, run:

```bash
claude setup-token
```

This generates a short-lived token tied to your Claude subscription.

### Step 2 — Enter the token in the TUI

1. Open the TUI: `anima tui`
2. Press `Ctrl+a → a` to open the token setup popup
3. Paste the token and press `Enter`

Anima validates the token against the Anthropic API and saves it to Rails encrypted credentials. The popup closes automatically on success.

!!! note
    The token setup popup also activates automatically when Anima detects a missing or invalid token — for example, after the token expires.

## Token Expiry

OAuth tokens expire periodically. When your token expires:

1. Run `claude setup-token` again for a new token
2. Open the TUI — the popup appears automatically, or press `Ctrl+a → a`
3. Paste the new token

## Credential Storage

Tokens are stored in Rails encrypted credentials at:

```
~/.anima/config/credentials/<environment>.yml.enc
```

The key file is at `~/.anima/config/credentials/<environment>.key`. Keep this file safe — it decrypts your credentials. The credentials file itself is safe to back up; the key file is not.

## MCP Server Secrets

API keys and tokens for MCP servers are stored separately via the `anima mcp secrets` commands. See [MCP Integration](../capabilities/mcp-integration.md#secrets-management) for details.
