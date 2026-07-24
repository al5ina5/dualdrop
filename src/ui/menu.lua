-- src/ui/menu.lua
-- Menu system coordinator - delegates to specific screen modules

local Base = require('src.ui.menu.base')
local MainMenu = require('src.ui.menu.main_menu')
local PauseMenu = require('src.ui.menu.pause_menu')
local ServerBrowser = require('src.ui.menu.server_browser')
local IPInput = require('src.ui.menu.ip_input')
local WaitingScreens = require('src.ui.menu.waiting_screens')
local Options = require('src.ui.menu.options_screen')
local Stats = require('src.ui.menu.stats_screen')
local ControlsUI = require('src.ui.menu.controls_screen')
local OnlineScreens = require('src.ui.menu.online_screens')
local RoomCodeInput = require('src.ui.menu.room_code_input')
local LobbyScreen = require('src.ui.menu.lobby_screen')
local SetupScreen = require('src.ui.menu.setup_screen')

local Menu = {}
Menu.__index = Menu

-- Export state constants
Menu.STATE = Base.STATE

function Menu:new(discovery, fonts)
    local menu = Base.create(discovery, fonts)
    setmetatable(menu, Menu)
    
    -- Initialize sub-menus with digit pickers
    Options.init(menu)
    ControlsUI.init(menu)
    RoomCodeInput.init(menu)
    IPInput.init(menu)
    
    return menu
end

function Menu:show(state)
    Base.show(self, state)
end

function Menu:hide()
    Base.hide(self)
end

function Menu:isVisible()
    return Base.isVisible(self)
end

function Menu:update(dt)
    Base.update(self, dt)
end

function Menu:setIPFromText(ipText)
    Base.setIPFromText(self, ipText)
end

function Menu:drawBackground(game)
    Base.drawBackground(self, game)
end

function Menu:drawForeground(game)
    if not self:isVisible() then return end
    local sw, sh = 640, 480

    if self.fonts then
        love.graphics.setFont(self.fonts.medium)
    end

    if self.state == Menu.STATE.MAIN or self.state == Menu.STATE.SUBMENU_SINGLEPLAYER or self.state == Menu.STATE.SUBMENU_MULTIPLAYER or self.state == Menu.STATE.SUBMENU_LAN or self.state == Menu.STATE.SUBMENU_ONLINE then
        MainMenu.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.WAITING then
        WaitingScreens.drawWaiting(self, sw, sh, game)
    elseif self.state == Menu.STATE.BROWSE then
        ServerBrowser.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.CONNECTING then
        WaitingScreens.drawConnecting(self, sw, sh, game)
    elseif self.state == Menu.STATE.IP_INPUT then
        IPInput.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.PAUSE then
        PauseMenu.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.OPTIONS then
        Options.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.STATS then
        Stats.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.CONTROLS then
        ControlsUI.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.ONLINE_HOST then
        OnlineScreens.drawHost(self, sw, sh, game)
    elseif self.state == Menu.STATE.ONLINE_JOIN then
        OnlineScreens.drawJoin(self, sw, sh, game)
    elseif self.state == Menu.STATE.ONLINE_BROWSE then
        OnlineScreens.drawBrowse(self, sw, sh, game)
    elseif self.state == Menu.STATE.ONLINE_WAITING then
        OnlineScreens.drawWaiting(self, sw, sh, game)
    elseif self.state == Menu.STATE.ROOM_CODE_INPUT then
        RoomCodeInput.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.MATCH_SETUP then
        SetupScreen.draw(self, sw, sh, game)
    elseif self.state == Menu.STATE.LOBBY then
        LobbyScreen.draw(self, sw, sh, game)
    end

    love.graphics.setColor(1, 1, 1)
end

