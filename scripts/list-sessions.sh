#!/usr/bin/env bash
# list-sessions.sh — List sessions from sessions-index.json files
# Usage: list-sessions.sh [project-path|"all"|"current"] [--limit N] [--since YYYY-MM-DD] [--grep PATTERN]
#
# Output format (tab-separated):
#   SESSION_ID  CREATED  MODIFIED  MSG_COUNT  BRANCH  SUMMARY  FIRST_PROMPT  PROJECT_PATH  FULL_PATH

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude/projects"

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

# Validate numeric limit
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --limit must be a number, got: $LIMIT" >&2
  exit 1
fi

find_project_dir() {
  local target="$1"
  local normalized
  normalized=$(echo "$target" | sed 's|/|-|g; s|^-||')

  if [[ -d "${CLAUDE_DIR}/-${normalized}" ]]; then
    echo "${CLAUDE_DIR}/-${normalized}"
    return
  fi

  # Fuzzy match on last component
  local basename_part
  basename_part=$(basename "$target")
  local found
  found=$(find "$CLAUDE_DIR" -maxdepth 1 -type d -name "*${basename_part}*" 2>/dev/null | head -1)
  if [[ -n "$found" ]]; then
    echo "$found"
  fi
}

process_index() {
  local index_file="$1"
  [[ -f "$index_file" ]] || return 0

  ES_LIMIT="$LIMIT" ES_SINCE="$SINCE" ES_GREP="$GREP_PAT" ES_INDEX="$index_file" \
  python3 << 'PYEOF'
import json, sys, os

limit = int(os.environ.get('ES_LIMIT', '50'))
since = os.environ.get('ES_SINCE', '')
grep_pat = os.environ.get('ES_GREP', '').lower()
index_file = os.environ['ES_INDEX']

try:
    with open(index_file) as f:
        data = json.load(f)
except (json.JSONDecodeError, OSError) as e:
    print(f"ERROR: Failed to read {index_file}: {e}", file=sys.stderr)
    sys.exit(0)

entries = data.get('entries', [])
entries.sort(key=lambda e: e.get('created', ''), reverse=True)

count = 0
for e in entries:
    if count >= limit:
        break

    created = e.get('created', '')
    if since and created[:10] < since:
        continue

    summary = e.get('summary', '')
    prompt = e.get('firstPrompt', '')
    if grep_pat:
        haystack = (summary + ' ' + prompt).lower()
        if grep_pat not in haystack:
            continue

    if len(summary) > 80:
        summary = summary[:77] + '...'
    if len(prompt) > 100:
        prompt = prompt[:97] + '...'
    summary = summary.replace('\t', ' ').replace('\n', ' ')
    prompt = prompt.replace('\t', ' ').replace('\n', ' ')

    fields = [
        e.get('sessionId', ''),
        created,
        e.get('modified', ''),
        str(e.get('messageCount', 0)),
        e.get('gitBranch', ''),
        summary,
        prompt,
        e.get('projectPath', ''),
        e.get('fullPath', '')
    ]
    print('\t'.join(fields))
    count += 1
PYEOF
}

# Determine which dirs to scan
if [[ "$SCOPE" == "all" ]]; then
  for index in "${CLAUDE_DIR}"/*/sessions-index.json; do
    [[ -f "$index" ]] && process_index "$index"
  done | sort -t$'\t' -k2 -r | head -n "$LIMIT"
elif [[ "$SCOPE" == "current" ]]; then
  proj_dir=$(find_project_dir "$(pwd)")
  if [[ -z "$proj_dir" ]]; then
    echo "ERROR: No Claude session directory found for $(pwd)" >&2
    echo "Hint: try 'list-sessions.sh all' to search all projects" >&2
    exit 1
  fi
  process_index "${proj_dir}/sessions-index.json"
else
  proj_dir=$(find_project_dir "$SCOPE")
  if [[ -z "$proj_dir" ]]; then
    echo "ERROR: No Claude session directory found for $SCOPE" >&2
    exit 1
  fi
  process_index "${proj_dir}/sessions-index.json"
fi
