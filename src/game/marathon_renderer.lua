-- src/game/marathon_renderer.lua
-- Renders Marathon-specific HUD elements

local Theme = require('src.ui.theme')

local MarathonRenderer = {}

function MarathonRenderer.drawHUD(marathonState, board, fonts, sw, sh, drawTextFunc)
    -- Right gutter beside the playfield (board is 320px centered on 640)
    local margin = 12
    local colW = 140
    local colRight = sw - margin
    local colLeft = colRight - colW
    local y = 200
    local row = 36

    local totalSeconds = marathonState.playTime
    local minutes = math.floor(totalSeconds / 60)
    local seconds = math.floor(totalSeconds % 60)
    local centiseconds = math.floor((totalSeconds % 1) * 100)
    local timeStr = string.format("%02d:%02d.%02d", minutes, seconds, centiseconds)

    drawTextFunc("TIME", colLeft, y, colW, "right", {1, 1, 1, 0.6})
    y = y + 18
    drawTextFunc(timeStr, colLeft, y, colW, "right", {1, 1, 1, 1})
    y = y + row

    drawTextFunc("LEVEL", colLeft, y, colW, "right", {1, 1, 1, 0.6})
    y = y + 18
    drawTextFunc(tostring(board.level), colLeft, y, colW, "right", {0.3, 1, 0.3, 1})
    y = y + 22

    -- Progress to next level (0-10 lines)
    local progress = (board.linesCleared % 10) / 10
    local barWidth = colW
    local barHeight = 8
    local barX = colLeft
    local barY = y
    local barBg = Theme.get().barBg
    love.graphics.setColor(barBg[1], barBg[2], barBg[3], barBg[4] or 0.85)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    love.graphics.setColor(0.25, 0.75, 0.25, 0.95)
    love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
    y = y + 20

    drawTextFunc("LINES", colLeft, y, colW, "right", {1, 1, 1, 0.6})
    y = y + 18
    drawTextFunc(tostring(board.linesCleared), colLeft, y, colW, "right", {1, 1, 1, 1})
    y = y + row

    drawTextFunc("MAX COMBO", colLeft, y, colW, "right", {1, 1, 1, 0.6})
    y = y + 18
    local comboColor = marathonState.maxCombo > 5 and {1, 0.7, 0.3, 1} or {1, 1, 1, 1}
    drawTextFunc(tostring(marathonState.maxCombo), colLeft, y, colW, "right", comboColor)

    local tspinTotal = MarathonRenderer.getTotalTSpins(marathonState)
    if tspinTotal > 0 then
        y = y + row
        drawTextFunc("T-SPINS", colLeft, y, colW, "right", {1, 1, 1, 0.6})
        y = y + 18
        drawTextFunc(tostring(tspinTotal), colLeft, y, colW, "right", {0.7, 0.3, 1, 1})
    end
end

function MarathonRenderer.getTotalTSpins(state)
    return state.tspinsSingle + state.tspinsDouble + state.tspinsTriple
end

function MarathonRenderer.drawGameOver(marathonState, board, fonts, sw, sh, drawTextFunc)
    -- Draw final statistics (doubled for 640x480)
    local centerX = sw / 2
    local startY = sh / 2 - 200
    local lineHeight = 70
    
    drawTextFunc("MARATHON COMPLETE", centerX, startY, 600, "center", {1, 1, 1, 1})
    
    local stats = {
        {"SCORE", board.score},
        {"LEVEL", board.level},
        {"LINES", board.linesCleared},
        {"TIME", MarathonRenderer.formatTime(marathonState.playTime)},
        {"MAX COMBO", marathonState.maxCombo}
    }
    
    local tspinTotal = MarathonRenderer.getTotalTSpins(marathonState)
    if tspinTotal > 0 then
        table.insert(stats, {"T-SPINS", tspinTotal})
    end
    
    for i, stat in ipairs(stats) do
        local y = startY + 100 + (i * lineHeight)
        drawTextFunc(stat[1] .. ": " .. tostring(stat[2]), centerX, y, 600, "center", {1, 1, 1, 0.8})
    end
end

function MarathonRenderer.formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    local centiseconds = math.floor((seconds % 1) * 100)
    return string.format("%02d:%02d.%02d", minutes, secs, centiseconds)
end

return MarathonRenderer
