#!/usr/bin/env bash
# Install (or remove) the launchd agent that starts the gateway daemon at login.
#
# Usage:
#   bash scripts/install-launchd.sh             # install
#   bash scripts/install-launchd.sh --uninstall # stop and remove
#
# A daemon that is already running by hand is never killed: peer agents hold
# their locks in that process, so restarting it would drop live locks. When one
# is found, the plist is written but not bootstrapped — launchd picks it up at
# the next login, by which time the hand-started daemon is gone anyway.
#
# Rollback is always one command: --uninstall.

set -euo pipefail

GATEWAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.iwe.local-gateway"
TEMPLATE="$GATEWAY_DIR/scripts/$LABEL.plist.template"
TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"
PID_FILE="$HOME/.iwe/gateway.pid"
DOMAIN="gui/$(id -u)"

if [[ "${1:-}" == "--uninstall" ]]; then
  if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    launchctl bootout "$DOMAIN/$LABEL"
    echo "[install-launchd] agent stopped"
  else
    echo "[install-launchd] agent was not loaded"
  fi
  rm -f "$TARGET"
  echo "[install-launchd] removed $TARGET"
  exit 0
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "[install-launchd] template not found: $TEMPLATE" >&2
  exit 1
fi

if [[ ! -f "$GATEWAY_DIR/dist/daemon.js" ]]; then
  echo "[install-launchd] daemon not built. Run: cd $GATEWAY_DIR && npm run build" >&2
  exit 1
fi

NODE_BIN="$(command -v node || true)"
if [[ -z "$NODE_BIN" ]]; then
  echo "[install-launchd] node not found in PATH" >&2
  exit 1
fi

# launchd starts with a minimal PATH, so the absolute node path goes into the
# plist. A node installed under a version manager resolves to a shim that does
# not exist outside an interactive shell — refuse it instead of writing a plist
# that fails silently at every login.
case "$NODE_BIN" in
  */.nvm/*|*/.asdf/*|*/shims/*)
    echo "[install-launchd] node resolves to a version-manager shim: $NODE_BIN" >&2
    echo "[install-launchd] launchd cannot use it. Install node system-wide (brew install node) and retry." >&2
    exit 1
    ;;
esac

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.iwe"

# An agent under this label may already exist and be supervising a daemon with
# settings this script knows nothing about (different log paths, different
# throttling). Overwriting it blind loses that configuration with no way back —
# launchd keeps the loaded copy in memory, not on disk. Back it up and stop.
if [[ -f "$TARGET" ]]; then
  BACKUP="$TARGET.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$TARGET" "$BACKUP"
  echo "[install-launchd] an agent is already installed at $TARGET" >&2
  echo "[install-launchd] backed it up to $BACKUP and made no changes." >&2
  echo "[install-launchd] review the difference, then either keep yours or run:" >&2
  echo "[install-launchd]   bash scripts/install-launchd.sh --uninstall && bash scripts/install-launchd.sh" >&2
  exit 1
fi

sed -e "s|__NODE_BIN__|$NODE_BIN|g" \
    -e "s|__GATEWAY_DIR__|$GATEWAY_DIR|g" \
    -e "s|__HOME__|$HOME|g" \
    "$TEMPLATE" > "$TARGET"

echo "[install-launchd] wrote $TARGET"
echo "[install-launchd] node: $NODE_BIN"
echo "[install-launchd] daemon: $GATEWAY_DIR/dist/daemon.js"

running_pid=""
if [[ -f "$PID_FILE" ]]; then
  candidate=$(cat "$PID_FILE")
  if kill -0 "$candidate" 2>/dev/null; then
    running_pid="$candidate"
  fi
fi

if [[ -n "$running_pid" ]]; then
  echo "[install-launchd] a daemon is already running (pid=$running_pid) — not starting a second one."
  echo "[install-launchd] it holds live locks for connected agents; killing it would drop them."
  echo "[install-launchd] autostart takes effect at the next login. To hand over now:"
  echo "[install-launchd]   kill $running_pid && launchctl bootstrap $DOMAIN $TARGET"
  exit 0
fi

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$TARGET"

# launchd spawns asynchronously; give it a moment before reading back state.
sleep 2

if ! launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
  echo "[install-launchd] agent failed to load" >&2
  exit 1
fi

PID=$(launchctl print "$DOMAIN/$LABEL" | awk '/^\tpid =/ {print $3}')
if [[ -z "$PID" ]]; then
  echo "[install-launchd] agent loaded but the daemon is not running; see ~/.iwe/gateway-launchd.log" >&2
  exit 1
fi

echo "[install-launchd] daemon running under launchd pid=$PID"
echo "[install-launchd] rollback: bash scripts/install-launchd.sh --uninstall"
