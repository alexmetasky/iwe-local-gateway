#!/usr/bin/env bash
# Switch which GEMINI_API_KEY the CLI uses by rewriting ~/.gemini/.env.
# Keys are read from /root/IWE/.exocortex.env: GEMINI_API_KEY, GEMINI_API_KEY_2, GEMINI_API_KEY_3, ...
# Usage: gemini-key-select.sh [N]   (default: 1, i.e. GEMINI_API_KEY)
#        gemini-key-select.sh list  (show which key slots exist, no values printed)

set -euo pipefail

ENV_FILE="/root/IWE/.exocortex.env"
TARGET="/root/.gemini/.env"

if [[ "${1:-1}" == "list" ]]; then
  echo "Доступные слоты ключей в $ENV_FILE:"
  grep -o "^GEMINI_API_KEY[A-Z0-9_]*=" "$ENV_FILE" | sed 's/=$//'
  exit 0
fi

N="${1:-1}"
if [[ "$N" == "1" ]]; then
  VAR="GEMINI_API_KEY"
else
  VAR="GEMINI_API_KEY_${N}"
fi

VALUE=$(awk -F= -v var="$VAR" '$1==var{print substr($0, index($0,"=")+1); found=1} END{if(!found) exit 1}' "$ENV_FILE") \
  || { echo "Ключ $VAR не найден в $ENV_FILE" >&2; exit 1; }

if [[ -z "$VALUE" ]]; then
  echo "Ключ $VAR пустой в $ENV_FILE" >&2
  exit 1
fi

printf "GEMINI_API_KEY=%s\n" "$VALUE" > "$TARGET"
chmod 600 "$TARGET"
echo "Активен ключ: $VAR (записан в $TARGET)"
