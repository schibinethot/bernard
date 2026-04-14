#!/usr/bin/env bash
# stop-auto-memory.sh — SessionEnd
# Emet un payload JSON pour demander a Claude Code de memoriser les
# decisions et learnings significatifs de la session via MCP
# agent-memory (outil store_memory).
#
# Le hook doit rester rapide (< 200ms) et resilient : si le MCP est
# indisponible, le prompt est simplement ignore cote Claude.

set -euo pipefail

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionEnd",
    "additionalContext": "Fin de session. Si des decisions ou learnings significatifs ont eu lieu, stocke-les via l'outil MCP mcp__agent-memory__store_memory (agent = agent actif, event_type = 'learning' ou 'decision', importance entre 0.5 et 1.0). Si rien de significatif, ne stocke rien. Si le MCP echoue, ignore silencieusement."
  }
}
JSON

exit 0
