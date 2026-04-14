#!/usr/bin/env bash
set -e

LABEL="dev.artemmac.filesandbox"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"

# ── Node path ────────────────────────────────────────────────────────────────
NODE_PATH="$(which node 2>/dev/null || true)"

# nvm fallback — pick highest installed version
if [ -z "$NODE_PATH" ] && [ -d "$HOME/.nvm/versions/node" ]; then
  LATEST=$(ls "$HOME/.nvm/versions/node" | sort -V | tail -1)
  NODE_PATH="$HOME/.nvm/versions/node/$LATEST/bin/node"
fi

if [ -z "$NODE_PATH" ] || [ ! -f "$NODE_PATH" ]; then
  echo "Error: node not found. Ensure node is in PATH or nvm is installed."
  exit 1
fi

NODE_VERSION=$("$NODE_PATH" --version)
NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "Error: Node.js 20+ required for --env-file flag (found $NODE_VERSION)."
  exit 1
fi

echo "Using node: $NODE_PATH ($NODE_VERSION)"

# ── Preflight ────────────────────────────────────────────────────────────────
if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo "Warning: $PROJECT_DIR/.env not found — daemon will fail to start without it."
fi

mkdir -p "$LOG_DIR"

# ── Write plist ──────────────────────────────────────────────────────────────
cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE_PATH</string>
        <string>--env-file=.env</string>
        <string>src/index.ts</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <!-- Restart on crash, but not after clean launchctl stop -->
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/filesandbox.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/filesandbox.error.log</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

# ── Load ─────────────────────────────────────────────────────────────────────
# Unload first in case an old version is registered
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || \
  launchctl unload "$PLIST" 2>/dev/null || true

if launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  echo "Loaded via bootstrap (macOS 12+)"
elif launchctl load "$PLIST"; then
  echo "Loaded via launchctl load"
else
  echo "Warning: could not auto-load. Run manually:"
  echo "  launchctl load $PLIST"
fi

echo ""
echo "✓ Installed: $PLIST"
echo "  Logs:      $LOG_DIR/filesandbox.log"
echo "  Status:    launchctl list | grep $LABEL"
echo "  Stop:      launchctl stop $LABEL"
echo "  Remove:    bash scripts/uninstall-launchagent.sh"
