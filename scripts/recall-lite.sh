#!/usr/bin/env bash
# recall-lite.sh — Local-only session search. Zero API calls.
#
# Pure-shell counterpart to /echo-sleuth:recall. Use this when you cannot or
# do not want to spend a Claude model turn — for example when your session is
# pinned to a billing tier (such as 1M-context Opus with Extra Usage disabled)
# that rejects requests outright, or when you just want fast, deterministic
# raw matches without synthesis.
#
# Usage:
#   recall-lite.sh <keyword> [--scope current|all] [--limit N] [--deep]
#
#   <keyword>          Single search term. Use the most distinctive word from
#                      your question. Substring match, case-insensitive at the
#                      index level. Required.
#   --scope current    Search only the current project's sessions (default).
#   --scope all        Search across every project under ~/.claude/projects.
#   --limit N          Number of matching sessions to deep-dive into. Default 5.
#   --deep             Also dump full conversation excerpts (--thinking off,
#                      role both, up to 30 messages) instead of only user
#                      messages and tool errors. Slower; produces more output.
#
# Output:
#   1. A header listing matching sessions (tab-separated, 9 fields).
#   2. For each of the top N matches: session metadata, the user-side messages,
#      and any tool errors. With --deep, also a full message excerpt.
#
# This is raw evidence, not a synthesized summary. You read it yourself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
fi

QUERY="$1"
shift

SCOPE="current"
LIMIT=5
DEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --deep)  DEEP=1; shift ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --limit must be a number, got: $LIMIT" >&2
  exit 1
fi

if [[ "$SCOPE" != "current" && "$SCOPE" != "all" ]]; then
  echo "ERROR: --scope must be 'current' or 'all', got: $SCOPE" >&2
  exit 1
fi

echo "=== recall-lite: query='$QUERY' scope=$SCOPE limit=$LIMIT ==="
echo

# list-sessions.sh exits 1 when no entries match, even if sessions exist for
# the project — that's a known quirk. Capture stderr so we can distinguish
# "no matches" (benign) from a real failure (fatal).
LIST_STDERR_FILE="$(mktemp)"
trap 'rm -f "$LIST_STDERR_FILE"' EXIT

if MATCHES="$("$SCRIPT_DIR/list-sessions.sh" "$SCOPE" --grep "$QUERY" --limit "$LIMIT" 2>"$LIST_STDERR_FILE")"; then
  : # success path; MATCHES populated
else
  STATUS=$?
  STDERR_CONTENT="$(cat "$LIST_STDERR_FILE")"
  # The "no session directory found" error fires both when truly no sessions
  # exist AND when grep filtered everything out. Treat it as "no matches".
  if [[ "$STDERR_CONTENT" == *"No Claude session directory found"* ]]; then
    echo "No matching sessions found for '$QUERY' in scope '$SCOPE'."
    if [[ "$SCOPE" == "current" ]]; then
      echo "Hint: try --scope all to search every project."
    fi
    exit 0
  fi
  echo "list-sessions.sh failed (status $STATUS):" >&2
  echo "$STDERR_CONTENT" >&2
  exit 1
fi

if [[ -z "$MATCHES" ]]; then
  echo "No matching sessions found for '$QUERY' in scope '$SCOPE'."
  exit 0
fi

echo "--- Matching sessions (SESSION_ID  CREATED  MODIFIED  MSG_COUNT  BRANCH  SUMMARY  FIRST_PROMPT  PROJECT_PATH  FULL_PATH) ---"
echo "$MATCHES"
echo

# Iterate top-N matches and dump evidence per session.
# Note: bash `read` with IFS=$'\t' collapses consecutive tabs because tab is
# whitespace IFS, which corrupts rows where SUMMARY is empty. Swap tabs for a
# non-whitespace delimiter (\x1f, ASCII unit separator) before parsing.
i=0
while IFS=$'\x1f' read -r session_id created modified msg_count branch summary first_prompt project_path full_path; do
  [[ -z "${full_path:-}" ]] && continue
  [[ ! -f "$full_path" ]] && continue
  i=$((i + 1))
  echo "============================================================"
  echo "Session $i/$LIMIT"
  echo "  Summary : $summary"
  echo "  Created : $created"
  echo "  Modified: $modified"
  echo "  Branch  : $branch"
  echo "  Messages: $msg_count"
  echo "  Path    : $full_path"
  echo "============================================================"
  echo
  echo "--- User messages (intent) ---"
  "$SCRIPT_DIR/extract-messages.sh" "$full_path" --role user --no-tools --limit 15 2>/dev/null || \
    echo "(extract-messages failed)"
  echo
  echo "--- Tool errors (if any) ---"
  "$SCRIPT_DIR/extract-tools.sh" "$full_path" --errors-only --limit 20 2>/dev/null || \
    echo "(extract-tools failed)"
  echo
  if [[ "$DEEP" -eq 1 ]]; then
    echo "--- Full excerpt (both roles, up to 30 messages) ---"
    "$SCRIPT_DIR/extract-messages.sh" "$full_path" --role both --limit 30 2>/dev/null || \
      echo "(extract-messages failed)"
    echo
  fi
done < <(printf '%s\n' "$MATCHES" | tr '\t' $'\x1f')

echo "=== recall-lite done. $i session(s) inspected. ==="
