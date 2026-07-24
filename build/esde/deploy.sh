#!/bin/bash
# build/esde/deploy.sh
# Copies ONLY Dualdrop game files (~/Games/Dualdrop/) to an ES-DE host.
# Never touches ~/ROMs/ports/Dualdrop.sh (Emusation wrapper with hotkey-exit).
#
# Usage:
#   ./build/esde/deploy.sh kiosk.local
#   ./build/esde/deploy.sh aio.local
#   DEPLOY_JUMP=kiosk.local ./build/esde/deploy.sh aio.local   # when direct SSH is closed
#
# Auth: SSH key preferred. Optional password:
#   DEPLOY_SSH_PASS='...' ./build/esde/deploy.sh host

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$PROJECT_ROOT/dist/esde"
GAME_NAME="Dualdrop"

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <host|user@host>"
    exit 1
fi

if [[ "$TARGET" != *@* ]]; then
    TARGET="alsinas@$TARGET"
fi

HOST_ONLY="${TARGET#*@}"

if [ ! -f "$OUT_DIR/$GAME_NAME/Dualdrop.love" ] || [ ! -f "$OUT_DIR/$GAME_NAME/love.AppImage" ]; then
    echo "Package missing — building first..."
    "$SCRIPT_DIR/build.sh"
fi

ssh_direct() {
    if [ -n "${DEPLOY_SSH_PASS:-}" ] && command -v sshpass >/dev/null 2>&1; then
        sshpass -p "$DEPLOY_SSH_PASS" ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -o ConnectTimeout=8 "$@"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "$@"
    fi
}

scp_direct() {
    if [ -n "${DEPLOY_SSH_PASS:-}" ] && command -v sshpass >/dev/null 2>&1; then
        sshpass -p "$DEPLOY_SSH_PASS" scp -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no "$@"
    else
        scp -o BatchMode=yes "$@"
    fi
}

echo "=== Deploying $GAME_NAME game files to $TARGET (launcher untouched) ==="

USE_JUMP=0
if ! ssh_direct "$TARGET" "echo OK" >/dev/null 2>&1; then
    if [ -n "${DEPLOY_JUMP:-}" ]; then
        echo "Direct SSH failed; using jump host ${DEPLOY_JUMP}"
        USE_JUMP=1
    else
        echo "ERROR: Cannot SSH to $TARGET"
        echo "Tip: DEPLOY_JUMP=kiosk.local DEPLOY_SSH_PASS='...' $0 $HOST_ONLY"
        exit 1
    fi
fi

if [ "$USE_JUMP" = "0" ]; then
    ssh_direct "$TARGET" "hostname; uname -m"
    ssh_direct "$TARGET" 'mkdir -p "$HOME/Games/Dualdrop"'
    if command -v rsync >/dev/null 2>&1 && [ -z "${DEPLOY_SSH_PASS:-}" ]; then
        rsync -az --delete "$OUT_DIR/$GAME_NAME/" "$TARGET:Games/Dualdrop/"
    else
        ssh_direct "$TARGET" 'rm -rf "$HOME/Games/Dualdrop" && mkdir -p "$HOME/Games/Dualdrop"'
        scp_direct -r "$OUT_DIR/$GAME_NAME/." "$TARGET:Games/Dualdrop/"
    fi
    ssh_direct "$TARGET" 'chmod +x "$HOME/Games/Dualdrop/love.AppImage" "$HOME/Games/Dualdrop/run.sh"'
    ssh_direct "$TARGET" 'cd "$HOME/Games/Dualdrop" && APPIMAGE_EXTRACT_AND_RUN=1 ./love.AppImage --version'
else
    JUMP="alsinas@${DEPLOY_JUMP}"
    # Stage on jump, then push game files only (never Ports launcher)
    ssh -o BatchMode=yes "$JUMP" 'rm -rf /tmp/dualdrop-deploy && mkdir -p /tmp/dualdrop-deploy/game'
    rsync -az "$OUT_DIR/$GAME_NAME/" "$JUMP:/tmp/dualdrop-deploy/game/"
    ssh -o BatchMode=yes "$JUMP" "sshpass -p \"${DEPLOY_SSH_PASS}\" ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no ${TARGET} 'mkdir -p \"\$HOME/Games/Dualdrop\"' && \
      sshpass -p \"${DEPLOY_SSH_PASS}\" scp -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no -r /tmp/dualdrop-deploy/game/. ${TARGET}:Games/Dualdrop/ && \
      sshpass -p \"${DEPLOY_SSH_PASS}\" ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no ${TARGET} 'chmod +x \"\$HOME/Games/Dualdrop/love.AppImage\" \"\$HOME/Games/Dualdrop/run.sh\" && cd \"\$HOME/Games/Dualdrop\" && APPIMAGE_EXTRACT_AND_RUN=1 ./love.AppImage --version'"
fi

echo ""
echo "=== DEPLOY COMPLETE on $TARGET ==="
echo "  Game:     ~/Games/Dualdrop/  (overwritten)"
echo "  Launcher: ~/ROMs/ports/Dualdrop.sh  (left alone — Emusation wrapper)"
echo "If UFW is active, allow UDP 12345+12346 from 10.0.0.0/24 (see docs/ESDE_LAN_INSTALL.md)."
