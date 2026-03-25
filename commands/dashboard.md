---
description: Global memory overview — staleness alerts, token costs, and stats across all projects
argument-hint:
model: sonnet
---

Show a global overview of Claude Code memories across all projects.

Run the memory dashboard script to get the overview:

bash "${CLAUDE_PLUGIN_ROOT}/scripts/memory-dashboard.sh"

Present the output to the user. If there are staleness alerts, suggest running `/audit` or `/audit --deep` for detailed analysis. If token costs are high, suggest `/prune` for cleanup.
