---
description: Summarize recent sessions
argument-hint: [N-sessions-or-days] [--detail low|medium|high]
model: sonnet
---

Summarize recent Claude Code sessions for the current project.

Arguments: $ARGUMENTS

If a number is given (e.g., "3"), summarize the last 3 sessions.
If a duration is given (e.g., "7d" or "1w"), summarize sessions from that period.
Default: last 5 sessions.

## Workflow

1. **List recent sessions**:
   ```
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-sessions.sh current --limit N
   ```

2. **For each session**, gather key info:
   ```
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-stats.sh <file>
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/extract-files-changed.sh <file>
   ```

3. **For medium/high detail**, also read messages:
   ```
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/extract-messages.sh <file> --role user --no-tools --limit 10
   ```

4. **Synthesize**: Present a concise recap of what was accomplished, what's in progress, and what problems were encountered.

## Output Format

### Low detail:
```
## Recent Sessions Recap

1. [Date] — [Summary] ([N] messages, [M] files)
2. [Date] — [Summary] ([N] messages, [M] files)
...

**Overall**: [1-2 sentences about the trajectory]
```

### Medium detail:
Add per-session: goal, key actions, outcome, files touched.

### High detail:
Add per-session: errors encountered, decisions made, unfinished work, token usage.
