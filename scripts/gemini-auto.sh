#!/usr/bin/env bash
# Wrapper around the real `gemini` CLI: on quota exhaustion (429 /
# RESOURCE_EXHAUSTED), automatically rotate to the next GEMINI_API_KEY_N
# and retry the same call. Headless (-p) use only — an interactive session
# can't be transparently retried mid-conversation.
#
# Usage: same as `gemini`, e.g.:
#   gemini-auto.sh -p "..."
#   gemini-auto.sh -y -p "..."
#
# Session continuity across key rotation: pass --session-id <id> on the
# FIRST call of a multi-step chain. If a retry (after key rotation) needs
# to happen, this wrapper automatically rewrites --session-id <id> into
# --resume <id> for that retry — Gemini CLI errors ("already exists") if
# --session-id is reused as-is on a session that was already started.
# Without --session-id, each retry is just an independent one-shot call
# (nothing to preserve).
#
# Key rotation state persists across calls in /root/.gemini/.auto-key-index
# so repeated invocations keep advancing instead of always retrying key 1 first.

set -uo pipefail

REAL_GEMINI="/usr/local/bin/gemini"
ENV_FILE="/root/IWE/.exocortex.env"
KEY_SELECT="/root/IWE/DS-MCP/local-gateway/scripts/gemini-key-select.sh"
STATE_FILE="/root/.gemini/.auto-key-index"
OUT_FILE="$(mktemp)"
trap 'rm -f "$OUT_FILE"' EXIT

mapfile -t KEY_SLOTS < <(grep -o "^GEMINI_API_KEY[A-Z0-9_]*=" "$ENV_FILE" | sed 's/=$//')
NUM_KEYS=${#KEY_SLOTS[@]}
if [[ "$NUM_KEYS" -eq 0 ]]; then
  echo "Нет ни одного GEMINI_API_KEY* в $ENV_FILE" >&2
  exit 1
fi

start_idx=0
if [[ -f "$STATE_FILE" ]]; then
  start_idx=$(<"$STATE_FILE")
  [[ "$start_idx" =~ ^[0-9]+$ ]] || start_idx=0
  (( start_idx >= NUM_KEYS )) && start_idx=0
fi

is_quota_error() {
  grep -qiE "RESOURCE_EXHAUSTED|429|quota exceeded|exceeded your current quota" "$OUT_FILE"
}

# Detect a user-supplied --session-id <id> so we can rewrite it to
# --resume <id> on retries (session already exists after attempt 1).
ORIG_ARGS=("$@")
SESSION_ID=""
for ((i = 0; i < ${#ORIG_ARGS[@]}; i++)); do
  if [[ "${ORIG_ARGS[$i]}" == "--session-id" ]]; then
    SESSION_ID="${ORIG_ARGS[$((i + 1))]}"
    break
  fi
done

build_args() {
  local is_retry="$1"
  local -a out=()
  if [[ -n "$SESSION_ID" && "$is_retry" == "true" ]]; then
    local i=0
    while (( i < ${#ORIG_ARGS[@]} )); do
      if [[ "${ORIG_ARGS[$i]}" == "--session-id" ]]; then
        out+=("--resume" "$SESSION_ID")
        i=$((i + 2))
      else
        out+=("${ORIG_ARGS[$i]}")
        i=$((i + 1))
      fi
    done
  else
    out=("${ORIG_ARGS[@]}")
  fi
  printf '%s\n' "${out[@]}"
}

attempt=0
idx="$start_idx"
while (( attempt < NUM_KEYS )); do
  slot_num=$(( idx + 1 ))  # gemini-key-select.sh is 1-indexed
  "$KEY_SELECT" "$slot_num" > /dev/null

  is_retry="false"
  (( attempt > 0 )) && is_retry="true"
  mapfile -t CALL_ARGS < <(build_args "$is_retry")

  if [[ "$is_retry" == "true" && -n "$SESSION_ID" ]]; then
    echo "[gemini-auto] продолжаю сессию '$SESSION_ID' через --resume на новом ключе" >&2
  fi

  "$REAL_GEMINI" "${CALL_ARGS[@]}" > "$OUT_FILE" 2>&1
  exit_code=$?

  if [[ $exit_code -eq 0 ]] && ! is_quota_error; then
    cat "$OUT_FILE"
    echo "$idx" > "$STATE_FILE"
    exit 0
  fi

  if is_quota_error; then
    echo "[gemini-auto] ${KEY_SLOTS[$idx]} — квота исчерпана, переключаюсь на следующий ключ" >&2
    idx=$(( (idx + 1) % NUM_KEYS ))
    attempt=$(( attempt + 1 ))
    continue
  fi

  # Non-quota error — don't burn through keys, surface it immediately.
  cat "$OUT_FILE"
  exit "$exit_code"
done

echo "[gemini-auto] Квота исчерпана на всех $NUM_KEYS ключах" >&2
cat "$OUT_FILE"
exit 1
