-- src/tetris/piece.lua
-- Piece management: spawning, movement, rotation, and bag randomizer

local Audio = require('src.audio')
local Constants = require('src.constants')

local Piece = {}

Piece.PIECES = Constants.PIECES
Piece.WALL_KICKS = Constants.WALL_KICKS
Piece.WALL_KICKS_I = Constants.WALL_KICKS_I

function Piece.initBag()
    return {}
end

function Piece.initQueue(bag)
    local queue = {}
    for i = 1, 3 do
        table.insert(queue, Piece.getRandomType(bag))
    end
    return queue
end

function Piece.getRandomType(bag)
    if #bag == 0 then
        bag[1] = "I"
        bag[2] = "J"
        bag[3] = "L"
        bag[4] = "O"
        bag[5] = "S"
        bag[6] = "T"
        bag[7] = "Z"
        
        -- Shuffle
        for i = #bag, 2, -1 do
            local j = love.math.random(i)
            bag[i], bag[j] = bag[j], bag[i]
        end
    end
    return table.remove(bag)
end

function Piece.spawn(board, type)
    local pieceType = type or board.nextPieceType
    local data = Piece.PIECES[pieceType]
    
    board.currentPiece = {
        type = pieceType,
        shape = Piece.copyTable(data),
        color = data.color
    }
    
    if not type then
        board.nextPieceType = table.remove(board.nextQueue, 1)
        table.insert(board.nextQueue, Piece.getRandomType(board.bag))
    end
    
    board.pieceX = math.floor(board.width / 2) - math.floor(#board.currentPiece.shape[1] / 2)
    board.pieceY = 1
    board.rotationIndex = 0
    board.canHold = true
    
    if Piece.checkCollision(board, board.pieceX, board.pieceY) then
        board.gameOver = true
        Audio:play('gameOver')
    end
end

function Piece.copyTable(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = Piece.copyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function Piece.checkCollision(board, px, py, shape)
    shape = shape or board.currentPiece.shape
    for y = 1, #shape do
        for x = 1, #shape[y] do
            if shape[y][x] ~= 0 then
                local worldX = px + x - 1
                local worldY = py + y - 1
                
                if worldX < 1 or worldX > board.width or worldY > board.height then
                    return true
                end
                
                if worldY >= 1 and board.grid[worldY][worldX] ~= 0 then
                    return true
                end
            end
        end
    end
    return false
end

function Piece.move(board, dx, dy)
    if not Piece.checkCollision(board, board.pieceX + dx, board.pieceY + dy) then
        board.pieceX = board.pieceX + dx
        board.pieceY = board.pieceY + dy
        board.lastMoveWasRotation = false
        
        -- Reset lock delay on successful move
        if board.isWaitingToLock then
            board.lockTimer = 0
        end
        
        return true
    end
    return false
end

function Piece.rotate(board, ccw)
    local oldShape = board.currentPiece.shape
    local n = #oldShape
    local newShape = {}
    for i = 1, n do newShape[i] = {} end
    
    if ccw then
        for y = 1, n do
            for x = 1, n do
                newShape[n - x + 1][y] = oldShape[y][x]
            end
        end
    else
        for y = 1, n do
            for x = 1, n do
                newShape[x][n - y + 1] = oldShape[y][x]
            end
        end
    end
    
    local oldRotation = board.rotationIndex
    local newRotation = (oldRotation + (ccw and -1 or 1)) % 4
    if newRotation < 0 then newRotation = 3 end
    
    local kickData = board.currentPiece.type == "I" and Piece.WALL_KICKS_I or Piece.WALL_KICKS
    local testKey = tostring(oldRotation) .. tostring(newRotation)
    local kicks = kickData[testKey] or {{0,0}}
    
    for _, kick in ipairs(kicks) do
        local dx, dy = kick[1], -kick[2]
        if not Piece.checkCollision(board, board.pieceX + dx, board.pieceY + dy, newShape) then
            board.pieceX = board.pieceX + dx
            board.pieceY = board.pieceY + dy
            board.currentPiece.shape = newShape
            board.rotationIndex = newRotation
            board.lastMoveWasRotation = true
            
            -- Reset lock delay on successful rotation
            if board.isWaitingToLock then
                board.lockTimer = 0
            end
            
            return true
        end
    end
    
    return false
end

function Piece.hold(board)
    if not board.canHold then return false end
    if board.holdLocked then return false end
    
    local oldHoldType = board.holdPieceType
    board.holdPieceType = board.currentPiece.type
    
    if oldHoldType then
        Piece.spawn(board, oldHoldType)
    else
        Piece.spawn(board)
    end
    
    board.canHold = false
    return true
end

function Piece.isTSpin(board)
    if board.currentPiece.type ~= "T" or not board.lastMoveWasRotation then
        return false
    end
    
    -- Check 4 corners around T-center
    local corners = 0
    local checkX = {0, 2, 0, 2}
    local checkY = {0, 0, 2, 2}
    
    for i = 1, 4 do
        local gx = board.pieceX + checkX[i]
        local gy = board.pieceY + checkY[i]
        if gx < 1 or gx > board.width or gy > board.height or (gy >= 1 and board.grid[gy][gx] ~= 0) then
            corners = corners + 1
        end
    end
    
    return corners >= 3
end

function Piece.getGhostY(board)
    if not board.currentPiece then return nil end
    
    local ghostY = board.pieceY
    while not Piece.checkCollision(board, board.pieceX, ghostY + 1) do
        ghostY = ghostY + 1
    end
    return ghostY
end

return Piece
