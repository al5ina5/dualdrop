-- src/ui/menu/lobby_screen.lua
-- Party lobby: host starts when a guest joins. P2 joins via Start on 2nd pad (no LOCAL PLAYERS UI).

local TeamMatch = require('src.game.team_match')

local LobbyScreen = {}

local function formatLabel(fmt)
    return string.upper(fmt or "1v1")
end

local function seatLabel(seatId, seat, game)
    if game and game.localVersus then
        if seatId == "a1" then
            return seat and seat.peerId and "[*] P1" or "[Open] P1"
        end
        if seatId == "b1" then
            return seat and seat.peerId and "[*] P2" or "[Open] P2"
        end
    end
    if not seat or not seat.peerId then
        return "[Open] " .. seatId
    end
    return "[*] " .. seatId .. " " .. tostring(seat.peerId)
end

function LobbyScreen.canStart(menu, game)
    local LocalSession = require('src.game.local_session')
    if game and game.localVersus then
        return LocalSession.canStartLocalVersus(game)
    end
    local lobby = game and game.lobby
    return lobby and TeamMatch.canStartMatch(lobby)
end

function LobbyScreen.leaveTarget(menu, game)
    local Base = require('src.ui.menu.base')
    if game and game.localVersus then
        return Base.STATE.SUBMENU_MULTIPLAYER, 1
    end
    if menu.onlineRoomCode then
        return Base.STATE.SUBMENU_ONLINE, 1
    end
    return Base.STATE.SUBMENU_LAN, 1
end

function LobbyScreen.buildOptions(menu, game)
    local isHost = game and game.isHost
    local options = {}
    if isHost then
        table.insert(options, { id = "start", label = "START MATCH" })
    end
    table.insert(options, { id = "leave", label = "LEAVE" })
    return options
end

