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

## Workflow

Launch the `experience-learner` agent to perform the full analysis. This agent will:

1. Survey all sessions for the project (or across projects if scope=all)
2. Strategically sample high-signal sessions
3. Extract insights across all categories from the experience-synthesis taxonomy
4. Cross-reference with git history if available
5. Produce a structured wisdom report

Use the Task tool to launch the `experience-learner` agent with context about:
- The target project/scope
- Any topic filter
- Any category filter
- The current working directory

The agent has access to all echo-sleuth skills and will handle the analysis autonomously.
