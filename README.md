# BreakLock

Customizable Menu bar app for breaks.

Morning prompt on weekdays, native Notification Center warnings (with No break) and automatic screen lock at the times you set.

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
| Open at Login | Registered automatically on first launch |

Grant the required permissions (Allow) when asked.

Uninstall:

```bash
./Scripts/uninstall.sh
```

## Localization

Follows macOS language order (`en` + `fi`).

## State

`~/Library/Application Support/BreakLock/state.json`
