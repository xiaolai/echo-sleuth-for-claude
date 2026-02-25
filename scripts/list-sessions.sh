#!/usr/bin/env bash
# list-sessions.sh — List sessions from sessions-index.json + fallback index
# Usage: list-sessions.sh [project-path|"all"|"current"] [--limit N] [--since YYYY-MM-DD] [--grep PATTERN]
#
# Output format (tab-separated):
#   SESSION_ID  CREATED  MODIFIED  MSG_COUNT  BRANCH  SUMMARY  FIRST_PROMPT  PROJECT_PATH  FULL_PATH
#
# Now covers ALL projects — builds fallback index for projects without sessions-index.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse scope: only consume first arg if it's not a flag
SCOPE="current"
if [[ $# -gt 0 && "${1}" != --* ]]; then
  SCOPE="$1"
  shift
fi

LIMIT=50
SINCE=""
GREP_PAT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --grep)  GREP_PAT="$2"; shift 2 ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --limit must be a number, got: $LIMIT" >&2
  exit 1
fi

ES_SCOPE="$SCOPE" ES_TARGET="$(pwd)" ES_LIMIT="$LIMIT" ES_SINCE="$SINCE" ES_GREP="$GREP_PAT" \
ES_SCRIPT_DIR="$SCRIPT_DIR" \
python3 << 'PYEOF'
import os, sys
sys.path.insert(0, os.environ["ES_SCRIPT_DIR"])
import echolib

scope = os.environ["ES_SCOPE"]
target = os.environ.get("ES_TARGET", "")
limit = int(os.environ.get("ES_LIMIT", "50"))
since = os.environ.get("ES_SINCE", "")
grep_pat = os.environ.get("ES_GREP", "")

if scope in ("current", "all"):
    entries = echolib.list_sessions(scope=scope, target=target, limit=limit, since=since, grep_pat=grep_pat)
else:
    entries = echolib.list_sessions(scope="path", target=scope, limit=limit, since=since, grep_pat=grep_pat)

if not entries and scope == "current":
    print("ERROR: No Claude session directory found for " + target, file=sys.stderr)
    print("Hint: try 'list-sessions.sh all' to search all projects", file=sys.stderr)
    sys.exit(1)

for e in entries:
    print(e.to_tsv())
PYEOF
