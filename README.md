# echo-sleuth

Mine past Claude Code conversations for decisions, mistakes, patterns, and wisdom.

## What it does

Echo Sleuth analyzes your Claude Code session history (`~/.claude/projects/`) to help you recall past work, trace decisions, learn from mistakes, and understand file histories.

- **Search past sessions** — find conversations by keyword, date, or file
- **Summarize recent work** — get a quick recap of what happened across sessions
- **Build timelines** — chronological project history combining sessions and git commits
- **Extract lessons** — surface patterns, mistakes, and decisions worth remembering

Part of the [xiaolai plugin marketplace](https://github.com/xiaolai/claude-plugin-marketplace).

## Installation

Add the marketplace (once):

```
/plugin marketplace add xiaolai/claude-plugin-marketplace
```

Then install:

```
/plugin install echo-sleuth@xiaolai
```

| Scope | Command | Effect |
|-------|---------|--------|
| **User** (default) | `/plugin install echo-sleuth@xiaolai` | Available in all your projects |
| **Project** | `/plugin install echo-sleuth@xiaolai --scope project` | Shared with team via `.claude/settings.json` |
| **Local** | `/plugin install echo-sleuth@xiaolai --scope local` | Only you, only this repo |

## Commands

| Command | Description |
|---------|-------------|
| `/recall` | Search and analyze past sessions |
| `/recap` | Summarize recent sessions |
| `/timeline` | Chronological project history (sessions + git) |
| `/lessons` | Extract lessons learned from past sessions |

> When installed as a plugin, commands appear as `/echo-sleuth:<command>` (e.g. `/echo-sleuth:recall`).

## How it works

1. **Commands** are user-facing entry points that dispatch to specialized agents
2. **Agents** handle the actual analysis — searching sessions, tracing file history, deep-diving into specific sessions, or detecting schema changes
3. **Scripts** (Python + bash) do the JSONL parsing and data extraction — no pip dependencies, only Python 3.6+ stdlib

### Agents

| Agent | Focus |
|-------|-------|
| `recall` | Unified search: session finding, decision archaeology, mistake hunting |
| `file-historian` | Trace a file's history across sessions and git |
| `analyze` | Deep analysis of specific sessions |
| `schema-scout` | Detect JSONL schema changes across Claude Code versions |

## Prerequisites

- Python 3.6+ (stdlib only, no pip packages)
- bash
- git (optional, needed for timeline and file history features)

## License

MIT
