-- src/game/renderer.lua
-- Handles all rendering logic: canvas, shaders, fonts, scaling, and drawing

local FX = require('src.fx')
local Theme = require('src.ui.theme')

local Renderer = {}

local function loadFont(path, size)
    local ok, font = pcall(love.graphics.newFont, path, size)
    if ok and font then
        return font
    end
    print("Renderer: missing font '" .. tostring(path) .. "', using default (" .. tostring(font) .. ")")
    return love.graphics.newFont(size)
end

function Renderer.init()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")
    
    -- Create fonts optimized for sharp scaling (Press Start 2P - OFL licensed)
    local fonts = {
        small = loadFont('assets/fonts/PressStart2P-Regular.ttf', 12),
        medium = loadFont('assets/fonts/PressStart2P-Regular.ttf', 16),
        large = loadFont('assets/fonts/PressStart2P-Regular.ttf', 32),
        score = loadFont('assets/fonts/PressStart2P-Regular.ttf', 24)
    }
    
    for _, f in pairs(fonts) do
        f:setFilter("nearest", "nearest")
    end
    
    local canvas = love.graphics.newCanvas(640, 480)
    canvas:setFilter("nearest", "nearest")
    
    return {
        fonts = fonts,
        canvas = canvas,
        activeShader = nil,
        hasTimeUniform = false,
        screenWidth = 640,
        screenHeight = 480
    }
end

function Renderer.loadShader(shaderType)
    if shaderType == "OFF" then
        return nil, false
    end
    
    local shaderPath = 'src.shaders.' .. string.lower(shaderType)
    local status, shaderCode = pcall(require, shaderPath)
    if not status then
        print("Error loading shader: " .. tostring(shaderCode))
        return nil, false
    end
    
    local shader = love.graphics.newShader(shaderCode)
    if shader:hasUniform("inputRes") then
        shader:send("inputRes", {640, 480})
    end
    local hasTime = shader:hasUniform("time")
    
    return shader, hasTime
end

function Renderer.drawText(text, x, y, limit, align, color, shadowColor, outlineColor, fonts)
    color = Theme.adaptColor(color or {1, 1, 1})

    local autoShadow = shadowColor == nil
    local autoOutline = outlineColor == nil
    shadowColor = shadowColor or Theme.textShadow()
    outlineColor = outlineColor or Theme.textOutline()

    if Theme.isLight() then
        -- Callers often pass hard-coded black shadows; flip them on light themes
        if not autoShadow and shadowColor[1] < 0.35 and shadowColor[2] < 0.35 and shadowColor[3] < 0.35 then
            shadowColor = Theme.textShadow()
        end
        if not autoOutline and outlineColor[1] < 0.35 and outlineColor[2] < 0.35 and outlineColor[3] < 0.35 then
            outlineColor = Theme.textOutline()
        end
    end
    
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    limit = math.floor(limit + 0.5)
    
    -- Outline (thick retro style)
    love.graphics.setColor(outlineColor)
    for ox = -1, 1 do
        for oy = -1, 1 do
            if ox ~= 0 or oy ~= 0 then
                love.graphics.printf(text, x + ox, y + oy, limit, align)
            end
        end
    end
    
    -- Shadow
    love.graphics.setColor(shadowColor)
    love.graphics.printf(text, x, y + 1, limit, align)
    
    -- Main text
    love.graphics.setColor(color)
    love.graphics.printf(text, x, y, limit, align)
end

