-- src/game/network_handler.lua
-- Handles all network message processing and synchronization

local Protocol = require('src.net.protocol')
local Audio = require('src.audio')
local TeamMatch = require('src.game.team_match')

local NetworkHandler = {}

function NetworkHandler.handleMessage(msg, game)
    print("NetworkHandler: Received message type: " .. tostring(msg.type) .. " from " .. tostring(msg.id))
    if msg.type == "player_joined" then
        NetworkHandler.handlePlayerJoined(msg, game)
    elseif msg.type == Protocol.MSG.START_COUNTDOWN then
        NetworkHandler.handleStartCountdown(msg, game)
    elseif msg.type == Protocol.MSG.SCORE_SYNC then
        NetworkHandler.handleScoreSync(msg, game)
    elseif msg.type == Protocol.MSG.BOARD_SYNC then
        NetworkHandler.handleBoardSync(msg, game)
    elseif msg.type == Protocol.MSG.PIECE_MOVE then
        NetworkHandler.handlePieceMove(msg, game)
    elseif msg.type == Protocol.MSG.GAME_OVER then
        NetworkHandler.handleGameOver(msg, game)
    elseif msg.type == Protocol.MSG.GARBAGE then
        NetworkHandler.handleGarbage(msg, game)
    elseif msg.type == Protocol.MSG.EFFECT then
        NetworkHandler.handleEffect(msg, game)
    elseif msg.type == Protocol.MSG.RACE_WIN then
        NetworkHandler.handleRaceWin(msg, game)
    elseif msg.type == Protocol.MSG.LOBBY then
        NetworkHandler.handleLobby(msg, game)
    elseif msg.type == Protocol.MSG.CLAIM then
        NetworkHandler.handleClaim(msg, game)
    elseif msg.type == Protocol.MSG.READY then
        NetworkHandler.handleReady(msg, game)
    elseif msg.type == Protocol.MSG.UNCLAIM then
        NetworkHandler.handleUnclaim(msg, game)
    elseif msg.type == Protocol.MSG.PING then
        if game.network then
            game.network:sendMessage({
                type = Protocol.MSG.PONG,
                data = tostring(msg.timestamp)
            })
        end
    elseif msg.type == Protocol.MSG.PONG then
        if msg.timestamp and msg.timestamp > 0 then
            local rtt = love.timer.getTime() - msg.timestamp
            game.latency = (game.latency * 0.8) + (rtt * 0.2)
            print(string.format("Network: Measured RTT: %.1fms (compensated: %.1fms)", rtt * 1000, (game.latency / 2) * 1000))
        end
    elseif msg.type == "player_left" then
        NetworkHandler.handlePlayerLeft(msg, game)
    else
        print("NetworkHandler: Unknown message type: " .. tostring(msg.type))
    end
end

function NetworkHandler.handleLobby(msg, game)
    local lobby = TeamMatch.decodeLobby(msg.lobbyData or msg.data or "")
    if not lobby then return end
    game.lobby = lobby
    game.matchFormat = lobby.format
    game.versusRules = lobby.rules or "classic"
    if game.connectionManager then
        game.connectionManager.lobbyReceived = true
    end
    local ConnectionManager = require('src.game.connection_manager')
    ConnectionManager.rebuildRemoteBoardsFromLobby(game)

    -- Refresh local seats if we already own some
    if game.peerId then
        local seats = TeamMatch.seatsForPeer(lobby, game.peerId)
        if #seats > 0 and (not game.ownedSeats or table.concat(game.ownedSeats, ",") ~= table.concat(seats, ",")) then
            ConnectionManager.applyLocalSeats(game, seats)
        end
    end

    if game.menu then
        game.menu.matchFormat = lobby.format
        game.menu.versusRules = lobby.rules or "classic"
    end
end

