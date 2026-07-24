-- src/game/state_manager.lua
-- Manages game state machine and transitions

local Audio = require('src.audio')
local Scores = require('src.data.scores')

local StateManager = {}

StateManager.STATES = {
    WAITING = "waiting",
    COUNTDOWN = "countdown",
    PLAYING = "playing",
    GAME_OVER = "over",
    DISCONNECTED_PAUSE = "disconnected_pause"
}

function StateManager.create()
    return {
        current = StateManager.STATES.WAITING,
        countdownTimer = 0,
        gameOverTimer = 0,
        disconnectPauseTimer = 0,
        disconnectReason = nil  -- "opponent_left", "connection_closed", etc.
    }
end

function StateManager.update(state, dt, game)
    if state.current == StateManager.STATES.WAITING then
        StateManager.updateWaiting(state, game)
    elseif state.current == StateManager.STATES.COUNTDOWN then
        StateManager.updateCountdown(state, dt, game)
    elseif state.current == StateManager.STATES.PLAYING then
        StateManager.updatePlaying(state, dt, game)
    elseif state.current == StateManager.STATES.GAME_OVER then
        StateManager.updateGameOver(state, dt, game)
    elseif state.current == StateManager.STATES.DISCONNECTED_PAUSE then
        StateManager.updateDisconnectedPause(state, dt, game)
    end
end

function StateManager.updateWaiting(state, game)
    -- Never auto-start a match while the player is browsing menus
    if game.menu and game.menu:isVisible() then
        local Base = require('src.ui.menu.base')
        local st = game.menu.state
        if st ~= Base.STATE.WAITING and st ~= Base.STATE.ONLINE_WAITING
            and st ~= Base.STATE.CONNECTING and st ~= Base.STATE.HOST
            and st ~= Base.STATE.LOBBY then
            return
        end
    end

    -- Host starts manually from the lobby once a guest has joined (no auto-start)
end

function StateManager.updateCountdown(state, dt, game)
    local TeamMatch = require('src.game.team_match')
    TeamMatch.tryToggleEnemyOverlay(game)
    TeamMatch.updateEnemyWatch(game, dt)

    local oldTime = math.ceil(state.countdownTimer)
    state.countdownTimer = state.countdownTimer - dt
    local newTime = math.ceil(state.countdownTimer)
    
    if oldTime ~= newTime then
        if newTime > 0 then
            Audio:play('beep')
        elseif newTime == 0 then
            Audio:play('go')
        end
    end
    
    if state.countdownTimer <= 0 then
        state.current = StateManager.STATES.PLAYING
        game.sprintTime = 0
        game.matchTime = 0
        Audio:playRandomGameMusic()
    end
end

function StateManager.updatePlaying(state, dt, game)
    -- Marathon tracking
    if game.gameMode == "MARATHON" and game.marathonState then
        local MarathonState = require('src.game.marathon_state')
        MarathonState.update(game.marathonState, dt, game.localBoard)
        
        -- Track piece placements
        if game.localBoard.pieceLocked then
            MarathonState.onPiecePlaced(game.marathonState)
            game.localBoard.pieceLocked = false
        end
        
        -- Marathon ends only on death
        if game.localBoard.gameOver then
            StateManager.enterGameOver(state, game)
            Audio:stopMusic()
            Audio:play('secret')
            
            local summary = MarathonState.getSummary(game.marathonState, game.localBoard)
            Scores.addMatch("MARATHON", summary.score, summary.time, "DEATH", {
                level = summary.level,
                lines = summary.lines,
                maxCombo = summary.maxCombo,
                tspins = summary.tspins
            })
            return
        end
    end
    
    -- Sprint mode
    if game.gameMode == "SPRINT" then
        game.sprintTime = game.sprintTime + dt
        
        -- Check for death first
        if game.localBoard.gameOver then
            StateManager.enterGameOver(state, game)
            Audio:stopMusic()
            Audio:play('gameOver')
            Scores.addMatch("SPRINT", game.localBoard.score, game.sprintTime, "DEATH", {
                lines = game.localBoard.linesCleared
            })
            return
        end
        
        -- Win condition: cleared 40 lines
        if game.localBoard.linesCleared >= 40 then
            StateManager.enterGameOver(state, game)
            Audio:stopMusic()
            Audio:play('secret')
            Scores.addMatch("SPRINT", game.localBoard.score, game.sprintTime, "FINISHED", {
                lines = game.localBoard.linesCleared
            })
            return
        end
    end

    -- Versus mode: track match time and check for game over
    if game.gameMode == "VERSUS" then
        game.matchTime = (game.matchTime or 0) + dt
        local TeamMatch = require('src.game.team_match')
        TeamMatch.updateEnemyWatch(game, dt)

        -- Don't resolve win/loss until play has actually begun
        if (game.matchTime or 0) < 0.25 then
            return
        end

        local VersusRules = require('src.game.versus_rules')
        local result = VersusRules.checkCheeseWin(game) or TeamMatch.versusResult(game)

        if result then
            StateManager.enterGameOver(state, game, result)
            Audio:stopMusic()
            Scores.addMatch("VERSUS", game.localBoard and game.localBoard.score or 0, game.matchTime or 0, result, {
                lines = game.localBoard and game.localBoard.linesCleared or 0
            })
        end
    end
end

function StateManager.updateGameOver(state, dt, game)
    -- Game over screen now waits for input to dismiss (no auto-timer)
    -- The gameOverTimer is used as a brief delay before allowing dismissal
    if state.gameOverTimer > 0 then
        state.gameOverTimer = state.gameOverTimer - dt
    end
