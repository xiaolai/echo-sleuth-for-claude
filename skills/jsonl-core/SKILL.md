---
name: jsonl-core
description: This skill should be used when the user asks to "analyze conversation history", "parse JSONL files", "read past sessions", "search conversation logs", "find what happened in a session", or needs to work with Claude Code's .jsonl conversation format. It provides the canonical parsing infrastructure for echo-sleuth agents.
version: 0.1.0
---

# JSONL Core — Conversation Parsing Infrastructure

## Data Locations

- **Session index (fast path)**: `~/.claude/projects/<encoded-path>/sessions-index.json`
- **Full conversations**: `~/.claude/projects/<encoded-path>/<uuid>.jsonl`
- **Subagent conversations**: `~/.claude/projects/<encoded-path>/<uuid>/subagents/agent-<id>.jsonl`
- **Global prompt history**: `~/.claude/history.jsonl`

The `<encoded-path>` is the project's absolute path with `/` replaced by `-` (e.g., `-Users-joker-github-myproject`).

## Strategy: Fast Path First

Always start with `sessions-index.json` before opening any `.jsonl` file:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-sessions.sh "current" --limit 20
bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-sessions.sh "all" --grep "search term" --limit 10
bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-sessions.sh "/path/to/project"
```

Output is tab-separated: `SESSION_ID  CREATED  MODIFIED  MSG_COUNT  BRANCH  SUMMARY  FIRST_PROMPT  PROJECT_PATH  FULL_PATH`

The `FULL_PATH` field (9th column) is the absolute path to the `.jsonl` file. Use this to pass to other scripts like `extract-messages.sh`.

Only open the full `.jsonl` when you need message-level detail.

## Parsing Scripts

All scripts are at `${CLAUDE_PLUGIN_ROOT}/scripts/`. They require only bash + python3 (stdlib only, no pip packages, minimum Python 3.6+). The git scripts use bash + awk + git.

### Extract human-readable messages
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/extract-messages.sh <file.jsonl> [--role user|assistant|both] [--no-tools] [--limit N] [--thinking]
```

### Extract tool calls with results
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/extract-tools.sh <file.jsonl> [--tool NAME] [--errors-only] [--limit N]
```

### List files edited in a session
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/extract-files-changed.sh <file.jsonl> [--with-versions]
```

### Quick session statistics
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-stats.sh <file.jsonl>
```

## When Scripts Are Not Enough

For targeted searches within large `.jsonl` files, use Grep directly:

```
# Find user messages containing a keyword
Grep pattern='"type":"user"' combined with Grep pattern='keyword'

# Find error results
Grep pattern='"is_error"\s*:\s*true'

# Find specific tool usage
Grep pattern='"name"\s*:\s*"ToolName"'

# Find decisions (AskUserQuestion usage)
Grep pattern='"name"\s*:\s*"AskUserQuestion"'
```

## Record Type Quick Reference

See `references/record-types.md` for the complete schema. The essential types:

| Type | What It Contains | When to Use |
|------|-----------------|-------------|
| `user` (string content) | Human's actual request | Understanding intent, finding topics |
| `assistant` (text blocks) | Claude's responses and reasoning | Finding decisions, explanations |
| `assistant` (tool_use blocks) | Tool invocations | Understanding what actions were taken |
| `file-history-snapshot` | Files edited with version counts | Knowing which files were touched |
| `summary` | AI-generated session title | Quick identification (also in sessions-index.json) |
| `system` (compact_boundary) | Context compaction marker | Session was long enough to need compaction |

## Finding the Right Session Directory

To map a project path to its Claude session directory:
1. Take the absolute project path (e.g., `/Users/joker/github/myproject`)
2. Replace all `/` with `-` → `Users-joker-github-myproject`
3. Prepend `-` → `-Users-joker-github-myproject`
4. Look in `~/.claude/projects/-Users-joker-github-myproject/`

If unsure, use `list-sessions.sh` which handles the lookup automatically.

## Noise Filtering

When reading raw `.jsonl`, skip these:
- Records where `type` is `progress` or `queue-operation` (streaming/internal bookkeeping)
- User records with `isMeta: true` (slash command injection)
- User records with `isCompactSummary: true` (auto-generated context, not human input)
- Assistant records with `model: "<synthetic>"` (passthrough, not real inference)
- User records where `content` is an array of `tool_result` blocks (tool outputs, not human messages)
