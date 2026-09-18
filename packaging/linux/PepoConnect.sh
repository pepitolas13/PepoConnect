#!/bin/sh
# Launcher for the tarball layout: <dir>/bundle/pepoconnect
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/bundle/pepoconnect" "$@"
