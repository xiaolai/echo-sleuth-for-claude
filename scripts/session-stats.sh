#!/usr/bin/env bash
# session-stats.sh — Quick statistics for a .jsonl session file
# Usage: session-stats.sh <file.jsonl>
#
# Output: key=value pairs

set -euo pipefail

FILE="${1:?Usage: session-stats.sh <file.jsonl>}"

ES_FILE="$FILE" python3 << 'PYEOF'
import json, sys, os

file_path = os.environ['ES_FILE']

user_msgs = 0
asst_msgs = 0
tool_calls = 0
input_tokens = 0
output_tokens = 0
cache_read = 0
cache_create = 0
first_ts = ''
last_ts = ''
model = ''
branch = ''
slug = ''
files_edited = 0
summary_text = ''
compactions = 0
errors = 0

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
        ts = rec.get('timestamp', '')

        if ts:
            if not first_ts or ts < first_ts:
                first_ts = ts
            if ts > last_ts:
                last_ts = ts

        if not branch:
            branch = rec.get('gitBranch', '')
        if not slug:
            slug = rec.get('slug', '')

        if rtype == 'user':
            msg = rec.get('message', {})
            content = msg.get('content', '')
            if rec.get('isMeta') or rec.get('isCompactSummary'):
                continue
            # Skip tool_result messages
            if isinstance(content, list):
                has_tr = any(
                    isinstance(b, dict) and b.get('type') == 'tool_result'
                    for b in content
                )
                if has_tr:
                    continue
                # Count text-array user messages too
                has_text = any(
                    isinstance(b, dict) and b.get('type') == 'text'
                    for b in content
                )
                if has_text:
                    user_msgs += 1
            elif isinstance(content, str) and content.strip():
                user_msgs += 1

        elif rtype == 'assistant':
            msg = rec.get('message', {})
            m = msg.get('model', '')
            if m == '<synthetic>':
                continue
            asst_msgs += 1
            if not model and m:
                model = m

            usage = msg.get('usage', {})
            input_tokens += usage.get('input_tokens', 0)
            output_tokens += usage.get('output_tokens', 0)
            cache_read += usage.get('cache_read_input_tokens', 0)
            cache_create += usage.get('cache_creation_input_tokens', 0)

            content = msg.get('content', [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict):
                        if block.get('type') == 'tool_use':
                            tool_calls += 1

        elif rtype == 'summary':
            summary_text = rec.get('summary', '')

        elif rtype == 'file-history-snapshot':
            backups = rec.get('snapshot', {}).get('trackedFileBackups', {})
            fc = len(backups)
            if fc > files_edited:
                files_edited = fc

        elif rtype == 'system':
            st = rec.get('subtype', '')
            if st in ('compact_boundary', 'microcompact_boundary'):
                compactions += 1

# Count errors from tool results
try:
    with open(file_path) as f:
        for line in f:
            if '"is_error": true' in line or '"is_error":true' in line:
                errors += 1
except OSError:
    pass

print(f'slug={slug}')
print(f'model={model}')
print(f'branch={branch}')
print(f'started={first_ts}')
print(f'ended={last_ts}')
print(f'user_messages={user_msgs}')
print(f'assistant_messages={asst_msgs}')
print(f'tool_calls={tool_calls}')
print(f'files_edited={files_edited}')
print(f'errors={errors}')
print(f'input_tokens={input_tokens}')
print(f'output_tokens={output_tokens}')
print(f'cache_read_tokens={cache_read}')
print(f'cache_create_tokens={cache_create}')
print(f'total_tokens={input_tokens + output_tokens}')
print(f'compactions={compactions}')
if summary_text:
    print(f'summary={summary_text}')
PYEOF
