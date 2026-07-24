-- src/ui/menu/pause_menu.lua
-- Pause menu screen

local PauseMenu = {}

function PauseMenu.draw(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    local options = {
        "RESUME",
        "OPTIONS",
        "MAIN MENU",
    }
    Base.drawLinkMenu(menu, sw, sh, game, "PAUSED", nil, options)
end

function PauseMenu.handleKey(menu, key)
    local Base = require('src.ui.menu.base')
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(3, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        return PauseMenu.select(menu)
    elseif key == "escape" or key == "z" then
        Base.hide(menu)
        return true
    end
    return false
end

function PauseMenu.handleGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    
    if button == "dpup" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.selectedIndex = math.min(3, menu.selectedIndex + 1)
        return true
    elseif button == "a" or button == "start" then
        return PauseMenu.select(menu)
    elseif button == "b" or button == "back" then
        Base.hide(menu)
        return true
    end
    return false
end

function PauseMenu.select(menu)
    local Base = require('src.ui.menu.base')
    
    if menu.selectedIndex == 1 then
        -- Resume
        Base.hide(menu)
    elseif menu.selectedIndex == 2 then
        -- Options
        menu.previousState = menu.state
        menu.state = Base.STATE.OPTIONS
        menu.optionsSelectedIndex = 1
    elseif menu.selectedIndex == 3 then
        -- Main Menu
        if menu.onMainMenu then menu.onMainMenu() end
        -- onMainMenu already shows MAIN; keep this as a safety net
        if not menu:isVisible() or menu.state == Base.STATE.PAUSE then
            Base.show(menu, Base.STATE.MAIN)
        end
    end
    return true
end

return PauseMenu
