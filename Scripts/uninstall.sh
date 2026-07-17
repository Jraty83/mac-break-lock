#!/bin/zsh
set -euo pipefail

LABEL="fi.breaklock.app"
APP_DST="$HOME/Applications/BreakLock.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f 'BreakLock.app/Contents/MacOS/BreakLock' 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$APP_DST"

echo "✓ Removed LaunchAgent and $APP_DST"
echo "  (Accessibility / Notifications entries may remain in System Settings — remove manually if desired.)"
