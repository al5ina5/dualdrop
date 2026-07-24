-- src/ui/menu/setup_screen.lua
-- Host / local: pick format (LAN/online) + versus rules. Local P2 is hot-join via Start.

local TeamMatch = require('src.game.team_match')
local VersusRules = require('src.game.versus_rules')

local SetupScreen = {}

function SetupScreen.isLocal(menu)
    return menu.setupMode == "local"
end

function SetupScreen.buildOptions(menu)
    local rules = VersusRules.normalize(menu.versusRules)
    if SetupScreen.isLocal(menu) then
        return {
            { id = "rules", label = "RULES: " .. VersusRules.label(rules) },
            { id = "create", label = "CONTINUE" },
            { id = "back", label = "BACK" },
        }
    end
    local fmt = menu.matchFormat or "1v1"
    return {
        { id = "format", label = "FORMAT: " .. string.upper(fmt) },
        { id = "rules", label = "RULES: " .. VersusRules.label(rules) },
        { id = "create", label = "CREATE ROOM" },
        { id = "back", label = "BACK" },
    }
end

function SetupScreen.draw(menu, sw, sh, game)
    love.graphics.setFont(game.renderer.fonts.medium)
    local title = SetupScreen.isLocal(menu) and "LOCAL VERSUS" or "CREATE SETUP"
    game:drawText(title, 0, 80, sw, "center", {1, 1, 1})

    local rules = VersusRules.normalize(menu.versusRules)
    local options = SetupScreen.buildOptions(menu)
    local y = 150

    for i, opt in ipairs(options) do
        local prefix = (menu.selectedIndex == i) and "> " or "  "
        local color = (menu.selectedIndex == i) and {1, 1, 0.5} or {0.8, 0.8, 0.8}
        game:drawText(prefix .. opt.label, 0, y, sw, "center", color)
        y = y + 36
    end

    love.graphics.setFont(game.renderer.fonts.small)
    game:drawText(VersusRules.DESCRIPTIONS[rules] or "", 0, sh - 90, sw, "center", {0.65, 0.85, 0.65})
    if menu.connectionError then
        local yErr = sh - 130
        for line in menu.connectionError:gmatch("[^\n]+") do
            game:drawText(line, 0, yErr, sw, "center", {1, 0.45, 0.45})
            yErr = yErr + 18
        end
    elseif SetupScreen.isLocal(menu) then
        game:drawText("Then wait for P2 · Start on 2nd pad to join", 0, sh - 45, sw, "center", {0.55, 0.55, 0.55})
    else
        local fmt = menu.matchFormat or "1v1"
        if fmt == "1v1" then
            game:drawText("1v1 · console vs console · one player per machine", 0, sh - 45, sw, "center", {0.55, 0.55, 0.55})
        else
            game:drawText("2v2 · console vs console · same-machine players share a team", 0, sh - 45, sw, "center", {0.55, 0.55, 0.55})
        end
    end
end

function SetupScreen.cycleFormat(menu, dir)
    local order = TeamMatch.FORMAT_ORDER
    local cur = menu.matchFormat or "1v1"
    local idx = 1
    for i, f in ipairs(order) do
        if f == cur then idx = i break end
    end
    idx = idx + dir
    if idx < 1 then idx = #order end
    if idx > #order then idx = 1 end
    menu.matchFormat = order[idx]
end

function SetupScreen.selectedId(menu)
    local options = SetupScreen.buildOptions(menu)
    local opt = options[menu.selectedIndex]
    return opt and opt.id
end

function SetupScreen.handleKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    local options = SetupScreen.buildOptions(menu)
    local maxIndex = #options

    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif key == "left" or key == "right" then
        local dir = (key == "left") and -1 or 1
        local id = SetupScreen.selectedId(menu)
        if id == "format" then
            SetupScreen.cycleFormat(menu, dir)
            return true
        elseif id == "rules" then
            menu.versusRules = VersusRules.next(menu.versusRules, dir)
            return true
        end
    elseif key == "return" or key == "space" or key == "x" then
        return SetupScreen.select(menu, game)
    elseif key == "escape" or key == "z" then
        menu.state = menu.setupReturnState or Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 1
        return true
    end
    return false
end

function SetupScreen.handleGamepad(menu, button, game)
    local options = SetupScreen.buildOptions(menu)
    local maxIndex = #options
    if button == "dpup" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif button == "dpleft" then
        return SetupScreen.handleKey(menu, "left", game)
    elseif button == "dpright" then
        return SetupScreen.handleKey(menu, "right", game)
    elseif button == "a" or button == "start" then
        return SetupScreen.select(menu, game)
    elseif button == "b" or button == "back" then
        return SetupScreen.handleKey(menu, "escape", game)
    end
    return false
end

function SetupScreen.select(menu, game)
    local Base = require('src.ui.menu.base')
    local LocalSession = require('src.game.local_session')
    local id = SetupScreen.selectedId(menu)

    if id == "format" then
        SetupScreen.cycleFormat(menu, 1)
        return true
    elseif id == "rules" then
        menu.versusRules = VersusRules.next(menu.versusRules, 1)
        return true
    elseif id == "create" then
        local rules = VersusRules.normalize(menu.versusRules)
        menu.versusRules = rules
        local mode = menu.setupMode or "host"

        if mode == "local" then
            menu.matchFormat = "1v1"
            menu.localPlayerCount = 2
            if game then
                game.gameMode = "VERSUS"
                game.matchFormat = "1v1"
                game.versusRules = rules
                game.localPlayerCount = 2
            end
            if menu.onLocalSetupDone then
                menu.onLocalSetupDone(rules)
            end
            return true
        end

        local fmt = menu.matchFormat or "1v1"
        local localCount = 1
        if game then
            game.matchFormat = fmt
            localCount = LocalSession.claimCount(game)
            game.gameMode = "VERSUS"
            game.localPlayerCount = localCount
            game.versusRules = rules
        end
        menu.localPlayerCount = localCount
        if mode == "host_online" then
            menu.state = Base.STATE.ONLINE_HOST
            menu.selectedIndex = 1
        elseif menu.onHostSetupDone then
            menu.onHostSetupDone(fmt, localCount, rules)
        end
        return true
    elseif id == "back" then
        menu.state = menu.setupReturnState or Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 1
        return true
    end
    return true
end

return SetupScreen
