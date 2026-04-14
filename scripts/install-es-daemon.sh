#!/usr/bin/env bash
# Installs ESWatcher as a root LaunchDaemon.
# Requires: SIP disabled (dev) OR Apple ES entitlement (prod).
set -e

LABEL="dev.artemmac.filesandbox-es"
PLIST="/Library/LaunchDaemons/$LABEL.plist"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BINARY="$PROJECT_DIR/es-daemon/.build/release/ESWatcher"
WATCH_PATH="${WATCH_PATH:-$(grep '^WATCH_PATH=' "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2)}"

if [ ! -f "$BINARY" ]; then
  echo "Building ESWatcher..."
  bash "$PROJECT_DIR/es-daemon/build.sh"
fi

if [ -z "$WATCH_PATH" ]; then
  echo "Error: WATCH_PATH not set. Export it or add to .env."
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Error: must run as root: sudo bash scripts/install-es-daemon.sh"
  exit 1
fi

cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BINARY</string>
        <string>$WATCH_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/logs/es-watcher.log</string>
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/logs/es-watcher.log</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF

launchctl bootout "system/$LABEL" 2>/dev/null || true
launchctl bootstrap system "$PLIST"

echo "✓ ES daemon installed: $PLIST"
echo "  Watching: $WATCH_PATH"
echo "  Logs: $PROJECT_DIR/logs/es-watcher.log"
echo "  Stop: sudo launchctl stop $LABEL"
echo "  Remove: sudo bash scripts/uninstall-es-daemon.sh"
