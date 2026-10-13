#!/bin/bash
# Removes the login item, quits CopyHero, and deletes the app.
set -euo pipefail

DEST="$HOME/Applications/CopyHero.app"
if [ -x "$DEST/Contents/MacOS/CopyHero" ]; then
    "$DEST/Contents/MacOS/CopyHero" --unregister-login || true
fi
pkill -x CopyHero 2>/dev/null || true
rm -rf "$DEST"
tccutil reset Accessibility com.kylar.copyhero >/dev/null 2>&1 || true
echo "CopyHero uninstalled."
