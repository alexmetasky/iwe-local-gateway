#!/usr/bin/env bash
# Switch the default Gemini CLI model by rewriting /root/.gemini/settings.json.
# Usage: gemini-model-select.sh [lite|flash|<raw-model-name>|list]
#        (default: lite — highest free-tier daily quota)
#
# Note: Pro models (gemini-pro-latest etc.) return limit:0 on free-tier keys —
# not a temporary shortage, Google requires billing for Pro access. No "pro"
# preset here; pass the raw model name once billing is enabled if needed.

set -euo pipefail

SETTINGS="/root/.gemini/settings.json"

declare -A PRESETS=(
  [lite]="gemini-3.5-flash-lite"
  [flash]="gemini-3.5-flash"
)

CHOICE="${1:-lite}"

if [[ "$CHOICE" == "list" ]]; then
  echo "Пресеты:"
  for k in "${!PRESETS[@]}"; do
    echo "  $k -> ${PRESETS[$k]}"
  done
  echo ""
  echo "Текущая модель по умолчанию:"
  python3 -c "import json; print(json.load(open('$SETTINGS'))['model']['name'])"
  exit 0
fi

MODEL="${PRESETS[$CHOICE]:-$CHOICE}"

python3 - "$SETTINGS" "$MODEL" <<'PYEOF'
import json, sys
path, model = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data.setdefault("model", {})["name"] = model
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

echo "Модель по умолчанию: $MODEL"
