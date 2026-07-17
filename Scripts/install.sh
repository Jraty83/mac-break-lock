#!/bin/zsh
set -euo pipefail

# Install BreakLock like Hot:
#   • ~/Applications/BreakLock.app
#   • Open at Login via macOS Login Items (registered by the app)
#   • Menu bar icon (no Dock)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/.build/App/BreakLock.app"
INSTALL_DIR="$HOME/Applications"
APP_DST="$INSTALL_DIR/BreakLock.app"
LABEL="fi.breaklock.app"

echo "→ Building…"
"$ROOT/Scripts/build-app.sh"

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build failed: missing $APP_SRC" >&2
  exit 1
fi

# Stop old copies / legacy LaunchAgent from earlier installs.
pkill -f 'BreakLock.app/Contents/MacOS/BreakLock' 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
sleep 0.3

echo "→ Installing to $APP_DST"
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

if [[ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST" >/dev/null 2>&1 || true
fi

codesign --force --deep --sign - "$APP_DST" 2>/dev/null || true

echo "→ Launching (registers Open at Login like Hot)…"
open "$APP_DST"

echo
echo "✓ Installed: $APP_DST"
echo "✓ Menu bar: cup icon"
echo "✓ Open at Login: registered by the app → System Settings → General → Login Items"
echo
echo "Permissions (important — correct path):"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  → find BreakLock → turn the toggle ON"
echo
echo "  (The page named just “Accessibility” with VoiceOver/Zoom is a different screen.)"
echo
echo "Also: System Settings → Notifications → BreakLock → Allow"
echo
echo "Open anytime: Spotlight → BreakLock   or   open -a BreakLock"
