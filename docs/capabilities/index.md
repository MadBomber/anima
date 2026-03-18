---
tags:
  - capabilities
---

# Capabilities

Anima ships with a full set of built-in capabilities that the agent can use out of the box, plus extension points for adding your own.

## Built-in Tools

10 tools the agent can call directly:

| Tool | What it does |
|---|---|
| `bash` | Execute shell commands with persistent working directory |
| `read` | Read files with smart truncation and offset/limit paging |
| `write` | Create or overwrite files |
| `edit` | Surgical text replacement with uniqueness constraint |
| `web_get` | Fetch content from HTTP/HTTPS URLs |
| `think` | Express reasoning or inner monologue between tool calls |
| `spawn_specialist` | Spawn a named specialist sub-agent from the registry |
| `spawn_subagent` | Spawn a generic child session with custom tool grants |
| `return_result` | Sub-agents only — deliver results back to parent |
| `request_feature` | Create a GitHub issue when a needed capability is missing |

Plus dynamic tools from any configured MCP servers, namespaced as `servername_toolname`.

→ [Full Tools Reference](tools.md)

## Built-in Skills

7 domain knowledge packs the analytical brain can activate:

- `activerecord` — Rails database patterns
- `draper-decorators` — view decorator patterns
- `dragonruby` — DragonRuby game engine
- `gh-issue` — GitHub issue creation
- `mcp-server` — Building MCP servers in Ruby
- `ratatui-ruby` — Terminal UI development
- `rspec` — RSpec testing patterns

→ [Skills System](skills.md)

## Built-in Workflows

13 operational recipes for common multi-step tasks:

`commit`, `create_handoff`, `create_note`, `create_plan`, `decompose_ticket`, `feature`, `implement_plan`, `iterate_plan`, `research_codebase`, `resume_handoff`, `review_pr`, `thoughts_init`, `validate_plan`

→ [Workflows System](workflows.md)

## Built-in Specialist Agents

5 pre-defined sub-agents with specific roles and tool sets:

| Specialist | Role |
|---|---|
| `codebase-analyzer` | Analyze implementation details |
| `codebase-pattern-finder` | Find similar patterns and usage examples |
| `documentation-researcher` | Fetch library docs and provide code examples |
| `thoughts-analyzer` | Extract decisions from project history |
| `web-search-researcher` | Research questions via web search |

→ [Sub-Agents](sub-agents.md)

## MCP Integration

Connect any Model Context Protocol server to give the agent access to external tools — Sentry, Linear, filesystem servers, custom internal tools, and more.

→ [MCP Integration](mcp-integration.md)
