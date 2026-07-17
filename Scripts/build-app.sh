#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="BreakLock"
BUILD_DIR="$ROOT/.build"
APP_DIR="$BUILD_DIR/App/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "→ Building $APP_NAME (release)…"
swift build -c release --product "$APP_NAME"

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
BIN_DIR="$(dirname "$BIN")"
if [[ ! -x "$BIN" ]]; then
  echo "Binary not found: $BIN" >&2
  exit 1
fi

echo "→ Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN" "$MACOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

for lproj in "$ROOT/Sources/BreakLock/Resources/"*.lproj; do
  [[ -d "$lproj" ]] || continue
  cp -R "$lproj" "$RESOURCES/"
done

for bundle in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  cp -R "$bundle" "$RESOURCES/"
done

if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi

echo "✓ Built: $APP_DIR"
echo
echo "Run with:"
echo "  open \"$APP_DIR\""
echo
echo "Optional: install LaunchAgent so it starts at login:"
echo "  \"$ROOT/Scripts/install-launch-agent.sh\""
