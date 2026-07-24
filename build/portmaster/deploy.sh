#!/bin/bash
# build/portmaster/deploy.sh
# Builds and deploys Dualdrop to PortMaster devices via SSH
#
# Usage:
#   SPRUCE_IP=10.0.0.94 SPRUCE_USER=spruce SPRUCE_PASS='...' ./build/portmaster/deploy.sh
#
# Credentials are NOT stored in this file — set via environment.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GAME_NAME="Dualdrop"
DIST_DIR="$PROJECT_ROOT/dist/portmaster"

SPRUCE_IP="${SPRUCE_IP:-}"
SPRUCE_USER="${SPRUCE_USER:-spruce}"
SPRUCE_PASS="${SPRUCE_PASS:-}"
SPRUCE_PATH="${SPRUCE_PATH:-/mnt/sdcard/Roms/PORTS}"

if [ -z "$SPRUCE_IP" ] || [ -z "$SPRUCE_PASS" ]; then
    echo "ERROR: Set SPRUCE_IP and SPRUCE_PASS environment variables."
    echo "Example: SPRUCE_IP=10.0.0.94 SPRUCE_PASS='...' $0"
    exit 1
fi

cd "$PROJECT_ROOT"

echo "=== Building $GAME_NAME ==="
"$SCRIPT_DIR/build.sh"

echo ""
echo "=== Deploying to SpruceOS ($SPRUCE_IP) ==="

echo "Testing connection..."
if ! sshpass -p "$SPRUCE_PASS" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SPRUCE_USER@$SPRUCE_IP" "echo OK" 2>/dev/null; then
    echo "ERROR: Cannot connect to $SPRUCE_IP"
    echo "Make sure device is on and SSH is enabled"
    exit 1
fi
echo "Connected!"

echo "Cleaning old files..."
sshpass -p "$SPRUCE_PASS" ssh -o StrictHostKeyChecking=no "$SPRUCE_USER@$SPRUCE_IP" \
    "rm -rf '$SPRUCE_PATH/$GAME_NAME' '$SPRUCE_PATH/$GAME_NAME.sh' '$SPRUCE_PATH/${GAME_NAME}Updater.sh'" 2>/dev/null

echo "Uploading files..."
sshpass -p "$SPRUCE_PASS" scp -r "$DIST_DIR/$GAME_NAME.sh" "$DIST_DIR/${GAME_NAME}Updater.sh" "$DIST_DIR/$GAME_NAME" "$SPRUCE_USER@$SPRUCE_IP:$SPRUCE_PATH/"

if [ $? -eq 0 ]; then
    echo ""
    echo "=== DEPLOYMENT COMPLETE ==="
else
    echo ""
    echo "=== DEPLOYMENT FAILED ==="
    exit 1
fi
