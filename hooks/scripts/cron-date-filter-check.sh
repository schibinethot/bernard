#!/usr/bin/env bash
# cron-date-filter-check.sh — PostToolUse apres Write / Edit
# Detecte les crons (TS/JS/SQL) qui ne filtrent pas par date (CRON_CREATED_AT
# / created_at > / date_joined >) pour eviter rattrapage historique email.
# Mode : warn non-bloquant via additionalContext. Exit 0 systematiquement.
# Ref : feedback_cron_historical_backfill.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")

if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Filtre extension : ts, tsx, js, mjs, cjs, sql
EXT="${FILE_PATH##*.}"
case "$EXT" in
  ts|tsx|js|mjs|cjs|sql)
    ;;
  *)
    exit 0
    ;;
esac

# Recupere le contenu ecrit/modifie depuis stdin (Write = content, Edit = new_string).
# Fallback : le fichier sur disque (Write/Edit sont en PostToolUse donc le fichier est deja ecrit).
CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
content = ti.get('content') or ti.get('new_string') or ''
print(content)
" 2>/dev/null || echo "")

if [ -z "$CONTENT" ] && [ -f "$FILE_PATH" ]; then
  CONTENT=$(cat "$FILE_PATH" 2>/dev/null || echo "")
fi

if [ -z "$CONTENT" ]; then
  exit 0
fi

# 1. Detecter si c'est un cron (TS/JS scheduler ou SQL cron).
IS_CRON=0
if echo "$CONTENT" | grep -qE "cron\.schedule\(|node-cron|CronJob|CRON_EXPRESSION|setInterval[^)]*cron|scheduler\.(schedule|add)"; then
  IS_CRON=1
fi

# SQL file : si pattern cron evoque dans nom de fichier ou commentaire en-tete
if [ "$IS_CRON" -eq 0 ] && [ "$EXT" = "sql" ]; then
  if echo "$FILE_PATH" | grep -qiE "(cron|scheduler|job|nurturing)"; then
    IS_CRON=1
  elif echo "$CONTENT" | head -20 | grep -qiE "cron|scheduler|nurturing"; then
    IS_CRON=1
  fi
fi

# Path heuristique pour TS/JS (crons/, scheduler/, jobs/)
if [ "$IS_CRON" -eq 0 ]; then
  if echo "$FILE_PATH" | grep -qE "(crons?/|scheduler/|jobs/)"; then
    IS_CRON=1
  fi
fi

if [ "$IS_CRON" -eq 0 ]; then
  exit 0
fi

# 2. Y a-t-il une requete SELECT / db.select dans ce fichier ?
HAS_SELECT=0
if echo "$CONTENT" | grep -qiE "SELECT[[:space:]].*FROM|db\.select\(|\.from\("; then
  HAS_SELECT=1
fi

if [ "$HAS_SELECT" -eq 0 ]; then
  exit 0
fi

# 3. Le filtre date est-il present ?
HAS_DATE_FILTER=0
if echo "$CONTENT" | grep -qE "CRON_CREATED_AT|cron_started|created_at[[:space:]]*>|date_joined[[:space:]]*>|gt\(.*createdAt|gt\(.*dateJoined"; then
  HAS_DATE_FILTER=1
fi

if [ "$HAS_DATE_FILTER" -eq 1 ]; then
  exit 0
fi

# 4. Warn via additionalContext (non-bloquant, exit 0).
MSG="Rappel feedback_cron_historical_backfill : le fichier ${FILE_PATH} semble etre un cron (scheduler/SELECT detecte) sans filtre date (created_at > CRON_CREATED_AT ou date_joined >). Risque : rattrapage historique des emails au premier run. Ajoute la constante CRON_CREATED_AT et filtre WHERE created_at > CRON_CREATED_AT."

# Echappage JSON via python3 pour safety.
python3 -c "
import json, sys
msg = sys.argv[1]
out = {
  'hookSpecificOutput': {
    'hookEventName': 'PostToolUse',
    'additionalContext': msg
  }
}
print(json.dumps(out))
" "$MSG"

exit 0
