-- src/ui/menu/base.lua
-- Base menu system with shared state and helpers

local Background = require('src.ui.menu.background')
local TitleAnimation = require('src.ui.menu.title_animation')

local Base = {}

Base.STATE = {
    MAIN = "main",
    SUBMENU_SINGLEPLAYER = "submenu_singleplayer",
    SUBMENU_MULTIPLAYER = "submenu_multiplayer",
    SUBMENU_LAN = "submenu_lan",
    SUBMENU_ONLINE = "submenu_online",
    HOST = "host",
    BROWSE = "browse",
    CONNECTING = "connecting",
    WAITING = "waiting",
    IP_INPUT = "ip_input",
    OPTIONS = "options",
    PAUSE = "pause",
    STATS = "stats",
    CONTROLS = "controls",
    -- Online multiplayer states
    ONLINE_HOST = "online_host",
    ONLINE_JOIN = "online_join",
    ONLINE_BROWSE = "online_browse",
    ONLINE_WAITING = "online_waiting",
    ROOM_CODE_INPUT = "room_code_input",
    -- Team / party lobby
    MATCH_SETUP = "match_setup",
    LOBBY = "lobby",
}

function Base.create(discovery, fonts)
    local menu = {
        state = nil,  -- Hidden by default
        previousState = nil,
        discovery = discovery,
        fonts = fonts,
        
        selectedServer = nil,
        selectedIndex = 1,
        serverName = "Player's Game",
        scanTimer = 0,
        
        inputCooldown = 0,
        COOLDOWN_TIME = 0.15,
        
        -- IP Input state
        ipDigits = {1,9,2,  1,6,8,  0,0,1,  0,0,1},
        selectedDigit = 1,
        
        -- Online multiplayer state
        playerName = "",
        roomCode = "",
        isPublicRoom = true,
        onlineRooms = {},
        onlineError = nil,
        onlineServersOnline = false,
        onlineServerCheckedAt = 0,
        connectionError = nil,

        -- Team battle lobby
        matchFormat = "1v1",
        localPlayerCount = 1,
        versusRules = "classic",
        setupMode = "host", -- host | join
        setupReturnState = nil,
        pendingJoinTarget = nil, -- { ip, port } or { roomCode }
        
        -- Background
        fallingBlocks = Background.init(),
        
        -- Title animation
        titleAnimation = TitleAnimation.init(),
        
        -- Callbacks (set by game)
        onHost = nil,
        onStopHost = nil,
        onStartAlone = nil,
        onJoin = nil,
        onCancel = nil,
        onMainMenu = nil,
        onSettingChanged = nil,
        onControlsChanged = nil,
        onHostOnline = nil,
        onJoinOnline = nil,
        onRefreshOnlineRooms = nil,
        onHostSetupDone = nil,
        onLocalSetupDone = nil,
        onJoinSetupDone = nil,
        onLobbyReady = nil,
        onLobbyStart = nil,
        onLocalCountChanged = nil,
        onPadJoinLocal = nil,
        
        -- Settings
        settings = {}
    }
    
    return menu
end

function Base.show(menu, state)
    state = state or Base.STATE.MAIN
    print("Menu: Showing menu, state: " .. tostring(state))
    menu.state = state
    menu.selectedIndex = 1
    menu.scanTimer = 0
    menu.inputCooldown = 0.2

    if state == Base.STATE.BROWSE then
        menu.discovery:startListening()
        menu.discovery:sendDiscoveryRequest()
    elseif state == Base.STATE.MAIN then
        menu.discovery:startListening()
        -- Reset title animation when returning to main menu
        if menu.titleAnimation.initialized then
            TitleAnimation.reset(menu.titleAnimation)
        end
    end
end

function Base.hide(menu)
    print("Menu: Hiding menu (was in state: " .. tostring(menu.state) .. ")")
    menu.state = nil
end

function Base.isVisible(menu)
    return menu.state ~= nil
end

function Base.update(menu, dt)
    if not Base.isVisible(menu) then return end
    
    -- Update falling blocks
    Background.update(menu.fallingBlocks, dt)
    
    -- Update title animation
    if menu.state == Base.STATE.MAIN then
        TitleAnimation.update(menu.titleAnimation, dt)
    end

    -- Update input cooldown
    if menu.inputCooldown > 0 then
        menu.inputCooldown = menu.inputCooldown - dt
    end
    
    -- Periodically rescan for servers when browsing
    if menu.state == Base.STATE.BROWSE then
        menu.scanTimer = menu.scanTimer + dt
        if menu.scanTimer >= 2.0 then
            menu.scanTimer = 0
            local hints = {}
            if menu.settings and menu.settings.lastIP then
                table.insert(hints, menu.settings.lastIP)
            end
            menu.discovery:sendDiscoveryRequest(hints)
        end
    end
