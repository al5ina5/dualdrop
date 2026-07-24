#!/bin/bash
# build/portmaster/build.sh
# Builds PortMaster package for Dualdrop (SpruceOS, muOS, etc.)
#
# Usage: ./build/portmaster/build.sh
# Output: dist/portmaster/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GAME_NAME="Dualdrop"
BUILD_DIR="$PROJECT_ROOT/dist/portmaster"

cd "$PROJECT_ROOT"

echo "=== Building PortMaster Package for $GAME_NAME ==="
echo "Project root: $PROJECT_ROOT"
echo "Output: $BUILD_DIR"
echo ""

# 1. Clean and create build structure
echo "[1/6] Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$GAME_NAME"

# 2. Package the .love file
echo "[2/6] Creating $GAME_NAME.love..."
zip -9 -r "$BUILD_DIR/$GAME_NAME/$GAME_NAME.love" . \
    -x "*.git*" \
    -x "dist/*" \
    -x "build/*" \
    -x "*.DS_Store" \
    -x "raw_udp_test.lua" \
    -x "debug/*" \
    -x "relay/*" \
    -x "docs/*" \
    -x "Dockerfile" \
    -x ".env" \
    -x "deploy.sh" \
    -x "build_portmaster.sh"

# 3. Create the Launcher (.sh)
echo "[3/6] Creating launcher script..."
cat > "$BUILD_DIR/$GAME_NAME.sh" << 'LAUNCHER_EOF'
#!/bin/bash
# PortMaster Launcher for Dualdrop

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt

get_controls
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

