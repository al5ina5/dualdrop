-- src/net/port_util.lua
-- Free a TCP listen port before hosting (prevents "port in use" soft fails)

local PortUtil = {}

-- Best-effort: kill other processes listening on this TCP port (never kill ourselves)
function PortUtil.freeListenPort(port)
    port = tonumber(port) or 12345
    local osName = (love and love.system and love.system.getOS and love.system.getOS()) or ""

    if osName == "Windows" then
        -- Kill PIDs that have the port in LISTENING state
        local cmd = string.format(
            'powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort %d -State Listen -ErrorAction SilentlyContinue | ForEach-Object { if ($_.OwningProcess -ne $PID) { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } }"',
            port
        )
        os.execute(cmd)
        return
    end

    -- macOS / Linux: only LISTEN sockets, never our own Love process
    local script = string.format([[
LOVE_PID=$PPID
PIDS=$(lsof -nP -iTCP:%d -sTCP:LISTEN -t 2>/dev/null || true)
for pid in $PIDS; do
  if [ -n "$pid" ] && [ "$pid" != "$LOVE_PID" ]; then
    kill -9 "$pid" 2>/dev/null || true
  fi
done
]], port)
    os.execute("sh -c " .. string.format("%q", script))
end

-- Try to create an ENet host; free the port and retry if bind fails
function PortUtil.createENetHost(bindAddress, peerCount, channelCount)
    local enet = require("enet")
    peerCount = peerCount or 4
    channelCount = channelCount or 2

    local host = enet.host_create(bindAddress, peerCount, channelCount)
    if host then
        return host
    end

    local port = tonumber((bindAddress or ""):match(":(%d+)$")) or 12345
    print("PortUtil: Bind failed on " .. tostring(bindAddress) .. " — freeing port " .. port)
    PortUtil.freeListenPort(port)

    -- Let the OS release the socket
    if love and love.timer and love.timer.sleep then
        love.timer.sleep(0.15)
    end
    collectgarbage("collect")

    host = enet.host_create(bindAddress, peerCount, channelCount)
    if host then
        print("PortUtil: Bind succeeded after freeing port " .. port)
        return host
    end

    -- One more hard retry
    PortUtil.freeListenPort(port)
    if love and love.timer and love.timer.sleep then
        love.timer.sleep(0.25)
    end
    collectgarbage("collect")
    host = enet.host_create(bindAddress, peerCount, channelCount)
    return host
end

return PortUtil
