-- src/ui/menu/stats_screen.lua
-- Stats hub with separate Statistics and Match History screens

local Scores = require('src.data.scores')
local Base = require('src.ui.menu.base')

local Stats = {}

Stats.VIEW = {
    HUB = "hub",
    SUMMARY = "summary",
    HISTORY = "history",
}

Stats.HUB_OPTIONS = {
    "STATISTICS",
    "MATCH HISTORY",
    "BACK",
}

local function ensureView(menu)
    if not menu.statsView then
        menu.statsView = Stats.VIEW.HUB
    end
end

local function resultColor(result)
    if result == "WIN" or result == "FINISHED" then
        return {0.6, 1, 0.6}
    elseif result == "LOSS" then
        return {1, 0.6, 0.6}
    end
    return {0.8, 0.8, 0.8}
end

local function matchDetail(match)
    if match.mode == "SPRINT" then
        return string.format("%.2fs", match.time or 0)
    elseif match.mode == "MARATHON" then
        return string.format("LVL %d  %d", match.level or 0, match.score or 0)
    elseif match.mode == "VERSUS" then
        return string.format("%d", match.score or 0)
    end
    return string.format("%d", match.score or 0)
end

local function historyVisibleCount(sh)
    local listTop = 100
    local listBottom = sh - 56
    local rowH = 50
    return math.max(1, math.floor((listBottom - listTop) / rowH)), listTop, rowH
end

