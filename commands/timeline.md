---
description: Show chronological timeline of project work
argument-hint: [--limit N] [--since YYYY-MM-DD]
model: sonnet
---

Show a chronological timeline of work on the current project, combining Claude Code session history with git history.

Optional arguments: $ARGUMENTS

## Workflow

1. **List all sessions** for the current project:
   ```
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-sessions.sh current --limit 50
   ```

2. **Get git history** if this is a git repo:
   ```
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/git-sessions.sh . --since "30 days ago"
   ```

3. **Merge both timelines** chronologically:
   - Claude sessions provide: what was discussed, what was tried, errors encountered
   - Git commits provide: what actually shipped, code changes made
   - Correlate by timestamp (commits during a session's time window belong to that session)

4. **Enrich key sessions**: For the most significant sessions (high message count, error-heavy, or milestone sessions like PR creation), get additional detail:
   ```
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-stats.sh <file>
   ```

5. **Present as timeline**: Chronological, with clear markers for milestones.

## Output Format

```
# Project Timeline: [project name]
Branch: [current branch]
Period: [earliest] → [latest]
Total: [N sessions, M git commits]

---

### [YYYY-MM-DD] — [Session summary]
  Branch: [branch] | Messages: [N] | Files: [N]
  [1-2 sentence description]
  Git: [commit hash] [commit message] (if commits match this time window)

### [YYYY-MM-DD] — [Session summary]
  ...
```

Mark notable milestones with emphasis: PR creation, major features, significant bug fixes.
