#!/usr/bin/env bash
# elena-casey-enforcer.sh — SubagentStop
# Apres fin d'un subagent SEBASTIEN/REMI/MORGAN sur projet critique
# (ERP-AM, SITE-AM, Nelvo, CRM-ESC-PACK, APP-NELVO), verifie si ELENA
# et/ou CASEY ont deja ete invoques dans la session en parsant le
# transcript JSONL. Si non, injecte un rappel via additionalContext
# pour que BERNARD les spawne dans le round suivant.
#
# Reference : feedback_elena_casey_systematique.md
# - ELENA : tests sur le code modifie
# - CASEY : scan secu si nouvelle route/endpoint/input utilisateur
#
# Exit 0 = OK (avec ou sans rappel). Le hook ne bloque jamais.

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
CWD="${CLAUDE_PROJECT_DIR:-$(get_field cwd)}"
SUBAGENT_NAME=$(get_field subagent_type)
if [ -z "$SUBAGENT_NAME" ]; then
  SUBAGENT_NAME=$(get_field tool_input.subagent_type)
fi

# 1) Matcher : SEBASTIEN, REMI, MORGAN uniquement
case "$(echo "$SUBAGENT_NAME" | tr '[:upper:]' '[:lower:]')" in
  sebastien|remi|morgan) : ;;
  *) exit 0 ;;
esac

# 2) Projet critique ? (match sur cwd)
CRITICAL_REGEX="(ERP-AM|SITE-AM|[Nn]elvo|CRM-ESC-PACK|APP-NELVO)"
if ! echo "$CWD" | grep -qE "$CRITICAL_REGEX"; then
  exit 0
fi

# 3) ELENA / CASEY deja invoques dans la session ?
ELENA_SEEN=0
CASEY_SEEN=0

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Scan bounded: last 2 MB only (fast even on 20MB+ transcripts).
  # Grep-based prefilter avoids JSON parse on irrelevant lines.
  # `|| true` pour absorber les SIGPIPE (python peut break early).
  FLAGS=$(set +o pipefail; tail -c 2097152 "$TRANSCRIPT_PATH" 2>/dev/null \
    | grep -iE "elena|casey" 2>/dev/null \
    | python3 - <<'PY' 2>/dev/null || true
import sys, json
seen = {"elena": False, "casey": False}
for line in sys.stdin:
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
            st = node.get("subagent_type") or node.get("agent") or ""
            if isinstance(st, str):
                s = st.lower()
                if "elena" in s:
                    seen["elena"] = True
                if "casey" in s:
                    seen["casey"] = True
            for v in node.values():
                if isinstance(v, (dict, list)):
                    stack.append(v)
        elif isinstance(node, list):
            stack.extend(node)
    if seen["elena"] and seen["casey"]:
        break
print(("1" if seen["elena"] else "0") + ("1" if seen["casey"] else "0"))
PY
)
  case "${FLAGS:-00}" in
    11) ELENA_SEEN=1; CASEY_SEEN=1 ;;
    10) ELENA_SEEN=1 ;;
    01) CASEY_SEEN=1 ;;
    *)  : ;;
  esac
fi

# 4) Si les deux sont deja vus, rien a faire
if [ "$ELENA_SEEN" = "1" ] && [ "$CASEY_SEEN" = "1" ]; then
  exit 0
fi

# 5) Construire le message de rappel
MISSING=""
[ "$ELENA_SEEN" = "0" ] && MISSING="ELENA pour ecrire/executer les tests sur le code modifie"
if [ "$CASEY_SEEN" = "0" ]; then
  if [ -n "$MISSING" ]; then MISSING="$MISSING + "; fi
  MISSING="${MISSING}CASEY pour un scan secu rapide (nouvelles routes, endpoints, inputs utilisateur)"
fi

MSG="[elena-casey-enforcer] Rappel : le subagent ${SUBAGENT_NAME} vient de finir sur un projet critique. Avant de clore, delegue en parallele : ${MISSING}. Regle : feedback_elena_casey_systematique."

# 6) Emettre le contexte additionnel pour Claude (via additionalContext)
HOOK_MSG="$MSG" python3 -c "
import json, os
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SubagentStop',
        'additionalContext': os.environ.get('HOOK_MSG', '')
    }
}))
"

exit 0
