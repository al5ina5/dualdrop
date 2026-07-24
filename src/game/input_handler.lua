-- src/game/input_handler.lua
-- Handles all keyboard and gamepad input for gameplay

local Controls = require('src.input.controls')
local Input = require('src.input.input_state')
local StateManager = require('src.game.state_manager')
local LocalSession = require('src.game.local_session')

local InputHandler = {}

function InputHandler.keypressed(key, game)
    -- Ignore GUI/Command/Super keys - they're OS-level shortcuts, not game input
    if key == "lgui" or key == "rgui" then
        return
    end
    
    -- Update input state first so Controls can check it
    Input:keyPressed(key)
    LocalSession.noteKeyboardActivity(game)
    
    -- Check for game over dismissal (any key dismisses after delay)
    if game.state == "over" and not game.menu:isVisible() then
        if StateManager.dismissGameOver(game.stateManager, game) then
            return
        end
    end
    
    -- During disconnected pause, allow skipping with any key
    if game.state == "disconnected_pause" and not game.menu:isVisible() then
        StateManager.resumeAsSinglePlayer(game.stateManager, game)
        return
    end
    
    if game.menu:isVisible() then
        -- When menu is visible, only process menu input
        -- Don't fall through to game controls even if key wasn't handled
        game.menu:keypressed(key, game)
        return
    end
    
    -- Check pause action through Controls system only (when menu not visible)
    if Controls.isActionPressed("pause", Input) then
        InputHandler.handlePause(game)
    end
end

function InputHandler.keyreleased(key, game)
    Input:keyReleased(key)
end

function InputHandler.gamepadpressed(button, game, joystick)
    -- Update input state first so Controls can check it
    Input:gamepadPressed(button, joystick)

    local padIndex = LocalSession.resolvePadIndex(joystick)

    -- Unused pad Start = seamless P2 join (before pause / menu select).
    -- Must run before notePadActivity so Start itself doesn't latch as P1.
    if button == "start" and padIndex and not LocalSession.isAssignedPad(game, padIndex) then
        if LocalSession.tryJoinPad(game, padIndex) then
            return
        end
    elseif padIndex then
        LocalSession.notePadActivity(game, padIndex)
    end
    
    -- Check for game over dismissal (any button dismisses after delay)
    if game.state == "over" and not game.menu:isVisible() then
        if StateManager.dismissGameOver(game.stateManager, game) then
            return
        end
    end
    
    -- During disconnected pause, allow skipping with any button
    if game.state == "disconnected_pause" and not game.menu:isVisible() then
        StateManager.resumeAsSinglePlayer(game.stateManager, game)
        return
    end
    
    if game.menu:isVisible() then
        if game.menu:gamepadpressed(button, game) then return end
    end
    
    -- Check pause action through Controls system only
    if Controls.isActionPressed("pause", Input) then
        InputHandler.handlePause(game)
    end
end

function InputHandler.gamepadreleased(button, game, joystick)
    Input:gamepadReleased(button, joystick)
end

function InputHandler.handlePause(game)
    if game.state == "playing" or game.state == "countdown" or game.state == "over" then
        if game.menu:isVisible() then
            game.menu:hide()
        else
            game.menu:show(game.menu.STATE.PAUSE)
        end
    elseif game.state == "disconnected_pause" then
        -- Ignore pause during disconnect interstitial
        return
    else
        -- WAITING: opening the menu means leaving the session (never hide into a broken board)
        if not game.menu:isVisible() then
            if game.network then
                local ConnectionManager = require('src.game.connection_manager')
                ConnectionManager.handleSessionAbandoned(game, "user_left")
            else
                game.menu:show(game.menu.STATE.MAIN)
            end
        end
    end
end

return InputHandler
