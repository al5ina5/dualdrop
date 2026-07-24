-- src/game/game.lua
-- Main game coordinator - ties together all game modules

local TetrisBoard = require('src.tetris.board')
local Input = require('src.input.input_state')
local Discovery = require('src.net.discovery')
local Menu = require('src.ui.menu')
local Audio = require('src.audio')
local FX = require('src.fx')
local Controls = require('src.input.controls')
local Settings = require('src.data.settings')
local Scores = require('src.data.scores')

local Renderer = require('src.game.renderer')
local StateManager = require('src.game.state_manager')
local InputHandler = require('src.game.input_handler')
local NetworkHandler = require('src.game.network_handler')
local SettingsHandler = require('src.game.settings_handler')
local ConnectionManager = require('src.game.connection_manager')
local LocalSession = require('src.game.local_session')

local Game = {
    isHost = false,
    localBoard = nil,
    remoteBoards = {},
    network = nil,
    discovery = nil,
    menu = nil,
    playerId = nil,
    lastSentMove = {x=0, y=0, rot=0, type=""},
    lastSentScore = 0,
    sentGameOver = false,
    gameMode = "VERSUS", -- "VERSUS" or "SPRINT"
    matchFormat = "1v1", -- "1v1" | "2v1" | "2v2"
    localPlayerCount = 1,
    versusRules = "classic", -- "classic" | "chaos" | "cheese"
    localPlayers = nil,
    ownedSeats = nil,
    lobby = nil,
    peerId = nil,
    localVersus = false,
    sprintTime = 0,
    matchTime = 0,
    
    -- Sub-modules
    renderer = nil,
    stateManager = nil,
    connectionManager = nil,
    latency = 0,
    pingTimer = 0
}

-- Expose state for convenience
function Game:getState()
    return self.stateManager.current
end

-- Setter for cleaner API
function Game:setState(newState)
    self.stateManager.current = newState
end

-- Backwards compatibility property (getter)
setmetatable(Game, {
    __index = function(t, k)
        if k == "state" then
            return rawget(t, "stateManager") and rawget(t, "stateManager").current
        end
        return rawget(t, k)
    end,
    __newindex = function(t, k, v)
        if k == "state" then
            if rawget(t, "stateManager") then
                rawget(t, "stateManager").current = v
            end
        else
            rawset(t, k, v)
        end
    end
})

