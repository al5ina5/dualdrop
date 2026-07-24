-- src/net/server.lua
-- Network server for Dualdrop
-- Hosts the game and relays board/piece updates to all clients

local Protocol = require("src.net.protocol")
local PortUtil = require("src.net.port_util")

local Server = {}
Server.__index = Server

function Server:new(port)
    local self = setmetatable({}, Server)

    self.port = port or 12345

    -- Always clear stale listeners first so hosting never soft-fails on a leftover process
    PortUtil.freeListenPort(self.port)
    if love and love.timer and love.timer.sleep then
        love.timer.sleep(0.05)
    end
    collectgarbage("collect")

    self.host = PortUtil.createENetHost("*:" .. self.port, 4)

    if not self.host then
        print("ERROR: Failed to create server on port " .. self.port)
        return nil
    end
    
    -- Track connected players
    self.players = {}
    self.nextPlayerId = 1
    self.playerId = "host"
    
    print("=== Dualdrop Server Started ===")
    print("Port: " .. self.port)
    
    return self
end

function Server:disconnect()
    if not self.host then return end
    for peer in pairs(self.players) do
        peer:disconnect_now()
    end
    self.host:flush()
    -- Explicit destroy so the OS port is released immediately for re-host
    if self.host.destroy then
        self.host:destroy()
    end
    self.host = nil
    self.players = {}
    collectgarbage("collect")
    print("Server stopped")
end

function Server:broadcast(data, excludePeer, reliable)
    if not self.host then return end
    local flag = reliable and "reliable" or "unreliable"
    for peer in pairs(self.players) do
        if peer ~= excludePeer then
            peer:send(data, 0, flag)
        end
    end
end

function Server:sendBoardSync(gridData, playerId)
    if not self.host then return end
    self:broadcast(Protocol.encode(Protocol.MSG.BOARD_SYNC, playerId or self.playerId or "host", gridData), nil, true)
end

function Server:sendPieceMove(type, x, y, rot, playerId)
    if not self.host then return end
    self:broadcast(Protocol.encode(Protocol.MSG.PIECE_MOVE, playerId or self.playerId or "host", type, x, y, rot))
end

function Server:sendMessage(msg)
    if not self.host then return end
    local id = msg.id or self.playerId or "host"
    local data
    if msg.type == Protocol.MSG.GARBAGE then
        if msg.target then
            data = Protocol.encode(msg.type, id, msg.lines or 0, msg.target)
        else
            data = Protocol.encode(msg.type, id, msg.lines or 0)
        end
    elseif msg.type == Protocol.MSG.EFFECT then
        data = Protocol.encode(msg.type, id, msg.effect or "fog", msg.target or "", msg.duration or 5)
    elseif msg.type == Protocol.MSG.RACE_WIN then
        data = Protocol.encode(msg.type, id)
    elseif msg.type == Protocol.MSG.LOBBY then
        data = Protocol.encode(msg.type, id, msg.data or "")
    elseif msg.type == Protocol.MSG.CLAIM or msg.type == Protocol.MSG.READY or msg.type == Protocol.MSG.UNCLAIM then
        data = Protocol.encode(msg.type, id, msg.data or "")
    else
        data = Protocol.encode(msg.type, id, msg.data or "")
    end
    self:broadcast(data, nil, true)
end

function Server:poll()
    local messages = {}
    if not self.host then return messages end
    
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            local playerId = "p" .. self.nextPlayerId
            self.nextPlayerId = self.nextPlayerId + 1
            self.players[event.peer] = { id = playerId, seats = {} }

            print("Server: Player " .. playerId .. " connected from " .. tostring(event.peer))

            local joinMsg = Protocol.encode(Protocol.MSG.PLAYER_JOIN, playerId)
            print("Server: Sending PLAYER_JOIN to new player: " .. joinMsg)
            event.peer:send(joinMsg, 0, "reliable")

            self:broadcast(Protocol.encode(Protocol.MSG.PLAYER_JOIN, playerId), event.peer, true)

            event.peer:send(Protocol.encode(Protocol.MSG.PLAYER_JOIN, "host"), 0, "reliable")
            for peer, p in pairs(self.players) do
                if peer ~= event.peer then
                    event.peer:send(Protocol.encode(Protocol.MSG.PLAYER_JOIN, p.id), 0, "reliable")
                end
            end

            table.insert(messages, { type = "player_joined", id = playerId })
            
        elseif event.type == "receive" then
            local msg = Protocol.decode(event.data)
            local player = self.players[event.peer]
            
            if player then
                if msg.type == Protocol.MSG.BOARD_SYNC or 
                   msg.type == Protocol.MSG.PIECE_MOVE or 
                   msg.type == Protocol.MSG.GAME_OVER or
                   msg.type == Protocol.MSG.START_COUNTDOWN or
                   msg.type == Protocol.MSG.SCORE_SYNC or
                   msg.type == Protocol.MSG.GARBAGE or
                   msg.type == Protocol.MSG.EFFECT or
                   msg.type == Protocol.MSG.RACE_WIN or
                   msg.type == Protocol.MSG.LOBBY or
                   msg.type == Protocol.MSG.CLAIM or
                   msg.type == Protocol.MSG.READY or
                   msg.type == Protocol.MSG.UNCLAIM or
                   msg.type == Protocol.MSG.PING or
                   msg.type == Protocol.MSG.PONG then
                    self:broadcast(event.data, event.peer, msg.type ~= Protocol.MSG.PIECE_MOVE)
                    table.insert(messages, msg)
                end
            end
            
        elseif event.type == "disconnect" then
            local player = self.players[event.peer]
            if player then
                print("Player " .. player.id .. " disconnected")
                self:broadcast(Protocol.encode(Protocol.MSG.PLAYER_LEAVE, player.id), nil, true)
                table.insert(messages, { type = "player_left", id = player.id, disconnectReason = "opponent_left" })
                self.players[event.peer] = nil
            end
        end
        event = self.host:service(0)
    end
    
    return messages
end

return Server

