-- src/game/connection_manager.lua
-- Manages network connections, hosting, joining, and party lobby

local Client = require('src.net.client')
local Server = require('src.net.server')
local OnlineClient = require('src.net.online_client')
local RelayClient = require('src.net.relay_client')
local NetworkAdapter = require('src.net.network_adapter')
local Protocol = require('src.net.protocol')
local TeamMatch = require('src.game.team_match')
local Audio = require('src.audio')

local ConnectionManager = {}

function ConnectionManager.create()
    return {
        connectionTimer = 0,
        connectionTimeout = 10.0,
        heartbeatTimer = 0,
        heartbeatInterval = 30.0,
        onlineClient = nil,
        pendingClaim = false,
        lobbyReceived = false,
    }
end

function ConnectionManager.broadcastLobby(game)
    if not game.network or not game.lobby then return end
    game.network:sendMessage({
        type = Protocol.MSG.LOBBY,
        id = game.peerId or "host",
        data = TeamMatch.encodeLobby(game.lobby),
    })
end

function ConnectionManager.applyLocalSeats(game, seatIds)
    local LocalSession = require('src.game.local_session')
    local devices = LocalSession.devicesForSeats(game, #seatIds)
    TeamMatch.setupLocalPlayers(game, seatIds, devices)
end

function ConnectionManager.ensureHostLobbySeats(game)
    local LocalSession = require('src.game.local_session')
    -- Host console is always Team A (console vs console)
    local team = "A"
    local count = LocalSession.claimCount(game, team)
    game.localPlayerCount = count
    if game.menu then game.menu.localPlayerCount = count end

    -- Release first so our own seats count as open for reclaim
    TeamMatch.releasePeer(game.lobby, "host")
    local seats = TeamMatch.findClaimableSeats(game.lobby, count, team)
    if not seats and count > 1 then
        seats = TeamMatch.findClaimableSeats(game.lobby, 1, team)
    end
    if not seats then
        print("Connection: Host could not claim Team A seats for local count " .. count)
        return false
    end
    TeamMatch.claimSeats(game.lobby, "host", seats)
    ConnectionManager.applyLocalSeats(game, seats)
    game.peerId = "host"
    return true
end

function ConnectionManager.tryClaimForLocal(game)
    if not game.lobby then return false end
    local LocalSession = require('src.game.local_session')
    local peerId = game.peerId or game.playerId
    if not peerId then return false end

    -- Lock to this console's team before releasing (stay put on hot-join)
    local team = TeamMatch.consoleTeam(game.lobby, peerId, game.isHost)
    local count = LocalSession.claimCount(game, team)
    game.localPlayerCount = count
    if game.menu then game.menu.localPlayerCount = count end

    TeamMatch.releasePeer(game.lobby, peerId)
    local seats = TeamMatch.findClaimableSeats(game.lobby, count, team)
    if not seats and count > 1 then
        seats = TeamMatch.findClaimableSeats(game.lobby, 1, team)
    end
    if not seats then
        print("Connection: No seats on team " .. team .. " for " .. count .. " local players")
        return false
    end
    TeamMatch.claimSeats(game.lobby, peerId, seats)
    ConnectionManager.applyLocalSeats(game, seats)
    if game.network then
        game.network:sendMessage({
            type = Protocol.MSG.CLAIM,
            id = peerId,
            data = table.concat(seats, ","),
        })
    end
    return true
end

-- Re-claim seats from current connected local count (P2 hot-join in lobby)
function ConnectionManager.syncLocalClaims(game)
    if not game.lobby or not game.peerId then return end
    local LocalSession = require('src.game.local_session')
    game.localPlayerCount = LocalSession.claimCount(game)
    if game.menu then game.menu.localPlayerCount = game.localPlayerCount end
    if game.isHost then
        ConnectionManager.ensureHostLobbySeats(game)
        ConnectionManager.broadcastLobby(game)
        ConnectionManager.rebuildRemoteBoardsFromLobby(game)
    else
        ConnectionManager.tryClaimForLocal(game)
    end
end

function ConnectionManager.becomeHost(game)
    if game.network then
        game.network:disconnect()
        game.network = nil
    end
    game.remoteBoards = {}
    game.isHost = true
    if game.menu then
        game.menu.connectionError = nil
    end

    game.network = Server:new(12345)

    if not game.network then
        print("Connection: Failed to create server after freeing port")
        game.isHost = false
        if game.menu then
            game.menu.connectionError = "Could not start host on port 12345.\nClose other Dualdrop windows and try again."
            -- Stay on setup so the error is visible immediately
            local Base = require('src.ui.menu.base')
            game.menu.state = Base.STATE.MATCH_SETUP
            game.menu.setupMode = "host"
            game.menu.selectedIndex = 1
        end
        return
    end

    local format = game.matchFormat or "1v1"
    local rules = game.versusRules or (game.menu and game.menu.versusRules) or "classic"
    local fmt = TeamMatch.getFormat(format)
    game.lobby = TeamMatch.createEmptyLobby(format, rules)
    game.matchFormat = format
    game.versusRules = rules
    game.peerId = "host"
    game.playerId = "host"
    ConnectionManager.ensureHostLobbySeats(game)

    ConnectionManager.startLanAdvertising(game)
    game.stateManager.current = "waiting"

    if game.menu then
        local Base = require('src.ui.menu.base')
        game.menu.state = Base.STATE.LOBBY
        game.menu.selectedIndex = 1
        game.menu.localPlayerCount = game.localPlayerCount or 1
        game.menu.matchFormat = format
        game.menu.versusRules = rules
        game.menu.connectionError = nil
    end
end

function ConnectionManager.stopHosting(game)
    if not game.isHost then return end
    if game.network then
        game.network:disconnect()
        game.network = nil
    end
    ConnectionManager.stopLanAdvertising(game)
    game.isHost = false
    game.remoteBoards = {}
    game.lobby = nil
    game.ownedSeats = nil
    game.localPlayers = nil
    Audio:playMusic('menu')
end

function ConnectionManager.connectToServer(address, port, game)
    if game.isHost then return end
    if game.network then game.network:disconnect() end
    game.remoteBoards = {}
    ConnectionManager.stopLanAdvertising(game)
    game.network = Client:new()
    print("Connection: Attempting to connect to " .. address .. ":" .. port)
    game.network:connect(address or "localhost", port or 12345)
    game.stateManager.current = "waiting"
    game.connectionManager.connectionTimer = 0
    game.connectionManager.pendingClaim = true
    game.connectionManager.lobbyReceived = false
    game.lobby = TeamMatch.createEmptyLobby(game.matchFormat or "1v1", game.versusRules)
end

function ConnectionManager.update(dt, game)
    local cm = game.connectionManager
    
    -- LAN client: assigned peer id
    if game.network and game.network.type == nil and not game.peerId and game.network.playerId then
        game.peerId = game.network.playerId
        game.playerId = game.network.playerId
        print("Connection: Client connected with peerId: " .. game.peerId)
        if not game.isHost then
            cm.connectionTimer = 0
            if cm.pendingClaim then
                -- Wait for lobby snapshot from host before claiming; if none soon, claim anyway
            end
            if game.menu then
                local Base = require('src.ui.menu.base')
                game.menu.state = Base.STATE.LOBBY
                game.menu.selectedIndex = 1
            end
        end
    elseif game.network and game.network.type == nil and not game.isHost and not game.peerId then
        cm.connectionTimer = cm.connectionTimer + dt
        if math.floor(cm.connectionTimer) % 2 == 0 and math.floor(cm.connectionTimer) ~= math.floor(cm.connectionTimer - dt) then
            print("Connection: Still connecting... " .. string.format("%.1f", cm.connectionTimer) .. "/" .. cm.connectionTimeout .. "s")
        end
        if cm.connectionTimer >= cm.connectionTimeout then
            print("Connection: Timeout after " .. cm.connectionTimeout .. " seconds")
            if game.network then
                game.network:disconnect()
                game.network = nil
            end
            game.stateManager.current = "waiting"
            if game.menu then
                game.menu.connectionError = "Could not connect.\nCheck IP/port and that host is waiting."
                local Base = require('src.ui.menu.base')
                game.menu:show(Base.STATE.SUBMENU_LAN)
            end
            cm.connectionTimer = 0
        end
    end

    -- After client has peer id + host lobby snapshot, claim seats once
    if not game.isHost and cm.pendingClaim and cm.lobbyReceived and game.peerId and game.lobby and game.network then
        if ConnectionManager.tryClaimForLocal(game) then
            cm.pendingClaim = false
        end
    end
    
    if game.isHost and game.network and game.network.type == nil and game.discovery then
        local filled = game.lobby and TeamMatch.countFilled(game.lobby) or (1 + game:countRemotePlayers())
        game.discovery:setPlayerCount(filled)
        if game.discovery.serverInfo then
            game.discovery.serverInfo.format = game.matchFormat or "1v1"
        end
    end
    
    ConnectionManager.updateOnline(dt, game)
end

function ConnectionManager.cleanupSession(game)
    if game.isHost then
        ConnectionManager.stopLanAdvertising(game)
    end

    if game.network then
        if game.network.disconnect then
            game.network:disconnect()
        end
        game.network = nil
    end

    if game.connectionManager and game.connectionManager.onlineClient then
        if game.connectionManager.onlineClient.disconnect then
            game.connectionManager.onlineClient:disconnect()
        end
        game.connectionManager.onlineClient = nil
    end

    game.remoteBoards = {}
    game.playerId = nil
    game.peerId = nil
    game.isHost = false
    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = { x = 0, y = 0, rot = 0, type = "" }
    game.lobby = nil
    game.ownedSeats = nil
    game.localPlayers = nil
    game.localVersus = false

    if game.connectionManager then
        game.connectionManager.connectionTimer = 0
        game.connectionManager.heartbeatTimer = 0
        game.connectionManager.pendingClaim = false
        game.connectionManager.lobbyReceived = false
        game.connectionManager.onlineClient = nil
    end
end

function ConnectionManager.returnToMainMenu(game)
    print("Connection: Returning to main menu")
    ConnectionManager.cleanupSession(game)

    game.stateManager.current = "waiting"
    game.stateManager.disconnectReason = nil
    game.stateManager.disconnectPauseTimer = 0
    game.stateManager.countdownTimer = 0
    game.stateManager.gameOverTimer = 0

    local TetrisBoard = require('src.tetris.board')
    game.localBoard = TetrisBoard:new(10, 20)

    if game.menu then
        local Base = require('src.ui.menu.base')
        game.menu.onlineRoomCode = nil
        game.menu.connectionError = nil
        game.menu.onlineError = nil
        if not game.menu:isVisible() or game.menu.state == Base.STATE.PAUSE then
            game.menu:show(Base.STATE.MAIN)
        end
    end

    Audio:playMusic('menu')
end

function ConnectionManager.handleSessionAbandoned(game, reason)
    print("Connection: Session abandoned (" .. tostring(reason) .. ")")
    ConnectionManager.cleanupSession(game)

    game.stateManager.current = "waiting"
    game.stateManager.disconnectReason = nil
    game.stateManager.disconnectPauseTimer = 0

    if game.menu then
        local Base = require('src.ui.menu.base')
        game.menu.onlineRoomCode = nil
        game.menu.connectionError = nil
        game.menu:show(Base.STATE.MAIN)
    end

    Audio:playMusic('menu')
end

function ConnectionManager.toggleReady(game)
    if not game.lobby or not game.peerId then return end
    local seats = TeamMatch.seatsForPeer(game.lobby, game.peerId)
    local ready = true
    for _, id in ipairs(seats) do
        if game.lobby.seats[id] and game.lobby.seats[id].ready then
            ready = false
            break
        end
    end
    TeamMatch.setPeerReady(game.lobby, game.peerId, ready)
    if game.network then
        game.network:sendMessage({
            type = Protocol.MSG.READY,
            id = game.peerId,
            data = ready and "1" or "0",
        })
    end
    if game.isHost then
        ConnectionManager.broadcastLobby(game)
    end
end

-- LAN: only advertise while the lobby is joinable (waiting), not mid-match / solo.
function ConnectionManager.hostDisplayName()
    local hostName = "Dualdrop"
    if love.system and love.system.getHostname then
        local hn = love.system.getHostname()
        if hn and hn ~= "" then
            hostName = hn
        end
    end
    return hostName
end

function ConnectionManager.startLanAdvertising(game)
    if not game.discovery or not game.discovery.startAdvertising then return end
    local format = game.matchFormat or "1v1"
    local fmt = TeamMatch.getFormat(format)
    game.discovery:startAdvertising(ConnectionManager.hostDisplayName(), 12345, fmt.maxSeats, format)
    local filled = game.lobby and TeamMatch.countFilled(game.lobby) or 1
    game.discovery:setPlayerCount(filled)
end

function ConnectionManager.stopLanAdvertising(game)
    if game.discovery and game.discovery.stopAdvertising then
        game.discovery:stopAdvertising()
    end
end

function ConnectionManager.hostStartMatch(game)
    if not game.isHost then return end
    if not game.lobby or not TeamMatch.canStartMatch(game.lobby) then
        print("Connection: Cannot start — need at least one guest")
        return
    end
    -- Sync final lobby snapshot so guests have format/rules/seats
    for _, seat in pairs(game.lobby.seats) do
        if seat.peerId then seat.ready = true end
    end
    ConnectionManager.broadcastLobby(game)
    ConnectionManager.stopLanAdvertising(game)
    if game.menu then game.menu:hide() end
    local StateManager = require('src.game.state_manager')
    StateManager.startCountdown(game.stateManager, game)
end

function ConnectionManager.changeLocalCount(game, count)
    -- Legacy: prefer syncLocalClaims from connected pads
    local LocalSession = require('src.game.local_session')
    if count and count >= 2 and not game.p2Device then
        -- Keep API for rare callers; still claim from LocalSession when possible
        game.localPlayerCount = 2
    end
    ConnectionManager.syncLocalClaims(game)
end

function ConnectionManager.rebuildRemoteBoardsFromLobby(game)
    local TetrisBoard = require('src.tetris.board')
    local fmt = TeamMatch.getFormat(game.matchFormat or (game.lobby and game.lobby.format) or "1v1")
    local keep = {}
    local inMatch = game.state == "playing" or game.state == "countdown" or game.state == "over"

    for _, seatId in ipairs(fmt.seats) do
        local seat = game.lobby and game.lobby.seats[seatId]
        if seat and seat.peerId and not TeamMatch.isLocalSeat(game, seatId) then
            keep[seatId] = game.remoteBoards[seatId] or TetrisBoard:new(10, 20)
            if not keep[seatId].currentPiece then
                keep[seatId].currentPiece = nil
            end
        end
    end

    -- Mid-match: never drop live remotes just because a lobby snapshot was incomplete
    if inMatch then
        for id, board in pairs(game.remoteBoards or {}) do
            if board and not keep[id] then
                keep[id] = board
            end
        end
    end

    game.remoteBoards = keep
end

-- Fresh boards + synced rules right before countdown
function ConnectionManager.prepareMatchStart(game)
    if game.lobby then
        game.matchFormat = game.lobby.format or game.matchFormat or "1v1"
        game.versusRules = game.lobby.rules or game.versusRules or "classic"
        if game.menu then
            game.menu.matchFormat = game.matchFormat
            game.menu.versusRules = game.versusRules
        end
    end

    local TeamMatch = require('src.game.team_match')
    local TetrisBoard = require('src.tetris.board')
    local VersusRules = require('src.game.versus_rules')
    local LocalSession = require('src.game.local_session')

    -- Same-machine splitscreen versus: keep a1/b1 duo, refresh boards
    if game.localVersus then
        if game.ownedSeats and #game.ownedSeats >= 2 then
            TeamMatch.refreshLocalBoards(game)
        elseif LocalSession.canStartLocalVersus(game) then
            LocalSession.beginLocalVersus(game, game.versusRules)
            TeamMatch.refreshLocalBoards(game)
        else
            -- Should not reach countdown without P2; fall back to solo boards
            LocalSession.prepareSoloBoards(game)
            return
        end
        VersusRules.seedMatchBoards(game)
        return
    end

    -- Solo / no lobby: use localPlayers path (supports P2 hot-join)
    if not game.lobby then
        LocalSession.prepareSoloBoards(game)
        return
    end

    -- Ensure local seats still match lobby claims (count from connected locals)
    game.localPlayerCount = LocalSession.claimCount(game)
    if game.peerId then
        local seats = TeamMatch.seatsForPeer(game.lobby, game.peerId)
        local want = LocalSession.claimCount(game)
        if #seats ~= want then
            ConnectionManager.syncLocalClaims(game)
            seats = TeamMatch.seatsForPeer(game.lobby, game.peerId)
        end
        if #seats > 0 then
            ConnectionManager.applyLocalSeats(game, seats)
        end
    end

    ConnectionManager.rebuildRemoteBoardsFromLobby(game)

    -- Reset remotes to clean boards; no placeholder piece until first PIECE_MOVE
    for id, _ in pairs(game.remoteBoards) do
        game.remoteBoards[id] = TetrisBoard:new(10, 20)
        game.remoteBoards[id].gameOver = false
        game.remoteBoards[id].raceWon = false
        game.remoteBoards[id].currentPiece = nil
    end

    if game.ownedSeats and #game.ownedSeats > 0 then
        TeamMatch.refreshLocalBoards(game)
    else
        game.localBoard = TetrisBoard:new(10, 20)
    end

    VersusRules.seedMatchBoards(game)
end

-- Online multiplayer functions

function ConnectionManager.hostOnline(isPublic, game)
    if not OnlineClient.isAvailable() then
        print("Connection: Online multiplayer not available (HTTPS support not found)")
        game.menu.onlineError = "Online multiplayer requires HTTPS support.\nPlease use LAN multiplayer instead."
        return false
    end
    
    print("Connection: Creating online room (public: " .. tostring(isPublic) .. ")")
    
    local onlineClient, initErr = OnlineClient:new()
    if not onlineClient then
        print("Connection: Failed to initialize online client: " .. tostring(initErr))
        game.menu.onlineError = "Failed to initialize online client"
        return false
    end

    local format = game.matchFormat or "1v1"
    local fmt = TeamMatch.getFormat(format)
    local LocalSession = require('src.game.local_session')
    local localCount = LocalSession.claimCount(game)
    game.localPlayerCount = localCount
    
    local roomSuccess, roomCode = onlineClient:createRoom(isPublic, {
        format = format,
        maxSeats = fmt.maxSeats,
        seatsUsed = localCount,
    })
    
    if not roomSuccess then
        print("Connection: Failed to create online room")
        game.menu.state = game.menu.STATE.ONLINE_HOST
        return false
    end
    
    print("Connection: Online room created with code: " .. roomCode)
    
    local relayClient = RelayClient:new()
    if not relayClient:connect(roomCode, "host") then
        print("Connection: Failed to connect to relay server")
        game.menu.onlineError = "Failed to connect to real-time relay server.\nCheck your internet connection."
        return false
    end

    game.network = NetworkAdapter:createRelay(relayClient)
    game.isHost = true
    game.peerId = "host"
    game.playerId = "host"
    game.matchFormat = format
    game.lobby = TeamMatch.createEmptyLobby(format, game.versusRules or "classic")
    if game.lobby then game.versusRules = game.lobby.rules end
    ConnectionManager.ensureHostLobbySeats(game)
    game.connectionManager.onlineClient = onlineClient
    
    game.menu.onlineRoomCode = roomCode
    local Base = require('src.ui.menu.base')
    game.menu.state = Base.STATE.LOBBY
    game.menu.selectedIndex = 1
    game.stateManager.current = "waiting"
    
    return true
end

function ConnectionManager.joinOnline(roomCode, game)
    if not OnlineClient.isAvailable() then
        print("Connection: Online multiplayer not available (HTTPS support not found)")
        game.menu.onlineError = "Online multiplayer requires HTTPS support.\nPlease use LAN multiplayer instead."
        return false
    end
    
    print("Connection: Joining online room " .. roomCode)
    
    local onlineClient, initErr = OnlineClient:new()
    if not onlineClient then
        print("Connection: Failed to initialize online client: " .. tostring(initErr))
        game.menu.onlineError = "Failed to initialize online client"
        return false
    end

    local LocalSession = require('src.game.local_session')
    local localCount = LocalSession.claimCount(game)
    game.localPlayerCount = localCount
    local joinSuccess, error = onlineClient:joinRoom(roomCode, localCount)
    
    if not joinSuccess then
        print("Connection: Failed to join online room: " .. tostring(error))
        game.menu.onlineError = "Failed to join room: " .. tostring(error)
        return false
    end

    if onlineClient.roomFormat then
        game.matchFormat = onlineClient.roomFormat
    end
    
    print("Connection: Successfully joined online room")
    
    -- Unique guest peer id (never hardcode "client" — multi-guest rooms collide)
    local peerId = ConnectionManager.makeGuestPeerId()
    local relayClient = RelayClient:new()
    if not relayClient:connect(roomCode, peerId) then
        print("Connection: Failed to connect to relay server")
        game.menu.onlineError = "Failed to connect to real-time relay server."
        return false
    end

    game.network = NetworkAdapter:createRelay(relayClient)
    game.isHost = false
    game.peerId = peerId
    game.playerId = peerId
    game.matchFormat = game.matchFormat or "1v1"
    game.lobby = TeamMatch.createEmptyLobby(game.matchFormat, game.versusRules or "classic")
    game.connectionManager.onlineClient = onlineClient
    game.connectionManager.pendingClaim = true
    game.connectionManager.lobbyReceived = false
    
    relayClient:send(Protocol.encode(Protocol.MSG.PLAYER_JOIN, peerId))
    
    local Base = require('src.ui.menu.base')
    game.menu.state = Base.STATE.LOBBY
    game.menu.selectedIndex = 1
    game.stateManager.current = "waiting"
    
    return true
end

function ConnectionManager.makeGuestPeerId()
    local t = math.floor((love.timer.getTime() % 1000) * 1000)
    local r = love.math.random(1000, 9999)
    return string.format("g%04d%04d", t % 10000, r)
end

function ConnectionManager.refreshOnlineRooms(game)
    if not OnlineClient.isAvailable() then
        print("Connection: Online multiplayer not available (HTTPS support not found)")
        game.menu.onlineRooms = {}
        game.menu.onlineError = "Online multiplayer requires HTTPS support.\nPlease use LAN multiplayer instead."
        return
    end
    
    print("Connection: Refreshing online rooms list")
    
    local onlineClient, initErr = OnlineClient:new()
    if not onlineClient then
        print("Connection: Failed to initialize online client: " .. tostring(initErr))
        game.menu.onlineRooms = {}
        game.menu.onlineError = "Failed to initialize online client"
        return
    end
    
    local rooms = onlineClient:listRooms()
    
    print("Connection: Found " .. #rooms .. " online rooms")
    game.menu.onlineRooms = rooms
end

function ConnectionManager.updateOnline(dt, game)
    local cm = game.connectionManager
    
    if cm.onlineClient and game.isHost then
        cm.heartbeatTimer = cm.heartbeatTimer + dt
        if cm.heartbeatTimer >= cm.heartbeatInterval then
            local seats = game.lobby and TeamMatch.countFilled(game.lobby) or nil
            if cm.onlineClient.heartbeat then
                cm.onlineClient:heartbeat(seats)
            end
            cm.heartbeatTimer = 0
        end
    end

    if not game.isHost and cm.pendingClaim and cm.lobbyReceived and game.peerId and game.lobby and game.network and game.network.type then
        if ConnectionManager.tryClaimForLocal(game) then
            cm.pendingClaim = false
        end
    end

    if game.network and game.state == "waiting" then
        game.pingTimer = game.pingTimer + dt
        if game.pingTimer >= 2.0 then
            game.network:sendMessage({
                type = Protocol.MSG.PING,
                data = tostring(love.timer.getTime())
            })
            game.pingTimer = 0
        end
    end
end

return ConnectionManager
