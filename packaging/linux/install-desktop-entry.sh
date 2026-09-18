#!/bin/sh
# Registers PepoConnect in the application menu for the current user (no root needed).
set -e
HERE="$(dirname "$(readlink -f "$0")")"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$APPS" "$ICONS"
sed "s|^Exec=.*|Exec=$HERE/PepoConnect.sh %U|" "$HERE/org.pepoconnect.PepoConnect.desktop" > "$APPS/org.pepoconnect.PepoConnect.desktop"
cp "$HERE/org.pepoconnect.PepoConnect.png" "$ICONS/org.pepoconnect.PepoConnect.png"
if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$APPS" || true; fi
echo "PepoConnect anadido al menu de aplicaciones."
