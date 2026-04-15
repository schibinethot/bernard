#!/usr/bin/env bash
# branch-sync-reminder.sh — PostToolUse pour Bash
# Apres `git push origin main` sur un projet critique (ERP-AM, SITE-AM,
# APP-NELVO, CRM-ESC-PACK), rappelle de sync preprod <- main (feedback_branches_iso).
# Toujours non-bloquant (exit 0).

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Detection push vers main : couvre `git push origin main`, `git push origin HEAD:main`,
# `git push -u origin main`, etc. On reste simple.
if ! echo "$COMMAND" | grep -qE "git push[[:space:]].*([[:space:]]|:)main([[:space:]]|$)"; then
  exit 0
fi

# Detection du projet critique via git remote get-url origin.
# On teste aussi le pwd au cas ou l'utilisateur est dans un worktree/subdir.
CRITICAL_PROJECTS="erp-am|site-am|app-nelvo|crm-esc-pack"

REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
CWD=$(pwd)

MATCH=""
if echo "$REMOTE" | grep -qiE "$CRITICAL_PROJECTS"; then
  MATCH=$(echo "$REMOTE" | grep -oiE "$CRITICAL_PROJECTS" | head -1 | tr '[:upper:]' '[:lower:]')
elif echo "$CWD" | grep -qiE "$CRITICAL_PROJECTS"; then
  MATCH=$(echo "$CWD" | grep -oiE "$CRITICAL_PROJECTS" | head -1 | tr '[:upper:]' '[:lower:]')
fi

if [ -n "$MATCH" ]; then
  echo "[bernard-reminder] Push vers main detecte sur $MATCH."
  echo "[bernard-reminder] Rappel : merger main -> preprod pour maintenir iso (feedback_branches_iso)."
  echo "[bernard-reminder] Skill suggere : am-promote-branch-sync."
fi

exit 0
