---
tags:
  - capabilities
  - mcp
---

# MCP Integration

Anima supports the [Model Context Protocol](https://modelcontextprotocol.io/) for integrating external tool servers. Both HTTP (SSE) and stdio transport types are supported.

## Configuration File

MCP servers are configured in `~/.anima/mcp.toml`:

```toml
[servers.sentry]
transport = "http"
url = "https://mcp.sentry.dev/mcp"

[servers.linear]
transport = "http"
url = "https://mcp.linear.app/mcp"
headers = { Authorization = "Bearer ${credential:linear_api_key}" }

[servers.filesystem]
transport = "stdio"
command = "mcp-server-filesystem"
args = ["--root", "/workspace"]

[servers.internal]
transport = "stdio"
command = "/usr/local/bin/my-mcp-server"
args = ["--mode", "production"]
env = { MY_SERVER_SECRET = "${credential:my_server_secret}" }
```

## Transport Types

=== "HTTP (SSE)"

    ```toml
    [servers.example]
    transport = "http"
    url = "https://example.com/mcp"
    headers = { Authorization = "Bearer ${credential:example_api_key}" }
    ```

    HTTP servers use Server-Sent Events for streaming. The `headers` table is optional — include it when the server requires authentication.

=== "Stdio"

    ```toml
    [servers.example]
    transport = "stdio"
    command = "mcp-server-example"
    args = ["--arg1", "value1"]
    env = { EXAMPLE_VAR = "value" }
    ```

    Stdio servers are spawned as subprocesses. Anima caches the client at the class level — the subprocess is started once per process, not once per agent turn.

## CLI Management

```bash
# List all configured servers with health status
anima mcp list

# Add an HTTP server
anima mcp add sentry https://mcp.sentry.dev/mcp

# Add an HTTP server with a secret
anima mcp add -s api_key=sk-xxx linear https://mcp.linear.app/mcp

# Add a stdio server (-- separates server name from command + args)
anima mcp add fs -- mcp-server-filesystem --root /

# Remove a server
anima mcp remove sentry
```

The `anima mcp list` command probes each server and reports its health status and tool count:

```
sentry     ✓ connected   12 tools
linear     ✓ connected    8 tools
filesystem ✗ failed       connection timeout
```

## Secrets Management

API keys and tokens for MCP servers are stored in Rails encrypted credentials — never in plaintext in `mcp.toml`.

```bash
# Store a secret
anima mcp secrets set linear_api_key=sk-abc123

# List stored secret names (values are never shown)
anima mcp secrets list

# Remove a secret
anima mcp secrets remove linear_api_key
```

In `mcp.toml`, reference secrets with `${credential:key_name}` syntax:

```toml
[servers.linear]
transport = "http"
url = "https://mcp.linear.app/mcp"
headers = { Authorization = "Bearer ${credential:linear_api_key}" }
```

The `${credential:...}` interpolation works in any TOML string value across both `mcp.toml` and `config.toml`.

## Tool Namespacing

Tools from MCP servers are prefixed with the server name to prevent collisions when multiple servers expose tools with the same name:

```
sentry_list_issues
sentry_get_event
linear_create_issue
linear_list_issues
filesystem_read_file
filesystem_write_file
```

The separator is `_` (underscore). If a server name contains hyphens, they become underscores in the tool name.

## Connection Management

Clients are cached at the class level in `Mcp::ClientManager`:

- **HTTP servers** — one connection per server per process
- **Stdio servers** — one subprocess per server per process, not re-spawned on every turn

On process exit, `at_exit` hooks call `ClientManager.stop_all` to cleanly terminate all stdio subprocesses.

If a server fails to connect at startup, a warning is shown in the TUI but the agent continues with the remaining tools. Failed server connections are retried on the next request.

## Health Check Timeout

The `anima mcp list` health check uses a 5-second timeout per server, balancing responsiveness (the CLI shouldn't hang) against giving slow servers a fair chance to respond.
