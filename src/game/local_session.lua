-- src/game/local_session.lua
-- Seamless local P2: Start on unused pad joins anytime (menu toast / solo split / lobby claim)

local LocalSession = {}

function LocalSession.resolvePadIndex(joystick)
    if not joystick then return nil end
    local joysticks = love.joystick.getJoysticks()
    for i, j in ipairs(joysticks) do
        if j == joystick then
            return i
        end
    end
    return nil
end

function LocalSession.toast(game, text, seconds)
    game.toastText = text
    game.toastTimer = seconds or 2.0
end

function LocalSession.update(game, dt)
    if game.toastTimer and game.toastTimer > 0 then
        game.toastTimer = game.toastTimer - dt
        if game.toastTimer <= 0 then
            game.toastTimer = 0
            game.toastText = nil
        end
    end
end

function LocalSession.drawToast(game, sw, sh, fonts)
    if not game.toastText or not game.toastTimer or game.toastTimer <= 0 then
        return
    end
    local alpha = math.min(1, game.toastTimer)
    if fonts and fonts.small then
        love.graphics.setFont(fonts.small)
    elseif fonts and fonts.medium then
        love.graphics.setFont(fonts.medium)
    end
    local Theme = require('src.ui.theme')
    if Theme.isLight() then
        love.graphics.setColor(1, 1, 1, 0.75 * alpha)
        love.graphics.rectangle("fill", sw * 0.2, sh - 70, sw * 0.6, 36, 6, 6)
        love.graphics.setColor(0.35, 0.30, 0.05, alpha)
    else
        love.graphics.setColor(0, 0, 0, 0.55 * alpha)
        love.graphics.rectangle("fill", sw * 0.2, sh - 70, sw * 0.6, 36, 6, 6)
        love.graphics.setColor(1, 1, 0.55, alpha)
    end
    love.graphics.printf(game.toastText, 0, sh - 62, sw, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function LocalSession.isAssignedPad(game, padIndex)
    if not padIndex then return false end
    if game.p2Device == padIndex then return true end
    if game.p1Device == padIndex then return true end
    for _, lp in ipairs(game.localPlayers or {}) do
        if lp.device == padIndex then
            return true
        end
    end
    return false
end

-- Latch primary controller from non-Start pad input (so Start on that pad = pause, not P2)
function LocalSession.notePadActivity(game, padIndex)
    if not padIndex then return end
    if game.p2Device == padIndex then return end
    if game.p1Device and game.p1Device ~= padIndex then return end

    if not game.p1Device then
        game.p1Device = padIndex
    end
    local p1 = game.localPlayers and game.localPlayers[1]
    if p1 and p1.device == "any" then
        p1.device = padIndex
    end
end

-- Latch keyboard as primary so a later pad Start can hot-join as P2
function LocalSession.noteKeyboardActivity(game)
    if game.p1Device then return end
    game.p1Device = "keyboard"
    local p1 = game.localPlayers and game.localPlayers[1]
    if p1 and p1.device == "any" then
        p1.device = "keyboard"
    end
end

function LocalSession.localCount(game)
    local n = 1
    if game.p2Device then
        n = 2
    end
    if game.localPlayers and #game.localPlayers > n then
        n = #game.localPlayers
    end
    return n
end

function LocalSession.claimCount(game, team)
    local TeamMatch = require('src.game.team_match')
    local fmt = game.matchFormat or (game.lobby and game.lobby.format) or "1v1"
    if not team and game.lobby then
        local peerId = game.peerId or game.playerId
        if peerId then
            team = TeamMatch.consoleTeam(game.lobby, peerId, game.isHost)
        end
    end
    local maxLocal = TeamMatch.maxLocalPlayers(fmt, team)
    return math.min(LocalSession.localCount(game), maxLocal)
end

local function blankPlayer(id, board, device)
    return {
        id = id,
        board = board,
        device = device or "any",
        sentGameOver = false,
        lastSentScore = 0,
        lastSentMove = { x = 0, y = 0, rot = 0, type = "" },
    }
end

function LocalSession.pickP1Device(excludePad)
    local pads = love.joystick.getJoysticks()
    for i = 1, #pads do
        if i ~= excludePad then
            return i
        end
    end
    return "keyboard"
end

function LocalSession.rebindP1OffAny(game, excludePad)
    if not game.localPlayers or not game.localPlayers[1] then return end
    local p1 = game.localPlayers[1]
    if p1.device == "any" or p1.device == excludePad then
        p1.device = LocalSession.pickP1Device(excludePad)
    end
    if p1.device and p1.device ~= "any" then
        game.p1Device = p1.device
    end
end

function LocalSession.addSoloP2Board(game, padIndex)
    local TetrisBoard = require('src.tetris.board')
    if not game.localPlayers then
        LocalSession.ensureSoloLocalPlayers(game)
    end
    if #game.localPlayers >= 2 then return false end

    LocalSession.rebindP1OffAny(game, padIndex)
    local board = TetrisBoard:new(10, 20)
    table.insert(game.localPlayers, blankPlayer("p2", board, padIndex))
    game.p2Device = padIndex
    game.localPlayerCount = 2
    return true
end

function LocalSession.ensureSoloLocalPlayers(game)
    local TetrisBoard = require('src.tetris.board')
    if game.localPlayers and #game.localPlayers > 0 then
        game.localBoard = game.localPlayers[1].board
        return
    end
    local board = game.localBoard or TetrisBoard:new(10, 20)
    game.localBoard = board
    local p1Device = game.p2Device and LocalSession.pickP1Device(game.p2Device)
        or (game.p1Device and game.p1Device ~= "any" and game.p1Device)
        or "any"
    game.localPlayers = { blankPlayer("p1", board, p1Device) }
    if type(p1Device) == "number" or p1Device == "keyboard" then
        game.p1Device = p1Device
    end
    if game.p2Device then
        LocalSession.addSoloP2Board(game, game.p2Device)
    end
end

function LocalSession.prepareSoloBoards(game)
    local TetrisBoard = require('src.tetris.board')
    LocalSession.ensureSoloLocalPlayers(game)
    for _, lp in ipairs(game.localPlayers) do
        lp.board = TetrisBoard:new(10, 20)
        lp.sentGameOver = false
        lp.lastSentScore = 0
        lp.lastSentMove = { x = 0, y = 0, rot = 0, type = "" }
    end
    if game.p2Device and #game.localPlayers < 2 then
        LocalSession.addSoloP2Board(game, game.p2Device)
    end
    game.localBoard = game.localPlayers[1].board
    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = { x = 0, y = 0, rot = 0, type = "" }
end

function LocalSession.beginSoloSession(game)
    game.ownedSeats = nil
    game.lobby = nil
    game.localVersus = false
    local TetrisBoard = require('src.tetris.board')
    local board = TetrisBoard:new(10, 20)
    game.localBoard = board
    local p1Device = game.p2Device and LocalSession.pickP1Device(game.p2Device)
        or (game.p1Device and game.p1Device ~= "any" and game.p1Device)
        or "any"
    game.localPlayers = { blankPlayer("p1", board, p1Device) }
    if type(p1Device) == "number" or p1Device == "keyboard" then
        game.p1Device = p1Device
    end
    if game.p2Device then
        LocalSession.addSoloP2Board(game, game.p2Device)
    end
    game.localPlayerCount = LocalSession.localCount(game)
end

-- Same-machine 1v1 lobby: P1 waits here; P2 presses Start on another pad to join
function LocalSession.enterLocalVersusLobby(game, rules)
    local TeamMatch = require('src.game.team_match')
    local VersusRules = require('src.game.versus_rules')
    local ConnectionManager = require('src.game.connection_manager')

    ConnectionManager.stopLanAdvertising(game)
    if game.network then
        game.network:disconnect()
        game.network = nil
    end

    rules = VersusRules.normalize(rules or game.versusRules)
    game.gameMode = "VERSUS"
    game.matchFormat = "1v1"
    game.versusRules = rules
    game.localVersus = true
    game.isHost = true
    game.remoteBoards = {}
    game.peerId = "p1"
    game.playerId = "a1"
    -- Require Start on this screen — don't carry a prior P2 claim
    game.p2Device = nil

    game.lobby = TeamMatch.createEmptyLobby("1v1", rules)
    TeamMatch.claimSeats(game.lobby, "p1", { "a1" })

    local p1Device = (game.p1Device and game.p1Device ~= "any" and game.p1Device) or "any"
    TeamMatch.setupLocalPlayers(game, { "a1" }, { p1Device })
    game.localPlayerCount = 1

    if game.menu then
        local Base = require('src.ui.menu.base')
        game.menu.localPlayerCount = 1
        game.menu.matchFormat = "1v1"
        game.menu.versusRules = rules
        game.menu.state = Base.STATE.LOBBY
        game.menu.selectedIndex = 1
        game.menu.connectionError = nil
    end

    if game.stateManager then
        game.stateManager.current = "waiting"
    end
end

-- Finalize seats for countdown (both players already joined in lobby)
function LocalSession.beginLocalVersus(game, rules)
    local TeamMatch = require('src.game.team_match')
    local VersusRules = require('src.game.versus_rules')

    if not game.localVersus or not game.lobby then
        LocalSession.enterLocalVersusLobby(game, rules)
    end

    rules = VersusRules.normalize(rules or game.versusRules)
    game.versusRules = rules
    game.matchFormat = "1v1"
    game.gameMode = "VERSUS"

    if not game.p2Device or LocalSession.localCount(game) < 2 then
        return false
    end

    -- Ensure lobby seats + local duo
    if game.lobby.seats.b1 and not game.lobby.seats.b1.peerId then
        TeamMatch.claimSeats(game.lobby, "p2", { "b1" })
    end
    if not game.ownedSeats or #game.ownedSeats < 2 then
        local devices = LocalSession.devicesForSeats(game, 2)
        TeamMatch.setupLocalPlayers(game, { "a1", "b1" }, devices)
    end
    game.localPlayerCount = 2
    if game.menu then
        game.menu.localPlayerCount = 2
    end
    return true
end

function LocalSession.joinLocalVersusP2(game, padIndex)
    local TeamMatch = require('src.game.team_match')
    local TetrisBoard = require('src.tetris.board')

    if not game.localVersus or not game.lobby then
        return false
    end
    if game.p2Device or (game.localPlayers and #game.localPlayers >= 2) then
        LocalSession.toast(game, "P2 already connected")
        return true
    end

    game.p2Device = padIndex
    LocalSession.rebindP1OffAny(game, padIndex)

    TeamMatch.releasePeer(game.lobby, "p2")
    if not TeamMatch.claimSeats(game.lobby, "p2", { "b1" }) then
        game.p2Device = nil
        LocalSession.toast(game, "Could not claim seat")
        return true
    end

    local board = TetrisBoard:new(10, 20)
    if not game.localPlayers or #game.localPlayers == 0 then
        local devices = LocalSession.devicesForSeats(game, 2)
        TeamMatch.setupLocalPlayers(game, { "a1", "b1" }, devices)
    else
        LocalSession.rebindP1OffAny(game, padIndex)
        table.insert(game.localPlayers, blankPlayer("b1", board, padIndex))
        table.insert(game.ownedSeats, "b1")
    end
    game.localPlayerCount = 2
    if game.menu then
        game.menu.localPlayerCount = 2
    end

    LocalSession.toast(game, "P2 joined!")
    return true
end

function LocalSession.canStartLocalVersus(game)
    return game.localVersus and game.p2Device and LocalSession.localCount(game) >= 2
end

function LocalSession.devicesForSeats(game, seatCount)
    local devices = {}
    if seatCount >= 2 then
        devices[1] = LocalSession.pickP1Device(game.p2Device)
        devices[2] = game.p2Device or 1
    else
        devices[1] = "any"
    end
    -- Preserve existing localPlayers devices when possible
    if game.localPlayers then
        for i = 1, math.min(seatCount, #game.localPlayers) do
            if game.localPlayers[i].device and game.localPlayers[i].device ~= "any" then
                devices[i] = game.localPlayers[i].device
            end
        end
    end
    if seatCount >= 2 and game.p2Device then
        devices[2] = game.p2Device
        if devices[1] == devices[2] or devices[1] == "any" then
            devices[1] = LocalSession.pickP1Device(game.p2Device)
        end
    end
    return devices
end

function LocalSession.tryVersusHotJoin(game, padIndex)
    local TeamMatch = require('src.game.team_match')
    local ConnectionManager = require('src.game.connection_manager')
    local TetrisBoard = require('src.tetris.board')

    if not game.lobby then
        LocalSession.toast(game, "No open seat")
        return false
    end
    if game.localPlayers and #game.localPlayers >= 2 then
        LocalSession.toast(game, "P2 already connected")
        return false
    end

    -- Same console always shares a team (console vs console)
    local peerId = game.peerId or game.playerId or "host"
    local myTeam = TeamMatch.localTeam(game)
        or TeamMatch.consoleTeam(game.lobby, peerId, game.isHost)
    local maxLocal = TeamMatch.maxLocalPlayers(
        game.matchFormat or game.lobby.format, myTeam)
    if maxLocal < 2 then
        LocalSession.toast(game, "1v1 — one player per console")
        return false
    end
    local open = TeamMatch.openSeatsOnTeam(game.lobby, myTeam)
    if #open == 0 then
        LocalSession.toast(game, "No open seat on your team")
        return false
    end

    local seats = TeamMatch.seatsForPeer(game.lobby, peerId)
    if #seats == 0 then
        LocalSession.toast(game, "No open seat")
        return false
    end
    local previous = {}
    for i, id in ipairs(seats) do previous[i] = id end
    local newSeat = open[1]
    table.insert(seats, newSeat)

    TeamMatch.releasePeer(game.lobby, peerId)
    if not TeamMatch.claimSeats(game.lobby, peerId, seats) then
        -- Restore prior seats so we don't strand the console
        if #previous > 0 then
            TeamMatch.claimSeats(game.lobby, peerId, previous)
        end
        LocalSession.toast(game, "Could not claim seat")
        return false
    end

    game.p2Device = padIndex
    game.localPlayerCount = (#previous) + 1
    if game.menu then game.menu.localPlayerCount = game.localPlayerCount end
    LocalSession.rebindP1OffAny(game, padIndex)

    local board = TetrisBoard:new(10, 20)
    if not game.localPlayers or #game.localPlayers == 0 then
        ConnectionManager.applyLocalSeats(game, seats)
    else
        table.insert(game.localPlayers, blankPlayer(newSeat, board, padIndex))
        table.insert(game.ownedSeats, newSeat)
        game.localPlayerCount = #game.localPlayers
    end

    local VersusRules = require('src.game.versus_rules')
    if VersusRules.isCheese(game) and game.localPlayers then
        local lp = game.localPlayers[#game.localPlayers]
        if lp and lp.board and not lp.board.cheeseRows then
            VersusRules.applyCheese(lp.board)
        end
    end

    if game.isHost then
        ConnectionManager.broadcastLobby(game)
        ConnectionManager.rebuildRemoteBoardsFromLobby(game)
    elseif game.network then
        local Protocol = require('src.net.protocol')
        game.network:sendMessage({
            type = Protocol.MSG.CLAIM,
            id = peerId,
            data = table.concat(seats, ","),
        })
    end

    LocalSession.toast(game, "P2 joined!")
    return true
end

function LocalSession.tryJoinPad(game, padIndex)
    if not padIndex then return false end

    if LocalSession.isAssignedPad(game, padIndex) then
        return false
    end

    -- No primary yet: first Start claims P1's pad (pause/select), not P2 join.
    -- P2 is Start on a *different* pad after P1 is latched (pad or keyboard).
    if not game.p1Device then
        game.p1Device = padIndex
        local p1 = game.localPlayers and game.localPlayers[1]
        if p1 and (p1.device == "any" or p1.device == nil) then
            p1.device = padIndex
        end
        -- In local lobby, consume Start so it doesn't fire START MATCH
        if game.localVersus and game.menu and game.menu:isVisible() then
            local Base = require('src.ui.menu.base')
            if game.menu.state == Base.STATE.LOBBY then
                LocalSession.toast(game, "P1 ready — P2: Start on 2nd pad")
                return true
            end
        end
        return false
    end

    if game.p2Device and game.p2Device ~= padIndex then
        LocalSession.toast(game, "P2 already connected")
        return true
    end

    local menuVisible = game.menu and game.menu:isVisible()
    local Base = require('src.ui.menu.base')
    local menuState = menuVisible and game.menu.state
    local playing = game.state == "playing" or game.state == "countdown"
    local networked = game.network ~= nil and game.lobby ~= nil

    -- Lobby / mid-match versus: claim seat first; only latch P2 on success
    if menuVisible and menuState == Base.STATE.LOBBY and game.lobby then
        if game.localVersus then
            game.p2Device = padIndex
            return LocalSession.joinLocalVersusP2(game, padIndex)
        end
        return LocalSession.tryVersusHotJoin(game, padIndex)
    end
    if playing and networked then
        return LocalSession.tryVersusHotJoin(game, padIndex)
    end

    game.p2Device = padIndex
    game.localPlayerCount = LocalSession.claimCount(game)
    if game.menu then
        game.menu.localPlayerCount = game.localPlayerCount
    end

    -- Mid solo play (or pause over solo)
    if playing and not networked then
        LocalSession.ensureSoloLocalPlayers(game)
        if #game.localPlayers >= 2 then
            LocalSession.toast(game, "P2 already connected")
            return true
        end
        LocalSession.addSoloP2Board(game, padIndex)
        LocalSession.toast(game, "P2 joined!")
        return true
    end

    -- Pause menu during solo
    if menuVisible and menuState == Base.STATE.PAUSE and not networked then
        LocalSession.ensureSoloLocalPlayers(game)
        if #game.localPlayers < 2 then
            LocalSession.addSoloP2Board(game, padIndex)
        end
        LocalSession.toast(game, "P2 connected")
        return true
    end

    -- Any other menu: remember P2 + toast
    LocalSession.toast(game, "P2 connected")
    return true
end

return LocalSession
