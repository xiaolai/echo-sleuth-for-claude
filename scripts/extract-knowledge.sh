#!/usr/bin/env bash
# extract-knowledge.sh — Two-pass knowledge extraction from a session
# Usage: bash extract-knowledge.sh <session-jsonl-path>
#
# Runs extract_tools() and extract_messages() to identify extractable items.
# Output: JSON array of candidate items.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_PATH="${1:?Usage: extract-knowledge.sh <session.jsonl>}"

python3 - "$SESSION_PATH" "$SCRIPT_DIR" <<'PYEOF'
import os, sys, json, re
session_path = sys.argv[1]
sys.path.insert(0, sys.argv[2])
import echolib

items = []

# Pass 1: Tool calls — find AskUserQuestion decisions and errors
for tool in echolib.extract_tools(session_path):
    if tool["name"] == "AskUserQuestion":
        items.append({
            "category": "decision",
            "content": "Question: %s | Answer: %s" % (
                tool.get("key_input", "")[:200],
                tool.get("result_preview", "")[:200]
            ),
            "timestamp": tool.get("timestamp", ""),
            "suggested_destination": "memory",
            "suggested_type": "project",
        })
    elif tool.get("status") == "error":
        items.append({
            "category": "lesson",
            "content": "Tool %s failed: %s" % (
                tool["name"],
                tool.get("result_preview", "")[:200]
            ),
            "timestamp": tool.get("timestamp", ""),
            "suggested_destination": "skip",
            "suggested_type": None,
        })

# Pass 2: Messages — find corrections, patterns, references
correction_patterns = re.compile(
    r"\b(no[,.]?\s+(?:don'?t|not|stop|wrong|instead))|"
    r"\b(don'?t\s+\w+)|"
    r"\b(stop\s+doing)|"
    r"\b(that'?s\s+(?:wrong|incorrect|not right))",
    re.IGNORECASE
)
approval_patterns = re.compile(
    r"\b(perfect|exactly|great|yes[,.]?\s+(?:that'?s|keep|do it)|works|looks good|nice)",
    re.IGNORECASE
)
imperative_patterns = re.compile(
    r"\b(always|never|must|do not|don'?t ever|every time|make sure)",
    re.IGNORECASE
)
url_pattern = re.compile(r"https?://[^\s\)\"'>]+")

value_patterns = re.compile(
    r"\b(\w+\s+(?:is|are)\s+(?:better|more important|more valuable|preferable)\s+(?:than|over|to)\s+)|"
    r"\b(prefer\s+\w+\s+(?:over|to|instead of)\s+)|"
    r"\b(prioritize\s+\w+\s+over\s+)|"
    r"\b(\w+\s+(?:matters?|trumps?|outweighs?|beats?)\s+(?:more than\s+)?)|"
    r"\b(choose\s+\w+\s+over\s+)|"
    r"\b((?:the )?most (?:important|valuable|useful|durable)\s+(?:\w+\s+)?(?:is|are)\s+)|"
    r"\b(rather\s+\w+\s+than\s+)|"
    r"\b(\w+\s+>\s+\w+)",
    re.IGNORECASE
)

prev_assistant_text = ""
for msg in echolib.extract_messages(session_path, role="both"):
    text = msg.get("text", "")
    if not text or len(text) < 5:
        if msg.get("role") == "assistant":
            prev_assistant_text = text or ""
        continue

    if msg.get("role") == "assistant":
        prev_assistant_text = text[:500]
        continue

    # User messages below
    if value_patterns.search(text):
        items.append({
            "category": "value",
            "content": text[:300],
            "timestamp": msg.get("timestamp", ""),
            "suggested_destination": "memory",
            "suggested_type": "value",
        })

    if correction_patterns.search(text):
        dest = "claude_md" if imperative_patterns.search(text) else "memory"
        items.append({
            "category": "correction",
            "content": text[:300],
            "timestamp": msg.get("timestamp", ""),
            "suggested_destination": dest,
            "suggested_type": "feedback",
        })

    if approval_patterns.search(text) and prev_assistant_text:
        items.append({
            "category": "pattern",
            "content": "Approach approved: %s" % prev_assistant_text[:200],
            "timestamp": msg.get("timestamp", ""),
            "suggested_destination": "memory",
            "suggested_type": "feedback",
        })

    for url in url_pattern.findall(text):
        items.append({
            "category": "reference",
            "content": "URL mentioned: %s" % url,
            "timestamp": msg.get("timestamp", ""),
            "suggested_destination": "memory",
            "suggested_type": "reference",
        })

# Deduplicate by content prefix
seen = set()
unique_items = []
for item in items:
    key = item["content"][:80]
    if key not in seen:
        seen.add(key)
        unique_items.append(item)

json.dump(unique_items, sys.stdout, indent=2)
PYEOF