function NetworkHandler.handleClaim(msg, game)
    if not game.isHost or not game.lobby then return end
    local peerId = msg.id
    local seatList = {}
    for seat in string.gmatch(msg.seats or msg.data or "", "[^,]+") do
        table.insert(seatList, seat)
    end
    if #seatList == 0 then return end

    TeamMatch.releasePeer(game.lobby, peerId)
    if TeamMatch.claimSeats(game.lobby, peerId, seatList) then
        local ConnectionManager = require('src.game.connection_manager')
        ConnectionManager.rebuildRemoteBoardsFromLobby(game)
        ConnectionManager.broadcastLobby(game)
    else
        print("Network: Rejected claim from " .. tostring(peerId))
        local ConnectionManager = require('src.game.connection_manager')
        ConnectionManager.broadcastLobby(game)
    end
end

function NetworkHandler.handleReady(msg, game)
    if not game.lobby then return end
    TeamMatch.setPeerReady(game.lobby, msg.id, msg.ready)
    if game.isHost then
        local ConnectionManager = require('src.game.connection_manager')
        ConnectionManager.broadcastLobby(game)
    end
end

function NetworkHandler.handleUnclaim(msg, game)
    if not game.lobby then return end
    TeamMatch.releasePeer(game.lobby, msg.id)
    if game.isHost then
        local ConnectionManager = require('src.game.connection_manager')
        ConnectionManager.rebuildRemoteBoardsFromLobby(game)
        ConnectionManager.broadcastLobby(game)
    end
end

function NetworkHandler.handlePlayerJoined(msg, game)
    print("Network: Peer joined: " .. msg.id)
    -- Peer presence only; seats come from lobby claims
    if game.isHost and game.network and msg.id ~= "host" then
        -- Announce host peer still present + send lobby
        game.network:sendMessage({ type = Protocol.MSG.PLAYER_JOIN, id = "host" })
        local ConnectionManager = require('src.game.connection_manager')
        ConnectionManager.broadcastLobby(game)
    end

    if not game.isHost and game.menu and game.menu:isVisible() then
        local Base = require('src.ui.menu.base')
        if game.menu.state == Base.STATE.CONNECTING then
            game.menu.state = Base.STATE.LOBBY
        end
    end
end

function NetworkHandler.handleStartCountdown(msg, game)
    if game.menu and game.menu:isVisible() then
        local Base = require('src.ui.menu.base')
        local st = game.menu.state
        if st == Base.STATE.MAIN or st == Base.STATE.SUBMENU_MULTIPLAYER
            or st == Base.STATE.SUBMENU_LAN or st == Base.STATE.SUBMENU_ONLINE
            or st == Base.STATE.SUBMENU_SINGLEPLAYER then
            print("Network: Ignoring START_COUNTDOWN — local player is in menu")
            return
        end
    end

    if game.state == "waiting" or game.state == "over" then
        if game.state == "over" then
            local StateManager = require('src.game.state_manager')
            StateManager.reset(game.stateManager, game)
        end
        game.stateManager.current = "countdown"
        
        local compensation = game.latency / 2
        game.stateManager.countdownTimer = 3.0 - compensation
        
        print(string.format("Network: Starting countdown with %.1fms compensation", compensation * 1000))
        Audio:play('beep')

        if game.menu:isVisible() then
            game.menu:hide()
        end

        local ConnectionManager = require('src.game.connection_manager')
        ConnectionManager.prepareMatchStart(game)
        NetworkHandler.syncLocalState(game)
    end
end

function NetworkHandler.ensureRemoteBoard(game, seatId)
    if not seatId or seatId == "" then return nil end
    if TeamMatch.isLocalSeat(game, seatId) then return nil end
    local board = game.remoteBoards[seatId]
    if board then return board end
    local TetrisBoard = require('src.tetris.board')
    board = TetrisBoard:new(10, 20)
    board.currentPiece = nil
    game.remoteBoards[seatId] = board
    return board
end

function NetworkHandler.handleScoreSync(msg, game)
    local board = NetworkHandler.ensureRemoteBoard(game, msg.id)
    if board then
        board.score = tonumber(msg.score) or 0
    end
end

function NetworkHandler.handleBoardSync(msg, game)
    if TeamMatch.isLocalSeat(game, msg.id) then return end
    local board = NetworkHandler.ensureRemoteBoard(game, msg.id)
    if not board then return end
    board:deserializeGrid(msg.gridData)
