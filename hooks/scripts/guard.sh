#!/usr/bin/env bash
# guard.sh — PreToolUse pour Bash
# Detecte les commandes dangereuses (git force push, rm -rf /, DROP TABLE,
# TRUNCATE, reset --hard) et demande reformulation.
# Exit 0 = OK, Exit 2 = reformulation demandee.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Ne checker que la partie avant -m pour git commit / git add
BASE_CMD=$(echo "$COMMAND" | python3 -c "
import sys
cmd = sys.stdin.read().strip()
if 'git commit' in cmd or 'git add' in cmd:
    print(cmd.split(' -m ')[0] if ' -m ' in cmd else cmd)
else:
    print(cmd)
" 2>/dev/null || echo "$COMMAND")

GIT_PATTERNS=("git push --force" "git push -f " "git reset --hard" "git checkout \.")
GIT_DESCRIPTIONS=(
  "git push --force (ecrasement distant)"
  "git push -f (ecrasement distant)"
  "git reset --hard (perte de changes)"
  "git checkout . (perte de changes)"
)

for i in "${!GIT_PATTERNS[@]}"; do
  if echo "$BASE_CMD" | grep -qiF "${GIT_PATTERNS[$i]}"; then
    echo "[bernard-guard] Commande dangereuse detectee : ${GIT_DESCRIPTIONS[$i]}. Reformule avec une approche plus sure." >&2
    exit 2
  fi
done

# Filesystem destructeur
if echo "$BASE_CMD" | grep -qiF "rm -rf /"; then
  echo "[bernard-guard] Commande dangereuse : rm -rf / (suppression racine). Reformule." >&2
  exit 2
fi

# SQL destructeur — seulement dans les contextes qui executent du SQL
if echo "$COMMAND" | grep -qiE "(psql|execute_sql|supabase sql)"; then
  for SQL_PATTERN in "DROP TABLE" "DROP DATABASE" "TRUNCATE"; do
    if echo "$COMMAND" | grep -qw "$SQL_PATTERN"; then
      echo "[bernard-guard] SQL dangereux : $SQL_PATTERN. Ajoute IF EXISTS / DELETE WHERE." >&2
      exit 2
    fi
  done
fi

exit 0
