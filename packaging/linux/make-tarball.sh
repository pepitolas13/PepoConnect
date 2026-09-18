#!/bin/bash
# Usage: make-tarball.sh <x64|arm64>
set -euo pipefail
ARCH="$1"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/build/linux/$ARCH/release/bundle"
OUT="$ROOT/build/tar/PepoConnect-linux-$ARCH"
[ -d "$SRC" ] || { echo "bundle not found: $SRC"; exit 1; }
rm -rf "$OUT"
mkdir -p "$OUT" "$ROOT/dist"
cp -r "$SRC" "$OUT/bundle"
bash "$ROOT/packaging/linux/bundle-extra-libs.sh" "$OUT/bundle"
cp "$ROOT/packaging/linux/org.pepoconnect.PepoConnect.desktop" \
   "$ROOT/packaging/linux/PepoConnect.sh" \
   "$ROOT/packaging/linux/install-desktop-entry.sh" "$OUT/"
cp "$ROOT/assets/icon/pepoconnect-256.png" "$OUT/org.pepoconnect.PepoConnect.png"
chmod +x "$OUT"/*.sh "$OUT/bundle/pepoconnect"
tar -C "$ROOT/build/tar" -czf "$ROOT/dist/PepoConnect-linux-$ARCH.tar.gz" "PepoConnect-linux-$ARCH"
ls -la "$ROOT/dist"
