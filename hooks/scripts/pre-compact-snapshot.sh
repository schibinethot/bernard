#!/bin/bash
# pre-compact-snapshot.sh — PreCompact
# Avant la compaction/troncature du contexte, injecte un prompt pour que
# Claude sauvegarde via store_memory les decisions critiques des derniers
# tours (afin qu'elles survivent a la compaction).
#
# Effort-aware (Claude Code v2.1.128+) : lit $CLAUDE_EFFORT pour adapter
# la quantite suggeree (xhigh/max = 1-3 entrees, high/medium = 1-2, low = 0-1).
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

# Effort-aware quota (v2.1.128+ : les hooks voient $CLAUDE_EFFORT)
EFFORT="${CLAUDE_EFFORT:-medium}"
case "$EFFORT" in
  max|xhigh) QUOTA="1-3 entrees" ;;
  low) QUOTA="0-1 entree" ;;
  *) QUOTA="1-2 entrees" ;;
esac

EFFORT="$EFFORT" QUOTA="$QUOTA" TRIGGER="$TRIGGER" python3 -c "
import json, os
out = {
  'hookSpecificOutput': {
    'hookEventName': 'PreCompact',
    'additionalContext': (
      f\"Le contexte va etre compacte (trigger: {os.environ['TRIGGER']}, effort: {os.environ['EFFORT']}). \"
      f\"Avant compaction : si des decisions importantes (arbitrages build/buy, fixes critiques, learnings sur un \"
      f\"agent ou une stack) ont eu lieu dans les derniers tours et n'ont pas encore ete stockees, appelle \"
      f\"mcp__agent-memory__store_memory ({os.environ['QUOTA']} max, importance >= 0.7, event_type='decision' ou \"
      f\"'learning'). Si rien de nouveau a sauver, ne stocke rien — la regle feedback_memory_hygiene \"
      f\"(max 3-5/session) s'applique.\"
    )
  }
}
print(json.dumps(out))
"

exit 0
