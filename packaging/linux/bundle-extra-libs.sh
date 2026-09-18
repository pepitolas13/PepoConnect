#!/bin/bash
# Copies optional runtime libraries (tray indicator, libnotify) into <bundle>/lib so the app
# starts even on systems that do not ship them. The Flutter runner has rpath $ORIGIN/lib.
# Usage: bundle-extra-libs.sh <bundle-dir>
set -euo pipefail
BUNDLE="$1"
mkdir -p "$BUNDLE/lib"
for lib in libayatana-appindicator3.so.1 libayatana-indicator3.so.7 libayatana-ido3-0.4.so.0 \
           libdbusmenu-glib.so.4 libdbusmenu-gtk3.so.4 libnotify.so.4; do
  src=$(ldconfig -p | awk -v l="$lib" '$1==l {print $NF; exit}')
  if [ -n "${src:-}" ] && [ ! -e "$BUNDLE/lib/$lib" ]; then
    cp -L "$src" "$BUNDLE/lib/$lib"
    echo "bundled $lib"
  fi
done
