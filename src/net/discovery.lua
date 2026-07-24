-- src/net/discovery.lua
-- LAN server discovery using UDP broadcast
-- Uses LuaSocket (built into LÖVE) separately from ENet

local socket = require("socket")

local Discovery = {}
Discovery.__index = Discovery

-- Port for discovery broadcast (different from game port)
local DISCOVERY_PORT = 12346
local BROADCAST_INTERVAL = 1.0  -- Seconds between broadcasts
local SERVER_TIMEOUT = 5.0      -- Remove server if no ping for this long

function Discovery:new()
    local self = setmetatable({}, Discovery)
    
    self.servers = {}
    self.broadcastTimer = 0
    self.serverInfo = nil
    self.socket = nil
    self.mode = nil  -- "server" or "client"
    self.localIP = self:fetchLocalIP()
    
    return self
end

-- Helper to find the actual local IP address
function Discovery:fetchLocalIP()
    local s = socket.udp()
    if not s then return "unknown" end
    
    -- Try to find the outgoing interface by "connecting" to an external IP
    -- (doesn't actually send any data)
    local targets = {"8.8.8.8", "1.1.1.1", "192.168.1.1", "192.168.0.1", "10.0.0.1"}
    local ip = nil
    
    for _, target in ipairs(targets) do
        if s:setpeername(target, 80) then
            local getsockname_ip = s:getsockname()
            if getsockname_ip and getsockname_ip ~= "0.0.0.0" and getsockname_ip ~= "127.0.0.1" then
                ip = getsockname_ip
                break
            end
        end
    end
    
    s:close()
    return ip or "unknown"
end

-- Helper to get all likely broadcast addresses
function Discovery:getBroadcastAddresses()
    local addresses = {
        "255.255.255.255", -- Global broadcast
        "127.0.0.1"        -- Localhost
    }
    
    local ip = self:fetchLocalIP()
    if ip ~= "unknown" and ip ~= "127.0.0.1" then
        -- Calculate subnet broadcast (assume /24)
        local a, b, c = ip:match("(%d+)%.(%d+)%.(%d+)%.%d+")
        if a and b and c then
            table.insert(addresses, string.format("%s.%s.%s.255", a, b, c))
        end
    end
    
    -- Common home network broadcasts
    local common = {"192.168.1.255", "192.168.0.255", "192.168.2.255", "10.0.0.255"}
    for _, addr in ipairs(common) do
        local exists = false
        for _, existing in ipairs(addresses) do
            if existing == addr then exists = true; break end
        end
        if not exists then table.insert(addresses, addr) end
    end
    
    return addresses
end

-- Create and configure a fresh UDP socket
function Discovery:createSocket()
    if self.socket then
        self.socket:close()
    end
    
    -- Try to create an IPv4 UDP socket
    local sock, err = socket.udp()
    if not sock then
        print("Discovery Error: Could not create socket: " .. tostring(err))
        return nil
    end
    
    self.socket = sock
    self.socket:settimeout(0)  -- Non-blocking
    self.socket:setoption("broadcast", true)
    self.socket:setoption("reuseaddr", true)
    
    return self.socket
end

-- Start advertising as a server
function Discovery:startAdvertising(serverName, gamePort, maxPlayers, format)
    print("Discovery: Attempting to start advertising...")
    self.localIP = self:fetchLocalIP()
    self:createSocket()
    if not self.socket then return end
    
    -- Bind to the discovery port to receive client queries
    local success, err = self.socket:setsockname("*", DISCOVERY_PORT)
    if not success then
        print("Discovery: ERROR binding " .. DISCOVERY_PORT .. ": " .. tostring(err))
        print("Discovery: advertising disabled (FIND GAME will not see this host)")
        if self.socket then
            self.socket:close()
            self.socket = nil
        end
        return
    end
    
    local boundIp, boundPort = self.socket:getsockname()
    print("Discovery: Bound to " .. tostring(boundIp) .. ":" .. tostring(boundPort))
    
    self.mode = "server"
    self.serverInfo = {
        name = serverName or "Dualdrop",
        port = gamePort or 12345,
        players = 1,
        maxPlayers = maxPlayers or 4,
        format = format or "1v1",
    }
    
    self.broadcastTimer = BROADCAST_INTERVAL
    print("Discovery: Advertising as '" .. self.serverInfo.name .. "' (IP: " .. self.localIP .. ")")
end

-- Stop advertising
function Discovery:stopAdvertising()
    if self.serverInfo then
        print("Discovery: Stopped advertising")
        self.serverInfo = nil
    end
    
    if self.mode == "server" then
        self.mode = nil
        if self.socket then
            self.socket:close()
            self.socket = nil
            print("Discovery: Server socket closed")
        end
    end
end

-- Start listening for servers (as a client)
function Discovery:startListening()
    -- Create socket if we don't have one
    if not self.socket then
        print("Discovery: Starting client listener")
        self:createSocket()
        if self.socket then
            -- Client binds to random port
            self.socket:setsockname("*", 0)
            local ip, port = self.socket:getsockname()
            print("Discovery: Client bound to " .. tostring(ip) .. ":" .. tostring(port))
            self.mode = "client"
        end
    end
    
    -- Clear current server list to force a refresh
    self.servers = {}
end

-- Update discovery (call every frame)
function Discovery:update(dt)
    if not self.socket then return end
    
    self.broadcastTimer = self.broadcastTimer + dt
    
    -- If we're a server, periodically broadcast our presence
    if self.serverInfo and self.broadcastTimer >= BROADCAST_INTERVAL then
        self.broadcastTimer = 0
        self:broadcastServer()
    end
    
    -- Always receive incoming messages
    self:receiveMessages()
    
    -- Clean up stale servers
    self:cleanupStaleServers()
end

-- Broadcast server info to LAN
function Discovery:broadcastServer()
    if not self.serverInfo or not self.socket then return end
    
    -- "|" is the discovery delimiter — strip it from the display name
    local safeName = tostring(self.serverInfo.name or "Host"):gsub("|", "/")
    
    local msg = string.format("SERVER|%s|%d|%d|%d|%s",
        safeName,
        self.serverInfo.port,
        self.serverInfo.players,
        self.serverInfo.maxPlayers,
        self.serverInfo.format or "1v1"
    )
    
    local addresses = self:getBroadcastAddresses()
    for _, addr in ipairs(addresses) do
        self.socket:sendto(msg, addr, DISCOVERY_PORT)
    end
end

-- Send a discovery request (as client looking for servers)
-- Optional hintIps: extra unicast targets (e.g. lastIP, known peers)
function Discovery:sendDiscoveryRequest(hintIps)
    if not self.socket then
        self:startListening()
    end
    if not self.socket then return end
    
    local msg = "DISCOVER"
    local addresses = self:getBroadcastAddresses()

    -- Unicast hints help when Wi‑Fi broadcast is flaky
    local function addHint(ip)
        if not ip or ip == "" or ip == "unknown" then return end
        -- strip port if present
        ip = tostring(ip):match("^([^:]+)") or tostring(ip)
        for _, existing in ipairs(addresses) do
            if existing == ip then return end
        end
        table.insert(addresses, ip)
    end

    if type(hintIps) == "table" then
        for _, ip in ipairs(hintIps) do addHint(ip) end
    elseif type(hintIps) == "string" then
        addHint(hintIps)
    end

    -- Try common Emusation hostnames when resolvable
    if socket.dns and socket.dns.toip then
        for _, host in ipairs({"aio.local", "kiosk.local", "aio", "kiosk"}) do
            local ok, resolved = pcall(socket.dns.toip, host)
            if ok and resolved then addHint(resolved) end
        end
    end
    
    print("Discovery: Sending broadcast/unicast request to " .. #addresses .. " addresses...")
    for _, addr in ipairs(addresses) do
        self.socket:sendto(msg, addr, DISCOVERY_PORT)
    end
end

-- Receive and process messages
function Discovery:receiveMessages()
    if not self.socket then return end
    
    -- Local helper to process a single data packet
    local function process(data, ip, port)
        -- print("Discovery Debug: Received raw [" .. tostring(data) .. "] from " .. tostring(ip) .. ":" .. tostring(port))
        
        local msgType = data:match("^(%w+)")
        
        if msgType == "DISCOVER" and self.serverInfo then
            -- Query received, reply directly
            local safeName = tostring(self.serverInfo.name or "Host"):gsub("|", "/")
            local response = string.format("SERVER|%s|%d|%d|%d|%s",
                safeName,
                self.serverInfo.port,
                self.serverInfo.players,
                self.serverInfo.maxPlayers,
                self.serverInfo.format or "1v1"
            )
            self.socket:sendto(response, ip, port)
            print("Discovery: Replied to DISCOVER from " .. ip)
            
        elseif msgType == "SERVER" then
            -- Server advertisement received (format field optional for older hosts)
            local name, gamePort, players, maxPlayers, format =
                data:match("^SERVER|([^|]+)|(%d+)|(%d+)|(%d+)|([^|]+)$")
            if not name then
                name, gamePort, players, maxPlayers =
                    data:match("^SERVER|([^|]+)|(%d+)|(%d+)|(%d+)$")
            end
            
            if name and gamePort then
                local sid = ip .. ":" .. gamePort
                if not self.servers[sid] then
                    print("Discovery: Found server '" .. name .. "' at " .. ip)
                end
                
                self.servers[sid] = {
                    name = name,
                    ip = ip,
                    port = tonumber(gamePort),
                    players = tonumber(players) or 1,
                    maxPlayers = tonumber(maxPlayers) or 4,
                    format = format or "1v1",
                    lastSeen = love.timer.getTime(),
                }
            end
        end
    end

    -- Poll all pending messages
    while true do
        local data, ip, port = self.socket:receivefrom()
        if not data then 
            if ip ~= "timeout" then
                -- Any error other than timeout (like "closed" or "refused")
                -- print("Discovery Receive Error: " .. tostring(ip))
            end
            break 
        end
        process(data, ip, port)
    end
end

-- Remove servers we haven't heard from recently
function Discovery:cleanupStaleServers()
    local now = love.timer.getTime()
    for sid, server in pairs(self.servers) do
        if now - server.lastSeen > SERVER_TIMEOUT then
            print("Discovery: Server '" .. server.name .. "' timed out")
            self.servers[sid] = nil
        end
    end
end

-- Get list of discovered servers
function Discovery:getServers()
    local list = {}
    for _, server in pairs(self.servers) do
        table.insert(list, server)
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Update player count (call when players join/leave)
function Discovery:setPlayerCount(count)
    if self.serverInfo then
        self.serverInfo.players = count
    end
end

-- Clean up
function Discovery:close()
    if self.socket then
        self.socket:close()
        self.socket = nil
    end
    self.mode = nil
    self.serverInfo = nil
    print("Discovery: Closed")
end

return Discovery
