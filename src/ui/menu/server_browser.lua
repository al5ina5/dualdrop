-- src/ui/menu/server_browser.lua
-- Server browser for finding LAN games

local ServerBrowser = {}

function ServerBrowser.draw(menu, sw, sh, game)
    game:drawText("FIND GAME", 0, 60, sw, "center", {1, 1, 1})
    
    local servers = menu.discovery:getServers()
    
    -- Keep selection in range when list changes
    if #servers == 0 then
        menu.selectedIndex = 1
    else
        menu.selectedIndex = math.min(menu.selectedIndex, #servers)
    end

    if #servers == 0 then
        game:drawText("Searching for games...", 0, 150, sw, "center", {0.6, 0.6, 0.6})
        love.graphics.setFont(game.renderer.fonts.small)
        game:drawText("Same WiFi/LAN required  •  auto-refresh", 0, 190, sw, "center", {0.5, 0.5, 0.5})
        game:drawText("Or use JOIN BY IP if discovery fails", 0, 220, sw, "center", {0.5, 0.5, 0.5})
        game:drawText("X/Y or R to rescan", 0, sh - 60, sw, "center", {0.45, 0.45, 0.45})
        love.graphics.setFont(game.renderer.fonts.medium)
    else
        local y = 120
        local spacing = 48
        for i, server in ipairs(servers) do
            local isSelected = (i == menu.selectedIndex)
            local color = isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8}
            local prefix = isSelected and "> " or "  "
            
            -- Server name and player count
            game:drawText(prefix .. server.name, 40, y, sw - 80, "left", color)
            local seatInfo = server.players .. "/" .. server.maxPlayers
            if server.format then
                seatInfo = string.upper(server.format) .. " " .. seatInfo
            end
            game:drawText(seatInfo, 40, y, sw - 120, "right", color)
            
            -- IP:port below
            love.graphics.setFont(game.renderer.fonts.small)
            local addr = server.ip .. ":" .. tostring(server.port or 12345)
            game:drawText(addr, 70, y + 22, sw - 80, "left", {0.5, 0.5, 0.5})
            love.graphics.setFont(game.renderer.fonts.medium)
            
            y = y + spacing
            if y > sh - 80 then break end
        end
    end
end

function ServerBrowser.handleKey(menu, key)
    local Base = require('src.ui.menu.base')
    local servers = menu.discovery:getServers()
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(math.max(1, #servers), menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if #servers > 0 and menu.selectedIndex <= #servers then
            menu.selectedServer = servers[menu.selectedIndex]
            menu.connectionError = nil
            menu.localPlayerCount = 1
            menu.state = Base.STATE.CONNECTING
            menu.selectedIndex = 1
            if menu.onJoin then
                menu.onJoin(menu.selectedServer.ip, menu.selectedServer.port)
            end
        end
        return true
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 2  -- FIND GAME is 2nd in LAN submenu
        return true
    elseif key == "r" then
        menu.discovery:sendDiscoveryRequest()
        return true
    end
    return false
end

function ServerBrowser.handleGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    local servers = menu.discovery:getServers()
    
    if button == "dpup" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.selectedIndex = math.min(math.max(1, #servers), menu.selectedIndex + 1)
        return true
    elseif button == "a" then
        if #servers > 0 and menu.selectedIndex <= #servers then
            menu.selectedServer = servers[menu.selectedIndex]
            menu.connectionError = nil
            menu.localPlayerCount = 1
            menu.state = Base.STATE.CONNECTING
            menu.selectedIndex = 1
            if menu.onJoin then
                menu.onJoin(menu.selectedServer.ip, menu.selectedServer.port)
            end
        end
        return true
    elseif button == "b" or button == "back" then
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 2  -- FIND GAME is 2nd in LAN submenu
        return true
    elseif button == "x" or button == "y" then
        menu.discovery:sendDiscoveryRequest()
        return true
    end
    return false
end

return ServerBrowser