end

function NetworkHandler.handlePieceMove(msg, game)
    if TeamMatch.isLocalSeat(game, msg.id) then return end
    local TetrisBoard = require('src.tetris.board')
    local board = NetworkHandler.ensureRemoteBoard(game, msg.id)
    if not board then return end
    
    if not board.currentPiece or board.currentPiece.type ~= msg.pieceType then
        local data = TetrisBoard.PIECES[msg.pieceType]
        if data then
            board.currentPiece = {
                type = msg.pieceType,
                shape = board:copyTable(data),
                color = data.color
            }
            board.rotationIndex = 0
        end
    end
    board.pieceX = msg.x
    board.pieceY = msg.y
    
    if board.rotationIndex ~= msg.rotation then
        local data = TetrisBoard.PIECES[msg.pieceType]
        if data then
            board.currentPiece.shape = board:copyTable(data)
            board.rotationIndex = 0
            for i = 1, msg.rotation do
                local oldShape = board.currentPiece.shape
                local n = #oldShape
                local newShape = {}
                for j = 1, n do newShape[j] = {} end
                for y = 1, n do
                    for x = 1, n do
                        newShape[x][n - y + 1] = oldShape[y][x]
                    end
                end
                board.currentPiece.shape = newShape
                board.rotationIndex = (board.rotationIndex + 1) % 4
            end
        end
    end
end

function NetworkHandler.handleGameOver(msg, game)
    local board = NetworkHandler.ensureRemoteBoard(game, msg.id)
    if board then
        board.gameOver = true
        board.currentPiece = nil
    end

    -- Resolve match immediately so joiners don't wait on a missed poll frame
    if game.state == "playing" and game.gameMode == "VERSUS" then
        local result = TeamMatch.versusResult(game)
        if result then
            local StateManager = require('src.game.state_manager')
            StateManager.enterGameOver(game.stateManager, game, result)
            Audio:stopMusic()
            local Scores = require('src.data.scores')
            Scores.addMatch("VERSUS", game.localBoard and game.localBoard.score or 0, game.matchTime or 0, result, {
                lines = game.localBoard and game.localBoard.linesCleared or 0
            })
        end
    end
end

function NetworkHandler.handleGarbage(msg, game)
    print("Network: Received " .. tostring(msg.lines) .. " garbage from " .. tostring(msg.id) .. " target=" .. tostring(msg.target))
    local target = msg.target
    if target then
        for _, lp in ipairs(game.localPlayers or {}) do
            if lp.id == target then
                lp.board:receiveGarbage(msg.lines)
                return
            end
        end
        return
    end
    -- Legacy: no target — apply to first local board if enemy
    if game.localBoard and TeamMatch.isEnemy(msg.id, game.ownedSeats and game.ownedSeats[1] or "b1") then
        game.localBoard:receiveGarbage(msg.lines)
    elseif game.localBoard and not game.ownedSeats then
        game.localBoard:receiveGarbage(msg.lines)
    end
end

function NetworkHandler.handleEffect(msg, game)
    local VersusRules = require('src.game.versus_rules')
    local target = msg.target
    local effect = msg.effect or "fog"
    local duration = msg.duration
    print("Network: Effect " .. tostring(effect) .. " from " .. tostring(msg.id) .. " -> " .. tostring(target))
    if target then
        for _, lp in ipairs(game.localPlayers or {}) do
            if lp.id == target then
                VersusRules.applyEffect(lp.board, effect, duration)
                Audio:play('item')
                return
            end
        end
    end
end

function NetworkHandler.handleRaceWin(msg, game)
    local seatId = msg.id
    print("Network: Race win from " .. tostring(seatId))
    local board = TeamMatch.getBoard(game, seatId) or NetworkHandler.ensureRemoteBoard(game, seatId)
    if board then
        board.raceWon = true
    end
end

