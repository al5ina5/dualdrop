-- src/ui/menu/online_screens.lua
-- Online multiplayer menu screens (host, join, browse)

local OnlineScreens = {}

-- Draw online host screen
function OnlineScreens.drawHost(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("HOST ONLINE", 0, 100, sw, "center", {1, 1, 1})

    love.graphics.setFont(game.renderer.fonts.small)
    local VersusRules = require('src.game.versus_rules')
    local fmt = (game and game.matchFormat) or menu.matchFormat or "1v1"
    local locals = (game and game.localPlayerCount) or menu.localPlayerCount or 1
    local rules = VersusRules.label((game and game.versusRules) or menu.versusRules)
    game:drawText(string.upper(fmt) .. " · " .. tostring(locals) .. " LOCAL · " .. rules, 0, 130, sw, "center", {0.7, 0.7, 0.7})
    love.graphics.setFont(game.renderer.fonts.medium)
    
    -- Show error if any
    if menu.onlineError then
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        local errorLines = {}
        for line in menu.onlineError:gmatch("[^\n]+") do
            table.insert(errorLines, line)
        end
        local y = 180
        for _, line in ipairs(errorLines) do
            game:drawText(line, 0, y, sw, "center", {1, 0.5, 0.5})
            y = y + 24
        end
        
        -- Only show back button when there's an error
        y = y + 20
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
        
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        game:drawText("See docs/HTTPS_SETUP.md for help", 0, sh - 60, sw, "center", {0.6, 0.6, 0.6})
        return
    end
    
    -- Create button
    local y = 180
    if menu.selectedIndex == 1 then
        game:drawText("> CREATE ROOM", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  CREATE ROOM", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Public/Private toggle
    y = y + 40
    local visibility = menu.isPublicRoom and "PUBLIC" or "PRIVATE"
    if menu.selectedIndex == 2 then
        game:drawText("> Visibility: " .. visibility, 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  Visibility: " .. visibility, 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Back button
    y = y + 40
    if menu.selectedIndex == 3 then
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  BACK", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
end

-- Draw online join screen
function OnlineScreens.drawJoin(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("JOIN ONLINE", 0, 120, sw, "center", {1, 1, 1})
    
    -- Show error if any
    if menu.onlineError then
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        local errorLines = {}
        for line in menu.onlineError:gmatch("[^\n]+") do
            table.insert(errorLines, line)
        end
        local y = 180
        for _, line in ipairs(errorLines) do
            game:drawText(line, 0, y, sw, "center", {1, 0.5, 0.5})
            y = y + 24
        end
        
        -- Only show back button when there's an error
        y = y + 20
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
        
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        game:drawText("See docs/HTTPS_SETUP.md for help", 0, sh - 60, sw, "center", {0.6, 0.6, 0.6})
        return
    end
    
    -- Room code input
    local y = 180
    local codeText = menu.roomCode ~= "" and menu.roomCode or "______"
    if menu.selectedIndex == 1 then
        game:drawText("> Code: " .. codeText, 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  Code: " .. codeText, 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Join button
    y = y + 40
    if menu.selectedIndex == 2 then
        game:drawText("> JOIN ROOM", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  JOIN ROOM", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Back button
    y = y + 40
    if menu.selectedIndex == 3 then
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  BACK", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Instructions
    if menu.fonts then love.graphics.setFont(menu.fonts.small) end
    if menu.selectedIndex == 1 and not menu.onlineError then
        game:drawText("Type the 6-character room code", 0, sh - 60, sw, "center", {0.6, 0.6, 0.6})
    end
end

-- Draw online browse screen
function OnlineScreens.drawBrowse(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("BROWSE GAMES", 0, 60, sw, "center", {1, 1, 1})
    
    local y = 120
    
    -- Show error if any
    if menu.onlineError then
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        local errorLines = {}
        for line in menu.onlineError:gmatch("[^\n]+") do
            table.insert(errorLines, line)
        end
        for _, line in ipairs(errorLines) do
            game:drawText(line, 0, y, sw, "center", {1, 0.5, 0.5})
            y = y + 24
        end
        
        -- Show back button when there's an error
        y = y + 20
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
        
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        game:drawText("See docs/HTTPS_SETUP.md for help", 0, sh - 60, sw, "center", {0.6, 0.6, 0.6})
        return
    end
    
    -- Room list
    if #menu.onlineRooms == 0 then
        game:drawText("No public games found", 0, y + 40, sw, "center", {0.6, 0.6, 0.6})
    else
        for i, room in ipairs(menu.onlineRooms) do
            local roomText = string.format("%s %s (%d/%d)",
                string.upper(room.format or "1v1"),
                room.code, room.players, room.maxPlayers)
            if menu.selectedIndex == i then
                game:drawText("> " .. roomText, 0, y, sw, "center", {1, 1, 0.5})
            else
                game:drawText("  " .. roomText, 0, y, sw, "center", {0.8, 0.8, 0.8})
            end
            y = y + 30
        end
    end
    
    -- Refresh button
    y = math.max(y, 200)
    local refreshIndex = #menu.onlineRooms + 1
    if menu.selectedIndex == refreshIndex then
        game:drawText("> REFRESH", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  REFRESH", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Back button
    y = y + 30
    local backIndex = #menu.onlineRooms + 2
    if menu.selectedIndex == backIndex then
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  BACK", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
end

-- Draw online waiting screen
function OnlineScreens.drawWaiting(menu, sw, sh, game)
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("WAITING FOR PLAYER", 0, 100, sw, "center", {1, 1, 1})
    
    -- Show room code with better spacing
    if menu.onlineRoomCode then
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        game:drawText("Room Code", 0, 170, sw, "center", {0.8, 0.8, 0.8})
        
        if menu.fonts then love.graphics.setFont(menu.fonts.large) end
        game:drawText(menu.onlineRoomCode, 0, 210, sw, "center", {1, 1, 0.5})
    end
    
    if menu.fonts then love.graphics.setFont(menu.fonts.small) end
    game:drawText("Share this code with your opponent", 0, 290, sw, "center", {0.6, 0.6, 0.6})
    game:drawText("Press ESC to cancel", 0, sh - 60, sw, "center", {0.6, 0.6, 0.6})
end

-- Handle keyboard input for online host screen
function OnlineScreens.handleHostKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    -- If there's an error, only allow going back
    if menu.onlineError then
        if key == "return" or key == "space" or key == "x" or key == "escape" or key == "z" then
            menu.onlineError = nil
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 1
            return true
        end
        return false
    end
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(3, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if menu.selectedIndex == 1 then
            -- Create room
            if menu.onHostOnline then
                menu.onHostOnline(menu.isPublicRoom)
            end
            return true
        elseif menu.selectedIndex == 2 then
            -- Toggle public/private
            menu.isPublicRoom = not menu.isPublicRoom
            return true
        elseif menu.selectedIndex == 3 then
            -- Back
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 1
            return true
        end
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 1
        return true
    end
    return false
end

-- Handle keyboard input for online join screen
function OnlineScreens.handleJoinKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    -- If there's an error, only allow going back
    if menu.onlineError then
        if key == "return" or key == "space" or key == "x" or key == "escape" or key == "z" then
            menu.onlineError = nil
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 3
            return true
        end
        return false
    end
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(3, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if menu.selectedIndex == 1 then
            -- Text input - handled by textinput
            return true
        elseif menu.selectedIndex == 2 then
            -- Join room
            if menu.roomCode ~= "" then
                if menu.onJoinOnline then
                    menu.onJoinOnline(menu.roomCode:upper())
                end
            end
            return true
        elseif menu.selectedIndex == 3 then
            -- Back
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 3
            return true
        end
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 3
        return true
    end
    return false
end

-- Handle keyboard input for online browse screen
function OnlineScreens.handleBrowseKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    -- If there's an error, only allow going back
    if menu.onlineError then
        if key == "return" or key == "space" or key == "x" or key == "escape" or key == "z" then
            menu.onlineError = nil
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 2
            return true
        end
        return false
    end
    
    local maxIndex = #menu.onlineRooms + 2
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if menu.selectedIndex >= 1 and menu.selectedIndex <= #menu.onlineRooms then
            -- Join selected room
            local roomIndex = menu.selectedIndex
            if menu.onlineRooms[roomIndex] then
                if menu.onJoinOnline then
                    menu.onJoinOnline(menu.onlineRooms[roomIndex].code)
                end
            end
            return true
        elseif menu.selectedIndex == #menu.onlineRooms + 1 then
            -- Refresh
            if menu.onRefreshOnlineRooms then
                menu.onRefreshOnlineRooms()
            end
            return true
        elseif menu.selectedIndex == #menu.onlineRooms + 2 then
            -- Back
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 2
            return true
        end
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 2
        return true
    end
    return false
end

-- Handle text input for online screens
function OnlineScreens.handleTextInput(menu, text)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.ONLINE_JOIN then
        if menu.selectedIndex == 1 and #menu.roomCode < 6 then
            menu.roomCode = menu.roomCode .. text:upper()
            return true
        end
    end
    
    return false
end

-- Handle backspace for online screens
function OnlineScreens.handleBackspace(menu)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.ONLINE_JOIN then
        if menu.selectedIndex == 1 and #menu.roomCode > 0 then
            menu.roomCode = menu.roomCode:sub(1, -2)
            return true
        end
    end
    
    return false
end

-- Handle keyboard input for online waiting screen
function OnlineScreens.handleWaitingKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    if key == "escape" or key == "z" then
        print("Menu: User cancelled online hosting")
        
        -- Disconnect online client
        if menu.onCancel then
            menu.onCancel()
        end
        
        -- Clear online room state
        menu.onlineRoomCode = nil
        
        -- Return to online submenu
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 1
        return true
    end
    
    return false
end

-- Handle gamepad input for online waiting screen
function OnlineScreens.handleWaitingGamepad(menu, button, game)
    local Base = require('src.ui.menu.base')
    
    if button == "b" or button == "back" then
        print("Menu: User cancelled online hosting (gamepad)")
        
        -- Disconnect online client
        if menu.onCancel then
            menu.onCancel()
        end
        
        -- Clear online room state
        menu.onlineRoomCode = nil
        
        -- Return to online submenu
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 1
        return true
    end
    
    return false
end

return OnlineScreens
