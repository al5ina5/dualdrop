-- src/ui/options.lua
-- Modular options screen for the menu system

local Theme = require('src.ui.theme')

local Options = {}

function Options.init(menu)
    menu.optionsSelectedIndex = 1
    menu.settings = {
        shader = _G.CRT_ENABLED and "CRT" or "OFF",
        ghost = true,
        musicVolume = 5,
        sfxVolume = 5,
        fullscreen = love.window.getFullscreen(),
        scaleMode = "STRETCH",
        bgColor = "BLACK"
    }
    
    -- Option definitions
    Options.ITEMS = {
        { name = "CONTROLS", type = "submenu", submenu = "controls" },
        { name = "SHADER", key = "shader", type = "select", options = {"OFF", "CRT", "GRAYSCALE", "DREAM", "GAMEBOY", "ANAGLYPH"} },
        { name = "BG COLOR", key = "bgColor", type = "select", options = Theme.OPTIONS },
        { name = "GHOST PIECE", key = "ghost", type = "toggle" },
        { name = "MUSIC VOLUME", key = "musicVolume", type = "slider", min = 0, max = 10 },
        { name = "SFX VOLUME", key = "sfxVolume", type = "slider", min = 0, max = 10 },
        { name = "FULLSCREEN", key = "fullscreen", type = "toggle" },
        { name = "SCALE", key = "scaleMode", type = "select", options = {"PIXEL", "FIT", "STRETCH"} },
        { name = "BACK", type = "back" }
    }
end

function Options.draw(menu, sw, sh, game)
    game:drawText("OPTIONS", 0, 48, sw, "center", {1, 1, 1})
    
    local startY = 100
    local spacing = 32
    
    for i, item in ipairs(Options.ITEMS) do
        local y = startY + (i-1) * spacing
        local isSelected = (i == menu.optionsSelectedIndex)
        local color = isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8}
        local prefix = isSelected and "> " or "  "
        
        local text = prefix .. item.name
        game:drawText(text, 40, y, sw - 80, "left", color)
        
        if item.type == "toggle" then
            local valText = menu.settings[item.key] and "ON" or "OFF"
            game:drawText(valText, 40, y, sw - 120, "right", color)
        elseif item.type == "select" then
            local valText = menu.settings[item.key] or "OFF"
            game:drawText(valText, 40, y, sw - 120, "right", color)
        elseif item.type == "slider" then
            local val = menu.settings[item.key]
            local valText = string.rep("|", val) .. string.rep(".", item.max - val)
            game:drawText(valText .. " " .. val, 40, y, sw - 120, "right", color)
        elseif item.type == "submenu" then
            game:drawText(">>", 40, y, sw - 120, "right", color)
        end
    end
end

function Options.handleKey(menu, key, onSettingChanged)
    if key == "up" then
        menu.optionsSelectedIndex = math.max(1, menu.optionsSelectedIndex - 1)
        return true
    elseif key == "down" then
        menu.optionsSelectedIndex = math.min(#Options.ITEMS, menu.optionsSelectedIndex + 1)
        return true
    elseif key == "left" or key == "right" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local step = (key == "right") and 1 or -1
            local nextIdx = idx + step
            if nextIdx > #item.options then nextIdx = 1 end
            if nextIdx < 1 then nextIdx = #item.options end
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "slider" then
            local step = (key == "right") and 1 or -1
            local newVal = math.max(item.min, math.min(item.max, menu.settings[item.key] + step))
            if newVal ~= menu.settings[item.key] then
                menu.settings[item.key] = newVal
                if onSettingChanged then onSettingChanged(item.key, newVal) end
            end
            return true
        end
    elseif key == "return" or key == "space" or key == "x" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local nextIdx = (idx % #item.options) + 1
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "submenu" then
            if item.submenu == "controls" then
                -- Don't overwrite previousState - Controls screen will return to OPTIONS
                menu.state = menu.STATE.CONTROLS
                local ControlsUI = require('src.ui.menu.controls_screen')
                ControlsUI.buildItems(menu)
            end
            return true
        elseif item.type == "back" then
            return Options.back(menu)
        end
    elseif key == "escape" or key == "z" then
        return Options.back(menu)
    end
    return false
end

function Options.handleGamepad(menu, button, onSettingChanged)
    if button == "dpup" then
        menu.optionsSelectedIndex = math.max(1, menu.optionsSelectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.optionsSelectedIndex = math.min(#Options.ITEMS, menu.optionsSelectedIndex + 1)
        return true
    elseif button == "dpleft" or button == "dpright" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local step = (button == "dpright") and 1 or -1
            local nextIdx = idx + step
            if nextIdx > #item.options then nextIdx = 1 end
            if nextIdx < 1 then nextIdx = #item.options end
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "slider" then
            local step = (button == "dpright") and 1 or -1
            local newVal = math.max(item.min, math.min(item.max, menu.settings[item.key] + step))
            if newVal ~= menu.settings[item.key] then
                menu.settings[item.key] = newVal
                if onSettingChanged then onSettingChanged(item.key, newVal) end
            end
            return true
        end
    elseif button == "a" or button == "start" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local nextIdx = (idx % #item.options) + 1
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "submenu" then
            if item.submenu == "controls" then
                -- Don't overwrite previousState - Controls screen will return to OPTIONS
                menu.state = menu.STATE.CONTROLS
                local ControlsUI = require('src.ui.menu.controls_screen')
                ControlsUI.buildItems(menu)
            end
            return true
        elseif item.type == "back" then
            return Options.back(menu)
        end
    elseif button == "b" or button == "back" then
        return Options.back(menu)
    end
    return false
end

function Options.back(menu)
    menu.state = menu.previousState or menu.STATE.MAIN
    -- Reset selection index to OPTIONS menu item position
    if menu.state == menu.STATE.MAIN then
        menu.selectedIndex = 4  -- OPTIONS is 4th item in main menu
    elseif menu.state == menu.STATE.PAUSE then
        menu.selectedIndex = 2  -- OPTIONS is 2nd item in pause menu
    else
        menu.selectedIndex = 1  -- Default
    end
    return true
end

return Options
