#!/bin/bash
# Usage: make-appimage.sh <x64|arm64> <x86_64|aarch64>
set -euo pipefail
ARCH="$1"
AIARCH="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ID=org.pepoconnect.PepoConnect
SRC="$ROOT/build/linux/$ARCH/release/bundle"
APPDIR="$ROOT/build/AppDir"
[ -d "$SRC" ] || { echo "bundle not found: $SRC"; exit 1; }
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps" "$ROOT/dist"
cp -r "$SRC/." "$APPDIR/usr/bin/"
bash "$ROOT/packaging/linux/bundle-extra-libs.sh" "$APPDIR/usr/bin"
cp "$ROOT/packaging/linux/$ID.desktop" "$APPDIR/$ID.desktop"
cp "$ROOT/packaging/linux/$ID.desktop" "$APPDIR/usr/share/applications/$ID.desktop"
cp "$ROOT/assets/icon/pepoconnect-256.png" "$APPDIR/$ID.png"
cp "$ROOT/assets/icon/pepoconnect-256.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$ID.png"
cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/pepoconnect" "$@"
RUN
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/pepoconnect"
TOOL="$ROOT/build/appimagetool-$AIARCH.AppImage"
if [ ! -x "$TOOL" ]; then
  curl -fsSL -o "$TOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$AIARCH.AppImage"
  chmod +x "$TOOL"
fi
ARCH="$AIARCH" "$TOOL" --appimage-extract-and-run "$APPDIR" "$ROOT/dist/PepoConnect-linux-$ARCH.AppImage"
ls -la "$ROOT/dist"
