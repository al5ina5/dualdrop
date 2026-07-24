-- src/ui/components.lua
-- Reusable UI components for menus

local Theme = require('src.ui.theme')

local Components = {}

-- Component: Confirmation dialog
function Components.drawDialog(game, sw, sh, title, message, options, selectedOption)
    if Theme.isLight() then
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.rectangle("fill", sw/2 - 240, sh/2 - 120, 480, 240)
        love.graphics.setColor(0.45, 0.45, 0.48)
    else
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", sw/2 - 240, sh/2 - 120, 480, 240)
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("line", sw/2 - 240, sh/2 - 120, 480, 240)
    
    -- Title
    love.graphics.setFont(game.renderer.fonts.medium)
    game:drawText(title, sw/2 - 115, sh/2 - 50, 230, "center", {1, 1, 1})
    
    -- Message
    love.graphics.setFont(game.renderer.fonts.small)
    game:drawText(message, sw/2 - 115, sh/2 - 30, 230, "center", {0.8, 0.8, 0.8})
    
    -- Options
    love.graphics.setFont(game.renderer.fonts.medium)
    local optionY = sh/2 + 10
    for i, opt in ipairs(options) do
        local color = (i == selectedOption) and {1, 1, 0.5} or {0.7, 0.7, 0.7}
        local prefix = (i == selectedOption) and "> " or "  "
        game:drawText(prefix .. opt, sw/2 - 115, optionY, 230, "center", color)
        optionY = optionY + 15
    end
end

return Components
