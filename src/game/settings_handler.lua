-- src/game/settings_handler.lua
-- Handles all game settings changes

local Audio = require('src.audio')
local Settings = require('src.data.settings')
local Theme = require('src.ui.theme')

local SettingsHandler = {}

function SettingsHandler.handleChange(key, value, game, renderer)
    print("Settings: " .. key .. " = " .. tostring(value))
    
    -- Save to persistent storage
    Settings.update(key, value)

    if key == "shader" then
        SettingsHandler.handleShaderChange(value, renderer)
    elseif key == "fullscreen" then
        love.window.setFullscreen(value)
    elseif key == "scaleMode" then
        -- Applied live in Renderer.draw from menu.settings
    elseif key == "bgColor" then
        Theme.set(value)
    elseif key == "musicVolume" then
        Audio:setMusicVolume(value / 10)
    elseif key == "sfxVolume" then
        Audio:setSFXVolume(value / 10)
    elseif key == "ghost" then
        -- Ghost piece setting is already in menu.settings, no action needed
    end
end

function SettingsHandler.handleShaderChange(shaderType, renderer)
    if shaderType == "OFF" then
        renderer.activeShader = nil
        renderer.hasTimeUniform = false
    else
        local Renderer = require('src.game.renderer')
        local shader, hasTime = Renderer.loadShader(shaderType)
        renderer.activeShader = shader
        renderer.hasTimeUniform = hasTime
    end
end

function SettingsHandler.handleControlsChange(game)
    print("Settings: Controls changed")
    local Controls = require('src.input.controls')
    Settings.current.controls = Controls.save()
    Settings.save()
end

return SettingsHandler
