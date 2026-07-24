-- src/tetris/renderer.lua
-- Board rendering with blocks, grid, ghost piece, and previews

local Theme = require('src.ui.theme')

local Renderer = {}

function Renderer.drawBlock(x, y, sw, sh, color)
    color = Theme.adaptBlockColor(color)
    local r, g, b = unpack(color)
    
    -- Main fill
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", x, y, sw, sh)
    
    -- Retro border effect (highlight/shadow)
    love.graphics.setColor(r + (1-r)*0.5, g + (1-g)*0.5, b + (1-b)*0.5)
    love.graphics.rectangle("fill", x, y, sw, 1) -- Top
    love.graphics.rectangle("fill", x, y, 1, sh) -- Left
    
    love.graphics.setColor(r*0.5, g*0.5, b*0.5)
    love.graphics.rectangle("fill", x, y + sh - 1, sw, 1) -- Bottom
    love.graphics.rectangle("fill", x + sw - 1, y, 1, sh) -- Right
end

function Renderer.drawPiecePreview(board, type, offsetX, offsetY, bw, bh)
    bh = bh or bw or 10
    bw = bw or 10
    local Piece = require('src.tetris.piece')
    local data = Piece.PIECES[type]
    if not data then return end
    
    local color = data.color
    for y = 1, #data do
        for x = 1, #data[y] do
            if data[y][x] ~= 0 then
                Renderer.drawBlock(offsetX + (x - 1) * bw, offsetY + (y - 1) * bh, bw, bh, color)
            end
        end
    end
end

