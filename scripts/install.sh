#!/bin/bash
# Builds and installs CopyHero to ~/Applications, then launches it.
# On launch it registers itself as a login item so it starts with your Mac.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

DEST="$HOME/Applications/CopyHero.app"
pkill -x CopyHero 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R build/CopyHero.app "$DEST"
open "$DEST"
echo "Installed to $DEST"
