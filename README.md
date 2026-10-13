# CopyHero

A small macOS clipboard manager that lives in the menu bar.

- Keeps your **last 20 copies** (text and images). Anything you copy with ⌘C (or Edit › Copy) is added.
- **⌃⇧V** (Ctrl+Shift+V) opens the history next to your mouse.
  - Hover a row to see a full preview beside the list.
  - Click a row, press **↩**, or press **1–9** to paste it into the app you were using.
  - **↑/↓** to move, **esc** to close.
  - **Clear History** button at the bottom wipes everything.
- **Private by design:** history is in memory only. No files written, no network code. Quitting or restarting clears it. Copies marked as concealed (password managers) are skipped.
- **Starts at login** automatically.

## Install

Requires macOS 13+ and Xcode Command Line Tools.

```sh
./scripts/install.sh
```

This builds the app, copies it to `~/Applications/CopyHero.app`, launches it, and registers it as a login item.

### Auto-paste permission

To type ⌘V into the app for you, CopyHero needs **Accessibility** access
(System Settings › Privacy & Security › Accessibility). macOS asks on first launch.
Without it, picking an item still puts it on your clipboard; just press ⌘V yourself.

The app is ad-hoc signed, so after a **rebuild** macOS may treat it as a new app. If auto-paste
stops working, remove CopyHero from the Accessibility list and add it again.

## Uninstall

```sh
./scripts/uninstall.sh
```

## Development

```sh
./scripts/build.sh      # produces build/CopyHero.app
```

Source is in `Sources/CopyHero/`:

| File | Purpose |
|---|---|
| `ClipboardHistory.swift` | In-memory history + pasteboard polling |
| `HistoryPanel.swift` | The ⌃⇧V popup and the hover preview |
| `HotKey.swift` | Global hotkey (Carbon) |
| `Paster.swift` | Writes to the clipboard and sends ⌘V |
| `AppDelegate.swift` | Menu bar item, login item |
