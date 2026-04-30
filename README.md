# echo-sleuth

Mine past Claude Code conversations and manage the knowledge lifecycle — search sessions, extract lessons, audit memory staleness, prune token waste.

## What it does

Echo Sleuth analyzes your Claude Code session history (`~/.claude/projects/`) and memory files to help you:

- **Search past sessions** — find conversations by keyword, date, or file
- **Summarize recent work** — get a quick recap of what happened across sessions
- **Build timelines** — chronological project history combining sessions and git commits
- **Extract lessons** — surface values, patterns, mistakes, and decisions worth remembering
- **Audit memories** — find stale, broken, or wasteful memories across all projects
- **Extract knowledge** — distill conversations into durable memories, CLAUDE.md rules, or human notes
- **Prune waste** — interactively clean up memories that silently eat tokens and money

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

> **Install fails with "Plugin not found in marketplace 'xiaolai'"?** Your local marketplace clone is stale. Run `claude plugin marketplace update xiaolai` and retry — `plugin install` does not auto-refresh.

| Scope | Command | Effect |
|-------|---------|--------|
| **User** (default) | `/plugin install echo-sleuth@xiaolai` | Available in all your projects |
| **Project** | `/plugin install echo-sleuth@xiaolai --scope project` | Shared with team via `.claude/settings.json` |
| **Local** | `/plugin install echo-sleuth@xiaolai --scope local` | Only you, only this repo |

## Commands

> When installed as a plugin, commands appear as `/echo-sleuth:<command>` (e.g. `/echo-sleuth:recall`).

### Conversation Mining

#### `/recall <topic> [--scope current|all] [--limit N] [--lite]`

Search past conversations for a topic, decision, or mistake.

```
/echo-sleuth:recall "why did we choose SQLite"
/echo-sleuth:recall "authentication bug" --scope all
/echo-sleuth:recall "CI setup" --limit 20
/echo-sleuth:recall vitepress --lite
```

