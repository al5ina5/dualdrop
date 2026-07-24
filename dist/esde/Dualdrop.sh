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