function Renderer.draw(state, game)
    local sw, sh = state.screenWidth, state.screenHeight
    local winW, winH = love.graphics.getDimensions()

    local scaleMode = "STRETCH"
    if game.menu and game.menu.settings and game.menu.settings.scaleMode then
        scaleMode = game.menu.settings.scaleMode
    end

    local scaleX, scaleY, ox, oy
    if scaleMode == "STRETCH" then
        -- True edge-to-edge fill (may slightly stretch 4:3 on widescreen)
        scaleX = winW / sw
        scaleY = winH / sh
        ox, oy = 0, 0
    elseif scaleMode == "FIT" then
        -- Largest float scale that keeps aspect ratio
        local scale = math.min(winW / sw, winH / sh)
        if scale < 0.01 then scale = 0.01 end
        scaleX, scaleY = scale, scale
        ox, oy = (winW - sw * scale) / 2, (winH - sh * scale) / 2
    else
        -- PIXEL: integer scale for crisp pixels (letterboxed)
        local scale = math.floor(math.min(winW / sw, winH / sh))
        if scale < 1 then scale = 1 end
        scaleX, scaleY = scale, scale
        ox, oy = (winW - sw * scale) / 2, (winH - sh * scale) / 2
    end

    -- PASS 1: Render to canvas (with shader effects)
    love.graphics.setCanvas(state.canvas)
    local themeBg = Theme.get().bg
    love.graphics.clear(themeBg[1], themeBg[2], themeBg[3], 1)
    
    if game.menu:isVisible() then
        game.menu:drawBackground(game)
    else
        Renderer.drawGameplay(state, game, sw, sh)
    end
    
    love.graphics.setCanvas()
    
    -- PASS 2: Draw canvas to screen with shader
    love.graphics.setColor(1, 1, 1)
    if state.activeShader then
        if state.hasTimeUniform then
            state.activeShader:send("time", love.timer.getTime())
        end
        love.graphics.setShader(state.activeShader)
    end
    
    local sx, sy = FX:getShake()
    love.graphics.draw(state.canvas, ox + sx * scaleX, oy + sy * scaleY, 0, scaleX, scaleY)
    love.graphics.setShader()
    
    -- FX Pass
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scaleX, scaleY)
    FX:drawParticles()
    FX:drawFlash(sw, sh)
    love.graphics.pop()

    -- PASS 3: UI elements (unshaded)
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scaleX, scaleY)
    
    if game.menu:isVisible() then
        game.menu:drawForeground(game)
    else
        Renderer.drawGameUI(state, game, sw, sh)
    end

    local LocalSession = require('src.game.local_session')
    LocalSession.drawToast(game, sw, sh, state.fonts)
    
    love.graphics.pop()
end