local function clampHistoryScroll(menu)
    local history = Scores.history
    local visibleCount = historyVisibleCount(480)
    local maxIndex = math.max(1, #history - visibleCount + 1)
    menu.historyScrollIndex = math.min(math.max(1, menu.historyScrollIndex or 1), maxIndex)
end

function Stats.draw(menu, sw, sh, game)
    ensureView(menu)

    if menu.statsView == Stats.VIEW.HUB then
        Base.drawLinkMenu(menu, sw, sh, game, "STATS", nil, Stats.HUB_OPTIONS)
        return
    end

    if menu.statsView == Stats.VIEW.SUMMARY then
        Stats.drawSummary(menu, sw, sh, game)
        return
    end

    Stats.drawHistory(menu, sw, sh, game)
end

function Stats.drawSummary(menu, sw, sh, game)
    local stats = Scores.stats

    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("STATISTICS", 0, 50, sw, "center", {1, 1, 1})

    local y = 110
    local rowH = 52
    local labelColor = {0.7, 0.7, 0.7}
    local statsColor = {0.8, 1, 0.8}
    local colW = sw / 2 - 40

    local rows = {
        {
            { "HIGH SCORE", tostring(stats.highScore) },
            { "BEST SPRINT", stats.bestSprint > 0 and string.format("%.2fs", stats.bestSprint) or "N/A" },
        },
        {
            { "MARATHON LVL", stats.marathonHighLevel > 0 and tostring(stats.marathonHighLevel) or "N/A" },
            { "MARATHON HI", stats.marathonHighScore > 0 and tostring(stats.marathonHighScore) or "N/A" },
        },
        {
            { "VERSUS W/L", string.format("%d - %d", stats.versusWins, stats.versusLosses) },
            { "TOTAL GAMES", tostring(stats.totalGames) },
        },
    }

    for _, row in ipairs(rows) do
        game:drawText(row[1][1], 30, y, colW, "left", labelColor)
        game:drawText(row[1][2], 30, y + 22, colW, "left", statsColor)
        game:drawText(row[2][1], sw / 2 + 20, y, colW, "left", labelColor)
        game:drawText(row[2][2], sw / 2 + 20, y + 22, colW, "left", statsColor)
        y = y + rowH
    end

    if menu.fonts and menu.fonts.small then love.graphics.setFont(menu.fonts.small) end
    game:drawText("BACK (B/ESC)", 0, sh - 30, sw, "center", {0.5, 0.5, 0.5})
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
end

function Stats.drawHistory(menu, sw, sh, game)
    local history = Scores.history
    clampHistoryScroll(menu)

    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("MATCH HISTORY", 0, 50, sw, "center", {1, 1, 1})

    local visibleCount, listTop, rowH = historyVisibleCount(sh)
    local historyIndex = menu.historyScrollIndex or 1

    if #history == 0 then
        if menu.fonts and menu.fonts.small then love.graphics.setFont(menu.fonts.small) end
        game:drawText("NO MATCHES RECORDED", 0, sh / 2 - 10, sw, "center", {0.5, 0.5, 0.5})
    else
        for i = historyIndex, math.min(#history, historyIndex + visibleCount - 1) do
            local match = history[i]
            local itemY = listTop + (i - historyIndex) * rowH
            local color = resultColor(match.result)
            local detail = matchDetail(match)
            local modeResult = string.format("%s  %s", match.mode or "?", match.result or "")

            -- Line 1: mode + result (full width, no overlap)
            if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
            game:drawText(modeResult, 24, itemY, sw - 48, "left", color)

            -- Line 2: timestamp left, detail right (small font, readable)
            if menu.fonts and menu.fonts.small then love.graphics.setFont(menu.fonts.small) end
            game:drawText(match.timestamp or "", 24, itemY + 22, sw / 2, "left", {0.45, 0.45, 0.45})
            game:drawText(detail, sw / 2, itemY + 22, sw / 2 - 24, "right", {0.7, 0.7, 0.7})
        end

        -- Scroll indicators
        if menu.fonts and menu.fonts.small then love.graphics.setFont(menu.fonts.small) end
        if historyIndex > 1 then
            game:drawText("^", sw - 28, listTop - 18, 20, "center", {1, 1, 0})
        end
        if historyIndex + visibleCount <= #history then
            game:drawText("v", sw - 28, listTop + visibleCount * rowH - 10, 20, "center", {1, 1, 0})
        end
        if #history > visibleCount then
            game:drawText(string.format("%d/%d", historyIndex, #history), 0, sh - 48, sw, "center", {0.4, 0.4, 0.4})
        end
    end

    if menu.fonts and menu.fonts.small then love.graphics.setFont(menu.fonts.small) end
    game:drawText("UP/DOWN SCROLL   BACK (B/ESC)", 0, sh - 28, sw, "center", {0.5, 0.5, 0.5})
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
end

local function goBackFromSubscreen(menu)
    menu.statsView = Stats.VIEW.HUB
    menu.selectedIndex = 1
    return true
end

local function handleHubSelect(menu)
    if menu.selectedIndex == 1 then
        menu.statsView = Stats.VIEW.SUMMARY
        return true
    elseif menu.selectedIndex == 2 then
        menu.statsView = Stats.VIEW.HISTORY
        menu.historyScrollIndex = 1
        return true
    else
        menu.state = menu.previousState or Base.STATE.MAIN
        menu.selectedIndex = 3 -- STATS on main
        return true
    end
end

function Stats.handleKey(menu, key)
    ensureView(menu)

    if menu.statsView == Stats.VIEW.HUB then
        if key == "up" then
            menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
            return true
        elseif key == "down" then
            menu.selectedIndex = math.min(#Stats.HUB_OPTIONS, menu.selectedIndex + 1)
            return true
        elseif key == "return" or key == "space" or key == "x" then
            return handleHubSelect(menu)
        elseif key == "escape" or key == "z" or key == "backspace" then
            menu.state = menu.previousState or Base.STATE.MAIN
            menu.selectedIndex = 3
            return true
        end
        return false
    end

    if menu.statsView == Stats.VIEW.HISTORY then
        local history = Scores.history
        local visibleCount = historyVisibleCount(480)
        if key == "up" then
            menu.historyScrollIndex = math.max(1, (menu.historyScrollIndex or 1) - 1)
            return true
        elseif key == "down" then
            local maxIndex = math.max(1, #history - visibleCount + 1)
            menu.historyScrollIndex = math.min(maxIndex, (menu.historyScrollIndex or 1) + 1)
            return true
        elseif key == "escape" or key == "z" or key == "backspace" then
            return goBackFromSubscreen(menu)
        end
        return false
    end

    -- Summary
    if key == "escape" or key == "z" or key == "backspace" then
        return goBackFromSubscreen(menu)
    end
    return false
end

function Stats.handleGamepad(menu, button)
    ensureView(menu)

    if menu.statsView == Stats.VIEW.HUB then
        if button == "dpup" then
            menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
            return true
        elseif button == "dpdown" then
            menu.selectedIndex = math.min(#Stats.HUB_OPTIONS, menu.selectedIndex + 1)
            return true
        elseif button == "a" or button == "start" then
            return handleHubSelect(menu)
        elseif button == "b" or button == "back" then
            menu.state = menu.previousState or Base.STATE.MAIN
            menu.selectedIndex = 3
            return true
        end
        return false
    end

    if menu.statsView == Stats.VIEW.HISTORY then
        local history = Scores.history
        local visibleCount = historyVisibleCount(480)
        if button == "dpup" then
            menu.historyScrollIndex = math.max(1, (menu.historyScrollIndex or 1) - 1)
            return true
        elseif button == "dpdown" then
            local maxIndex = math.max(1, #history - visibleCount + 1)
            menu.historyScrollIndex = math.min(maxIndex, (menu.historyScrollIndex or 1) + 1)
            return true
        elseif button == "b" or button == "back" then
            return goBackFromSubscreen(menu)
        end
        return false
    end

    if button == "b" or button == "back" then
        return goBackFromSubscreen(menu)
    end
    return false
end

return Stats
