#!/usr/bin/env bash
set -e
LABEL="dev.artemmac.filesandbox-es"
PLIST="/Library/LaunchDaemons/$LABEL.plist"

if [ "$EUID" -ne 0 ]; then
  echo "Error: must run as root: sudo bash scripts/uninstall-es-daemon.sh"
  exit 1
fi

launchctl bootout "system/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "✓ Uninstalled $LABEL"
