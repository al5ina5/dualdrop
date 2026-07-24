-- main.lua
-- Entry point for the LÖVE2D game

local Game = require('src.game.game')

function love.load()
    -- Pixel-art friendly graphics settings
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Set window title
    love.window.setTitle("Dualdrop")

    -- Initialize game
    Game:load()
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    -- Draw the game directly using the full window space
    Game:draw()
end

-- Input event (like an event listener)
function love.keypressed(key)
    Game:keypressed(key)
end

function love.keyreleased(key)
    Game:keyreleased(key)
end

function love.gamepadpressed(joystick, button)
    Game:gamepadpressed(button, joystick)
end

function love.gamepadreleased(joystick, button)
    Game:gamepadreleased(button, joystick)
end

function love.textinput(text)
    if Game.menu and Game.menu.textinput then
        Game.menu:textinput(text)
    end
end

-- Clean up on exit
function love.quit()
    Game:quit()
end