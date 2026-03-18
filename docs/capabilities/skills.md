---
tags:
  - capabilities
  - skills
---

# Skills

Skills are domain knowledge bundles loaded from Markdown files. The analytical brain activates and deactivates them automatically based on conversation context.

## How Skills Work

When the analytical brain observes a conversation topic that matches a skill's domain (e.g., the agent starts working with ActiveRecord queries), it calls `activate_skill` to inject that skill's content into the system prompt. The main agent's very next LLM call includes that knowledge.

When the topic shifts away, the analytical brain calls `deactivate_skill` to free up the token budget.

**Skills are additive** — multiple skills can be active simultaneously. Unlike workflows, there's no "only one active" constraint.

Active skills are shown in the TUI info panel.

## Built-in Skills

### `activerecord`

ActiveRecord query patterns, associations, migrations, callbacks, and validations for Rails applications. Includes examples organized by category:

- Associations (belongs_to, has_many, has_many :through, etc.)
- Basics (CRUD, attribute access)
- Callbacks
- Migrations
- Querying (where, joins, includes, scopes)
- Validations

### `draper-decorators`

Draper view decorator patterns — creating decorators, helper methods, associations, and Rails integration. Useful when working with Anima's own decorator layer or any Rails app using Draper.

### `dragonruby`

DragonRuby game engine development — entity system, input handling, rendering, audio, scenes, game logic, and distribution.

### `gh-issue`

GitHub issue creation best practices — format, labels, minimal reproduction cases, communicating bugs vs. feature requests.

### `mcp-server`

Building Model Context Protocol servers in Ruby — tool definitions, transport types, server configuration.

### `ratatui-ruby`

Terminal UI development with the RatatuiRuby gem — layout system, widgets, event handling, styling. Used when working on the Anima TUI itself or any terminal application.

### `rspec`

RSpec testing patterns — spec structure, matchers, mocks, factory_bot, Rails-specific helpers. Includes extensive examples.

## Adding Your Own Skills

Drop Markdown files into `~/.anima/skills/` to add custom knowledge:

=== "Flat file"

    ```
    ~/.anima/skills/
    └── my-framework.md
    ```

    The filename becomes the skill name: `my-framework`.

=== "Directory"

    ```
    ~/.anima/skills/
    └── my-framework/
        ├── SKILL.md          ← primary skill content
        ├── examples/
        │   ├── basic.md
        │   └── advanced.md
        └── references/
            └── api.md
    ```

    All files are merged into a single skill document.

## Skill File Format

Skills use YAML frontmatter for metadata, followed by Markdown content:

```markdown
---
name: my-framework
description: "Knowledge about MyFramework for Ruby — initialization, configuration, and usage patterns."
---

# MyFramework

MyFramework is a Ruby library for...

## Quick Start

```ruby
require 'my_framework'

client = MyFramework::Client.new(api_key: ENV['MY_KEY'])
```

## Common Patterns

...
```

The `description` is used by the analytical brain to decide when to activate the skill. Make it specific to the domain so the brain can match it accurately.

## Override Built-in Skills

A user skill with the same name as a built-in skill **replaces** it entirely. This lets you customize or extend any built-in knowledge:

```
~/.anima/skills/rspec.md    ← replaces the built-in rspec skill
```