function LobbyScreen.draw(menu, sw, sh, game)
    local lobby = game and game.lobby
    local fmt = TeamMatch.getFormat(lobby and lobby.format or menu.matchFormat or "1v1")
    local isHost = game and game.isHost
    local LocalSession = require('src.game.local_session')
    local localVersus = game and game.localVersus

    love.graphics.setFont(game.renderer.fonts.medium)
    if localVersus then
        game:drawText("LOCAL VERSUS", 0, 40, sw, "center", {1, 1, 1})
    else
        game:drawText("LOBBY " .. formatLabel(fmt.id), 0, 40, sw, "center", {1, 1, 1})
    end

    local VersusRules = require('src.game.versus_rules')
    local rules = (lobby and lobby.rules) or (game and game.versusRules) or menu.versusRules or "classic"
    love.graphics.setFont(game.renderer.fonts.small)
    game:drawText(VersusRules.label(rules), 0, 68, sw, "center", {0.7, 1, 0.7})

    if localVersus then
        game:drawText("Split-screen 1v1", 0, 88, sw, "center", {0.65, 0.65, 0.65})
    elseif menu.onlineRoomCode then
        game:drawText("CODE " .. menu.onlineRoomCode, 0, 88, sw, "center", {1, 1, 0.5})
    elseif menu.discovery and menu.discovery.localIP and menu.discovery.localIP ~= "unknown" then
        game:drawText(menu.discovery.localIP .. ":12345", 0, 88, sw, "center", {0.4, 0.9, 0.4})
    end

    local filled = lobby and TeamMatch.countFilled(lobby) or 0
    local locals = game and LocalSession.localCount(game) or 1
    if localVersus then
        game:drawText(string.format("PLAYERS %d/2", locals), 0, 108, sw, "center", {0.7, 0.7, 0.7})
    else
        game:drawText(string.format("SEATS %d/%d  ·  LOCAL %d", filled, fmt.maxSeats, locals), 0, 108, sw, "center", {0.7, 0.7, 0.7})
    end

    local leftX, rightX = 40, sw / 2 + 20
    local y = 140
    love.graphics.setFont(game.renderer.fonts.medium)
    game:drawText("TEAM A", leftX, y, sw / 2 - 60, "left", {0.4, 0.9, 1})
    game:drawText("TEAM B", rightX, y, sw / 2 - 60, "left", {1, 0.45, 0.45})

    y = y + 36
    love.graphics.setFont(game.renderer.fonts.small)
    local maxRows = math.max(#fmt.teams.A, #fmt.teams.B)
    for i = 1, maxRows do
        local aId = fmt.teams.A[i]
        local bId = fmt.teams.B[i]
        if aId then
            local seat = lobby and lobby.seats[aId]
            local mine = game and TeamMatch.isLocalSeat(game, aId)
            local color = mine and {1, 1, 0.5} or {0.85, 0.85, 0.85}
            game:drawText(seatLabel(aId, seat, game), leftX, y, sw / 2 - 60, "left", color)
        end
        if bId then
            local seat = lobby and lobby.seats[bId]
            local mine = game and TeamMatch.isLocalSeat(game, bId)
            local color = mine and {1, 1, 0.5} or {0.85, 0.85, 0.85}
            game:drawText(seatLabel(bId, seat, game), rightX, y, sw / 2 - 60, "left", color)
        end
        y = y + 28
    end

    y = math.max(y + 20, 320)
    love.graphics.setFont(game.renderer.fonts.medium)
    local options = LobbyScreen.buildOptions(menu, game)
    menu.selectedIndex = math.min(menu.selectedIndex or 1, #options)

    for i, opt in ipairs(options) do
        local prefix = (menu.selectedIndex == i) and "> " or "  "
        local color = (menu.selectedIndex == i) and {1, 1, 0.5} or {0.8, 0.8, 0.8}
        if opt.id == "start" then
            local canStart = LobbyScreen.canStart(menu, game)
            if not canStart then
                color = (menu.selectedIndex == i) and {0.6, 0.6, 0.4} or {0.45, 0.45, 0.45}
            end
        end
        game:drawText(prefix .. opt.label, 0, y, sw, "center", color)
        y = y + 32
    end

    love.graphics.setFont(game.renderer.fonts.small)
    if localVersus then
        if LobbyScreen.canStart(menu, game) then
            game:drawText("P2 joined — P1: START MATCH when ready", 0, sh - 40, sw, "center", {0.55, 0.85, 0.55})
        else
            game:drawText("Waiting for P2 · press Start on 2nd pad to join", 0, sh - 40, sw, "center", {0.55, 0.55, 0.55})
        end
    elseif isHost then
        if LobbyScreen.canStart(menu, game) then
            game:drawText("Guest joined — press START MATCH when ready", 0, sh - 40, sw, "center", {0.55, 0.85, 0.55})
        else
            game:drawText("Waiting for a guest · P2 Start = same team (console vs console)", 0, sh - 40, sw, "center", {0.55, 0.55, 0.55})
        end
    else
        game:drawText("Waiting for host · P2 Start joins your console's team", 0, sh - 40, sw, "center", {0.55, 0.55, 0.55})
    end
end

function LobbyScreen.getMaxIndex(menu, game)
    return #LobbyScreen.buildOptions(menu, game)
end

function LobbyScreen.selectedId(menu, game)
    local options = LobbyScreen.buildOptions(menu, game)
    local opt = options[menu.selectedIndex]
    return opt and opt.id
end

function LobbyScreen.leave(menu, game)
    if menu.onCancel then menu.onCancel() end
    local state, index = LobbyScreen.leaveTarget(menu, game)
    menu.state = state
    menu.selectedIndex = index
    return true
end

function LobbyScreen.handleKey(menu, key, game)
    local maxIndex = LobbyScreen.getMaxIndex(menu, game)

    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        return LobbyScreen.select(menu, game)
    elseif key == "escape" or key == "z" then
        return LobbyScreen.leave(menu, game)
    end
    return false
end

function LobbyScreen.handleGamepad(menu, button, game)
    local maxIndex = LobbyScreen.getMaxIndex(menu, game)

    if button == "dpup" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif button == "a" or button == "start" then
        return LobbyScreen.select(menu, game)
    elseif button == "b" or button == "back" then
        return LobbyScreen.leave(menu, game)
    end
    return false
end

function LobbyScreen.select(menu, game)
    local id = LobbyScreen.selectedId(menu, game)

    if id == "start" then
        if not LobbyScreen.canStart(menu, game) then
            local LocalSession = require('src.game.local_session')
            if game and game.localVersus then
                LocalSession.toast(game, "Waiting for P2 — Start on 2nd pad")
            end
            return true
        end
        if menu.onLobbyStart then
            menu.onLobbyStart()
        end
        return true
    end

    return LobbyScreen.leave(menu, game)
end

return LobbyScreen