function Game:load()
    local savedSettings = Settings.load()
    
    -- Initialize controls
    Controls.load(savedSettings.controls)
    
    -- Initialize sub-modules
    self.renderer = Renderer.init()
    self.stateManager = StateManager.create()
    self.connectionManager = ConnectionManager.create()
    
    self.localBoard = TetrisBoard:new(10, 20)
    self.remoteBoards = {}
    self.network = nil
    self.isHost = false
    self.playerId = nil
    self.sentGameOver = false
    
    self.discovery = Discovery:new()
    self.menu = Menu:new(self.discovery, self.renderer.fonts)
    
    Scores.load()

    -- Sync menu settings with saved settings
    for k, v in pairs(savedSettings) do
        self.menu.settings[k] = v
    end
    if savedSettings.lastIP then
        self.menu:setIPFromText(savedSettings.lastIP)
    end

    Audio:init()
    
    -- Setup menu callbacks
    self.menu.onHost = function() ConnectionManager.becomeHost(self) end
    self.menu.onStopHost = function() ConnectionManager.stopHosting(self) end
    self.menu.onStartAlone = function() self:startAlone() end
    self.menu.onJoin = function(ip, port)
        self.gameMode = "VERSUS"
        self.localPlayerCount = LocalSession.claimCount(self)
        if self.menu then self.menu.localPlayerCount = self.localPlayerCount end
        ConnectionManager.connectToServer(ip, port, self)
    end
    self.menu.onMainMenu = function() ConnectionManager.returnToMainMenu(self) end
    self.menu.onSettingChanged = function(key, value)
        SettingsHandler.handleChange(key, value, self, self.renderer)
    end
    self.menu.onControlsChanged = function()
        SettingsHandler.handleControlsChange(self)
    end
    self.menu.onCancel = function()
        print("Game: Cancel requested")
        ConnectionManager.cleanupSession(self)
        self.stateManager.current = "waiting"
        Audio:playMusic('menu')
    end
    self.menu.onHostOnline = function(isPublic)
        ConnectionManager.hostOnline(isPublic, self)
    end
    self.menu.onJoinOnline = function(roomCode)
        self.gameMode = "VERSUS"
        self.localPlayerCount = LocalSession.claimCount(self)
        if self.menu then self.menu.localPlayerCount = self.localPlayerCount end
        ConnectionManager.joinOnline(roomCode, self)
    end
    self.menu.onRefreshOnlineRooms = function()
        ConnectionManager.refreshOnlineRooms(self)
    end
    self.menu.onHostSetupDone = function(format, localCount, rules)
        self.gameMode = "VERSUS"
        self.matchFormat = format or "1v1"
        self.versusRules = rules or self.menu.versusRules or "classic"
        self.localPlayerCount = LocalSession.claimCount(self)
        if self.menu then self.menu.localPlayerCount = self.localPlayerCount end
        ConnectionManager.becomeHost(self)
    end
    self.menu.onLocalSetupDone = function(rules)
        self:enterLocalVersusLobby(rules)
    end
    self.menu.onLobbyReady = function()
        ConnectionManager.toggleReady(self)
    end
    self.menu.onLobbyStart = function()
        if self.localVersus then
            self:startLocalVersusMatch()
        else
            ConnectionManager.hostStartMatch(self)
        end
    end
    -- Local count / P2 join is handled by LocalSession via Start on unused pad
    self.menu.onLocalCountChanged = nil
    self.menu.onPadJoinLocal = nil
    
    -- Apply initial settings
    SettingsHandler.handleChange("shader", self.menu.settings.shader, self, self.renderer)
    SettingsHandler.handleChange("bgColor", self.menu.settings.bgColor or "BLACK", self, self.renderer)
    SettingsHandler.handleChange("musicVolume", self.menu.settings.musicVolume, self, self.renderer)
    SettingsHandler.handleChange("sfxVolume", self.menu.settings.sfxVolume, self, self.renderer)
    SettingsHandler.handleChange("fullscreen", self.menu.settings.fullscreen, self, self.renderer)
    SettingsHandler.handleChange("ghost", self.menu.settings.ghost, self, self.renderer)
    
    self.menu:show()
    Audio:playMusic('menu')
end

function Game:update(dt)
    self.discovery:update(dt)
    FX:update(dt)
    LocalSession.update(self, dt)
    
    -- ALWAYS poll network messages
    if self.network then
        local messages = self.network:poll()
        for _, msg in ipairs(messages) do
            NetworkHandler.handleMessage(msg, self)
        end
    end

    -- Update connection manager
    ConnectionManager.update(dt, self)
    
    -- State machine updates (run even when menu visible for waiting state)
    StateManager.update(self.stateManager, dt, self)

    if self.menu:isVisible() then
        self.menu:update(dt)
        Input:postUpdate()  -- Clear input state even when menu visible
        return
    end

    if self.stateManager.current == StateManager.STATES.DISCONNECTED_PAUSE then
        return -- Skip normal game logic while paused
    end

    -- Update input timers
    Input:update(dt)

    -- Playing state logic
    if self.stateManager.current == StateManager.STATES.PLAYING then
        self:updatePlaying(dt)
    elseif self.stateManager.current == StateManager.STATES.COUNTDOWN then
        -- Sync boards during countdown so guests see opponent pieces immediately
        NetworkHandler.syncLocalState(self)
    end

    Input:postUpdate()
end

