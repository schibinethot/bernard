#!/bin/bash
# pre-compact-snapshot.sh — PreCompact
# Avant la compaction/troncature du contexte, injecte un prompt pour que
# Claude sauvegarde via store_memory les decisions critiques des derniers
# tours (afin qu'elles survivent a la compaction).
#
# Non bloquant, exit 0 toujours. La compaction peut se faire immediatement
# apres — c'est juste un nudge pour eviter de perdre l'etat.
#
# Ref : feedback_memory_hygiene (max 3-5/session), donc on rappelle que
# ce snapshot compte dans le quota.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

# Recupere la raison de la compaction si fournie (auto vs manual)
TRIGGER=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('trigger', d.get('compact_trigger', 'unknown')))
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")

cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreCompact",
    "additionalContext": "Le contexte va etre compacte (trigger: ${TRIGGER}). Avant compaction : si des decisions importantes (arbitrages build/buy, fixes critiques, learnings sur un agent ou une stack) ont eu lieu dans les derniers tours et n'ont pas encore ete stockees, appelle mcp__agent-memory__store_memory (1-2 entrees max, importance >= 0.7, event_type='decision' ou 'learning'). Si rien de nouveau a sauver, ne stocke rien — la regle feedback_memory_hygiene (max 3-5/session) s'applique."
  }
}
JSON

exit 0