function Renderer.draw(board, offsetX, offsetY, bw, bh, game, forcedColor, showGhost)
    -- Handle old signature compatibility
    if type(bw) == "table" then
        game = bw
        bw = 10
        bh = 10
    elseif type(bh) == "table" then
        showGhost = forcedColor
        forcedColor = game
        game = bh
        bh = bw
    elseif bh == nil then
        bh = bw or 10
        bw = bw or 10
    end
    
    showGhost = showGhost ~= false
    if board.fogTimer and board.fogTimer > 0 then
        showGhost = false
    end
    if board.tunnelTimer and board.tunnelTimer > 0 then
        -- Tunnel still shows ghost in the slit; keep ghost on
    end

    local theme = Theme.get()
    local fieldW = board.width * bw
    local fieldH = board.height * bh
    local flipH = board.flipHTimer and board.flipHTimer > 0
    local flipV = board.flipVTimer and board.flipVTimer > 0
    local invisible = board.invisibleTimer and board.invisibleTimer > 0

    love.graphics.push()
    if flipH or flipV then
        local cx = offsetX + fieldW / 2
        local cy = offsetY + fieldH / 2
        love.graphics.translate(cx, cy)
        love.graphics.scale(flipH and -1 or 1, flipV and -1 or 1)
        love.graphics.translate(-cx, -cy)
    end
    
    -- Draw playfield background (theme-aware; WHITE inverts to light)
    local pf = theme.playfield
    love.graphics.setColor(pf[1], pf[2], pf[3], 0.95)
    love.graphics.rectangle("fill", offsetX, offsetY, fieldW, fieldH)

    -- Draw grid lines with gradient fade
    love.graphics.setLineWidth(1)
    local gridBrightness = theme.gridBrightness
    local maxAlpha = theme.gridMaxAlpha
    local minAlpha = theme.gridMinAlpha
    local fadeRatio = 0.2
    
    -- Vertical lines
    for x = 1, board.width - 1 do
        local lineX = offsetX + x * bw
        local totalHeight = fieldH
        local segments = 20
        
        for i = 0, segments - 1 do
            local y1 = offsetY + (i / segments) * totalHeight
            local y2 = offsetY + ((i + 1) / segments) * totalHeight
            local t = i / segments
            
            local alpha
            if t < fadeRatio then
                alpha = minAlpha + (maxAlpha - minAlpha) * (t / fadeRatio)
            elseif t > (1 - fadeRatio) then
                alpha = minAlpha + (maxAlpha - minAlpha) * ((1 - t) / fadeRatio)
            else
                alpha = maxAlpha
            end
            
            love.graphics.setColor(gridBrightness, gridBrightness, gridBrightness, alpha)
            love.graphics.line(lineX, y1, lineX, y2)
        end
    end
    
    -- Horizontal lines
    for y = 1, board.height - 1 do
        local lineY = offsetY + y * bh
        local totalWidth = fieldW
        local segments = 20
        
        for i = 0, segments - 1 do
            local x1 = offsetX + (i / segments) * totalWidth
            local x2 = offsetX + ((i + 1) / segments) * totalWidth
            local t = i / segments
            
            local alpha
            if t < fadeRatio then
                alpha = minAlpha + (maxAlpha - minAlpha) * (t / fadeRatio)
            elseif t > (1 - fadeRatio) then
                alpha = minAlpha + (maxAlpha - minAlpha) * ((1 - t) / fadeRatio)
            else
                alpha = maxAlpha
            end
            
            love.graphics.setColor(gridBrightness, gridBrightness, gridBrightness, alpha)
            love.graphics.line(x1, lineY, x2, lineY)
        end
    end
    
    -- Draw locked blocks
    for y = 1, board.height do
        for x = 1, board.width do
            if board.grid[y][x] ~= 0 then
                if invisible then
                    -- Nearly invisible stack (still solid)
                    local color = forcedColor or board.grid[y][x]
                    color = Theme.adaptBlockColor(color)
                    local r, g, b = unpack(color)
                    love.graphics.setColor(r, g, b, 0.08)
                    love.graphics.rectangle("fill", offsetX + (x - 1) * bw, offsetY + (y - 1) * bh, bw, bh)
                else
                    Renderer.drawBlock(offsetX + (x - 1) * bw, offsetY + (y - 1) * bh, bw, bh, forcedColor or board.grid[y][x])
                end
            end
        end
    end
    
    -- Draw ghost piece
    if showGhost and board.currentPiece and not board.gameOver and not forcedColor then
        local Piece = require('src.tetris.piece')
        local ghostY = Piece.getGhostY(board)
        if board.phantomTimer and board.phantomTimer > 0 then
            ghostY = (ghostY or board.pieceY) + (board.phantomOffset or 3)
            ghostY = math.max(1, math.min(board.height, ghostY))
        end
        if ghostY and ghostY ~= board.pieceY then
            local ghostColor = Theme.adaptBlockColor(forcedColor or board.currentPiece.color)
            local r, g, b = unpack(ghostColor)
            local ghostAlpha = Theme.isLight() and 0.65 or 0.5
            love.graphics.setColor(r, g, b, ghostAlpha)
            for y = 1, #board.currentPiece.shape do
                for x = 1, #board.currentPiece.shape[y] do
                    if board.currentPiece.shape[y][x] ~= 0 then
                        local gy = ghostY + y - 1
                        local gx = board.pieceX + x - 1
                        if gy >= 1 and gy <= board.height and gx >= 1 and gx <= board.width then
                            love.graphics.rectangle("line", offsetX + (gx - 1) * bw + 1, offsetY + (gy - 1) * bh + 1, bw - 2, bh - 2)
                        end
                    end
                end
            end
        end
    end

    -- Draw current piece
    if board.currentPiece and not board.gameOver then
        for y = 1, #board.currentPiece.shape do
            for x = 1, #board.currentPiece.shape[y] do
                if board.currentPiece.shape[y][x] ~= 0 then
                    local gy = board.pieceY + y - 1
                    local gx = board.pieceX + x - 1
                    if gy >= 1 and gy <= board.height and gx >= 1 and gx <= board.width then
                        Renderer.drawBlock(offsetX + (gx - 1) * bw, offsetY + (gy - 1) * bh, bw, bh, forcedColor or board.currentPiece.color)
                    end
                end
            end
        end
    end
    
    -- Draw game over overlay
    if board.gameOver then
        local goAlpha = Theme.isLight() and 0.28 or 0.4
        love.graphics.setColor(1, 0, 0, goAlpha)
        love.graphics.rectangle("fill", offsetX, offsetY, fieldW, fieldH)
    end

    -- Fog overlay (hide stack clarity a bit)
    if board.fogTimer and board.fogTimer > 0 and not board.gameOver then
        local fog = theme.fog
        love.graphics.setColor(fog[1], fog[2], fog[3], fog[4])
        love.graphics.rectangle("fill", offsetX, offsetY, fieldW, fieldH)
    end

    love.graphics.pop()

    -- Post-flip overlays (axis-aligned on playfield rect)
    local t = love.timer.getTime()

    -- Fuzz / static
    if board.fuzzTimer and board.fuzzTimer > 0 and not board.gameOver then
        local bands = 12
        local bandH = fieldH / bands
        for i = 0, bands - 1 do
            local wobble = math.sin(t * 14 + i * 1.7) * 3
                + math.sin(t * 23 + i * 0.9) * 2
            local shade = 0.15 + 0.2 * (0.5 + 0.5 * math.sin(t * 9 + i))
            love.graphics.setColor(shade, shade, shade + 0.05, 0.28)
            love.graphics.rectangle("fill", offsetX + wobble, offsetY + i * bandH, fieldW, bandH + 1)
            for n = 1, 4 do
                local nx = offsetX + ((i * 37 + n * 91 + math.floor(t * 40)) % math.max(1, math.floor(fieldW)))
                local ny = offsetY + i * bandH + (n * 7) % bandH
                love.graphics.setColor(1, 1, 1, 0.14)
                love.graphics.rectangle("fill", nx, ny, 2, 2)
            end
        end
    end

    -- Glitch: CRT-style wavy tears
    if board.glitchTimer and board.glitchTimer > 0 and not board.gameOver then
        local bands = 10
        local bandH = fieldH / bands
        for i = 0, bands - 1 do
            local wobble = math.sin(t * 18 + i * 2.1) * 5
                + math.sin(t * 31 + i) * 2
            love.graphics.setColor(0.9, 0.95, 1.0, 0.12)
            love.graphics.rectangle("fill", offsetX + wobble, offsetY + i * bandH, fieldW, 2)
            if i % 3 == 0 then
                love.graphics.setColor(1, 0.2, 0.35, 0.18)
                love.graphics.rectangle("fill", offsetX + wobble * 1.4, offsetY + i * bandH + 1, fieldW * 0.35, 1)
            end
        end
    end

    -- Chroma / prism: RGB split fringes along edges
    if board.chromaTimer and board.chromaTimer > 0 and not board.gameOver then
        local off = 2 + math.sin(t * 6) * 1.5
        love.graphics.setColor(1, 0.15, 0.2, 0.45)
        love.graphics.rectangle("fill", offsetX - off, offsetY, 3, fieldH)
        love.graphics.setColor(0.15, 0.85, 1, 0.45)
        love.graphics.rectangle("fill", offsetX + fieldW + off - 3, offsetY, 3, fieldH)
        love.graphics.setColor(0.3, 1, 0.35, 0.25)
        love.graphics.rectangle("fill", offsetX, offsetY - 1, fieldW, 2)
        love.graphics.rectangle("fill", offsetX, offsetY + fieldH - 1, fieldW, 2)
    end

    -- Tunnel: darken top/bottom, leave middle slit readable
    if board.tunnelTimer and board.tunnelTimer > 0 and not board.gameOver then
        local slitH = fieldH * 0.28
        local slitY = offsetY + fieldH * 0.36
        love.graphics.setColor(0.02, 0.02, 0.05, 0.78)
        love.graphics.rectangle("fill", offsetX, offsetY, fieldW, slitY - offsetY)
        love.graphics.rectangle("fill", offsetX, slitY + slitH, fieldW, offsetY + fieldH - (slitY + slitH))
    end
end

return Renderer
