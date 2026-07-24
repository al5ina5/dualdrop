-- src/ui/menu/waiting_screens.lua
-- Waiting and connecting screens

local WaitingScreens = {}

function WaitingScreens.drawWaiting(menu, sw, sh, game)
    game:drawText("HOSTING GAME", 0, 60, sw, "center", {1, 1, 1})
    game:drawText("Waiting for opponent...", 0, 140, sw, "center", {0.6, 0.6, 0.6})
    
    local ip = menu.discovery and menu.discovery.localIP
    if ip and ip ~= "unknown" then
        love.graphics.setFont(game.renderer.fonts.large)
        game:drawText(ip .. ":12345", 0, 200, sw, "center", {0.4, 0.9, 0.4})
        love.graphics.setFont(game.renderer.fonts.medium)
    else
        game:drawText("IP unavailable", 0, 200, sw, "center", {0.8, 0.5, 0.5})
    end

    love.graphics.setFont(game.renderer.fonts.small)
    game:drawText("Other machine: MULTIPLAYER > LAN > FIND GAME", 0, 280, sw, "center", {0.55, 0.55, 0.55})
    game:drawText("or JOIN BY IP using the address above", 0, 304, sw, "center", {0.55, 0.55, 0.55})
    love.graphics.setFont(game.renderer.fonts.medium)
end

function WaitingScreens.drawConnecting(menu, sw, sh, game)
    game:drawText("CONNECTING", 0, 60, sw, "center", {1, 1, 1})
    game:drawText("Please wait...", 0, 160, sw, "center", {0.6, 0.6, 0.6})

    if menu.selectedServer then
        local label = menu.selectedServer.name or "Server"
        local detail = tostring(menu.selectedServer.ip or "")
        if menu.selectedServer.port then
            detail = detail .. ":" .. tostring(menu.selectedServer.port)
        end
        game:drawText(label, 0, 220, sw, "center", {0.8, 0.8, 0.8})
        love.graphics.setFont(game.renderer.fonts.small)
        game:drawText(detail, 0, 250, sw, "center", {0.5, 0.5, 0.5})
        love.graphics.setFont(game.renderer.fonts.medium)
    end

    if menu.connectionError then
        love.graphics.setFont(game.renderer.fonts.small)
        local y = 300
        for line in menu.connectionError:gmatch("[^\n]+") do
            game:drawText(line, 0, y, sw, "center", {1, 0.4, 0.4})
            y = y + 20
        end
        love.graphics.setFont(game.renderer.fonts.medium)
    end
end

function WaitingScreens.handleWaitingKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    if key == "escape" or key == "z" then
        if menu.onStopHost then menu.onStopHost() end
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 1  -- CREATE GAME is 1st in LAN submenu
        return true
    end
    return false
end

function WaitingScreens.handleWaitingGamepad(menu, button, game)
    local Base = require('src.ui.menu.base')
    
    if button == "b" or button == "back" then
        if menu.onStopHost then menu.onStopHost() end
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 1  -- CREATE GAME is 1st in LAN submenu
        return true
    end
    return false
end

function WaitingScreens.handleConnectingKey(menu, key)
    local Base = require('src.ui.menu.base')
    
    if key == "escape" or key == "z" then
        print("Menu: User cancelled connection")
        menu.connectionError = nil
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 2  -- FIND GAME is 2nd in LAN submenu
        if menu.onCancel then menu.onCancel() end
        return true
    end
    return false
end

function WaitingScreens.handleConnectingGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    
    if button == "b" then
        print("Menu: User cancelled connection (gamepad)")
        menu.connectionError = nil
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 2  -- FIND GAME is 2nd in LAN submenu
        if menu.onCancel then menu.onCancel() end
        return true
    end
    return false
end

return WaitingScreens
