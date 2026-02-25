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

Launch the `recall` agent via the Task tool with the following context:

- **Focus**: recap / recent summary
- **Parse arguments**: $ARGUMENTS (number, duration, --detail flag)
- **Default**: last 5 sessions, medium detail

The agent should:
1. List recent sessions using `bash ${CLAUDE_PLUGIN_ROOT}/scripts/list-sessions.sh current --limit N`
2. For each session, get stats: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-stats.sh <path>`
3. For medium/high detail, read user messages: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/extract-messages.sh <path> --role user --no-tools --limit 10`
4. Synthesize: what was accomplished, what's in progress, what problems were encountered

Detail levels:
- **low**: Date, summary, message count, file count per session + overall trajectory
- **medium**: Add per-session goal, key actions, outcome, files touched
- **high**: Add errors encountered, decisions made, unfinished work, token usage
