---
tags:
  - capabilities
  - tools
---

# Tools

The agent has 10 built-in tools available for every session. MCP servers add dynamic tools on top of these.

## `bash`

Execute shell commands in a persistent working directory.

```
bash(command: "ls -la", working_dir: "/path/to/dir")
```

The working directory persists across calls within a session — `cd` in one call, and the next call starts in that directory. Output is truncated at `max_output_bytes` (default: 100,000 bytes). Execution timeout is `timeouts.command` (default: 30 seconds).

---

## `read`

Read file contents with smart truncation, offset, and limit controls.

```
read(path: "app/models/user.rb")
read(path: "large_file.txt", offset: 500, limit: 100)
```

- **`offset`** — start reading from this line number
- **`limit`** — read at most this many lines

Files larger than `max_file_size` (default: 10 MB) are rejected. Output is capped at `max_read_bytes` (default: 50,000 bytes) or `max_read_lines` (default: 2,000 lines).

---

## `write`

Create or overwrite a file with the given content.

```
write(path: "docs/notes.md", content: "# Notes\n\n...")
```

Creates any missing parent directories automatically. Prefer `edit` for modifying existing files — `write` replaces the entire file.

---

## `edit`

Surgical text replacement within a file. Requires the `old_string` to appear exactly once in the file (uniqueness constraint).

```
edit(path: "app/models/user.rb", old_string: "def activate\n  update(active: true)\nend", new_string: "def activate\n  update(active: true, activated_at: Time.current)\nend")
```

The uniqueness constraint prevents accidental multi-site replacements. If the old string appears more than once, provide more surrounding context to make it unique.

---

## `web_get`

Fetch content from an HTTP or HTTPS URL.

```
web_get(url: "https://api.example.com/data")
```

Response is truncated at `max_web_response_bytes` (default: 100,000 bytes). Timeout is `timeouts.web_request` (default: 10 seconds).

---

## `think`

Express reasoning or inner monologue without taking an external action.

```
think(thoughts: "I need to check whether the migration already ran before...", visibility: "inner")
think(thoughts: "I'm going to search for the config file first.", visibility: "aloud")
```

- **`visibility: "inner"`** (default) — thoughts are not visible in the TUI (silent)
- **`visibility: "aloud"`** — thoughts are narrated to the user in the TUI

Use `think` to reason through a complex problem before acting, document decision-making, or communicate intent to the user without it counting as a response.

---

## `spawn_specialist`

Spawn a named specialist sub-agent from the built-in (or user-defined) agent registry.

```
spawn_specialist(name: "codebase-analyzer", task: "Analyze the authentication module and describe its design")
```

The specialist inherits the parent's full event context (up to `parent_context_ratio` × token budget). Results are delivered back to the parent via the sub-agent's `return_result` call.

**Available specialists:**

| Name | Role |
|---|---|
| `codebase-analyzer` | Deep implementation analysis |
| `codebase-pattern-finder` | Find patterns and usage examples |
| `documentation-researcher` | Library docs and code examples |
| `thoughts-analyzer` | Extract decisions from project history |
| `web-search-researcher` | Research via web search |

---

## `spawn_subagent`

Spawn a generic child session with a custom task and custom tool grants.

```
spawn_subagent(
  task: "Search the web for the latest ruby_llm changelog and summarize the new features",
  tools: ["web_get"],
  wait: true
)
```

- **`tools`** — array of tool names the sub-agent can use (subset of all available tools)
- **`wait`** — if `true`, the parent blocks until the sub-agent finishes (default: `false` for background)

Unlike `spawn_specialist`, generic sub-agents have no predefined role — the task and tool list define everything.

---

## `return_result`

Delivers results from a sub-agent back to its parent session. Only available to sub-agents (not the main agent).

```
return_result(result: "Analysis complete. The authentication module uses...", success: true)
```

After calling `return_result`, the sub-agent's session ends. The parent session receives the result and continues.

---

## `request_feature`

Create a GitHub issue when the agent encounters a task it can't complete with available tools.

```
request_feature(
  title: "Add PDF parsing tool",
  description: "I was asked to extract text from a PDF file but have no tool for this. A read_pdf tool would enable me to handle this class of requests."
)
```

Issues are created in the repository configured by `github.repo` in `config.toml`, with the label configured by `github.label` (default: `anima-wants`). Falls back to parsing `git remote origin` if `repo` is not set.

---

## MCP Tools

Tools from configured MCP servers appear automatically in the agent's tool list, namespaced with the server name:

```
sentry_list_issues(project: "my-project")
linear_create_issue(title: "Bug: login fails", team_id: "ENG")
filesystem_read_file(path: "/workspace/config.json")
```

See [MCP Integration](mcp-integration.md) for how to configure MCP servers.