end

function StateManager.canDismissGameOver(state)
    return state.current == StateManager.STATES.GAME_OVER and state.gameOverTimer <= 0
end

function StateManager.dismissGameOver(state, game)
    if StateManager.canDismissGameOver(state) then
        StateManager.reset(state, game)
        return true
    end
    return false
end

function StateManager.updateDisconnectedPause(state, dt, game)
    state.disconnectPauseTimer = state.disconnectPauseTimer - dt
    if state.disconnectPauseTimer <= 0 then
        StateManager.resumeAsSinglePlayer(state, game)
    end
end

function StateManager.startCountdown(state, game)
    state.current = StateManager.STATES.COUNTDOWN
    state.countdownTimer = 3.0
    Audio:play('beep')

    local ConnectionManager = require('src.game.connection_manager')
    -- Match is no longer joinable — drop from LAN lobby lists
    ConnectionManager.stopLanAdvertising(game)
    ConnectionManager.prepareMatchStart(game)

    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = {x=0, y=0, rot=0, type=""}
    game.sprintTime = 0
    game.matchTime = 0
    game.matchResult = nil
    local TeamMatch = require('src.game.team_match')
    TeamMatch.resetEnemyWatch(game)
    
    if game.gameMode == "MARATHON" then
        local MarathonState = require('src.game.marathon_state')
        game.marathonState = MarathonState.create(1)
    end
    
    if game.network and game.isHost then
        local Protocol = require('src.net.protocol')
        game.network:sendMessage({type = Protocol.MSG.START_COUNTDOWN})
    end

    -- Push initial boards/pieces immediately (cheese layout, spawn positions)
    if game.network then
        local NetworkHandler = require('src.game.network_handler')
        NetworkHandler.syncLocalState(game)
    end
end

function StateManager.enterGameOver(state, game, result)
    state.current = StateManager.STATES.GAME_OVER
    state.gameOverTimer = 1.0  -- Brief delay before allowing dismissal
    if result then
        game.matchResult = result
    elseif game.matchResult == nil and game.gameMode == "VERSUS" then
        local TeamMatch = require('src.game.team_match')
        game.matchResult = TeamMatch.versusResult(game)
    end
end

function StateManager.enterDisconnectedPause(state, game, reason)
    print("StateManager: Entering disconnected pause (reason: " .. tostring(reason) .. ")")
    state.current = StateManager.STATES.DISCONNECTED_PAUSE
    state.disconnectPauseTimer = 5.0  -- Give players 5 seconds to read the message
    state.disconnectReason = reason or "opponent_left"
    Audio:pauseMusic()
end

function StateManager.resumeAsSinglePlayer(state, game)
    print("StateManager: Resuming as single player")
    state.current = StateManager.STATES.PLAYING
    state.disconnectReason = nil

    local ConnectionManager = require('src.game.connection_manager')
    ConnectionManager.stopLanAdvertising(game)
    
    -- Clean up network connections
    if game.network then
        game.network:disconnect()
        game.network = nil
    end
    
    -- Clean up online client
    if game.connectionManager and game.connectionManager.onlineClient then
        if game.connectionManager.onlineClient.disconnect then
            game.connectionManager.onlineClient:disconnect()
        end
        game.connectionManager.onlineClient = nil
    end
    
    -- Clear remote boards and switch to single player mode
    game.remoteBoards = {}
    game.isHost = true  -- Mark as host so game over/reset works correctly
    game.playerId = nil
    
    Audio:resumeMusic()
end

function StateManager.reset(state, game)
    local TeamMatch = require('src.game.team_match')
    local TetrisBoard = require('src.tetris.board')

    if game.ownedSeats and #game.ownedSeats > 0 then
        TeamMatch.refreshLocalBoards(game)
    else
        game.localBoard = TetrisBoard:new(10, 20)
    end
    
    for id, board in pairs(game.remoteBoards) do
        game.remoteBoards[id] = TetrisBoard:new(10, 20)
        game.remoteBoards[id].currentPiece = nil
    end
    
    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = {x=0, y=0, rot=0, type=""}
    game.matchResult = nil
    
    if not game.network then
        game.remoteBoards = {}
        game.isHost = false
        game.playerId = nil
        game.lobby = nil
        game.ownedSeats = nil
        game.localPlayers = nil
        game.localVersus = false
        state.current = StateManager.STATES.WAITING
        if game.menu then
            local Base = require('src.ui.menu.base')
            game.menu:show(Base.STATE.MAIN)
        end
        Audio:playMusic('menu')
        return
    end

    if game.isHost then
        -- Return to lobby for rematch instead of instant restart for team formats
        if game.matchFormat and game.matchFormat ~= "1v1" then
            state.current = StateManager.STATES.WAITING
            local ConnectionManager = require('src.game.connection_manager')
            ConnectionManager.startLanAdvertising(game)
            if game.menu then
                local Base = require('src.ui.menu.base')
                game.menu:show(Base.STATE.LOBBY)
            end
            Audio:playMusic('menu')
        else
            StateManager.startCountdown(state, game)
        end
    else
        state.current = StateManager.STATES.WAITING
        if game.menu then
            local Base = require('src.ui.menu.base')
            game.menu:show(Base.STATE.LOBBY)
        end
        Audio:playMusic('menu')
    end
end

return StateManager
