#!/usr/bin/env bash
# extract-files-changed.sh — List all files edited during a session
# Usage: extract-files-changed.sh <file.jsonl> [--with-versions]
#
# Output format:
#   FILE_PATH  [VERSION_COUNT]

set -euo pipefail

FILE="${1:?Usage: extract-files-changed.sh <file.jsonl> [--with-versions]}"
WITH_VERSIONS=0
[[ "${2:-}" == "--with-versions" ]] && WITH_VERSIONS=1

# Get the last file-history-snapshot line (|| true prevents exit on no match)
last_snapshot=$(grep '"file-history-snapshot"' "$FILE" || true)
last_snapshot=$(echo "$last_snapshot" | tail -1)

if [[ -z "$last_snapshot" ]]; then
  echo "(no files changed in this session)" >&2
  exit 0
fi

ES_VERSIONS="$WITH_VERSIONS" ES_SNAPSHOT="$last_snapshot" python3 << 'PYEOF'
import json, sys, os

with_ver = os.environ.get('ES_VERSIONS', '0') == '1'
line = os.environ.get('ES_SNAPSHOT', '').strip()
if not line:
    sys.exit(0)
try:
    rec = json.loads(line)
except json.JSONDecodeError as e:
    print(f"ERROR: Malformed JSON in snapshot: {e}", file=sys.stderr)
    sys.exit(1)

backups = rec.get('snapshot', {}).get('trackedFileBackups', {})
for path, info in sorted(backups.items()):
    ver = info.get('version', 1)
    if with_ver:
        print(f'{path}\t{ver}')
    else:
        print(path)
PYEOF
