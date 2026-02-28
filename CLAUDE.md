# Echo Sleuth — Plugin Development Guide

## Purpose

Echo Sleuth mines Claude Code session JSONL files for insights. It helps users recall past work, trace decisions, learn from mistakes, and understand file histories by analyzing `~/.claude/projects/` conversation data.

## Architecture

```
commands/  → User-facing slash commands (entry points)
agents/    → Task-specific agents dispatched by commands via the Task tool
skills/    → Reusable knowledge (parsing rules, git patterns, synthesis taxonomy)
scripts/   → Python/bash tools that do the actual JSONL parsing and extraction
```

**Flow:** Commands dispatch to agents. Agents use skills for domain knowledge and call scripts (via Bash tool) for data extraction. Scripts are thin bash wrappers around `scripts/echolib.py`.

### Commands
- `/recall` — Search and analyze past sessions
- `/recap` — Summarize recent sessions
- `/timeline` — Chronological project history (sessions + git)
- `/lessons` — Extract lessons learned

### Agents
- `recall` — Unified search: session finding, decision archaeology, mistake hunting
- `file-historian` — Trace a file's history across sessions and git
- `analyze` — Deep analysis of specific sessions
- `schema-scout` — Detect JSONL schema changes

### Skills
- `jsonl-core` — Canonical JSONL parsing infrastructure and record type reference
- `git-mining` — Git log/blame/diff patterns for correlating commits with sessions
- `experience-synthesis` — Taxonomy for categorizing insights (decisions, mistakes, patterns)

### Scripts
All in `scripts/`, require only Python 3.6+ (stdlib only) and bash. Git scripts additionally require git.
- `echolib.py` — Core Python parsing module (no pip dependencies)
- `list-sessions.sh` — Index-based session listing with grep/limit
- `session-stats.sh` — Single-pass session statistics
- `extract-messages.sh` — Human-readable message extraction
- `extract-tools.sh` — Tool call extraction with error filtering
- `extract-files-changed.sh` — Files edited in a session
- `parse-jsonl.sh` — Low-level JSONL parser with schema detection
- `build-index.sh` — Build fallback index for projects without sessions-index.json
- `git-context.sh` / `git-sessions.sh` — Git history helpers

## Key Conventions

- **Index first**: Always query `list-sessions.sh` before opening raw `.jsonl` files.
- **Script-based parsing**: Use the provided scripts instead of ad-hoc grep/jq pipelines. `echolib.py` handles schema variations and noise filtering.
- **Grep tool is not bash**: In agent/skill docs, `Grep pattern=...` calls refer to the Claude Code Grep tool, not the bash `grep` command.
- **`${CLAUDE_PLUGIN_ROOT}`**: Resolves to this plugin's root directory at runtime. Use it to reference scripts.
- **Cache side effect**: `build-index.sh` / `build_fallback_index()` writes `.echo-sleuth-index.json` inside `~/.claude/projects/<dir>/`. This is excluded from the plugin repo via `.gitignore`.

## Prerequisites

- Python 3.6+ (stdlib only, no pip packages)
- bash
- git (optional, needed only for git-mining features and git-based agents)
