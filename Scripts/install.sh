#!/bin/zsh
set -euo pipefail

# Install BreakLock like a normal Mac menu-bar app (e.g. Hot):
#   • ~/Applications/BreakLock.app  → Finder / Spotlight / Launchpad
#   • LaunchAgent                   → starts at login, stays running

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/.build/App/BreakLock.app"
INSTALL_DIR="$HOME/Applications"
APP_DST="$INSTALL_DIR/BreakLock.app"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST="$PLIST_DIR/fi.breaklock.app.plist"
LABEL="fi.breaklock.app"

echo "→ Building…"
"$ROOT/Scripts/build-app.sh"

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build failed: missing $APP_SRC" >&2
  exit 1
fi

# Stop any previously running copy (build path or Applications).
pkill -f 'BreakLock.app/Contents/MacOS/BreakLock' 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
sleep 0.3

echo "→ Installing to $APP_DST"
mkdir -p "$INSTALL_DIR" "$PLIST_DIR"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

# Refresh Launch Services so it appears under Applications / Spotlight.
if [[ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST" >/dev/null 2>&1 || true
fi

codesign --force --deep --sign - "$APP_DST" 2>/dev/null || true

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
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
	<key>StandardOutPath</key>
	<string>$HOME/Library/Logs/BreakLock.out.log</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Logs/BreakLock.err.log</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo
echo "✓ Installed: $APP_DST"
echo "✓ Login item: LaunchAgent $LABEL (KeepAlive)"
echo "✓ Menu bar: cup icon (no Dock icon — same idea as Hot)"
echo
echo "Important — permissions bind to this install path:"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  → turn ON the toggle for BreakLock"
echo "  (remove any old BreakLock rows that point at .build/…)"
echo
echo "Also: System Settings → Notifications → BreakLock → Allow"
echo
echo "Open anytime: Spotlight → BreakLock   or   open -a BreakLock"
