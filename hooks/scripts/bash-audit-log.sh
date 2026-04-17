#!/bin/bash
# bash-audit-log.sh — PostToolUse apres Bash
# Log la commande + exit code + duree dans le MCP agent-memory (via curl)
# Utile pour audit Phase 5 + analyse de patterns d'erreur sur les crons.
#
# Env requis :
#   AGENT_MEMORY_MCP_URL    default: https://agent-memory-mcp.fly.dev
#   AGENT_MEMORY_MCP_TOKEN  auth bearer (optionnel selon config serveur)
#
# Contraintes :
#   - non-bloquant (exit 0 systematique, meme si curl fail)
#   - timeout curl 3s max pour ne pas ralentir la session
#   - importance 0.2 (audit, pas decision)
#   - skip si env vars absentes (graceful degradation)

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# tool_response contient exit_code, duration_ms, stdout, stderr selon la version du CLI
RESPONSE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('tool_response', {}) or {}
    exit_code = r.get('exit_code', r.get('exitCode', 'unknown'))
    duration_ms = r.get('duration_ms', r.get('durationMs', 0))
    # stdout/stderr peut etre enorme, on tronque
    stderr = (r.get('stderr', '') or '')[:200]
    print(f'{exit_code}|{duration_ms}|{stderr}')
except Exception:
    print('unknown|0|')
" 2>/dev/null || echo "unknown|0|")

EXIT_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
DURATION_MS=$(echo "$RESPONSE" | cut -d'|' -f2)
STDERR_SHORT=$(echo "$RESPONSE" | cut -d'|' -f3-)

# Truncate command to 300 chars
CMD_SHORT=$(echo "$COMMAND" | head -c 300)

if [ -z "$CMD_SHORT" ]; then
  exit 0
fi

MCP_URL="${AGENT_MEMORY_MCP_URL:-https://agent-memory-mcp.fly.dev}"
MCP_TOKEN="${AGENT_MEMORY_MCP_TOKEN:-}"

# Skip si pas d'URL MCP configuree
if [ -z "$MCP_URL" ]; then
  exit 0
fi

# Skip si on est dans le plugin bernard lui-meme (bruit)
if echo "$CMD_SHORT" | grep -qE "(bernard-cc-plugin|\.claude/plugins)"; then
  exit 0
fi

# Construction du payload JSON (via python3 pour safety)
PAYLOAD=$(python3 -c "
import json, os
cmd = os.environ.get('CMD_SHORT', '')
code = os.environ.get('EXIT_CODE', 'unknown')
duration = os.environ.get('DURATION_MS', '0')
stderr = os.environ.get('STDERR_SHORT', '')
summary = f'bash exit={code} dur={duration}ms: {cmd[:200]}'
if stderr.strip():
    summary += f' | stderr: {stderr[:100]}'
print(json.dumps({
    'agent': 'LEO',
    'event_type': 'interaction',
    'summary': summary,
    'importance': 0.2,
    'metadata': {
        'source': 'bash-audit-log-hook',
        'command': cmd[:300],
        'exit_code': str(code),
        'duration_ms': str(duration)
    }
}))
" 2>/dev/null || echo "")

if [ -z "$PAYLOAD" ]; then
  exit 0
fi

# POST vers le MCP — best effort, timeout court. Ignore tout echec.
CURL_HEADERS=(-H "Content-Type: application/json")
if [ -n "$MCP_TOKEN" ]; then
  CURL_HEADERS+=(-H "Authorization: Bearer $MCP_TOKEN")
fi

CMD_SHORT="$CMD_SHORT" EXIT_CODE="$EXIT_CODE" DURATION_MS="$DURATION_MS" STDERR_SHORT="$STDERR_SHORT" \
  curl -sS -m 3 -X POST \
    "${CURL_HEADERS[@]}" \
    -d "$PAYLOAD" \
    "$MCP_URL/tools/store_memory" \
    >/dev/null 2>&1 \
  || true

exit 0
