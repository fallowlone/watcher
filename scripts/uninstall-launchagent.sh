#!/usr/bin/env bash
set -e

LABEL="dev.artemmac.filesandbox"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || \
  launchctl unload "$PLIST" 2>/dev/null || true

rm -f "$PLIST"

echo "✓ Uninstalled $LABEL"
