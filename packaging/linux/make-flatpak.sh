#!/bin/bash
# Builds a single-file .flatpak bundle (the format that works on musl distros such as postmarketOS).
# Usage: make-flatpak.sh <x64|arm64> <x86_64|aarch64>
set -euo pipefail
ARCH="$1"
FPARCH="$2"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ID=org.pepoconnect.PepoConnect
SRC="$ROOT/build/linux/$ARCH/release/bundle"
WORK="$ROOT/build/flatpak"
[ -d "$SRC" ] || { echo "bundle not found: $SRC"; exit 1; }
rm -rf "$WORK"
mkdir -p "$WORK/src" "$ROOT/dist"
cp -r "$SRC" "$WORK/src/bundle"
bash "$ROOT/packaging/linux/bundle-extra-libs.sh" "$WORK/src/bundle"
cp "$ROOT/packaging/linux/$ID.desktop" "$ROOT/packaging/linux/$ID.metainfo.xml" "$WORK/src/"
cp "$ROOT/assets/icon/pepoconnect-256.png" "$WORK/src/$ID.png"
printf '#!/bin/sh\nexec /app/pepoconnect/pepoconnect "$@"\n' > "$WORK/src/pepoconnect.sh"
cat > "$WORK/$ID.yml" <<YML
app-id: $ID
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
command: pepoconnect
finish-args:
  - --share=network
  - --share=ipc
  - --socket=wayland
  - --socket=fallback-x11
  - --socket=pulseaudio
  - --device=dri
  - --filesystem=xdg-download
  - --filesystem=xdg-pictures
  - --filesystem=xdg-videos
  - --talk-name=org.freedesktop.Avahi
  - --talk-name=org.freedesktop.Notifications
  - --talk-name=org.kde.StatusNotifierWatcher
modules:
  - name: pepoconnect
    buildsystem: simple
    build-commands:
      - mkdir -p /app/pepoconnect /app/bin /app/share/applications /app/share/icons/hicolor/256x256/apps /app/share/metainfo
      - cp -r bundle/. /app/pepoconnect/
      - install -Dm755 pepoconnect.sh /app/bin/pepoconnect
      - install -Dm644 $ID.desktop /app/share/applications/$ID.desktop
      - install -Dm644 $ID.png /app/share/icons/hicolor/256x256/apps/$ID.png
      - install -Dm644 $ID.metainfo.xml /app/share/metainfo/$ID.metainfo.xml
    sources:
      - type: dir
        path: src
YML
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y --noninteractive flathub "org.freedesktop.Platform//24.08" "org.freedesktop.Sdk//24.08"
flatpak-builder --user --arch="$FPARCH" --force-clean --repo="$WORK/repo" "$WORK/build-dir" "$WORK/$ID.yml"
flatpak build-bundle --arch="$FPARCH" "$WORK/repo" "$ROOT/dist/PepoConnect-linux-$ARCH.flatpak" "$ID"
ls -la "$ROOT/dist"
