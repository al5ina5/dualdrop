-- src/net/protocol.lua
-- Network message protocol for Dualdrop
-- Defines how messages are serialized/deserialized

local Protocol = {}

-- Message types
Protocol.MSG = {
    PLAYER_JOIN = "join",     -- New player / peer connected
    PLAYER_LEAVE = "leave",   -- Peer disconnected (may free multiple seats)
    BOARD_SYNC = "board",     -- Full board state sync
    PIECE_MOVE = "move",      -- Current piece position/type update
    GAME_OVER = "over",       -- Player topped out
    START_COUNTDOWN = "scd",  -- Start the 3-2-1 timer
    SCORE_SYNC = "score",     -- Sync player score
    GARBAGE = "garb",         -- Send garbage lines (optional target seat)
    EFFECT = "fx",            -- Chaos power-up attack (flip/fuzz/drunk/fog)
    RACE_WIN = "rwin",        -- Cheese race: seat cleared the board
    PING = "ping",
    PONG = "pong",
    LOBBY = "lobby",          -- Lobby snapshot
    CLAIM = "claim",          -- Claim seats: seat1,seat2
    READY = "ready",          -- Ready toggle 0/1
    UNCLAIM = "unclaim",      -- Release seats for peer
}

-- Sentinel for intentionally empty optional fields (gmatch "[^|]+" drops "")
Protocol.EMPTY = "-"

function Protocol.encode(msgType, ...)
    local parts = {msgType}
    for _, v in ipairs({...}) do
        local s = tostring(v)
        if s == "" then s = Protocol.EMPTY end
        table.insert(parts, s)
    end
    return table.concat(parts, "|")
end

-- Split on "|" while preserving empty segments
function Protocol.split(data)
    local parts = {}
    local start = 1
    local len = #data
    while start <= len + 1 do
        local i = data:find("|", start, true)
        if not i then
            table.insert(parts, data:sub(start))
            break
        end
        table.insert(parts, data:sub(start, i - 1))
        start = i + 1
    end
    return parts
end

local function field(parts, index)
    local v = parts[index]
    if v == nil or v == Protocol.EMPTY then return "" end
    return v
end

function Protocol.decode(data)
    local parts = Protocol.split(data)
    
    local msgType = parts[1]
    local msg = { type = msgType, raw = data }
    
    if msgType == Protocol.MSG.PLAYER_JOIN then
        msg.id = field(parts, 2)
        
    elseif msgType == Protocol.MSG.PLAYER_LEAVE then
        msg.id = field(parts, 2)
        
    elseif msgType == Protocol.MSG.BOARD_SYNC then
        msg.id = field(parts, 2)
        -- Rejoin remainder in case grid ever contains "|"
        msg.gridData = table.concat(parts, "|", 3)
        
    elseif msgType == Protocol.MSG.PIECE_MOVE then
        msg.id = field(parts, 2)
        msg.pieceType = field(parts, 3)
        msg.x = tonumber(field(parts, 4)) or 0
        msg.y = tonumber(field(parts, 5)) or 0
        msg.rotation = tonumber(field(parts, 6)) or 0
        
    elseif msgType == Protocol.MSG.GAME_OVER then
        msg.id = field(parts, 2)
        
    elseif msgType == Protocol.MSG.SCORE_SYNC then
        msg.id = field(parts, 2)
        msg.score = tonumber(field(parts, 3)) or 0

    elseif msgType == Protocol.MSG.GARBAGE then
        msg.id = field(parts, 2)
        msg.lines = tonumber(field(parts, 3)) or 0
        local target = field(parts, 4)
        msg.target = (target ~= "" and target) or nil

    elseif msgType == Protocol.MSG.EFFECT then
        msg.id = field(parts, 2)
        msg.effect = field(parts, 3)
        if msg.effect == "" then msg.effect = "fog" end
        local target = field(parts, 4)
        msg.target = (target ~= "" and target) or nil
        msg.duration = tonumber(field(parts, 5)) or 5

    elseif msgType == Protocol.MSG.RACE_WIN then
        msg.id = field(parts, 2)

    elseif msgType == Protocol.MSG.PING then
        msg.id = field(parts, 2)
        msg.timestamp = tonumber(field(parts, 3)) or 0
        
    elseif msgType == Protocol.MSG.PONG then
        msg.id = field(parts, 2)
        msg.timestamp = tonumber(field(parts, 3)) or 0

    elseif msgType == Protocol.MSG.LOBBY then
        msg.id = field(parts, 2)
        -- Lobby payload may itself contain "|" (legacy format|rules;seats)
        msg.lobbyData = table.concat(parts, "|", 3)

    elseif msgType == Protocol.MSG.CLAIM then
        msg.id = field(parts, 2) -- peer id
        msg.seats = table.concat(parts, "|", 3)

    elseif msgType == Protocol.MSG.READY then
        msg.id = field(parts, 2)
        msg.ready = field(parts, 3) == "1"

    elseif msgType == Protocol.MSG.UNCLAIM then
        msg.id = field(parts, 2)
    end
    
    return msg
end

return Protocol
