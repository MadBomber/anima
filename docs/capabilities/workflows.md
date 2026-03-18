---
tags:
  - capabilities
  - workflows
---

# Workflows

Workflows are operational recipes that describe how to perform multi-step tasks. Unlike skills (which provide domain knowledge), workflows describe **what to do step by step**.

## How Workflows Work

When the analytical brain recognizes a task pattern in the conversation (e.g., the user asks to "implement a feature"), it:

1. Calls `read_workflow` to inspect the matching workflow
2. Activates the workflow — its content is injected into the system prompt
3. Converts the workflow's prose into tracked goals the agent works through
4. Deactivates the workflow when all goals are complete

**Only one workflow can be active at a time.** If a new workflow is activated, the previous one is deactivated first.

The active workflow is shown in the TUI info panel with a 🔄 indicator.

## Built-in Workflows

### `commit`

Guide the agent through creating a well-formed git commit — staging changes, writing a conventional commit message, and handling pre-commit hook failures.

### `create_handoff`

Create a structured handoff document capturing current project state, recent changes, open questions, and next steps. Used when ending a session and wanting to resume context efficiently later.

### `create_note`

Capture findings, decisions, or context as a persistent note file in the project.

### `create_plan`

Break down a feature request or task into a structured implementation plan — architecture decisions, component list, step-by-step tasks, acceptance criteria.

### `decompose_ticket`

Take a high-level ticket or user story and decompose it into granular implementation tasks suitable for a sprint.

### `feature`

Full feature development workflow — exploration, planning, implementation, testing, and review. The most comprehensive workflow.

### `implement_plan`

Execute a previously created plan file step by step, tracking progress and handling blockers.

### `iterate_plan`

Refine and update an existing plan based on new information, feedback, or changed requirements.

### `research_codebase`

Systematic codebase research — understand architecture, find patterns, identify dependencies, answer specific questions about the implementation.

### `resume_handoff`

Read a handoff document and reconstruct context — understand where things left off and what needs to happen next.

### `review_pr`

Review a pull request — read the diff, understand the intent, check for issues, provide structured feedback.

### `thoughts_init`

Initialize a `thoughts/` directory structure for tracking project thinking, decisions, and open questions.

### `validate_plan`

Review a plan against the current codebase to check for feasibility, missing steps, or potential conflicts.

## Adding Your Own Workflows

Drop Markdown files into `~/.anima/workflows/` to add custom workflows:

```
~/.anima/workflows/
└── deploy.md
```

### Workflow File Format

```markdown
---
name: deploy
description: "Deploy the application to production — pre-deploy checks, deployment, and verification."
---

## Deploy to Production

You are deploying the application to production. Follow these steps carefully.

### Pre-deploy Checklist

1. Verify the main branch is clean and all tests pass
2. Check for any pending migrations
3. Review the CHANGELOG for breaking changes
...

### Deployment

...

### Post-deploy Verification

...
```

The `description` field is used by the analytical brain to recognize when this workflow applies. Make it specific.

## Disable Built-in Workflows

To suppress all built-in workflows and use only your own:

```toml
[workflows]
load_builtin = false
```

## Override a Built-in Workflow

A user workflow with the same name as a built-in **replaces** it:

```
~/.anima/workflows/commit.md    ← replaces the built-in commit workflow
```