function NetworkHandler.handlePlayerLeft(msg, game)
    print("Network: Peer left: " .. tostring(msg.id) .. " (reason: " .. tostring(msg.disconnectReason) .. ")")

    local TetrisBoard = require('src.tetris.board')

    -- Online relay often sends generic "opponent"
    if msg.id == "opponent" and game.lobby then
        for seatId, seat in pairs(game.lobby.seats) do
            if seat.peerId and seat.peerId ~= game.peerId then
                seat.peerId = nil
                seat.ready = false
                local board = game.remoteBoards[seatId]
                if not board then
                    board = TetrisBoard:new(10, 20)
                    game.remoteBoards[seatId] = board
                end
                board.gameOver = true
                board.currentPiece = nil
            end
        end
    end
    
    local freed = {}
    if game.lobby and msg.id ~= "opponent" then
        freed = TeamMatch.releasePeer(game.lobby, msg.id)
    end

    for _, seatId in ipairs(freed) do
        local board = game.remoteBoards[seatId]
        if not board then
            board = TetrisBoard:new(10, 20)
            game.remoteBoards[seatId] = board
        end
        board.gameOver = true
        board.currentPiece = nil
    end

    -- Legacy peer-id keyed boards
    if #freed == 0 and msg.id ~= "opponent" then
        if game.remoteBoards[msg.id] then
            game.remoteBoards[msg.id].gameOver = true
        end
        for seatId, seat in pairs(game.lobby and game.lobby.seats or {}) do
            if seat.peerId == msg.id then
                seat.peerId = nil
                seat.ready = false
                local board = game.remoteBoards[seatId]
                if not board then
                    board = TetrisBoard:new(10, 20)
                    game.remoteBoards[seatId] = board
                end
                board.gameOver = true
            end
        end
    end

    local remainingAlive = 0
    for id, board in pairs(game.remoteBoards) do
        if board and not board.gameOver then
            remainingAlive = remainingAlive + 1
        end
    end

    if game.state == "playing" or game.state == "countdown" then
        local result = TeamMatch.versusResult(game)
        if result == "WIN" then
            local StateManager = require('src.game.state_manager')
            StateManager.enterGameOver(game.stateManager, game, "WIN")
            Audio:stopMusic()
            local Scores = require('src.data.scores')
            Scores.addMatch("VERSUS", game.localBoard and game.localBoard.score or 0, game.matchTime or 0, "WIN")
        elseif remainingAlive == 0 and (not game.matchFormat or game.matchFormat == "1v1") then
            local StateManager = require('src.game.state_manager')
            StateManager.enterDisconnectedPause(game.stateManager, game, msg.disconnectReason)
        end
    elseif game.state == "over" then
        if remainingAlive == 0 then
            if game.network then
                if game.network.disconnect then game.network:disconnect() end
                game.network = nil
            end
            if game.connectionManager and game.connectionManager.onlineClient then
                if game.connectionManager.onlineClient.disconnect then
                    game.connectionManager.onlineClient:disconnect()
                end
                game.connectionManager.onlineClient = nil
            end
            game.isHost = true
            game.playerId = nil
        end
    elseif game.isHost and game.menu and game.menu:isVisible() then
        print("Network: Guest left while host in lobby, staying")
        local ConnectionManager = require('src.game.connection_manager')
        ConnectionManager.broadcastLobby(game)
        ConnectionManager.rebuildRemoteBoardsFromLobby(game)
    else
        if remainingAlive == 0 and not game.isHost then
            print("Network: Session abandoned during waiting, returning to main menu")
            local ConnectionManager = require('src.game.connection_manager')
            ConnectionManager.handleSessionAbandoned(game, msg.disconnectReason or "opponent_left")
        end
    end
end

