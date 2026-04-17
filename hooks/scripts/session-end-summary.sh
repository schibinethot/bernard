#!/bin/bash
# session-end-summary.sh — SessionEnd
# Pousse un resume de la session dans MCP agent-memory via curl (direct).
# Complementaire a stop-auto-memory.sh (qui, lui, demande a Claude de
# faire store_memory intelligemment).
#
# Ce hook-ci garantit qu'au moins 1 trace audit existe cote MCP meme
# si Claude coupe sans avoir emis de store_memory. Il detecte si la
# session a produit des PRs/fixes (via git log recent) → event_type
# 'learning' sinon 'interaction'.
#
# Stub OTEL/Grafana : placeholder si $OTEL_EXPORTER_OTLP_ENDPOINT est
# defini, on log simplement vers stderr (sera complete en Phase 6).
#
# Non bloquant, exit 0 toujours.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

# Essaie de recuperer le cwd + le repertoire projet depuis le payload
CWD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('cwd', '') or d.get('workspace', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

if [ -z "$CWD" ]; then
  CWD=$(pwd)
fi

# Detection activite git : commits depuis 1h ?
EVENT_TYPE="interaction"
RECENT_COMMITS=""
if command -v git >/dev/null 2>&1 && [ -d "$CWD/.git" ]; then
  RECENT_COMMITS=$(cd "$CWD" && git log --since="1 hour ago" --oneline 2>/dev/null | head -5 || echo "")
  if [ -n "$RECENT_COMMITS" ]; then
    EVENT_TYPE="learning"
  fi
fi

# Recupere le nom du projet depuis le basename du cwd
PROJECT=$(basename "$CWD" 2>/dev/null || echo "unknown")

MCP_URL="${AGENT_MEMORY_MCP_URL:-https://agent-memory-mcp.fly.dev}"
MCP_TOKEN="${AGENT_MEMORY_MCP_TOKEN:-}"

if [ -z "$MCP_URL" ]; then
  exit 0
fi

# Construction payload
PAYLOAD=$(CWD="$CWD" PROJECT="$PROJECT" EVENT_TYPE="$EVENT_TYPE" RECENT_COMMITS="$RECENT_COMMITS" python3 -c "
import json, os
project = os.environ.get('PROJECT', 'unknown')
commits = os.environ.get('RECENT_COMMITS', '').strip()
event_type = os.environ.get('EVENT_TYPE', 'interaction')
cwd = os.environ.get('CWD', '')

if commits:
    summary = f'Session terminee sur {project}. Commits recents : {commits[:400]}'
    importance = 0.5
else:
    summary = f'Session terminee sur {project}. Pas de commits durant la session.'
    importance = 0.2

print(json.dumps({
    'agent': 'BERNARD',
    'event_type': event_type,
    'summary': summary,
    'importance': importance,
    'metadata': {
        'source': 'session-end-summary-hook',
        'project': project,
        'cwd': cwd,
        'commits_count': str(len(commits.split(chr(10))) if commits else 0)
    }
}))
" 2>/dev/null || echo "")

if [ -z "$PAYLOAD" ]; then
  exit 0
fi

CURL_HEADERS=(-H "Content-Type: application/json")
if [ -n "$MCP_TOKEN" ]; then
  CURL_HEADERS+=(-H "Authorization: Bearer $MCP_TOKEN")
fi

curl -sS -m 5 -X POST \
  "${CURL_HEADERS[@]}" \
  -d "$PAYLOAD" \
  "$MCP_URL/tools/store_memory" \
  >/dev/null 2>&1 \
  || true

# Stub OTEL (Phase 6)
if [ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]; then
  echo "[session-end-summary] stub OTEL: endpoint=$OTEL_EXPORTER_OTLP_ENDPOINT project=$PROJECT event=$EVENT_TYPE (export non-implemente, Phase 6)" >&2
fi

exit 0
