#!/bin/bash
# build/esde/build.sh
# Builds a self-contained Dualdrop drop for ES-DE / Linux Mint kiosks.
# Output: dist/esde/Dualdrop/{love.AppImage,Dualdrop.love} + Dualdrop.sh
#
# Usage: ./build/esde/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GAME_NAME="Dualdrop"
LOVE_VERSION="11.5"
OUT_DIR="$PROJECT_ROOT/dist/esde"
GAME_DIR="$OUT_DIR/$GAME_NAME"
CACHE_DIR="$PROJECT_ROOT/build/desktop/.cache"
LOVE_URL="https://github.com/love2d/love/releases/download/${LOVE_VERSION}/love-${LOVE_VERSION}-x86_64.AppImage"
CACHE_APPIMAGE="$CACHE_DIR/love-${LOVE_VERSION}-x86_64.AppImage"

echo "=== Building ES-DE package for $GAME_NAME ==="

mkdir -p "$CACHE_DIR" "$GAME_DIR"
rm -rf "$GAME_DIR"
mkdir -p "$GAME_DIR"

# 1. .love via desktop build
"$PROJECT_ROOT/build/desktop/build.sh" love
cp "$PROJECT_ROOT/dist/desktop/${GAME_NAME}.love" "$GAME_DIR/${GAME_NAME}.love"

# 2. Bundled LÖVE AppImage (no apt install on target)
if [ ! -f "$CACHE_APPIMAGE" ]; then
    echo "Downloading LÖVE ${LOVE_VERSION} AppImage..."
    curl -L --progress-bar -o "$CACHE_APPIMAGE" "$LOVE_URL"
fi
cp "$CACHE_APPIMAGE" "$GAME_DIR/love.AppImage"
chmod +x "$GAME_DIR/love.AppImage"

# 3. Internal run helper (optional direct launch)
cat > "$GAME_DIR/run.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export APPIMAGE_EXTRACT_AND_RUN=1
exec "$DIR/love.AppImage" "$DIR/Dualdrop.love" "$@"
EOF
chmod +x "$GAME_DIR/run.sh"

# 4. Thin ES-DE ports launcher (install to ~/ROMs/ports/Dualdrop.sh)
cat > "$OUT_DIR/${GAME_NAME}.sh" << 'EOF'
#!/usr/bin/env bash
# ES-DE Ports launcher for Dualdrop — only starts this game.
set -euo pipefail
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export APPIMAGE_EXTRACT_AND_RUN=1
GAME_DIR="$HOME/Games/Dualdrop"
cd "$GAME_DIR" || { echo "Missing $GAME_DIR"; exit 1; }
exec ./love.AppImage ./Dualdrop.love
EOF
chmod +x "$OUT_DIR/${GAME_NAME}.sh"

# 5. Short install note shipped with the package
cat > "$OUT_DIR/INSTALL.txt" << 'EOF'
Dualdrop — minimal ES-DE / LAN install
=======================================

Files to copy (and nothing else on the host):

  ~/Games/Dualdrop/          <- contents of dist/esde/Dualdrop/
  ~/ROMs/ports/Dualdrop.sh   <- dist/esde/Dualdrop.sh

Then refresh ES-DE (or restart) and launch Ports > Dualdrop.

LAN: one machine CREATE GAME, the other FIND GAME (or JOIN BY IP).
Game port UDP/TCP 12345, discovery UDP 12346.

Deploy from the repo (game files only — does not overwrite Ports launcher):
  npm run deploy:machines
  npm run deploy:kiosk
  npm run deploy:aio
EOF

echo ""
echo "=== Package ready: $OUT_DIR ==="
ls -la "$GAME_DIR"
ls -la "$OUT_DIR/${GAME_NAME}.sh"
