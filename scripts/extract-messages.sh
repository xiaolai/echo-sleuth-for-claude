#!/usr/bin/env bash
# extract-messages.sh — Extract human-readable messages from a .jsonl session file
# Usage: extract-messages.sh <file.jsonl> [--role user|assistant|both] [--no-tools] [--limit N] [--thinking]
#
# Output format:
#   === [ROLE] [TIMESTAMP] ===
#   message text
#   ---

set -euo pipefail

FILE="${1:?Usage: extract-messages.sh <file.jsonl> [--role user|assistant|both] [--no-tools] [--limit N] [--thinking]}"
shift

ROLE="both"
NO_TOOLS=0
LIMIT=0
SHOW_THINKING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --no-tools) NO_TOOLS=1; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --thinking) SHOW_THINKING=1; shift ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate inputs
if [[ "$ROLE" != "both" && "$ROLE" != "user" && "$ROLE" != "assistant" ]]; then
  echo "ERROR: --role must be user, assistant, or both" >&2
  exit 1
fi
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --limit must be a number" >&2
  exit 1
fi

ES_FILE="$FILE" ES_ROLE="$ROLE" ES_NO_TOOLS="$NO_TOOLS" ES_LIMIT="$LIMIT" ES_THINKING="$SHOW_THINKING" \
python3 << 'PYEOF'
import json, sys, os

file_path = os.environ['ES_FILE']
role_filter = os.environ.get('ES_ROLE', 'both')
no_tools = os.environ.get('ES_NO_TOOLS', '0') == '1'
limit = int(os.environ.get('ES_LIMIT', '0'))
show_thinking = os.environ.get('ES_THINKING', '0') == '1'

count = 0
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
        if rtype not in ('user', 'assistant'):
            continue
        if role_filter != 'both' and role_filter != rtype:
            continue

        ts = rec.get('timestamp', '')
        msg = rec.get('message', {})
        content = msg.get('content', '')

        if rtype == 'user':
            if rec.get('isMeta'):
                continue
            if rec.get('isCompactSummary'):
                continue

            if isinstance(content, str):
                text = content.strip()
                if not text or text.startswith('<system-reminder>'):
                    continue
                if limit > 0 and count >= limit:
                    sys.exit(0)
                print(f'=== [USER] [{ts}] ===')
                print(text)
                print('---')
                count += 1
            elif isinstance(content, list):
                has_tool_result = any(
                    isinstance(b, dict) and b.get('type') == 'tool_result'
                    for b in content
                )
                if has_tool_result:
                    continue
                texts = [
                    b.get('text', '')
                    for b in content
                    if isinstance(b, dict) and b.get('type') == 'text'
                ]
                text = '\n'.join(t for t in texts if t).strip()
                if not text or text.startswith('<system-reminder>') or text.startswith('[Request interrupted'):
                    continue
                if limit > 0 and count >= limit:
                    sys.exit(0)
                print(f'=== [USER] [{ts}] ===')
                print(text)
                print('---')
                count += 1

        elif rtype == 'assistant':
            model = msg.get('model', '')
            if model == '<synthetic>':
                continue

            if not isinstance(content, list):
                continue

            parts = []
            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get('type', '')
                if btype == 'text':
                    t = block.get('text', '').strip()
                    if t:
                        parts.append(t)
                elif btype == 'thinking' and show_thinking:
                    t = block.get('thinking', '')[:500].strip()
                    if t:
                        parts.append(f'[THINKING] {t}')
                elif btype == 'tool_use' and not no_tools:
                    name = block.get('name', '?')
                    inp = block.get('input', {})
                    if not isinstance(inp, dict):
                        inp = {}
                    key = ''
                    if name in ('Read', 'Write', 'Edit', 'MultiEdit'):
                        key = inp.get('file_path', '')
                    elif name == 'Bash':
                        key = inp.get('command', '')[:80]
                    elif name in ('Grep', 'Glob'):
                        key = inp.get('pattern', '')
                    elif name == 'Task':
                        key = inp.get('description', '')
                    elif name == 'WebSearch':
                        key = inp.get('query', '')
                    if key:
                        parts.append(f'[TOOL: {name}] {key}')
                    else:
                        parts.append(f'[TOOL: {name}]')

            if not parts:
                continue
            if limit > 0 and count >= limit:
                sys.exit(0)
            print(f'=== [ASSISTANT] [{ts}] ===')
            print('\n'.join(parts))
            print('---')
            count += 1
PYEOF
