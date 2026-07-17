#!/bin/zsh
set -euo pipefail

LABEL="fi.breaklock.app"
APP_DST="$HOME/Applications/BreakLock.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# Quit running app first so login-item unregister can run if we launch briefly — just kill.
pkill -f 'BreakLock.app/Contents/MacOS/BreakLock' 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$APP_DST"

echo "✓ Removed $APP_DST and any legacy LaunchAgent"
echo
echo "If BreakLock still appears under Login Items, remove it with − :"
echo "  System Settings → General → Login Items & Extensions → Open at Login"
echo
echo "Accessibility / Notifications rows can be removed manually in Privacy & Security."
