-- src/net/relay_client.lua
-- Real-time online multiplayer client using persistent TCP sockets via Relay
-- Much faster than polling HTTP/REST

local socket = require("socket")
local json = require("src.lib.dkjson")
local Protocol = require("src.net.protocol")
local Constants = require("src.constants")

local RelayClient = {}
RelayClient.__index = RelayClient

function RelayClient:new()
    local self = setmetatable({}, RelayClient)
    self.tcp = nil
    self.roomCode = nil
    self.connected = false
    self.playerId = nil
    self.paired = false -- True when opponent is also connected to relay
    self.buffer = "" -- For handling partial TCP packets
    
    return self
end

function RelayClient:connect(roomCode, playerId)
    self.roomCode = roomCode:upper()
    self.playerId = playerId -- "host" or "client"
    
    print("RelayClient: Connecting to " .. Constants.RELAY_HOST .. ":" .. Constants.RELAY_PORT)
    
    -- Resolve hostname to IP to avoid some luasocket issues with DNS
    local ip = socket.dns.toip(Constants.RELAY_HOST)
    if not ip then
        print("RelayClient: Could not resolve hostname: " .. Constants.RELAY_HOST)
        return false
    end

    local tcp, err = socket.tcp()
    if not tcp then
        print("RelayClient: Failed to create socket: " .. tostring(err))
        return false
    end
    
    -- Use non-blocking connect pattern for better reliability across OSs
    tcp:settimeout(0) 
    local success, connectErr = tcp:connect(ip, Constants.RELAY_PORT)
    
    -- "timeout" or "Operation already in progress" means it's connecting in background
    if not success and connectErr ~= "timeout" and connectErr ~= "Operation already in progress" then
        print("RelayClient: Connection failed immediately: " .. tostring(connectErr))
        return false
    end
    
    -- Wait for the socket to become writable (indicates connection success)
    local retries = 0
    local connected = false
    while retries < 5 and not connected do
        local _, writable, selectErr = socket.select(nil, {tcp}, 1) -- 1 second per check
        if writable and #writable > 0 then
            connected = true
        else
            retries = retries + 1
            print("RelayClient: Waiting for connection... (try " .. retries .. "/5)")
        end
    end
    
    if not connected then
        print("RelayClient: Connection timed out or failed")
        tcp:close()
        return false
    end
    
    -- Connection successful
    tcp:setoption("tcp-nodelay", true)
    self.tcp = tcp
    self.connected = true
    
    -- Send handshake
    self:send("JOIN:" .. self.roomCode)
    print("RelayClient: Connected and joined room " .. self.roomCode)
    
    return true
end

function RelayClient:poll()
    if not self.connected or not self.tcp then return {} end
    
    local messages = {}
    local data, err, partial = self.tcp:receive("*a") -- Receive all available data
    
    if err == "closed" then
        print("RelayClient: Connection closed by relay")
        self.connected = false
        -- Generate a player_left message so the game handles it properly
        table.insert(messages, { type = "player_left", id = "opponent", disconnectReason = "connection_closed" })
        return messages
    end
    
    -- Append available bytes; keep incomplete trailing line in buffer
    self.buffer = self.buffer .. (data or partial or "")

    while true do
        local nl = self.buffer:find("\n", 1, true)
        if not nl then break end
        local line = self.buffer:sub(1, nl - 1)
        self.buffer = self.buffer:sub(nl + 1)
        -- Strip CR if present (some platforms)
        if line:sub(-1) == "\r" then line = line:sub(1, -2) end

        if line == "PAIRED" then
            print("RelayClient: Opponent connected to relay!")
            self.paired = true
        elseif line == "OPPONENT_LEFT" then
            print("RelayClient: Opponent left the room!")
            self.paired = false
            table.insert(messages, { type = "player_left", id = "opponent", disconnectReason = "opponent_left" })
        elseif line:match("^ERROR:") then
            local errorMsg = line:sub(7)
            print("RelayClient: Server error: " .. errorMsg)
        elseif line ~= "" then
            local msg = Protocol.decode(line)
            if msg and msg.id ~= self.playerId then
                if msg.type == Protocol.MSG.PLAYER_JOIN then 
                    msg.type = "player_joined"
                elseif msg.type == Protocol.MSG.PLAYER_LEAVE then 
                    msg.type = "player_left"
                end
                table.insert(messages, msg)
            end
        end
    end
    
    return messages
end

function RelayClient:send(data)
    if not self.connected or not self.tcp then return false end
    -- Relay protocol expects one message per line
    local success, err = self.tcp:send(data .. "\n")
    if not success then
        print("RelayClient: Send failed: " .. tostring(err))
        if err == "closed" then self.connected = false end
    end
    return success
end

-- Compatible interface with ENet client
function RelayClient:sendBoardSync(gridData, playerId)
    return self:send(Protocol.encode(Protocol.MSG.BOARD_SYNC, playerId or self.playerId, gridData))
end

function RelayClient:sendPieceMove(type, x, y, rot, playerId)
    return self:send(Protocol.encode(Protocol.MSG.PIECE_MOVE, playerId or self.playerId, type, x, y, rot))
end

function RelayClient:sendMessage(msg)
    local id = msg.id or self.playerId
    local encoded
    if msg.type == Protocol.MSG.GARBAGE then
        if msg.target then
            encoded = Protocol.encode(msg.type, id, msg.lines or 0, msg.target)
        else
            encoded = Protocol.encode(msg.type, id, msg.lines or 0)
        end
    elseif msg.type == Protocol.MSG.EFFECT then
        encoded = Protocol.encode(msg.type, id, msg.effect or "fog", msg.target or "", msg.duration or 5)
    elseif msg.type == Protocol.MSG.RACE_WIN then
        encoded = Protocol.encode(msg.type, id)
    elseif msg.type == Protocol.MSG.LOBBY then
        encoded = Protocol.encode(msg.type, id, msg.data or "")
    else
        encoded = Protocol.encode(msg.type, id, msg.data or "")
    end
    return self:send(encoded)
end

function RelayClient:disconnect()
    if self.tcp then
        self.tcp:close()
        self.tcp = nil
    end
    self.connected = false
    self.roomCode = nil
    self.paired = false
    print("RelayClient: Disconnected")
end

return RelayClient
