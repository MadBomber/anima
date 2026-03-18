---
tags:
  - development
  - contributing
---

# Contributing

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork: `git clone https://github.com/<your-username>/anima.git`
3. Set up: `bin/setup`
4. Create a branch: `git checkout -b my-feature`

## Commit Style

This project uses [Conventional Commits](https://www.conventionalcommits.org/). See `COMMITS.md` for the project's specific conventions.

```
feat(tools): add pdf_read tool for extracting text from PDF files
fix(mcp): handle connection timeout with exponential backoff
docs(skills): add rspec skill examples for shared contexts
refactor(agent_loop): extract interrupt detection into private method
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

Scope: the affected subsystem (tools, mcp, agent_loop, analytical_brain, tui, skills, workflows, etc.)

## Code Style

Anima uses StandardRB for Ruby formatting:

```bash
bundle exec standardrb        # check
bundle exec standardrb --fix  # auto-fix
```

## Adding a Tool

1. Create `lib/tools/my_tool.rb` inheriting from `Tools::Base`
2. Implement `schema` (returns JSON schema Hash) and `execute(**params)`
3. Register in the tool registry (or confirm auto-discovery if the registry scans the directory)
4. Add tests in `test/lib/tools/my_tool_test.rb`
5. Document in `docs/capabilities/tools.md`

```ruby
# lib/tools/my_tool.rb
# frozen_string_literal: true

module Tools
  class MyTool < Base
    name "my_tool"
    description "Does the thing. Use when you need the thing done."

    def schema
      {
        type: "object",
        properties: {
          input: { type: "string", description: "The input to process" }
        },
        required: %w[input]
      }
    end

    # @param input [String] the input to process
    # @return [String] the result
    def execute(input:)
      # implementation
    end
  end
end
```

## Adding a Skill

Create a Markdown file in `skills/` with YAML frontmatter:

```markdown
---
name: my-skill
description: "Knowledge about MyThing — initialization, patterns, and gotchas."
---

# MyThing

...
```

No Ruby code needed. The skill registry discovers files automatically.

## Adding a Workflow

Same pattern as skills, in `workflows/`:

```markdown
---
name: my-workflow
description: "How to accomplish MyTask — step-by-step operational recipe."
---

## MyTask Workflow

You are performing MyTask. Follow these steps...
```

## Adding a Specialist Agent

Create a Markdown file in `agents/`:

```markdown
---
name: my-specialist
description: "Specialist for MyDomain — does deep analysis of MyThing."
tools:
  - bash
  - read
---

## My Specialist

You are a specialist in MyDomain. Your job is to...
```

## Pull Requests

- Keep PRs focused — one concern per PR
- Add tests for new behavior
- Update documentation for user-facing changes
- Ensure `bundle exec standardrb` passes
- Ensure `bundle exec rails test` passes

## Filing Issues

Use `anima mcp add` to connect the GitHub MCP server, then ask Anima to create the issue for you — it'll use the correct format automatically. Or file directly on GitHub with a clear reproduction case.