function Renderer.drawGameplay(state, game, sw, sh)
    local CONST = require('src.constants')
    local TeamMatch = require('src.game.team_match')
    local hasOpponents = game:countRemotePlayers() > 0
    local isNetworked = game.network ~= nil
    local isDisconnectedPause = game.state == "disconnected_pause"
    local bsW, bsH = CONST.BLOCK_SIZE_W, CONST.BLOCK_SIZE_H
    local bw, bh = 10 * bsW, 20 * bsH
    -- Hold (left) + next queue (right) sit at the very top
    local previewTop = 8
    local nextSpacing = 28

    local localPlayers = game.localPlayers
    if not localPlayers or #localPlayers == 0 then
        localPlayers = {{ id = "local", board = game.localBoard, device = "any" }}
    end
    local localCount = #localPlayers

    local enemyColor = {0.95, 0.4, 0.4}

    local function drawLocalHalf(lp, lx, label)
        local fogged = lp.board.fogTimer and lp.board.fogTimer > 0
        lp.board:draw(lx, 0, bsW, bsH, game, nil, game.menu.settings.ghost)
        love.graphics.setFont(state.fonts.small)
        Renderer.drawText(label, lx, 2, bw, "center", {1, 1, 0.6})
        if lp.board.holdPieceType and not lp.board.holdLocked then
            lp.board:drawPiecePreview(lp.board.holdPieceType, lx + 20, previewTop, 8, 8)
        end
        if not fogged then
            for i, pieceType in ipairs({lp.board.nextPieceType, lp.board.nextQueue[1], lp.board.nextQueue[2]}) do
                lp.board:drawPiecePreview(pieceType, lx + bw - 52, previewTop + (i - 1) * nextSpacing, 8, 8)
            end
        else
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("???", lx + bw - 52, previewTop + 20, 40, "center", {0.6, 0.6, 0.7})
        end
    end

    if not hasOpponents and (not isNetworked or isDisconnectedPause) and localCount < 2 then
        local bx = (sw - bw) / 2
        local fogged = game.localBoard.fogTimer and game.localBoard.fogTimer > 0
        game.localBoard:draw(bx, 0, bsW, bsH, game, nil, game.menu.settings.ghost)
        if game.localBoard.holdPieceType and not game.localBoard.holdLocked then
            game.localBoard:drawPiecePreview(game.localBoard.holdPieceType, bx - 80, previewTop, 16, 16)
        end
        if not fogged then
            for i, pieceType in ipairs({game.localBoard.nextPieceType, game.localBoard.nextQueue[1], game.localBoard.nextQueue[2]}) do
                game.localBoard:drawPiecePreview(pieceType, bx + bw + 20, previewTop + (i - 1) * 70, 16, 16)
            end
        end
    elseif localCount >= 2 then
        -- Team split-screen: only this console's boards
        for i, lp in ipairs(localPlayers) do
            local lx = (i == 1) and 0 or (sw / 2)
            local label = (i == 1) and "P1" or "P2"
            drawLocalHalf(lp, lx, label)
        end
        local div = Theme.isLight() and 0.55 or 0.3
        love.graphics.setColor(div, div, div)
        love.graphics.line(sw / 2, 0, sw / 2, sh)

        -- Center scout overlay (opt-in): small, low-opacity, straddles both halves
        if game.enemyOverlay then
            local enemyId, enemyBoard, blend, nextId, nextBoard = TeamMatch.enemyWatchView(game)
            if enemyBoard then
                local scale = TeamMatch.ENEMY_OVERLAY_SCALE
                local baseA = TeamMatch.ENEMY_OVERLAY_ALPHA
                local obsW, obsH = bsW * scale, bsH * scale
                local obw, obh = 10 * obsW, 20 * obsH
                local ox = math.floor((sw - obw) / 2)
                local oy = math.floor((sh - obh) / 2)

                local ghostCanvas = state.enemyOverlayCanvas
                if not ghostCanvas then
                    ghostCanvas = love.graphics.newCanvas(bw, bh)
                    ghostCanvas:setFilter("nearest", "nearest")
                    state.enemyOverlayCanvas = ghostCanvas
                end

                local function blitOverlay(board, alpha)
                    if not board or alpha <= 0.01 then return end
                    love.graphics.setCanvas(ghostCanvas)
                    love.graphics.clear(0, 0, 0, 0)
                    board:draw(0, 0, bsW, bsH, game, enemyColor)
                    love.graphics.setCanvas(state.canvas)
                    love.graphics.setColor(1, 1, 1, alpha)
                    love.graphics.draw(ghostCanvas, ox, oy, 0, scale, scale)
                    love.graphics.setColor(1, 1, 1, 1)
                end

                -- Soft dark plate behind so it reads over both playfields
                love.graphics.setColor(0, 0, 0, baseA * 0.45)
                love.graphics.rectangle("fill", ox - 4, oy - 14, obw + 8, obh + 20)

                if blend and blend > 0.01 and nextBoard then
                    blitOverlay(enemyBoard, baseA * (1 - blend))
                    blitOverlay(nextBoard, baseA * blend)
                else
                    blitOverlay(enemyBoard, baseA)
                end

                local showId = (blend and blend > 0.5 and nextId) or enemyId
                love.graphics.setFont(state.fonts.small)
                love.graphics.setColor(enemyColor[1], enemyColor[2], enemyColor[3], baseA + 0.25)
                love.graphics.printf(showId or "VS", ox, oy - 12, obw, "center")
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    else
        -- Solo on this console: you + rotating enemy ghost (crossfade every ~30s)
        drawLocalHalf(localPlayers[1], 0, localPlayers[1].id == "local" and "YOU" or "P1")

        local enemyId, enemyBoard, blend, nextId, nextBoard = TeamMatch.enemyWatchView(game)
        if enemyBoard then
            local rx = sw / 2
            -- Soft crossfade via offscreen canvas (non-distracting dissolve)
            local ghostCanvas = state.enemyGhostCanvas
            if not ghostCanvas then
                ghostCanvas = love.graphics.newCanvas(bw, bh)
                ghostCanvas:setFilter("nearest", "nearest")
                state.enemyGhostCanvas = ghostCanvas
            end

            local function blitGhost(board, alpha)
                if not board or alpha <= 0.01 then return end
                love.graphics.setCanvas(ghostCanvas)
                love.graphics.clear(0, 0, 0, 0)
                board:draw(0, 0, bsW, bsH, game, enemyColor)
                love.graphics.setCanvas(state.canvas)
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.draw(ghostCanvas, rx, 0)
                love.graphics.setColor(1, 1, 1, 1)
            end

            if blend and blend > 0.01 and nextBoard then
                blitGhost(enemyBoard, 1 - blend)
                blitGhost(nextBoard, blend)
            else
                blitGhost(enemyBoard, 1)
            end

            local showId = (blend and blend > 0.5 and nextId) or enemyId
            local showBoard = (blend and blend > 0.5 and nextBoard) or enemyBoard
            if showBoard and showBoard.nextPieceType then
                -- Preview fades with the active board identity
                local previewA = 1
                if blend and blend > 0.01 and blend < 0.99 then
                    previewA = (blend > 0.5) and ((blend - 0.5) * 2) or (1 - blend * 2)
                end
                love.graphics.setColor(1, 1, 1, previewA)
                showBoard:drawPiecePreview(showBoard.nextPieceType, rx + bw - 52, previewTop, 8, 8)
                love.graphics.setColor(1, 1, 1, 1)
            end
            love.graphics.setFont(state.fonts.small)
            local labelA = 1
            if blend and blend > 0.01 and blend < 0.99 then
                labelA = 0.35 + 0.65 * math.abs(blend - 0.5) * 2
            end
            Renderer.drawText(showId or "VS", rx, 2, bw, "center", {
                enemyColor[1], enemyColor[2], enemyColor[3], labelA
            })
        elseif isNetworked and game.state == "waiting" then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("WAITING FOR OPPONENT...", sw * 0.75, sh / 2, sw / 2, "center", {0.5, 0.5, 0.5})
        end

        local div = Theme.isLight() and 0.55 or 0.3
        love.graphics.setColor(div, div, div)
        love.graphics.line(sw / 2, 0, sw / 2, sh)
    end

    if game.state == "countdown" then
        if Theme.isLight() then
            love.graphics.setColor(1, 1, 1, 0.55)
        else
            love.graphics.setColor(0, 0, 0, 0.7)
        end
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    elseif game.state == "over" or game.state == "disconnected_pause" then
        if Theme.isLight() then
            love.graphics.setColor(1, 1, 1, 0.65)
        else
            love.graphics.setColor(0, 0, 0, 0.8)
        end
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
end

