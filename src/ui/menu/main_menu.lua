-- src/ui/menu/main_menu.lua
-- Main menu screen

local MainMenu = {}

local ONLINE_STATUS_TTL = 20

function MainMenu.refreshOnlineStatus(menu, force)
    local now = love.timer.getTime()
    if not force and menu.onlineServerCheckedAt
        and (now - menu.onlineServerCheckedAt) < ONLINE_STATUS_TTL then
        return menu.onlineServersOnline
    end
    local OnlineClient = require('src.net.online_client')
    menu.onlineServersOnline = OnlineClient.isServerReachable()
    menu.onlineServerCheckedAt = now
    return menu.onlineServersOnline
end

function MainMenu.draw(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.MAIN then
        -- Main menu - link style with subtitle
        local options = {
            "SINGLE PLAYER",
            "MULTIPLAYER",
            "STATS",
            "OPTIONS",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "DUALDROP", nil, options)
    elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
        -- Single player submenu - link style
        local options = {
            "SPRINT (40 LINES)",
            "MARATHON",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "SINGLE PLAYER", nil, options)
    elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
        MainMenu.refreshOnlineStatus(menu)
        -- Multiplayer submenu — ONLINE struck/dimmed when matchmaking is down
        local options = {
            "LOCAL",
            { label = "ONLINE", disabled = not menu.onlineServersOnline },
            "LAN",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "MULTIPLAYER", nil, options)
    elseif menu.state == Base.STATE.SUBMENU_LAN then
        -- LAN submenu - link style
        local options = {
            "CREATE GAME",
            "FIND GAME",
            "JOIN BY IP",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "LAN", nil, options)
        if menu.connectionError then
            love.graphics.setFont(game.renderer.fonts.small)
            local y = sh - 90
            for line in menu.connectionError:gmatch("[^\n]+") do
                game:drawText(line, 0, y, sw, "center", {1, 0.45, 0.45})
                y = y + 18
            end
            love.graphics.setFont(game.renderer.fonts.medium)
        end
    elseif menu.state == Base.STATE.SUBMENU_ONLINE then
        -- Online submenu - link style
        local options = {
            "CREATE GAME",
            "FIND GAME",
            "JOIN WITH CODE",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "ONLINE", nil, options)
    end
end

function MainMenu.handleKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    local maxIndex = MainMenu.getMaxIndex(menu)
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        return MainMenu.select(menu, game)
    elseif key == "escape" or key == "z" then
        -- Back navigation
        if menu.state == Base.STATE.MAIN then
            return true -- No escape from main menu
        elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 2
            return true
        elseif menu.state == Base.STATE.SUBMENU_ONLINE then
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 2  -- ONLINE is 2nd
            return true
        elseif menu.state == Base.STATE.SUBMENU_LAN then
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 3  -- LAN is 3rd
            return true
        else
            -- Default back to main menu
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        end
    end
    return false
end

function MainMenu.handleGamepad(menu, button, game)
    local Base = require('src.ui.menu.base')
    local maxIndex = MainMenu.getMaxIndex(menu)
    
    if button == "dpup" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif button == "a" or button == "start" then
        return MainMenu.select(menu, game)
    elseif button == "b" or button == "back" then
        -- Back navigation
        if menu.state == Base.STATE.MAIN then
            return true -- No escape from main menu
        elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 2
            return true
        elseif menu.state == Base.STATE.SUBMENU_ONLINE then
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 2  -- ONLINE is 2nd
            return true
        elseif menu.state == Base.STATE.SUBMENU_LAN then
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 3  -- LAN is 3rd
            return true
        else
            -- Default back to main menu
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        end
    end
    return false
end

function MainMenu.getMaxIndex(menu)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.MAIN then
        return 4  -- Single Player, Multiplayer, Stats, Options
    elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
        return 3  -- Sprint, Marathon, Back
    elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
        return 4  -- Local, Online, LAN, Back
    elseif menu.state == Base.STATE.SUBMENU_LAN then
        return 4  -- Create Game, Find Game, Join IP, Back
    elseif menu.state == Base.STATE.SUBMENU_ONLINE then
        return 4  -- Create Game, Find Game, Join Code, Back
    end
    return 1
end

function MainMenu.select(menu, game)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.MAIN then
        -- Main menu
        if menu.selectedIndex == 1 then
            -- Single Player
            menu.state = Base.STATE.SUBMENU_SINGLEPLAYER
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 2 then
            -- Multiplayer
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 3 then
            -- Stats hub (Statistics / Match History)
            menu.previousState = menu.state
            menu.state = Base.STATE.STATS
            menu.statsView = "hub"
            menu.selectedIndex = 1
            menu.historyScrollIndex = 1
        elseif menu.selectedIndex == 4 then
            -- Options
            menu.previousState = menu.state
            menu.state = Base.STATE.OPTIONS
            menu.optionsSelectedIndex = 1
        end
    elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
        -- Single player submenu
        if menu.selectedIndex == 1 then
            -- Sprint
            if game then game.gameMode = "SPRINT" end
            if menu.onStartAlone then menu.onStartAlone() end
        elseif menu.selectedIndex == 2 then
            -- Marathon
            if game then game.gameMode = "MARATHON" end
            if menu.onStartAlone then menu.onStartAlone() end
        elseif menu.selectedIndex == 3 then
            -- Back
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
        end
    elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
        -- Multiplayer submenu
        if menu.selectedIndex == 1 then
            -- Local splitscreen — rules setup then start
            menu.setupMode = "local"
            menu.setupReturnState = Base.STATE.SUBMENU_MULTIPLAYER
            menu.matchFormat = "1v1"
            menu.localPlayerCount = 2
            menu.state = Base.STATE.MATCH_SETUP
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 2 then
            -- Online (blocked while matchmaking servers are offline)
            MainMenu.refreshOnlineStatus(menu)
            if not menu.onlineServersOnline then
                return true
            end
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 3 then
            -- LAN
            menu.state = Base.STATE.SUBMENU_LAN
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 4 then
            -- Back
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 2
        end
    elseif menu.state == Base.STATE.SUBMENU_LAN then
        -- LAN submenu
        menu.connectionError = nil
        if menu.selectedIndex == 1 then
            -- Host LAN — setup format + local players first
            menu.setupMode = "host"
            menu.setupReturnState = Base.STATE.SUBMENU_LAN
            menu.matchFormat = menu.matchFormat or "1v1"
            menu.localPlayerCount = menu.localPlayerCount or 1
            menu.state = Base.STATE.MATCH_SETUP
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 2 then
            -- Browse LAN Games
            if game then game.gameMode = "VERSUS" end
            menu.state = Base.STATE.BROWSE
            menu.selectedIndex = 1
            menu.discovery:sendDiscoveryRequest()
        elseif menu.selectedIndex == 3 then
            -- Join by IP — go straight to IP entry (host owns format/rules)
            if game then game.gameMode = "VERSUS" end
            menu.localPlayerCount = 1
            if game then game.localPlayerCount = 1 end
            menu.pendingJoinTarget = { kind = "ip" }
            menu.state = Base.STATE.IP_INPUT
            menu.selectedIndex = 1
            menu.selectedDigit = 1
        elseif menu.selectedIndex == 4 then
            -- Back
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 3  -- LAN is 3rd
        end
    elseif menu.state == Base.STATE.SUBMENU_ONLINE then
        -- Online submenu
        if menu.selectedIndex == 1 then
            -- Host Online — format setup then host screen
            menu.setupMode = "host_online"
            menu.setupReturnState = Base.STATE.SUBMENU_ONLINE
            menu.matchFormat = menu.matchFormat or "1v1"
            menu.localPlayerCount = menu.localPlayerCount or 1
            menu.state = Base.STATE.MATCH_SETUP
            menu.selectedIndex = 1
            menu.isPublicRoom = true
        elseif menu.selectedIndex == 2 then
            -- Browse Online Games
            if game then game.gameMode = "VERSUS" end
            menu.localPlayerCount = 1
            if game then game.localPlayerCount = 1 end
            menu.state = Base.STATE.ONLINE_BROWSE
            menu.selectedIndex = 1
            if menu.onRefreshOnlineRooms then menu.onRefreshOnlineRooms() end
        elseif menu.selectedIndex == 3 then
            -- Join with Code — go straight to code entry
            if game then game.gameMode = "VERSUS" end
            menu.localPlayerCount = 1
            if game then game.localPlayerCount = 1 end
            menu.roomCode = ""
            menu.state = Base.STATE.ROOM_CODE_INPUT
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 4 then
            -- Back
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 2  -- ONLINE is 2nd
        end
    end
    return true
end

return MainMenu
