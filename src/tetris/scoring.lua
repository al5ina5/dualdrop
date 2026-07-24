-- src/tetris/scoring.lua
-- Scoring system: line clearing, combos, garbage, and level progression

local Audio = require('src.audio')
local FX = require('src.fx')
local Constants = require('src.constants')

local Scoring = {}

function Scoring.updateDropSpeed(board)
    local VersusRules = require('src.game.versus_rules')
    -- Chaos molasses/hyper override via VersusRules when timers active
    if (board.molassesTimer and board.molassesTimer > 0)
        or (board.hyperTimer and board.hyperTimer > 0) then
        VersusRules.refreshDropSpeed(board)
        return
    end
    board.dropSpeed = math.max(0.05, 1.0 * (0.8 ^ (board.level - 1)))
end

function Scoring.clearLines(board)
    local linesToRemove = {}
    for y = board.height, 1, -1 do
        local full = true
        for x = 1, board.width do
            if board.grid[y][x] == 0 then
                full = false
                break
            end
        end
        if full then
            table.insert(linesToRemove, y)
        end
    end
    
    if #linesToRemove > 0 then
        board.combo = board.combo + 1
        
        -- Flash effect
        FX:flash()
        FX:shake(5, 0.2)
        
        -- Particles for cleared lines
        for _, y in ipairs(linesToRemove) do
            for x = 1, board.width do
                FX:spawnParticles(
                    (x-1)*Constants.BLOCK_SIZE_W + 8,
                    (y-1)*Constants.BLOCK_SIZE_H + 5,
                    board.grid[y][x], 1
                )
            end
        end

        -- Remove lines
        for _, y in ipairs(linesToRemove) do
            table.remove(board.grid, y)
        end
        
        -- Add empty lines at top
        for i = 1, #linesToRemove do
            local newRow = {}
            for x = 1, board.width do newRow[x] = 0 end
            table.insert(board.grid, 1, newRow)
        end
        
        -- Calculate score and garbage
        local lineCount = #linesToRemove
        local points = 0
        local garbageToSend = 0
        local difficultClear = false -- Tetris or T-spin clear (for B2B)
        
        if board.lastWasTSpin then
            difficultClear = true
            if lineCount == 1 then 
                points = 800; garbageToSend = 2
                board.lastTSpinType = "single"
            elseif lineCount == 2 then 
                points = 1200; garbageToSend = 4
                board.lastTSpinType = "double"
            elseif lineCount == 3 then 
                points = 1600; garbageToSend = 6
                board.lastTSpinType = "triple"
            end
            points = points * board.level
        else
            local multipliers = {100, 300, 500, 800}
            points = multipliers[math.min(lineCount, 4)] * board.level
            
            -- Standard garbage
            if lineCount == 2 then garbageToSend = 1
            elseif lineCount == 3 then garbageToSend = 2
            elseif lineCount == 4 then
                garbageToSend = 4
                difficultClear = true
            end
        end
        
        -- Back-to-back bonus (Tetris / T-spin chains)
        if difficultClear and board.backToBack then
            garbageToSend = garbageToSend + 1
            if lineCount >= 4 then
                garbageToSend = garbageToSend + 1 -- Tetris B2B hits harder
            end
            points = points + (board.level * 50)
        end
        if difficultClear then
            board.backToBack = true
        elseif lineCount > 0 then
            board.backToBack = false
        end
        
        -- Combo bonus
        points = points + (50 * board.combo * board.level)
        garbageToSend = garbageToSend + math.floor(board.combo / 2)

        -- Perfect Clear: board empty after the clear
        local perfectClear = true
        for y = 1, board.height do
            for x = 1, board.width do
                if board.grid[y][x] ~= 0 then
                    perfectClear = false
                    break
                end
            end
            if not perfectClear then break end
        end
        if perfectClear then
            garbageToSend = garbageToSend + 8
            points = points + (board.level * 2000)
            FX:shake(12, 0.35)
            FX:flash()
            board.perfectClearNotify = true
        end
        
        board.score = board.score + points
        board.linesCleared = board.linesCleared + lineCount

        local VersusRules = require('src.game.versus_rules')
        VersusRules.onLinesCleared(board, lineCount)
        
        -- Cancel pending garbage first
        if garbageToSend > 0 and board.pendingGarbage > 0 then
            local cancel = math.min(garbageToSend, board.pendingGarbage)
            garbageToSend = garbageToSend - cancel
            board.pendingGarbage = board.pendingGarbage - cancel
        end
        
        -- If still have garbage to send, notify game
        if garbageToSend > 0 then
            board.garbageToNotify = garbageToSend
        end

        -- Level up
        if board.linesCleared >= board.linesForNextLevel then
            board.level = board.level + 1
            board.linesForNextLevel = board.linesForNextLevel + 10
            Scoring.updateDropSpeed(board)
            Audio:play('item')
        end
        
        -- Sound effects
        if perfectClear or lineCount >= 4 or board.lastWasTSpin then
            Audio:play('secret')
        else
            Audio:play('clear')
        end
        return true
    else
        board.combo = -1
    end
    return false
end

function Scoring.receiveGarbage(board, lines)
    board.pendingGarbage = board.pendingGarbage + lines
end

function Scoring.applyGarbage(board)
    local lines = board.pendingGarbage
    board.pendingGarbage = 0
    
    local Piece = require('src.tetris.piece')
    local hole = math.random(1, board.width)
    for i = 1, lines do
        table.remove(board.grid, 1)
        local row = {}
        for x = 1, board.width do
            if x == hole then
                row[x] = 0
            else
                row[x] = Piece.PIECES.GARBAGE.color
            end
        end
        table.insert(board.grid, board.height, row)
    end
    board.gridChanged = true
end

function Scoring.lockPiece(board)
    local Piece = require('src.tetris.piece')
    local tspin = Piece.isTSpin(board)
    board.lastWasTSpin = tspin
    board.lastTSpinType = nil  -- Reset, will be set if T-spin clears lines
    
    -- Place piece on grid
    for y = 1, #board.currentPiece.shape do
        for x = 1, #board.currentPiece.shape[y] do
            if board.currentPiece.shape[y][x] ~= 0 then
                local gy = board.pieceY + y - 1
                local gx = board.pieceX + x - 1
                if gy >= 1 and gy <= board.height then
                    board.grid[gy][gx] = board.currentPiece.color
                    FX:spawnParticles(
                        (gx-1)*Constants.BLOCK_SIZE_W + 8,
                        (gy-1)*Constants.BLOCK_SIZE_H + 5,
                        board.currentPiece.color, 2
                    )
                end
            end
        end
    end
    
    local cleared = Scoring.clearLines(board)
    board.gridChanged = true
    if not cleared then
        Audio:play('lock')
        FX:shake(2, 0.1)
        board.combo = -1
        
        -- Apply pending garbage if no lines cleared
        if board.pendingGarbage > 0 then
            Scoring.applyGarbage(board)
        end
    end
    
    board.lockTimer = 0
    board.isWaitingToLock = false
    board.pieceLocked = true  -- Signal that a piece was locked
    Piece.spawn(board)
end

return Scoring