function NetworkHandler.syncLocalState(game)
    if not game.network then return end

    local players = game.localPlayers
    if not players or #players == 0 then
        players = {{
            id = game.playerId or "host",
            board = game.localBoard,
            lastSentMove = game.lastSentMove,
            sentGameOver = game.sentGameOver,
        }}
    end

    for _, lp in ipairs(players) do
        local board = lp.board
        if board then
            local px, py = board.pieceX, board.pieceY
            local ptype = board.currentPiece and board.currentPiece.type or "I"
            local rot = board.rotationIndex or 0
            local last = lp.lastSentMove or game.lastSentMove

            if last.x ~= px or last.y ~= py or last.type ~= ptype or last.rot ~= rot then
                game.network:sendPieceMove(ptype, px, py, rot, lp.id)
                lp.lastSentMove = { x = px, y = py, type = ptype, rot = rot }
                if lp == players[1] then
                    game.lastSentMove = lp.lastSentMove
                end
            end

            if board.gridChanged then
                game.network:sendBoardSync(board:serializeGrid(), lp.id)
                board.gridChanged = false
            end

            if board.gameOver and not lp.sentGameOver then
                game.network:sendMessage({ type = Protocol.MSG.GAME_OVER, id = lp.id })
                lp.sentGameOver = true
                if lp == players[1] then game.sentGameOver = true end
            end
        end
    end
end

function NetworkHandler.syncScore(game)
    if not game.network then return end
    local players = game.localPlayers
    if not players or #players == 0 then
        if game.localBoard and game.localBoard.score ~= game.lastSentScore then
            game.network:sendMessage({
                type = Protocol.MSG.SCORE_SYNC,
                id = game.playerId or "host",
                data = game.localBoard.score
            })
            game.lastSentScore = game.localBoard.score
        end
        return
    end
    for _, lp in ipairs(players) do
        if lp.board and lp.board.score ~= lp.lastSentScore then
            game.network:sendMessage({
                type = Protocol.MSG.SCORE_SYNC,
                id = lp.id,
                data = lp.board.score
            })
            lp.lastSentScore = lp.board.score
            if lp == players[1] then game.lastSentScore = lp.lastSentScore end
        end
    end
end

function NetworkHandler.sendGarbage(game, lines, fromSeat)
    fromSeat = fromSeat or (game.ownedSeats and game.ownedSeats[1]) or game.playerId or "host"
    local targets = TeamMatch.listEnemyTargets(game, fromSeat)
    if #targets == 0 then return end

    for _, target in ipairs(targets) do
        local deliveredLocal = false
        for _, lp in ipairs(game.localPlayers or {}) do
            if lp.id == target and lp.board then
                lp.board:receiveGarbage(lines)
                deliveredLocal = true
                break
            end
        end
        if not deliveredLocal and game.network then
            game.network:sendMessage({
                type = Protocol.MSG.GARBAGE,
                id = fromSeat,
                lines = lines,
                target = target,
            })
        end
    end
end

function NetworkHandler.sendEffect(game, effect, fromSeat)
    if not effect then return false end
    local VersusRules = require('src.game.versus_rules')
    if not VersusRules.isChaos(game) then return false end
    fromSeat = fromSeat or (game.ownedSeats and game.ownedSeats[1]) or game.playerId or "host"
    local targets = TeamMatch.listEnemyTargets(game, fromSeat)
    if #targets == 0 then return false end
    local duration = VersusRules.EFFECT_DURATION[effect] or 5
    local any = false

    for _, target in ipairs(targets) do
        local deliveredLocal = false
        for _, lp in ipairs(game.localPlayers or {}) do
            if lp.id == target and lp.board then
                VersusRules.applyEffect(lp.board, effect, duration)
                Audio:play('item')
                deliveredLocal = true
                any = true
                break
            end
        end
        if not deliveredLocal and game.network then
            game.network:sendMessage({
                type = Protocol.MSG.EFFECT,
                id = fromSeat,
                effect = effect,
                target = target,
                duration = duration,
            })
            any = true
        end
    end
    return any
end

function NetworkHandler.sendRaceWin(game, fromSeat)
    fromSeat = fromSeat or (game.ownedSeats and game.ownedSeats[1]) or game.playerId or "host"
    local board = TeamMatch.getBoard(game, fromSeat)
    if board then
        board.raceWon = true
    end
    if not game.network then return end
    game.network:sendMessage({
        type = Protocol.MSG.RACE_WIN,
        id = fromSeat,
    })
end

return NetworkHandler
