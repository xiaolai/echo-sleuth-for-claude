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

## Canonical Parser

The primary parsing tool for all JSONL operations:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/parse-jsonl.sh <file.jsonl> [options]
```

Key modes:
- **Schema detection** (check if format has changed):
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/parse-jsonl.sh <file.jsonl> --detect-schema
  ```
- **Filtered extraction** (skip noise, 38% faster on large files):
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/parse-jsonl.sh <file.jsonl> --types user,assistant --skip-noise --limit 20
  ```
- **Field selection** (only extract specific fields):
  ```bash
  bash ${CLAUDE_PLUGIN_ROOT}/scripts/parse-jsonl.sh <file.jsonl> --types user --fields timestamp,message --format tsv
  ```

### Performance Notes

- Python3 startup (80ms) dominates for files < 1MB (97% of all files)
- `--limit N` enables early exit — near-instant for small N
- `--skip-noise` avoids `json.loads` on `progress`/`queue-operation` lines by string pre-filter
- For the 81 files > 10MB: `json.loads` is the CPU bottleneck (63% of time), not I/O
- grep is NOT faster than Python for this format — avoid grep-then-parse pipelines

## Convenience Scripts

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

Use `--skip-noise` with `parse-jsonl.sh` for automatic noise filtering, or use the convenience scripts which handle this internally.

## Schema Evolution Awareness

Claude Code evolves rapidly. The JSONL format has changed across versions:
- New record types appear silently (e.g., `progress` at v2.1.14, `pr-link` later)
- New optional fields are added to existing records (~3-5 per minor version)
- Some record types (`summary`, `pr-link`, `file-history-snapshot`) lack common fields like `version` or `uuid`
- The directory encoding is lossy for Unicode paths — use `sessions-index.json`'s `originalPath` field as ground truth

When parsing results look unexpected, use the schema-scout agent or run:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/parse-jsonl.sh <file.jsonl> --detect-schema
```
to check for unknown record types or field changes.
