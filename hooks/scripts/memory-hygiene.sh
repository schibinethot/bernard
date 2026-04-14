#!/usr/bin/env bash
# memory-hygiene.sh — SessionEnd
# Compte les store_memory pour l'agent BERNARD emises dans la session
# courante (parsing du transcript JSONL). Si > 5, injecte un warning
# pour rappeler la regle feedback_memory_hygiene (max 3-5/jour).
#
# Reference : feedback_memory_hygiene.md
# - Max 3-5 store_memory par session BERNARD
# - Seules decisions + learnings critiques, pas routings ni focus
#
# Hook best-effort : jamais bloquant, sort 0 en cas d'erreur.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

get_field() {
  local key="$1"
  echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    v = d
    for k in '$key'.split('.'):
        v = v.get(k, '') if isinstance(v, dict) else ''
    print(v if v else '')
except Exception:
    print('')
" 2>/dev/null || echo ""
}

TRANSCRIPT_PATH="${CLAUDE_TRANSCRIPT_PATH:-$(get_field transcript_path)}"

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

BERNARD_COUNT=$(python3 - "$TRANSCRIPT_PATH" <<'PY' 2>/dev/null
import sys, json
path = sys.argv[1]
count = 0
try:
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except Exception:
                continue
            stack = [row]
            while stack:
                node = stack.pop()
                if isinstance(node, dict):
                    name = node.get("name") or node.get("tool_name") or ""
                    if isinstance(name, str) and "store_memory" in name:
                        inp = node.get("input") or node.get("tool_input") or {}
                        agent = ""
                        if isinstance(inp, dict):
                            agent = str(inp.get("agent", "")).lower()
                        if agent == "bernard":
                            count += 1
                    for v in node.values():
                        if isinstance(v, (dict, list)):
                            stack.append(v)
                elif isinstance(node, list):
                    stack.extend(node)
except Exception:
    pass
print(count)
PY
)

BERNARD_COUNT="${BERNARD_COUNT:-0}"

if [ "${BERNARD_COUNT:-0}" -le 5 ] 2>/dev/null; then
  exit 0
fi

MSG="[memory-hygiene] BERNARD a emis ${BERNARD_COUNT} store_memory dans cette session (limite 3-5/jour, feedback_memory_hygiene). Verifier que chaque entree est une decision ou un learning critique, pas un routing ou un focus ephemere."

HOOK_MSG="$MSG" python3 -c "
import json, os
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionEnd',
        'additionalContext': os.environ.get('HOOK_MSG', '')
    }
}))
"

exit 0