function Game:updatePlaying(dt)
    local TeamMatch = require('src.game.team_match')
    TeamMatch.tryToggleEnemyOverlay(self)

    local players = self.localPlayers
    if not players or #players == 0 then
        players = {{ id = self.playerId or "local", board = self.localBoard, device = "any" }}
    end

    for _, lp in ipairs(players) do
        local board = lp.board
        if board and not board.gameOver then
            local device = lp.device or "any"

            if Controls.shouldActionRepeat("move_left", Input, device) then
                local dir = (board.invertTimer and board.invertTimer > 0) and 1 or -1
                if board:move(dir, 0) then Audio:play('move') end
            end
            if Controls.shouldActionRepeat("move_right", Input, device) then
                local dir = (board.invertTimer and board.invertTimer > 0) and -1 or 1
                if board:move(dir, 0) then Audio:play('move') end
            end
            if Controls.shouldActionRepeat("move_down", Input, device) then
                if board:move(0, 1) then
                    Audio:play('move')
                    board.score = board.score + 1
                end
            end

            if Controls.isActionPressed("hard_drop", Input, device) then
                local dropDistance = 0
                while board:move(0, 1) do
                    dropDistance = dropDistance + 1
                end
                board.score = board.score + (dropDistance * 2)
                board:lockPiece()
            end

            if Controls.isActionPressed("rotate_cw", Input, device) then
                if not (board.iceTimer and board.iceTimer > 0) then
                    local ccw = (board.invertTimer and board.invertTimer > 0)
                    if board:rotate(ccw) then Audio:play('rotate') end
                end
            end
            if Controls.isActionPressed("rotate_ccw", Input, device) then
                if not (board.iceTimer and board.iceTimer > 0) then
                    local ccw = not (board.invertTimer and board.invertTimer > 0)
                    if board:rotate(ccw) then Audio:play('rotate') end
                end
            end

            if Controls.isActionPressed("hold", Input, device) then
                if board:hold() then
                    Audio:play('rotate')
                end
            end

            if Controls.isActionPressed("fire_power", Input, device) then
                if board.chaosEnabled and board.chaosPowerUp and not board.chaosLottery then
                    local effect = board.chaosPowerUp
                    if NetworkHandler.sendEffect(self, effect, lp.id) then
                        board.chaosPowerUp = nil
                    end
                end
            end

            board:update(dt)

            if board.garbageToNotify then
                NetworkHandler.sendGarbage(self, board.garbageToNotify, lp.id)
                board.garbageToNotify = nil
            end

            -- Cheese race: emptied the board after clearing something
            local VersusRules = require('src.game.versus_rules')
            if VersusRules.isCheese(self) and not board.raceWon
                and VersusRules.isBoardEmpty(board) and (board.linesCleared or 0) > 0 then
                board.raceWon = true
                NetworkHandler.sendRaceWin(self, lp.id)
            end
        elseif board then
            board:update(dt)
        end
    end

    -- Always sync while playing so GAME_OVER / board diffs are not skipped on quiet frames
    NetworkHandler.syncLocalState(self)
    NetworkHandler.syncScore(self)
end

function Game:startAlone()
    print("Game: Starting alone")
    self.isHost = true
    self.lobby = nil
    self.ownedSeats = nil
    self.matchFormat = nil
    self.localVersus = false
    ConnectionManager.stopLanAdvertising(self)
    if self.network then
        self.network:disconnect()
        self.network = nil
    end
    LocalSession.beginSoloSession(self)
    self.menu:hide()
    StateManager.startCountdown(self.stateManager, self)
end

function Game:enterLocalVersusLobby(rules)
    print("Game: Entering local versus lobby")
    LocalSession.enterLocalVersusLobby(self, rules)
end

function Game:startLocalVersusMatch()
    if not LocalSession.canStartLocalVersus(self) then
        LocalSession.toast(self, "Waiting for P2 — Start on 2nd pad")
        return
    end
    print("Game: Starting local versus")
    if not LocalSession.beginLocalVersus(self, self.versusRules) then
        LocalSession.toast(self, "Waiting for P2 — Start on 2nd pad")
        return
    end
    self.menu:hide()
    StateManager.startCountdown(self.stateManager, self)
end

function Game:draw()
    Renderer.draw(self.renderer, self)
end

function Game:drawText(text, x, y, limit, align, color, shadowColor, outlineColor)
    Renderer.drawText(text, x, y, limit, align, color, shadowColor, outlineColor, self.renderer.fonts)
end

function Game:countRemotePlayers()
    local count = 0
    for _ in pairs(self.remoteBoards) do count = count + 1 end
    return count
end

function Game:keypressed(key)
    InputHandler.keypressed(key, self)
end

function Game:keyreleased(key)
    InputHandler.keyreleased(key, self)
end

function Game:gamepadpressed(button, joystick)
    InputHandler.gamepadpressed(button, self, joystick)
end

function Game:gamepadreleased(button, joystick)
    InputHandler.gamepadreleased(button, self, joystick)
end

function Game:quit()
    if self.network then self.network:disconnect() end
    if self.discovery then self.discovery:close() end
end

return Game
