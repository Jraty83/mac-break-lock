# BreakLock

Menu bar app for weekday breaks — same idea as [Hot](https://github.com/xs-labs/Hot): lives in the **menu bar**, not the Dock.

## Install

```bash
git clone https://github.com/Jraty83/mac-break-lock.git
cd mac-break-lock
chmod +x Scripts/*.sh
./Scripts/install.sh
```

| What | Where |
|------|--------|
| App | `~/Applications/BreakLock.app` (Applications / Spotlight) |
| Menu bar | Cup icon (top-right) |
| Open at Login | **System Settings → General → Login Items** (same list as Hot) |

### Permissions — correct paths

**Accessibility (screen lock)** — *not* the VoiceOver/Zoom page:

**System Settings → Privacy & Security → Accessibility** → enable **BreakLock**

**Notifications:**

**System Settings → Notifications → BreakLock** → Allow

### Login Items

You do **not** need to press **+** yourself. On launch the app registers as an Open at Login item (like Hot). It should appear in that list after install; if macOS asks for approval, allow it there.

Uninstall:

```bash
./Scripts/uninstall.sh
```

## Why permissions reset after rebuilds

macOS binds Accessibility to the app path/binary. Prefer the installed app only:

```bash
open -a BreakLock
```

## Localization

Follows macOS language order (`en` + `fi`).

## State

`~/Library/Application Support/BreakLock/state.json`
