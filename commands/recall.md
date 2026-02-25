---
description: Search past conversations for a topic
argument-hint: <search-topic> [--scope current|all] [--limit N]
model: sonnet
---

Search past Claude Code conversation sessions for information about: $ARGUMENTS

## Workflow

1. **Parse arguments**: Extract the search topic and optional flags from the arguments. Default scope is "current" project, default limit is 10.

2. **Search session index first** (fast path):
   - Use `bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-sessions.sh` with `--grep` to match the topic against session summaries and first prompts
   - If scope is "all", search across all projects

3. **Deep search if needed**: If session-level matches aren't sufficient:
   - Use Grep to search inside `.jsonl` files for the topic keyword
   - Focus on user messages and assistant text blocks (skip progress, tool_results, etc.)

4. **Extract relevant context**: For the top matches:
   - Use `bash ${CLAUDE_PLUGIN_ROOT}/scripts/extract-messages.sh` to get the conversation around the topic
   - Use `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-stats.sh` for session context

5. **Present findings**: Summarize what was found, linking to specific sessions and dates. Include enough context for the user to understand the relevance.

## Output Format

For each relevant finding:
- **Session**: [date] — [summary]
- **Context**: [what was being discussed]
- **Relevant excerpt**: [the key information found]