# Dynamic path resolution - remove trailing slashes, handle leading slash
GAMEDIR="${directory%/}/Dualdrop"
# Ensure path starts with /
[[ "$GAMEDIR" != /* ]] && GAMEDIR="/$GAMEDIR"

# If not found in root, check in /ports/ subfolder
if [ ! -d "$GAMEDIR" ]; then
    GAMEDIR="${directory%/}/ports/Dualdrop"
    [[ "$GAMEDIR" != /* ]] && GAMEDIR="/$GAMEDIR"
fi

cd "$GAMEDIR"

# Setup saves path
export XDG_DATA_HOME="$GAMEDIR/saves"
export XDG_CONFIG_HOME="$GAMEDIR/saves"
mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_CONFIG_HOME"

# Redirect all output to log.txt for debugging
exec > >(tee "$GAMEDIR/log.txt") 2>&1
echo "--- Starting Dualdrop ---"
echo "Date: $(date)"
echo "GAMEDIR: $GAMEDIR"
echo "Device: $DEVICE_NAME ($DEVICE_ARCH)"

# Search for LÖVE binary
LOVE_BIN=""
# 1. Check PortMaster runtimes first (highest quality)
for ver in "11.5" "11.4"; do
    R_PATH="$controlfolder/runtimes/love_$ver/love.$DEVICE_ARCH"
    if [ -f "$R_PATH" ]; then
        LOVE_BIN="$R_PATH"
        export LD_LIBRARY_PATH="$(dirname "$R_PATH")/libs.$DEVICE_ARCH:$LD_LIBRARY_PATH"
        break
    fi
done

# 2. Check system paths fallback
if [ -z "$LOVE_BIN" ]; then
    for path in "/usr/bin/love" "/usr/local/bin/love" "/opt/love/bin/love"; do
        if [ -f "$path" ]; then
            LOVE_BIN="$path"
            break
        fi
    done
fi

if [ -z "$LOVE_BIN" ]; then
    echo "ERROR: LÖVE binary not found in runtimes or system paths!"
    exit 1
fi

echo "Using LÖVE binary: $LOVE_BIN"

# We use the basename of LOVE_BIN for gptokeyb to watch
LOVE_NAME=$(basename "$LOVE_BIN")

$GPTOKEYB "$LOVE_NAME" -c "$GAMEDIR/Dualdrop.gptk" &
pm_platform_helper "$LOVE_BIN"
"$LOVE_BIN" "$GAMEDIR/Dualdrop.love"

# Cleanup after exit
killall gptokeyb
pm_finish
LAUNCHER_EOF

chmod +x "$BUILD_DIR/$GAME_NAME.sh"

# 4. Create the Controller Mapping (.gptk)
echo "[4/6] Creating controller mapping..."
cat > "$BUILD_DIR/$GAME_NAME/$GAME_NAME.gptk" << 'EOF'
back = m
start = enter

up = up
down = down
left = left
right = right

left_analog_up = up
left_analog_down = down
left_analog_left = left
left_analog_right = right

a = x
b = z
x = space
y = c

l1 = c
r1 = x
EOF

# 5. Create PortMaster metadata (port.json)
echo "[5/6] Creating port.json..."
cat > "$BUILD_DIR/$GAME_NAME/port.json" << EOF
{
    "version": 1,
    "name": "$GAME_NAME",
    "items": ["$GAME_NAME.sh"],
    "items_opt": [],
    "attr": {
        "title": "Dualdrop",
        "desc": "Multiplayer falling block puzzle game.",
        "inst": "D-Pad to move. X/Y for Menu. Host on one device, Find on another!",
        "genres": ["multiplayer", "puzzle"],
        "porter": "Antigravity",
        "runtime": "love-11.4"
    }
}
EOF

# 6. Create updater script (next to launcher, not inside game folder)
echo "[6/6] Creating DualdropUpdater.sh..."
cat > "$BUILD_DIR/DualdropUpdater.sh" << 'UPDATE_EOF'
#!/bin/bash
# DualdropUpdater.sh - Updates Dualdrop from GitHub
# Place this next to Dualdrop.sh in your ports folder
#
# Usage: Run from PortMaster menu or: ./DualdropUpdater.sh

REPO="al5ina5/dualdrop"
BRANCH="main"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$SCRIPT_DIR/Dualdrop"

echo "=== Dualdrop Updater ==="
echo "Game directory: $GAME_DIR"
echo ""

# Check game folder exists
if [ ! -d "$GAME_DIR" ]; then
    echo "ERROR: Dualdrop folder not found at $GAME_DIR"
    echo "Make sure DualdropUpdater.sh is in the same folder as Dualdrop/"
    exit 1
fi

# Check for curl or wget
if command -v curl &> /dev/null; then
    DOWNLOADER="curl"
elif command -v wget &> /dev/null; then
    DOWNLOADER="wget"
else
    echo "ERROR: Neither curl nor wget found!"
    exit 1
fi

echo "Using $DOWNLOADER for downloads..."
echo ""

# Download function
download_file() {
    local url="$1"
    local dest="$2"
    
    echo "Downloading: $(basename "$dest")"
    
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -L -s -o "$dest" "$url"
    else
        wget -q -O "$dest" "$url"
    fi
    
    if [ $? -eq 0 ] && [ -f "$dest" ] && [ -s "$dest" ]; then
        echo "  OK"
        return 0
    else
        echo "  FAILED"
        return 1
    fi
}

# Base URL for raw files
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/dist/portmaster"

echo "Downloading updates..."
echo ""

# Backup current .love file
if [ -f "$GAME_DIR/Dualdrop.love" ]; then
    cp "$GAME_DIR/Dualdrop.love" "$GAME_DIR/Dualdrop.love.backup"
    echo "Backed up current Dualdrop.love"
fi

# Download new files
download_file "$BASE_URL/Dualdrop/Dualdrop.love" "$GAME_DIR/Dualdrop.love"
LOVE_OK=$?

download_file "$BASE_URL/Dualdrop/Dualdrop.gptk" "$GAME_DIR/Dualdrop.gptk"
GPTK_OK=$?

download_file "$BASE_URL/Dualdrop/port.json" "$GAME_DIR/port.json"
JSON_OK=$?

echo ""

if [ $LOVE_OK -eq 0 ]; then
    # Remove backup on success
    rm -f "$GAME_DIR/Dualdrop.love.backup"
    echo "=== Update complete! ==="
    echo "Restart the game to use the new version."
else
    # Restore backup on failure
    if [ -f "$GAME_DIR/Dualdrop.love.backup" ]; then
        mv "$GAME_DIR/Dualdrop.love.backup" "$GAME_DIR/Dualdrop.love"
        echo "Update failed - restored previous version."
    fi
    echo "=== Update FAILED ==="
    exit 1
fi
UPDATE_EOF

chmod +x "$BUILD_DIR/DualdropUpdater.sh"

echo ""
echo "=== BUILD COMPLETE ==="
echo ""
echo "Output files:"
echo "  $BUILD_DIR/Dualdrop.sh"
echo "  $BUILD_DIR/DualdropUpdater.sh"
echo "  $BUILD_DIR/Dualdrop/"
echo "    - Dualdrop.love"
echo "    - Dualdrop.gptk"
echo "    - port.json"
echo ""
echo "To deploy, run: ./build/portmaster/deploy.sh"
