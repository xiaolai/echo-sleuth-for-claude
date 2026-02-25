---
description: Extract accumulated wisdom from past sessions
argument-hint: [topic] [--scope current|all] [--category decisions|mistakes|patterns|all]
model: sonnet
---

Extract lessons and wisdom from past Claude Code conversation sessions.

Arguments: $ARGUMENTS

Default: analyze the current project across all categories.
If a topic is provided, focus on lessons related to that topic.
If --category is specified, focus on that insight category only.

Launch the `analyze` agent via the Task tool with the following context:

- **Task**: Extract accumulated wisdom and lessons
- **Scope**: current project (or all if `--scope all` specified)
- **Topic filter**: from $ARGUMENTS if provided
- **Category filter**: from --category flag if provided
- **Current working directory**: for project identification

The analyze agent will:
1. Survey all sessions for the project
2. Strategically sample high-signal sessions (longest, most errors, most recent)
3. Extract insights across all categories from the experience-synthesis taxonomy
4. Cross-reference with git history if available
5. Produce a structured wisdom report with confidence levels
