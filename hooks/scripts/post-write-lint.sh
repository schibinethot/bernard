#!/usr/bin/env bash
# post-write-lint.sh — PostToolUse apres Write / Edit
# Lance eslint --fix sur les fichiers .ts/.tsx/.js modifies. Jamais bloquant.

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

EXT="${FILE_PATH##*.}"

case "$EXT" in
  ts|tsx|js|jsx|mjs|cjs)
    # Skip si pas de package.json pres du fichier (evite le cout d'un npx
    # resolve hors projet Node).
    DIR="$(dirname "$FILE_PATH")"
    FOUND_PKG=""
    while [ "$DIR" != "/" ] && [ "$DIR" != "." ] && [ -n "$DIR" ]; do
      if [ -f "$DIR/package.json" ]; then
        FOUND_PKG="$DIR"
        break
      fi
      DIR="$(dirname "$DIR")"
    done
    if [ -n "$FOUND_PKG" ] && command -v npx >/dev/null 2>&1; then
      # timeout 8s max pour eviter de geler le turn Claude
      ( cd "$FOUND_PKG" && timeout 8 npx --no-install eslint --fix "$FILE_PATH" ) 2>/dev/null || true
    fi
    ;;
  *)
    ;;
esac

# Ne jamais bloquer sur un lint
exit 0
