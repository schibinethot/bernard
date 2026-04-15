#!/usr/bin/env bash
# worktree-gitignore-check.sh — PreToolUse pour Bash
# Bloque les `git add .worktrees/...` et les `git add .`/`git add -A` dans un
# repo ou `.worktrees/` existe sans etre ignore.
# Exit 0 = OK, Exit 2 = bloquant (reformulation demandee).

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

# Detection directe : git add ... .worktrees ...
# On exclut `git add -f` (intention explicite de l'utilisateur, on laisse passer
# avec un warn seulement).
if echo "$COMMAND" | grep -qE "git add[[:space:]]+-f[[:space:]].*\.worktrees"; then
  echo "[bernard-guard] git add -f .worktrees detecte (force). Intention explicite, passe mais attention : .worktrees/ doit rester ignore." >&2
  exit 0
fi

if echo "$COMMAND" | grep -qE "git add[[:space:]]+[^-].*\.worktrees|git add[[:space:]]+\.worktrees"; then
  echo "[bernard-guard] Tentative d'ajout de .worktrees/ au git. Ce dossier doit etre dans .gitignore, pas add. Abort." >&2
  exit 2
fi

# Cas indirect : git add . / git add -A / git add --all dans un repo ou .worktrees/ existe
# mais n'est pas dans .gitignore.
if echo "$COMMAND" | grep -qE "git add[[:space:]]+(\.|-A|--all)([[:space:]]|$)"; then
  if [ -d ".worktrees" ]; then
    if [ ! -f ".gitignore" ] || ! grep -qE "^\.worktrees(/|$)" .gitignore 2>/dev/null; then
      echo "[bernard-guard] .worktrees/ existe mais pas dans .gitignore. Ajoute \".worktrees/\" a .gitignore avant git add . Abort." >&2
      exit 2
    fi
  fi
fi

exit 0