end

function Base.drawBackground(menu, game)
    if not Base.isVisible(menu) then return end
    Background.draw(menu.fallingBlocks)
end

-- Normalize menu option: string or { label = "...", disabled = bool }
function Base.optionLabel(option)
    if type(option) == "table" then
        return option.label or option[1] or ""
    end
    return option
end

function Base.optionDisabled(option)
    return type(option) == "table" and option.disabled == true
end

-- Draw a link-style menu (centered, navigation-focused)
-- Used for main menu, submenus, pause menu, etc.
-- options: strings, or { label, disabled } tables for strikethrough/dim items
function Base.drawLinkMenu(menu, sw, sh, game, title, subtitle, options)
    -- Title
    if title then
        if title == "DUALDROP" then
            -- Main menu title - animated falling letters
            if menu.fonts and menu.fonts.large then
                local font = menu.fonts.large
                -- Initialize title animation if needed
                if not menu.titleAnimation.initialized then
                    TitleAnimation.setup(menu.titleAnimation, title, font)
                end
                -- Draw animated title
                TitleAnimation.draw(menu.titleAnimation, sw/2, sh/2 - 130 + font:getHeight()/2, font, game, nil)
            end
        else
            -- Submenu titles - medium font
            if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
            game:drawText(title, 0, sh/2 - 130, sw, "center", {1, 1, 1})
        end
    end

    -- Subtitle (for main menu)
    if subtitle then
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText(subtitle, 0, sh/2 - 60, sw, "center", {0.7, 0.7, 0.7})
    end

    -- Menu options - centered
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    local font = love.graphics.getFont()
    local y = sh/2 - 20
    local spacing = 30
    
    for i, option in ipairs(options) do
        local label = Base.optionLabel(option)
        local disabled = Base.optionDisabled(option)
        local selected = (i == menu.selectedIndex)
        local color
        local text
        if disabled then
            color = selected and {0.55, 0.55, 0.35, 0.4} or {0.45, 0.45, 0.45, 0.35}
            text = (selected and "> " or "  ") .. label
        else
            color = selected and {1, 1, 0.5} or {0.8, 0.8, 0.8}
            text = (selected and "> " or "  ") .. label
        end
        
        game:drawText(text, 0, y, sw, "center", color,
            disabled and {0, 0, 0, (color[4] or 1) * 0.35} or nil,
            disabled and {0, 0, 0, (color[4] or 1) * 0.4} or nil)

        if disabled and font then
            local tw = font:getWidth(text)
            local th = font:getHeight()
            local lx = math.floor((sw - tw) / 2 + 0.5)
            local ly = math.floor(y + th * 0.5 + 0.5)
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.9)
            love.graphics.setLineWidth(1)
            love.graphics.line(lx, ly, lx + tw, ly)
            love.graphics.setColor(1, 1, 1, 1)
        end

        y = y + spacing
    end
end

-- Legacy function for backwards compatibility
-- Automatically detects which style to use based on title
function Base.drawList(menu, sw, sh, game, title, subtitle, options, startY)
    -- For navigation menus (main, submenus), use link style
    if title == "DUALDROP" or subtitle or not startY then
        Base.drawLinkMenu(menu, sw, sh, game, title, subtitle, options)
    else
        -- Content-heavy style (left-aligned, for options screens)
        if title then
            if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
            game:drawText(title, 0, 60, sw, "center", {1, 1, 1})
        end

        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        local y = startY or 120
        local spacing = 36
        
        for i, option in ipairs(options) do
            local color = {0.8, 0.8, 0.8}
            local text = "  " .. option
            if i == menu.selectedIndex then
                color = {1, 1, 0.5}
                text = "> " .. option
            end
            
            game:drawText(text, 40, y, sw - 80, "left", color)
            y = y + spacing
        end
    end
end

function Base.setIPFromText(menu, ipText)
    local octets = {}
    for octet in ipText:gmatch("%d+") do
        table.insert(octets, octet)
    end
    
    if #octets == 4 then
        local newDigits = {}
        for i = 1, 4 do
            local octet = octets[i]
            while #octet < 3 do
                octet = "0" .. octet
            end
            for j = 1, 3 do
                table.insert(newDigits, tonumber(octet:sub(j, j)))
            end
        end
        menu.ipDigits = newDigits
    end
end

return Base
