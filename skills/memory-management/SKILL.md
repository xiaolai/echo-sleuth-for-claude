---
name: memory-management
description: Use when auditing, extracting, pruning, or writing Claude Code memory files. Covers memory file format, MEMORY.md index conventions, staleness scoring, claim extraction heuristics, destination routing, mutation rules, and archive conventions.
---

# Memory Management

## Memory File Format

Frontmatter schema (simple key: value, NOT general YAML):

    ---
    name: <string, required>           # short identifier
    description: <string, required>    # one-line summary for relevance matching
    type: <enum, required>             # user | feedback | project | reference
    ---

- All values are plain strings, no quoting needed unless value contains `:`
- No nested structures, no lists, no multi-line values
- Body follows after the closing `---` delimiter as markdown

## MEMORY.md Index Format

- Plain markdown file, no frontmatter
- Contains links to individual memory files with brief descriptions
- Lines after 200 are truncated by Claude Code's loader — keep concise
- Entry format: `- [filename.md](filename.md) — brief description`
- When writing: create individual .md file first, then append entry

## Staleness Scoring

Exponential decay: `score = 100 * (1 - exp(-age_days * ln(2) / half_life))`

| Type | Half-life | Score 50 at | Score 90 at |
|------|-----------|-------------|-------------|
| project | 14 days | 14d | ~47d |
| feedback | 90 days | 90d | ~299d |
| user | 180 days | 180d | ~598d |
| reference | 60 days | 60d | ~199d |
| unknown | 30 days | 30d | ~100d |

Score-to-action: 0-50 = keep, 50-75 = review, 75-100 = prune.

Deep verification modifiers (additive, capped at 100):
- +20 if referenced file is missing
- +30 if referenced function/class not found
- +10 if URL returns non-200
- +15 if referenced branch doesn't exist

## Claim Extraction Heuristics (Deep Audit)

| Claim Type | Detection Pattern | Verification |
|------------|-------------------|--------------|
| File path | Contains `/`, ends with file extension | Glob for existence |
| Function/class | Backtick identifier in camelCase/PascalCase/snake_case | Grep in project |
| URL | Starts with `http://` or `https://` | curl HEAD request |
| Branch | After "branch" keyword or git pattern in backticks | `git branch -a` |
| Package | In dependency/package context | Grep in manifest files |

Skip generic descriptions that aren't verifiable (e.g., "use a database" vs "uses PostgreSQL 15").

## Destination Routing

| Destination | When to Use | Target Path |
|-------------|-------------|-------------|
| Memory file | Knowledge for Claude's future behavior | Session's project `memory/` dir |
| CLAUDE.md | High-impact instructions for every conversation | Session's project root CLAUDE.md |
| Knowledge file | Human-readable notes, decision logs | `docs/knowledge/` in project root |
| Skip | Session-specific, not worth preserving | — |

**Rule:** Always target the session's originating project, not the current shell cwd.

## Mutation Rules

| Layout | How to Write |
|--------|-------------|
| Index + files | Create .md file with frontmatter, append to MEMORY.md |
| Standalone MEMORY.md | Convert to index layout: create first .md file, rewrite MEMORY.md as index |
| No memory dir | Create `memory/`, create MEMORY.md, create .md file |
| Malformed frontmatter | Read as type=unknown. Never corrupt existing files. |

## Archive Convention

- Location: `memory/archive/` subdirectory
- Files preserved intact (frontmatter + content)
- MEMORY.md entry removed on archive
- `iter_memories()` skips `archive/` — invisible to dashboard/audit/tokens
- Standalone MEMORY.md: archiving not supported (offer delete or keep)
- Restore: manual move from `archive/` + re-add to MEMORY.md
