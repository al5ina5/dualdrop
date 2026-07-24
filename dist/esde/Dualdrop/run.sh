#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export APPIMAGE_EXTRACT_AND_RUN=1
exec "$DIR/love.AppImage" "$DIR/Dualdrop.love" "$@"