- Searches session summaries, first prompts, and message content
- Auto-detects focus: decision archaeology ("why did we..."), mistake hunting ("what went wrong..."), or general search
- Default scope: current project. Use `--scope all` to search across all projects.
- `--lite` skips agent dispatch and synthesis. The slash command runs `recall-lite.sh` and returns its raw output verbatim — minimum-tokens mode for when you hit billing limits or just want raw evidence. See [Lite mode and API usage](#lite-mode-and-api-usage) below.

#### `/recap [N-sessions|duration] [--detail low|medium|high]`

Summarize recent sessions.

```
/echo-sleuth:recap
/echo-sleuth:recap 10
/echo-sleuth:recap 7d --detail high
```

- Default: last 5 sessions, medium detail
- Accepts session count (`10`) or duration (`3d`, `1w`)
- Detail levels: `low` (one-liners), `medium` (paragraph per session), `high` (full analysis)

#### `/timeline [--limit N] [--since YYYY-MM-DD]`

Chronological project history combining Claude sessions and git commits.

```
/echo-sleuth:timeline
/echo-sleuth:timeline --since 2026-03-01 --limit 50
```

- Merges session timestamps with git commit history
- Shows what work happened when, in what order
- Requires git for commit correlation

#### `/lessons [topic] [--scope current|all] [--category decisions|mistakes|patterns|all]`

Extract accumulated wisdom from past sessions.

```
/echo-sleuth:lessons
/echo-sleuth:lessons "database" --category decisions
/echo-sleuth:lessons --scope all --category mistakes
```

- Surveys all sessions, samples the highest-signal ones (longest, most errors, most recent)
- Categories: learned values, decisions, mistakes, patterns, tool preferences, architecture insights, cost/efficiency
- Cross-references with git history when available

### Memory Management

#### `/dashboard`

Global overview of Claude Code memories across all projects.

```
/echo-sleuth:dashboard
```

Shows:
- **Summary stats** — how many projects have memories, total files, estimated token load per conversation
- **Staleness alerts** — memories scored > 50 on the staleness scale, with age, type, and recommended action
- **Top token consumers** — which projects' memories cost the most tokens

Use this as the entry point to understand your memory landscape before auditing or pruning.

#### `/audit [project] [--deep]`

Audit memory staleness — quick heuristic scan or deep content verification.

```
/echo-sleuth:audit
/echo-sleuth:audit pixel-office
/echo-sleuth:audit --deep
/echo-sleuth:audit pixel-office --deep
```

**Without `--deep` (default):** Fast type-based heuristic scoring. Each memory gets a staleness score (0-100) based on its type and age:

| Type | Half-life | Score 50 at | Typical decay |
|------|-----------|-------------|---------------|
| `value` | 365 days | 1 year | Slowest — learned preferences ("X > Y") outlast everything |
| `user` | 180 days | 6 months | Very slow — user identity rarely changes |
| `feedback` | 90 days | 3 months | Slow — user preferences are stable |
| `reference` | 60 days | 2 months | Medium — external links go stale |
| `project` | 14 days | 2 weeks | Fast — project context changes often |

Score-to-action: 0-50 = keep, 50-75 = review, 75-100 = prune.

**With `--deep`:** Dispatches the `memory-auditor` agent which reads each memory and verifies its claims against the current codebase:
- Does the referenced file still exist?
- Can the mentioned function/class be found via grep?
- Does the URL return a 200 status?
- Does the git branch still exist?

Deep audit processes up to 10 projects (highest staleness first) and reports per-memory with evidence.

#### `/extract [session-id] [--scope current|all]`

Extract durable knowledge from a conversation session into memories, CLAUDE.md rules, or human-readable notes.

```
/echo-sleuth:extract
/echo-sleuth:extract abc123-def4-5678-ghij-klmnopqrstuv
/echo-sleuth:extract --scope all
```

**How it works:**

1. Lists recent sessions (last 7 days) and lets you pick one, or specify a session ID directly
2. Runs two-pass extraction:
   - **Tool pass** — finds `AskUserQuestion` decisions and tool errors (lessons)
   - **Message pass** — finds user corrections ("don't do X"), approved patterns ("perfect, keep doing that"), and referenced URLs
3. Presents each extractable item with a suggested destination
4. You choose where each item goes:

| Destination | When to use | What happens |
|-------------|-------------|-------------|
| **Memory** | Knowledge for Claude's future behavior | Creates a `.md` file in the project's `memory/` directory with proper frontmatter |
| **CLAUDE.md** | High-impact rules for every conversation | Appends to the project's CLAUDE.md |
| **Knowledge file** | Human-readable notes and decision logs | Writes markdown to `docs/knowledge/` (or custom path) |
| **Skip** | Not worth preserving | Discarded |

Extraction categories:
- **Values** — comparative preferences ("X is better than Y", "prefer X over Y") — the most durable type of memory
- **Decisions** — `AskUserQuestion` calls + user responses
- **Corrections** — user rejecting Claude's approach (imperative corrections suggest CLAUDE.md)
- **Patterns** — approaches the user approved ("great", "perfect", "works")
- **Lessons** — tool failures and error sequences
- **References** — URLs mentioned in conversation

#### `/prune [project] [--dry-run]`

Interactively clean up stale memories.

```
/echo-sleuth:prune
/echo-sleuth:prune pixel-office
/echo-sleuth:prune --dry-run
```

For each memory with staleness score > 50, you choose:

| Action | What happens |
|--------|-------------|
| **Delete** | Removes the file and its MEMORY.md entry. Content is printed to the conversation first (recoverable from session transcript). |
| **Archive** | Moves to `memory/archive/` subfolder. Removed from MEMORY.md so Claude no longer loads it, but preserved on disk. |
| **Keep** | Touches the file to reset the staleness clock. Use when a memory is old but still valid. |
| **Edit** | Shows content, asks what to change, applies edits in-place. |
| **Skip** | Move to next memory. |

`--dry-run` shows what would be flagged without taking action.

Reports at the end: N deleted, N archived, N kept, N edited, N skipped, and estimated tokens saved.

## Lite mode and API usage

Echo Sleuth is a Claude Code plugin, so every command goes through a model turn — that's how slash commands, agents, and skills work. The local Python and shell scripts (`scripts/`) parse JSONL files without any API calls, but turning their raw output into "here's what was decided and why" is what costs a model turn.

That matters in two situations:

1. **Your session is on a tier that rejects requests.** For example, `claude-opus-4-7[1m]` (the 1M-context Opus variant) requires Extra Usage to be enabled. If it isn't, every command — including `/recall` — fails with `API Error: Extra usage is required for 1M context` before any work happens.
2. **You only want raw evidence.** Sometimes you don't need synthesis; you just want the matched messages dumped to your terminal so you can read them yourself.

Two ways to avoid the synthesis cost:

### Option A: `/echo-sleuth:recall <keyword> --lite`

Stays inside Claude Code, but the slash command skips agent dispatch and runs the shell script directly. The model spends one cheap turn passing your keyword to the script and returning its output verbatim — no synthesis, no ranking, no commentary. Works on standard tiers and is the cheapest API path.

```
/echo-sleuth:recall vitepress --lite
/echo-sleuth:recall "auth bug" --scope all --limit 10 --lite
```

### Option B: `scripts/recall-lite.sh` directly from a shell

Zero API calls. Run it from your terminal:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/recall-lite.sh <keyword> [--scope current|all] [--limit N] [--deep]

# Example
~/.claude/plugins/cache/xiaolai/echo-sleuth/<version>/scripts/recall-lite.sh vitepress --limit 5
```

The script:
- Lists matching sessions via `list-sessions.sh`
- Dumps user messages (intent) and tool errors for the top N matches
- With `--deep`, also dumps a full message excerpt (both roles, up to 30 messages per session)

You read the output yourself. No synthesis, no ranking by decision-relevance — that's the trade-off for zero API cost.

### When to use which

| Goal | Use |
|------|-----|
| "Why did we choose SQLite, and what alternatives did we reject?" | `/echo-sleuth:recall ...` (full mode — needs synthesis) |
| "Show me every session that mentioned vitepress; I'll read them" | `/echo-sleuth:recall vitepress --lite` |
| "I'm rate-limited / on the wrong tier / want zero API cost" | `scripts/recall-lite.sh` from your shell |

If a `/recall` command fails with a billing/tier error, re-run with `--lite`, or fall back to the shell script.

## How it works

```
Commands → dispatch to → Agents → use → Skills (domain knowledge)
                                  → call → Scripts (data extraction)
```

1. **Commands** are user-facing entry points
2. **Agents** handle the actual analysis
3. **Skills** provide domain knowledge (JSONL format, git patterns, memory conventions)
4. **Scripts** (Python + bash) do the parsing — no pip dependencies, only Python 3.6+ stdlib

### Agents

| Agent | Focus |
|-------|-------|
| `recall` | Unified search: session finding, decision archaeology, mistake hunting |
| `analyze` | Deep analysis and lesson extraction across sessions |
| `file-historian` | Trace a file's complete history across sessions and git |
| `schema-scout` | Detect JSONL schema changes across Claude Code versions |
| `memory-auditor` | Deep content-aware memory verification (file/code/URL/branch checks) |

### Skills

| Skill | Purpose |
|-------|---------|
| `jsonl-core` | JSONL parsing infrastructure and record type reference |
| `git-mining` | Git log/blame/diff patterns for commit-session correlation |
| `experience-synthesis` | Taxonomy for categorizing insights |
| `memory-management` | Memory file format, staleness scoring, routing, mutation rules |

## Prerequisites

- Python 3.6+ (stdlib only, no pip packages)
- bash
- git (optional, for timeline, file history, and branch verification in deep audit)
- curl (optional, for URL validation in `/audit --deep`)

## License

ISC
