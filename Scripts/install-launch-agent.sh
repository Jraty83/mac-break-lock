#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/.build/App/BreakLock.app"
INSTALL_DIR="$HOME/Applications"
APP_DST="$INSTALL_DIR/BreakLock.app"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST="$PLIST_DIR/fi.breaklock.app.plist"

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build the app first: $ROOT/Scripts/build-app.sh" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$PLIST_DIR"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>fi.breaklock.app</string>
	<key>ProgramArguments</key>
	<array>
		<string>$APP_DST/Contents/MacOS/BreakLock</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>WorkingDirectory</key>
	<string>$HOME</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/fi.breaklock.app" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/fi.breaklock.app" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/fi.breaklock.app"

echo "✓ Installed to $APP_DST"
echo "✓ LaunchAgent loaded (starts at login, KeepAlive)"
echo
echo "Grant once in System Settings:"
echo "  • Notifications → BreakLock → Allow (banners/alerts)"
echo "  • Privacy & Security → Accessibility → enable BreakLock"
echo "  • Privacy & Security → Automation → BreakLock → System Events (if prompted)"
