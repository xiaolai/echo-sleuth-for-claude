#!/usr/bin/env bash
# git-sessions.sh — Cluster git commits into work sessions based on time gaps
# Usage: git-sessions.sh [repo-path] [--since "14 days ago"] [--gap 3600]
#
# A "session" is a burst of commits with less than --gap seconds between them.
# Output format:
#   --- SESSION N (YYYY-MM-DD HH:MM, X commits) ---
#     HASH  SUBJECT
#     HASH  SUBJECT
#   FILES: file1.ext, file2.ext, ...

set -euo pipefail

# Parse repo path: only consume first arg if it's not a flag
REPO="."
if [[ $# -gt 0 && "${1}" != --* ]]; then
  REPO="$1"
  shift
fi

SINCE="30 days ago"
GAP=3600

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --gap)   GAP="$2"; shift 2 ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Verify git is available and it's a git repo
if ! command -v git &>/dev/null; then
  echo "ERROR: git is not installed or not in PATH" >&2
  exit 1
fi

if ! git -C "$REPO" rev-parse --git-dir &>/dev/null; then
  echo "ERROR: $REPO is not a git repository" >&2
  exit 1
fi

# Use unit separator (0x1f) as delimiter to avoid conflicts with | in subjects
git -C "$REPO" log \
  --pretty=format:"%at%x1f%ai%x1f%h%x1f%s" \
  --name-only \
  --since="$SINCE" | awk -F$'\x1f' -v gap="$GAP" '
BEGIN { session = 0; commit_count = 0; files = "" }
NF >= 4 && $1 ~ /^[0-9]+/ {
  ts = $1
  date_str = $2
  hash = $3
  subject = $4

  if (session == 0 || (prev_ts - ts) > gap) {
    if (session > 0 && commit_count > 0) {
      if (files != "") printf "  FILES: %s\n", files
      printf "\n"
    }
    session++
    commit_count = 0
    files = ""
    printf "--- SESSION %d (%s, %s) ---\n", session, substr(date_str, 1, 16), "starting"
  }

  printf "  %s  %s\n", hash, subject
  commit_count++
  prev_ts = ts
  next
}
# File names (non-empty lines after commit header)
/^.+$/ {
  f = $0
  if (files == "") files = f
  else if (index(files, f) == 0) files = files ", " f
}
/^$/ { }
END {
  if (session > 0 && commit_count > 0 && files != "") {
    printf "  FILES: %s\n", files
  }
}
'
