#!/usr/bin/env bash
# extract-tools.sh — Extract tool calls and their results from a .jsonl session
# Usage: extract-tools.sh <file.jsonl> [--tool NAME] [--errors-only] [--limit N]
#
# Output format (tab-separated):
#   TIMESTAMP  TOOL_NAME  STATUS  KEY_INPUT  RESULT_PREVIEW

set -euo pipefail

FILE="${1:?Usage: extract-tools.sh <file.jsonl> [--tool NAME] [--errors-only] [--limit N]}"
shift

TOOL_FILTER=""
ERRORS_ONLY=0
LIMIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL_FILTER="$2"; shift 2 ;;
    --errors-only) ERRORS_ONLY=1; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --limit must be a number" >&2
  exit 1
fi

ES_FILE="$FILE" ES_TOOL="$TOOL_FILTER" ES_ERRORS="$ERRORS_ONLY" ES_LIMIT="$LIMIT" \
python3 << 'PYEOF'
import json, sys, os

file_path = os.environ['ES_FILE']
tool_filter = os.environ.get('ES_TOOL', '')
errors_only = os.environ.get('ES_ERRORS', '0') == '1'
limit = int(os.environ.get('ES_LIMIT', '0'))

tool_calls = {}   # id -> (ts, name, key_input)
tool_order = []
tool_results = {}  # id -> (is_error, preview)

with open(file_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue

        rtype = rec.get('type', '')
        ts = rec.get('timestamp', '')[:19] if rec.get('timestamp') else ''
        msg = rec.get('message', {})
        content = msg.get('content', '')

        if rtype == 'assistant' and isinstance(content, list):
            for block in content:
                if not isinstance(block, dict) or block.get('type') != 'tool_use':
                    continue
                tid = block.get('id', '')
                name = block.get('name', '')
                inp = block.get('input', {})
                if not isinstance(inp, dict):
                    inp = {}

                if tool_filter and name != tool_filter:
                    continue

                key = ''
                if name in ('Read', 'Write', 'Edit', 'MultiEdit'):
                    key = inp.get('file_path', '')
                elif name == 'Bash':
                    key = inp.get('command', '')[:120].replace('\n', ' ')
                elif name in ('Grep', 'Glob'):
                    key = inp.get('pattern', '')
                elif name == 'Task':
                    key = inp.get('description', '')
                elif name == 'WebSearch':
                    key = inp.get('query', '')
                elif name == 'WebFetch':
                    key = inp.get('url', '')

                tool_calls[tid] = (ts, name, key)
                tool_order.append(tid)

        elif rtype == 'user' and isinstance(content, list):
            for block in content:
                if not isinstance(block, dict) or block.get('type') != 'tool_result':
                    continue
                tid = block.get('tool_use_id', '')
                is_error = block.get('is_error', False)
                rc = block.get('content', '')
                if isinstance(rc, list):
                    preview = ' '.join(
                        b.get('text', '')[:100]
                        for b in rc if isinstance(b, dict)
                    )
                elif isinstance(rc, str):
                    preview = rc[:150].replace('\n', ' ').replace('\t', ' ')
                else:
                    preview = ''
                tool_results[tid] = ('error' if is_error else 'ok', preview)

count = 0
for tid in tool_order:
    if tid not in tool_calls:
        continue
    ts, name, key = tool_calls[tid]
    status, preview = tool_results.get(tid, ('ok', '(no result captured)'))

    if errors_only and status != 'error':
        continue
    if limit > 0 and count >= limit:
        break

    print(f'{ts}\t{name}\t{status}\t{key}\t{preview}')
    count += 1
PYEOF