function Menu:keypressed(key, game)
    if not self:isVisible() then return false end
    if self.inputCooldown > 0 then return true end

    local handled = false
    if self.state == Menu.STATE.MAIN or self.state == Menu.STATE.SUBMENU_SINGLEPLAYER or self.state == Menu.STATE.SUBMENU_MULTIPLAYER or self.state == Menu.STATE.SUBMENU_LAN or self.state == Menu.STATE.SUBMENU_ONLINE then
        handled = MainMenu.handleKey(self, key, game)
    elseif self.state == Menu.STATE.WAITING then
        handled = WaitingScreens.handleWaitingKey(self, key, game)
    elseif self.state == Menu.STATE.BROWSE then
        handled = ServerBrowser.handleKey(self, key)
    elseif self.state == Menu.STATE.PAUSE then
        handled = PauseMenu.handleKey(self, key)
    elseif self.state == Menu.STATE.OPTIONS then
        handled = Options.handleKey(self, key, self.onSettingChanged)
    elseif self.state == Menu.STATE.STATS then
        handled = Stats.handleKey(self, key)
    elseif self.state == Menu.STATE.CONTROLS then
        handled = ControlsUI.handleKey(self, key)
    elseif self.state == Menu.STATE.IP_INPUT then
        handled = IPInput.handleKey(self, key)
    elseif self.state == Menu.STATE.CONNECTING then
        handled = WaitingScreens.handleConnectingKey(self, key)
    elseif self.state == Menu.STATE.ONLINE_HOST then
        handled = OnlineScreens.handleHostKey(self, key, game)
    elseif self.state == Menu.STATE.ONLINE_JOIN then
        handled = OnlineScreens.handleJoinKey(self, key, game)
    elseif self.state == Menu.STATE.ONLINE_BROWSE then
        handled = OnlineScreens.handleBrowseKey(self, key, game)
    elseif self.state == Menu.STATE.ONLINE_WAITING then
        handled = OnlineScreens.handleWaitingKey(self, key, game)
    elseif self.state == Menu.STATE.ROOM_CODE_INPUT then
        handled = RoomCodeInput.handleKey(self, key)
    elseif self.state == Menu.STATE.MATCH_SETUP then
        handled = SetupScreen.handleKey(self, key, game)
    elseif self.state == Menu.STATE.LOBBY then
        handled = LobbyScreen.handleKey(self, key, game)
    end
    
    -- Handle text input and backspace for online screens
    if key == "backspace" then
        handled = OnlineScreens.handleBackspace(self) or handled
    end

    if handled then
        self.inputCooldown = self.COOLDOWN_TIME
    end
    return handled
end

function Menu:gamepadpressed(button, game)
    if not self:isVisible() then return false end
    if self.inputCooldown > 0 then return true end

    local handled = false
    if self.state == Menu.STATE.MAIN or self.state == Menu.STATE.SUBMENU_SINGLEPLAYER or self.state == Menu.STATE.SUBMENU_MULTIPLAYER or self.state == Menu.STATE.SUBMENU_LAN or self.state == Menu.STATE.SUBMENU_ONLINE then
        handled = MainMenu.handleGamepad(self, button, game)
    elseif self.state == Menu.STATE.WAITING then
        handled = WaitingScreens.handleWaitingGamepad(self, button, game)
    elseif self.state == Menu.STATE.BROWSE then
        handled = ServerBrowser.handleGamepad(self, button)
    elseif self.state == Menu.STATE.PAUSE then
        handled = PauseMenu.handleGamepad(self, button)
    elseif self.state == Menu.STATE.OPTIONS then
        handled = Options.handleGamepad(self, button, self.onSettingChanged)
    elseif self.state == Menu.STATE.STATS then
        handled = Stats.handleGamepad(self, button)
    elseif self.state == Menu.STATE.CONTROLS then
        handled = ControlsUI.handleGamepad(self, button)
    elseif self.state == Menu.STATE.IP_INPUT then
        handled = IPInput.handleGamepad(self, button)
    elseif self.state == Menu.STATE.CONNECTING then
        handled = WaitingScreens.handleConnectingGamepad(self, button)
    elseif self.state == Menu.STATE.ONLINE_WAITING then
        handled = OnlineScreens.handleWaitingGamepad(self, button, game)
    elseif self.state == Menu.STATE.ROOM_CODE_INPUT then
        handled = RoomCodeInput.handleGamepad(self, button)
    elseif self.state == Menu.STATE.MATCH_SETUP then
        handled = SetupScreen.handleGamepad(self, button, game)
    elseif self.state == Menu.STATE.LOBBY then
        handled = LobbyScreen.handleGamepad(self, button, game)
    elseif self.state == Menu.STATE.ONLINE_HOST then
        handled = OnlineScreens.handleHostKey(self, button == "a" and "return" or (button == "b" and "escape" or button), game)
    elseif self.state == Menu.STATE.ONLINE_BROWSE then
        -- map common gamepad to browse keys
        local keyMap = { dpup = "up", dpdown = "down", a = "return", b = "escape", start = "return" }
        if keyMap[button] then
            handled = OnlineScreens.handleBrowseKey(self, keyMap[button], game)
        end
    end

    if handled then
        self.inputCooldown = self.COOLDOWN_TIME
    end
    return handled
end

function Menu:textinput(text)
    if not self:isVisible() then return false end
    return OnlineScreens.handleTextInput(self, text)
end

function Menu:close()
    -- Discovery is owned by Game, don't close it here
end

return Menu
