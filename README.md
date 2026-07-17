# BreakLock

Menu bar app for weekday breaks — same idea as apps like [Hot](https://github.com/xs-labs/Hot): lives in the **menu bar**, not the Dock.

- Morning prompt on weekdays
- Native Notification Center warning (+ **No break**)
- Locks the screen at break time (Control+Command+Q equivalent)
- UI language follows macOS (`en` + `fi`)

## Install (recommended)

From the repo:

```bash
git clone https://github.com/Jraty83/mac-break-lock.git
cd mac-break-lock
chmod +x Scripts/*.sh
./Scripts/install.sh
```

What that does:

| Step | Result |
|------|--------|
| Build | `.build/App/BreakLock.app` |
| Copy | `~/Applications/BreakLock.app` → shows under **Applications** / Spotlight / Launchpad |
| LaunchAgent | Starts at **login**, stays running (`KeepAlive`) |
| Menu bar | Cup icon in the top-right status area (like Hot’s flame) |

After install:

1. **System Settings → Privacy & Security → Accessibility** → turn **ON** BreakLock  
   (If you previously allowed a `.build/…` copy, remove that row and enable the one for `~/Applications/BreakLock.app`.)
2. **System Settings → Notifications → BreakLock** → Allow

Uninstall:

```bash
./Scripts/uninstall.sh
```

## Why permissions were asked again

macOS ties Accessibility to the **exact app binary/path**. Rebuilding, moving, or running from `.build/` vs `~/Applications/` looks like a **new app**, so TCC may show BreakLock again with the toggle **off**. Always run the installed copy:

```bash
open -a BreakLock
```

## After Quit

With the LaunchAgent installed, macOS restarts BreakLock automatically (`KeepAlive`).  
Without it:

```bash
open -a BreakLock
# or
open ~/Applications/BreakLock.app
```

## Develop / rebuild only

```bash
./Scripts/build-app.sh
open .build/App/BreakLock.app   # temporary — prefer ./Scripts/install.sh for daily use
```

## Localization

- `Sources/BreakLock/Resources/en.lproj/Localizable.strings`
- `Sources/BreakLock/Resources/fi.lproj/Localizable.strings`

## State

`~/Library/Application Support/BreakLock/state.json`
