# BreakLock

Lightweight macOS menu bar app for weekday breaks: morning prompt, native Notification Center warning with an action button, and automatic screen lock (same as Control+Command+Q).

UI language follows **macOS preferred languages** (`en` + `fi` shipped). With English first (e.g. U.S.), the app shows English.

## Features

1. **Weekdays after 08:00** (or first unlock after that) — morning prompt
2. **No breaks today** — skip until next weekday
3. **Vacation mode** — mute until a chosen date
4. **Set break times** — add times one by one, then confirm
5. **5 minutes before** — native banner with **No break**
6. **At break time** — locks the screen; unlock normally with password / Touch ID

## Requirements

- macOS 15+
- Apple Command Line Tools (`swift`)
- Permissions: **Notifications**, **Accessibility** (prompted on first launch)

## Build & run

```bash
cd ~/mac-break-lock
chmod +x Scripts/*.sh
./Scripts/build-app.sh
open .build/App/BreakLock.app
```

### After Quit — how to start again

BreakLock does not live in the Dock (menu bar only). After **Quit BreakLock**:

```bash
open ~/mac-break-lock/.build/App/BreakLock.app
```

Or Spotlight → type `BreakLock` if you installed it to `~/Applications` via:

```bash
./Scripts/install-launch-agent.sh
```

That also starts BreakLock at login (`KeepAlive`).

## Localization

- `Sources/BreakLock/Resources/en.lproj/Localizable.strings`
- `Sources/BreakLock/Resources/fi.lproj/Localizable.strings`

Language = system order (System Settings → General → Language & Region).

## State

`~/Library/Application Support/BreakLock/state.json`
