#!/usr/bin/env bash
# extract-messages.sh — Extract human-readable messages from a .jsonl session file
# Usage: extract-messages.sh <file.jsonl> [--role user|assistant|both] [--no-tools] [--limit N] [--thinking [LIMIT]]
#
# Output format:
#   === [ROLE] [TIMESTAMP] ===
#   message text
#   ---

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

FILE="${1:?Usage: extract-messages.sh <file.jsonl> [--role user|assistant|both] [--no-tools] [--limit N] [--thinking [LIMIT]]}"
shift

ROLE="both"
NO_TOOLS=0
LIMIT=0
THINKING_LIMIT=0  # 0 = full, -1 = hide (default: hide)
THINKING_LIMIT=-1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --no-tools) NO_TOOLS=1; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --thinking)
      # --thinking without a number means full; --thinking N means limit to N chars
      if [[ $# -gt 1 && "${2}" =~ ^[0-9]+$ ]]; then
        THINKING_LIMIT="$2"; shift 2
      else
        THINKING_LIMIT=0; shift
      fi
      ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$ROLE" != "both" && "$ROLE" != "user" && "$ROLE" != "assistant" ]]; then
  echo "ERROR: --role must be user, assistant, or both" >&2
  exit 1
fi
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --limit must be a number" >&2
  exit 1
fi

ES_FILE="$FILE" ES_ROLE="$ROLE" ES_NO_TOOLS="$NO_TOOLS" ES_LIMIT="$LIMIT" \
ES_THINKING="$THINKING_LIMIT" ES_SCRIPT_DIR="$SCRIPT_DIR" \
python3 << 'PYEOF'
import os, sys
sys.path.insert(0, os.environ["ES_SCRIPT_DIR"])
import echolib

file_path = os.environ["ES_FILE"]
role = os.environ.get("ES_ROLE", "both")
no_tools = os.environ.get("ES_NO_TOOLS", "0") == "1"
limit = int(os.environ.get("ES_LIMIT", "0"))
thinking_limit = int(os.environ.get("ES_THINKING", "-1"))

for msg in echolib.extract_messages(file_path, role=role, no_tools=no_tools,
                                      limit=limit, thinking_limit=thinking_limit):
    print("=== [{}] [{}] ===".format(msg["role"], msg["timestamp"]))
    print(msg["text"])
    print("---")
PYEOF
