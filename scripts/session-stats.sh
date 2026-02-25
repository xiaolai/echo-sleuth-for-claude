#!/usr/bin/env bash
# session-stats.sh — Quick statistics for a .jsonl session file (single-pass)
# Usage: session-stats.sh <file.jsonl>
#
# Output: key=value pairs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

FILE="${1:?Usage: session-stats.sh <file.jsonl>}"

ES_FILE="$FILE" ES_SCRIPT_DIR="$SCRIPT_DIR" \
python3 << 'PYEOF'
import os, sys
sys.path.insert(0, os.environ["ES_SCRIPT_DIR"])
import echolib

stats = echolib.session_stats(os.environ["ES_FILE"])

print("slug={}".format(stats["slug"]))
print("model={}".format(stats["model"]))
print("branch={}".format(stats["branch"]))
print("started={}".format(stats["started"]))
print("ended={}".format(stats["ended"]))
print("user_messages={}".format(stats["user_messages"]))
print("assistant_messages={}".format(stats["assistant_messages"]))
print("tool_calls={}".format(stats["tool_calls"]))
print("files_edited={}".format(stats["files_edited"]))
print("errors={}".format(stats["errors"]))
print("input_tokens={}".format(stats["input_tokens"]))
print("output_tokens={}".format(stats["output_tokens"]))
print("cache_read_tokens={}".format(stats["cache_read_tokens"]))
print("cache_create_tokens={}".format(stats["cache_create_tokens"]))
print("total_tokens={}".format(stats["total_tokens"]))
print("compactions={}".format(stats["compactions"]))
if stats["summary"]:
    print("summary={}".format(stats["summary"]))
PYEOF
