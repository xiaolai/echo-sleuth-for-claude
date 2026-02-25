---
description: Search past conversations for a topic, decision, or mistake
argument-hint: <search-topic> [--scope current|all] [--limit N]
model: sonnet
---

Search past Claude Code conversation sessions for information about: $ARGUMENTS

Launch the `recall` agent via the Task tool with the following context:

- **Search topic**: $ARGUMENTS
- **Current project**: the current working directory
- **Default scope**: "current" project (use "all" if `--scope all` is specified)
- **Default limit**: 10 sessions

The recall agent will:
1. Search session indices (including fallback index for unindexed projects)
2. Deep-dive into the most relevant sessions
3. Determine focus from the query (session search, decision archaeology, or mistake hunting)
4. Present findings with dates, context, and excerpts

If the query mentions decisions, rationale, "why did we", or alternatives — focus on decision archaeology.
If the query mentions errors, mistakes, failures, "what went wrong" — focus on mistake hunting.
Otherwise, perform a general session search and summarize findings.