function Renderer.drawGameUI(state, game, sw, sh)
    local CONST = require('src.constants')
    local TeamMatch = require('src.game.team_match')
    local hasOpponents = game:countRemotePlayers() > 0
    local isNetworked = game.network ~= nil
    local bsW, bsH = CONST.BLOCK_SIZE_W, CONST.BLOCK_SIZE_H
    local bw, bh = 10 * bsW, 20 * bsH
    
    -- Score at top with same edge margin as before (~10px)
    local scoreY = 10
    local localCount = game.localPlayers and #game.localPlayers or 1
    local teamSplit = localCount >= 2
    local localVersus = game.localVersus
        or (game.gameMode == "VERSUS" and not isNetworked and teamSplit)
    
    if (localVersus or teamSplit) and game.localPlayers and #game.localPlayers >= 2 then
        -- Split-screen team HUD (local or networked duo — remotes hidden)
        local VersusRules = require('src.game.versus_rules')
        local isChaos = VersusRules.isChaos(game)
        for i, lp in ipairs(game.localPlayers) do
            local halfX = (i == 1) and 0 or (sw / 2)
            if game.state ~= "over" and lp.board then
                love.graphics.setFont(state.fonts.score)
                Renderer.drawText(tostring(lp.board.score or 0), halfX, scoreY, sw / 2, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
                if isChaos then
                    love.graphics.setFont(state.fonts.small)
                    Renderer.drawText("CHAOS", halfX, 36, sw / 2, "center", {1, 0.5, 0.8})
                    VersusRules.drawPowerUpUI(lp.board, halfX, 52, sw / 2, state.fonts.small)
                end
                if lp.board.pendingGarbage and lp.board.pendingGarbage > 0 then
                    love.graphics.setFont(state.fonts.small)
                    Renderer.drawText("GARBAGE: " .. lp.board.pendingGarbage, halfX, bh - 50, sw / 2, "center", {1, 0, 0})
                end
                local labels = VersusRules.statusLabels(lp.board)
                if #labels > 0 then
                    love.graphics.setFont(state.fonts.small)
                    Renderer.drawText(table.concat(labels, "  "), halfX, bh - 70, sw / 2, "center", {1, 0.55, 0.9})
                end
            end
        end
        if VersusRules.isCheese(game) then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("CHEESE RACE", 0, 42, sw, "center", {0.7, 1, 0.7})
        end
        if TeamMatch.canScoutOverlay(game) then
            love.graphics.setFont(state.fonts.small)
            local hint = game.enemyOverlay and "SELECT: hide scout" or "SELECT: scout"
            Renderer.drawText(hint, 0, sh - 22, sw, "center", {0.55, 0.55, 0.6, 0.7})
        end
    elseif not hasOpponents and not isNetworked then
        -- Single player UI
        local bx = (sw - bw) / 2
        
        -- Don't draw score here during game over (it's shown in the game over overlay)
        if game.state ~= "over" then
            love.graphics.setFont(state.fonts.score)
            Renderer.drawText(tostring(game.localBoard.score), bx, scoreY, bw, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        end
        
        if game.gameMode == "SPRINT" then
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText("LINES: " .. game.localBoard.linesCleared .. "/40", bx, 45, bw, "center", {1, 1, 1})
            Renderer.drawText(string.format("TIME: %.2f", game.sprintTime), bx, 70, bw, "center", {1, 1, 1})
        elseif game.gameMode == "MARATHON" and game.marathonState then
            love.graphics.setFont(state.fonts.medium)
            local MarathonRenderer = require('src.game.marathon_renderer')
            local drawFunc = function(text, x, y, limit, align, color)
                Renderer.drawText(text, x, y, limit, align, color, nil, nil, state.fonts)
            end
            MarathonRenderer.drawHUD(game.marathonState, game.localBoard, state.fonts, sw, sh, drawFunc)
        end

        if game.localBoard.combo > 0 then
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText("COMBO x" .. game.localBoard.combo, bx - 120, bh - 40, 120, "right", {1, 0.5, 0.5})
        end
        
    else
        -- Solo console vs ghost opponent
        love.graphics.setFont(state.fonts.score)
        Renderer.drawText(tostring(game.localBoard.score), 0, scoreY, sw / 2, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        
        if game.localBoard.pendingGarbage > 0 then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("GARBAGE: " .. game.localBoard.pendingGarbage, 0, bh - 50, sw / 2, "center", {1, 0, 0})
        end

        local VersusRules = require('src.game.versus_rules')
        local labels = VersusRules.statusLabels(game.localBoard)
        if #labels > 0 then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText(table.concat(labels, "  "), 0, bh - 70, sw / 2, "center", {1, 0.55, 0.9})
        end
        if VersusRules.isCheese(game) then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("CHEESE RACE — clear the board!", 0, 42, sw / 2, "center", {0.7, 1, 0.7})
        elseif VersusRules.isChaos(game) then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("CHAOS", 0, 36, sw / 2, "center", {1, 0.5, 0.8})
            VersusRules.drawPowerUpUI(game.localBoard, 0, 52, sw / 2, state.fonts.small)
        end
        
        local _, enemyBoard = TeamMatch.primaryEnemy(game)
        if enemyBoard then
            Renderer.drawText(tostring(enemyBoard.score or 0), sw / 2, scoreY, sw / 2, "center", {0.8, 0.8, 0.8})
        end
    end

    -- Countdown
    if game.state == "countdown" then
        love.graphics.setFont(state.fonts.large)
        local text = math.ceil(game.stateManager.countdownTimer)
        if text == 0 then text = "GO!" end
        Renderer.drawText(tostring(text), 0, sh/2 - 40, sw, "center", {1, 0.3, 0.1}, {0.3, 0, 0})
    end

    -- Game Over
    if game.state == "over" then
        love.graphics.setFont(state.fonts.large)
        local color = {1, 0.2, 0.2}
        local shadow = {0.3, 0, 0}

        local Scores = require('src.data.scores')

        local function formatMatchTime(seconds)
            seconds = seconds or 0
            return string.format("%02d:%02d.%02d",
                math.floor(seconds / 60),
                math.floor(seconds % 60),
                math.floor((seconds % 1) * 100))
        end

        local function drawEndStats(score, lines, timeSeconds, statsY)
            local highScore, highLines = Scores.getHighsForMode(game.gameMode, score, lines)
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText(string.format("SCORE %d / %d", score, highScore), 0, statsY, sw, "center", {1, 0.9, 0.3})
            Renderer.drawText(string.format("LINES %d / %d", lines, highLines), 0, statsY + 40, sw, "center", {1, 1, 1})
            Renderer.drawText("TIME " .. formatMatchTime(timeSeconds), 0, statsY + 80, sw, "center", {1, 1, 1})
        end
        
        if game.gameMode == "SPRINT" and game.localBoard.linesCleared >= 40 then
            Renderer.drawText("SPRINT", 0, sh/2 - 120, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            Renderer.drawText("FINISHED!", 0, sh/2 - 50, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            drawEndStats(game.localBoard.score, game.localBoard.linesCleared, game.sprintTime, sh/2 + 20)
        elseif game.gameMode == "MARATHON" and game.marathonState then
            Renderer.drawText("MARATHON", 0, sh/2 - 140, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            Renderer.drawText("COMPLETE", 0, sh/2 - 70, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            
            love.graphics.setFont(state.fonts.medium)
            local MarathonState = require('src.game.marathon_state')
            local summary = MarathonState.getSummary(game.marathonState, game.localBoard)
            local highScore, highLines = Scores.getHighsForMode("MARATHON", summary.score, summary.lines)
            
            local statsY = sh/2 + 20
            Renderer.drawText("LEVEL " .. summary.level, 0, statsY, sw, "center", {1, 1, 1})
            Renderer.drawText(string.format("LINES %d / %d", summary.lines, highLines), 0, statsY + 40, sw, "center", {1, 1, 1})
            Renderer.drawText("TIME " .. formatMatchTime(summary.time), 0, statsY + 80, sw, "center", {1, 1, 1})
            
            love.graphics.setFont(state.fonts.score)
            Renderer.drawText(string.format("%d / %d", game.localBoard.score, highScore), 0, statsY + 130, sw, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        elseif game.localVersus and (game.matchResult == "WIN" or game.matchResult == "LOSS") then
            local p1Wins = game.matchResult == "WIN"
            local title = p1Wins and "P1 WINS!" or "P2 WINS!"
            local titleColor = p1Wins and {0.2, 1, 0.2} or {0.4, 0.7, 1}
            local titleShadow = p1Wins and {0, 0.3, 0} or {0, 0.15, 0.3}
            Renderer.drawText(title, 0, sh/2 - 100, sw, "center", titleColor, titleShadow)
            local winner = p1Wins and (game.localPlayers and game.localPlayers[1]) or (game.localPlayers and game.localPlayers[2])
            local board = winner and winner.board or game.localBoard
            drawEndStats(board and board.score or 0, board and board.linesCleared or 0, game.matchTime or 0, sh/2 + 10)
        elseif game.matchResult == "WIN"
            or (not game.matchResult and game:countRemotePlayers() > 0 and game.localBoard and not game.localBoard.gameOver) then
            Renderer.drawText("YOU WON!", 0, sh/2 - 100, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            drawEndStats(game.localBoard.score, game.localBoard.linesCleared, game.matchTime, sh/2 + 10)
        elseif game.matchResult == "LOSS"
            or (game:countRemotePlayers() > 0 and game.localBoard and game.localBoard.gameOver) then
            Renderer.drawText("YOU LOST", 0, sh/2 - 100, sw, "center", color, shadow)
            drawEndStats(game.localBoard.score, game.localBoard.linesCleared, game.matchTime or 0, sh/2 + 10)
        else
            Renderer.drawText("GAME OVER", 0, sh/2 - 100, sw, "center", color, shadow)
            local endTime = game.gameMode == "SPRINT" and game.sprintTime or (game.matchTime or 0)
            drawEndStats(game.localBoard.score, game.localBoard.linesCleared, endTime, sh/2 + 10)
        end
        
        -- Show "press any key" hint after delay
        local StateManager = require('src.game.state_manager')
        if StateManager.canDismissGameOver(game.stateManager) then
            love.graphics.setFont(state.fonts.small)
            local alpha = 0.5 + 0.3 * math.sin(love.timer.getTime() * 3)
            Renderer.drawText("PRESS ANY KEY", 0, sh - 40, sw, "center", {1, 1, 1, alpha})
        end
    end

    -- Disconnected Pause
    if game.state == "disconnected_pause" then
        love.graphics.setFont(state.fonts.large)
        
        -- Choose message based on disconnect reason
        local reason = game.stateManager.disconnectReason or "opponent_left"
        local mainText = "OPPONENT LEFT"
        local subText = "Rage quit? Crashed? Who knows :P"
        
        if reason == "connection_closed" then
            mainText = "CONNECTION LOST"
            subText = "Network hiccup... it happens"
        end
        
        Renderer.drawText(mainText, 0, sh/2 - 80, sw, "center", {1, 0.5, 0}, {0.3, 0.1, 0})
        
        love.graphics.setFont(state.fonts.small)
        Renderer.drawText(subText, 0, sh/2 - 10, sw, "center", {0.7, 0.7, 0.7})
        
        love.graphics.setFont(state.fonts.medium)
        local timeLeft = math.ceil(game.stateManager.disconnectPauseTimer)
        Renderer.drawText("Continuing solo in " .. timeLeft .. "...", 0, sh/2 + 60, sw, "center", {0.8, 0.8, 0.8})
        
        -- Hint to skip
        love.graphics.setFont(state.fonts.small)
        local alpha = 0.5 + 0.3 * math.sin(love.timer.getTime() * 3)
        Renderer.drawText("Press any key to continue now", 0, sh/2 + 110, sw, "center", {1, 1, 1, alpha})
    end
end

return Renderer
