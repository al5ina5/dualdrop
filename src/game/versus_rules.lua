-- src/game/versus_rules.lua
-- Versus rulesets: classic / chaos / cheese race helpers

local VersusRules = {}

VersusRules.ORDER = { "classic", "chaos", "cheese" }

VersusRules.LABELS = {
    classic = "CLASSIC",
    chaos = "CHAOS",
    cheese = "CHEESE RACE",
}

VersusRules.DESCRIPTIONS = {
    classic = "B2B + Perfect Clear garbage",
    chaos = "Garbage + charge power-ups",
    cheese = "Start with cheese — first to clear wins",
}

VersusRules.CHEESE_ROWS = 8
VersusRules.LOCKHOLD_CLEARS = 2
VersusRules.BASE_LOCK_DELAY = 0.5
VersusRules.CEMENT_LOCK_DELAY = 0.05

-- Weighted chaos power-ups (visuals common, rares sparse)
-- Display names match frosty_rabbid icon flavor
VersusRules.EFFECT_WEIGHTS = {
    -- Visual-only
    glitch = 3,
    chroma = 3,
    fuzz = 3,
    fog = 2,
    flip_h = 2,
    flip_v = 2,
    -- Soft gameplay
    drunk = 2,
    molasses = 2,
    hyper = 2,
    ice = 2,
    phantom = 2,
    tunnel = 2,
    quake = 2,
    bonk = 2,
    -- Rare
    invisible = 1,
    lockhold = 1,
    cement = 1,
    scramble = 1,
}

VersusRules.EFFECT_LABELS = {
    glitch = "GLITCH",
    chroma = "PRISM",
    fuzz = "STATIC",
    fog = "MIST",
    flip_h = "MIRROR",
    flip_v = "DIVE",
    drunk = "HEX",
    molasses = "SLOW",
    hyper = "HASTE",
    ice = "FROST",
    phantom = "EYE",
    tunnel = "VOID",
    quake = "QUAKE",
    bonk = "METEOR",
    invisible = "CLOAK",
    lockhold = "BIND",
    cement = "STONE",
    scramble = "SCROLL",
}

VersusRules.EFFECT_LETTERS = {
    glitch = "G",
    chroma = "P",
    fuzz = "S",
    fog = "M",
    flip_h = "R",
    flip_v = "V",
    drunk = "X",
    molasses = "W",
    hyper = "H",
    ice = "F",
    phantom = "E",
    tunnel = "O",
    quake = "Q",
    bonk = "B",
    invisible = "C",
    lockhold = "L",
    cement = "T",
    scramble = "Z",
}

VersusRules.EFFECT_DURATION = {
    glitch = 5.0,
    chroma = 5.0,
    fuzz = 5.0,
    fog = 6.0,
    flip_h = 5.0,
    flip_v = 5.0,
    drunk = 4.0,
    molasses = 6.0,
    hyper = 4.0,
    ice = 3.5,
    phantom = 5.0,
    tunnel = 5.0,
    quake = 4.0,
    bonk = 2.5, -- cement follow-up
    invisible = 4.0,
    lockhold = 0,
    cement = 3.5,
    scramble = 0,
    invert = 4.0, -- legacy
}

VersusRules.CHARGE_MAX = 3
VersusRules.LOTTERY_DURATION = 1.0
VersusRules.LOTTERY_TICK = 0.05
VersusRules.QUAKE_INTERVAL = 0.65

local iconCache = nil

local function loadIcons()
    if iconCache then return iconCache end
    iconCache = {}
    for id, _ in pairs(VersusRules.EFFECT_WEIGHTS) do
        local path = "assets/icons/chaos/" .. id .. ".png"
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            iconCache[id] = img
        end
    end
    return iconCache
end

function VersusRules.getIcon(effect)
    local icons = loadIcons()
    return icons[effect]
end

function VersusRules.normalize(id)
    if id == "chaos" or id == "cheese" then return id end
    return "classic"
end

function VersusRules.label(id)
    return VersusRules.LABELS[VersusRules.normalize(id)] or "CLASSIC"
end

function VersusRules.next(id, dir)
    local cur = VersusRules.normalize(id)
    local idx = 1
    for i, r in ipairs(VersusRules.ORDER) do
        if r == cur then idx = i break end
    end
    idx = idx + (dir or 1)
    if idx < 1 then idx = #VersusRules.ORDER end
    if idx > #VersusRules.ORDER then idx = 1 end
    return VersusRules.ORDER[idx]
end

function VersusRules.isChaos(game)
    return VersusRules.normalize(game and game.versusRules) == "chaos"
end

function VersusRules.isCheese(game)
    return VersusRules.normalize(game and game.versusRules) == "cheese"
end

function VersusRules.pickEffect()
    local total = 0
    for _, w in pairs(VersusRules.EFFECT_WEIGHTS) do
        total = total + w
    end
    local roll = love.math.random() * total
    local acc = 0
    -- Stable order for determinism across platforms
    local keys = {}
    for id in pairs(VersusRules.EFFECT_WEIGHTS) do
        table.insert(keys, id)
    end
    table.sort(keys)
    for _, id in ipairs(keys) do
        acc = acc + VersusRules.EFFECT_WEIGHTS[id]
        if roll <= acc then
            return id
        end
    end
    return keys[#keys]
end

function VersusRules.effectLetter(effect)
    return VersusRules.EFFECT_LETTERS[effect] or "?"
end

function VersusRules.effectLabel(effect)
    return VersusRules.EFFECT_LABELS[effect] or string.upper(tostring(effect or "?"))
end

function VersusRules.enableChaosBoards(game)
    local enabled = VersusRules.isChaos(game)
    local function flag(board)
        if not board then return end
        board.chaosEnabled = enabled
        if not enabled then
            board.chaosCharge = 0
            board.chaosPowerUp = nil
            board.chaosLottery = nil
        end
    end
    if game.localPlayers then
        for _, lp in ipairs(game.localPlayers) do
            flag(lp.board)
        end
    end
    flag(game.localBoard)
end

function VersusRules.refreshDropSpeed(board)
    if not board then return end
    local Scoring = require('src.tetris.scoring')
    local base = math.max(0.05, 1.0 * (0.8 ^ ((board.level or 1) - 1)))
    if board.hyperTimer and board.hyperTimer > 0 then
        board.dropSpeed = math.max(0.05, base / 2.5)
    elseif board.molassesTimer and board.molassesTimer > 0 then
        board.dropSpeed = base * 2.2
    else
        board.dropSpeed = base
    end
    -- Keep Scoring helper in sync for non-chaos callers
    board._chaosDropOverride = true
end

function VersusRules.refreshLockDelay(board)
    if not board then return end
    if board.cementTimer and board.cementTimer > 0 then
        board.lockDelay = VersusRules.CEMENT_LOCK_DELAY
    else
        board.lockDelay = VersusRules.BASE_LOCK_DELAY
    end
end

local function forceBonk(board)
    if not board or not board.currentPiece or board.gameOver then return end
    local Piece = require('src.tetris.piece')
    while Piece.move(board, 0, 1) do end
    local Scoring = require('src.tetris.scoring')
    Scoring.lockPiece(board)
end

local function scrambleNext(board)
    local Piece = require('src.tetris.piece')
    if not board.bag then board.bag = Piece.initBag() end
    board.nextQueue = Piece.initQueue(board.bag)
    board.nextPieceType = table.remove(board.nextQueue, 1)
    table.insert(board.nextQueue, Piece.getRandomType(board.bag))
end

function VersusRules.applyEffect(board, effect, duration)
    if not board or not effect then return end
    if effect == "invert" then effect = "drunk" end
    local dur = duration or VersusRules.EFFECT_DURATION[effect] or 5

    if effect == "fog" then
        board.fogTimer = dur
    elseif effect == "drunk" then
        board.invertTimer = dur
    elseif effect == "flip_h" then
        board.flipHTimer = dur
    elseif effect == "flip_v" then
        board.flipVTimer = dur
    elseif effect == "fuzz" then
        board.fuzzTimer = dur
    elseif effect == "glitch" then
        board.glitchTimer = dur
    elseif effect == "chroma" then
        board.chromaTimer = dur
    elseif effect == "molasses" then
        board.molassesTimer = dur
        board.hyperTimer = 0
        VersusRules.refreshDropSpeed(board)
    elseif effect == "hyper" then
        board.hyperTimer = dur
        board.molassesTimer = 0
        VersusRules.refreshDropSpeed(board)
    elseif effect == "ice" then
        board.iceTimer = dur
    elseif effect == "phantom" then
        board.phantomTimer = dur
        board.phantomOffset = (love.math.random(0, 1) == 0) and -3 or 3
    elseif effect == "tunnel" then
        board.tunnelTimer = dur
    elseif effect == "quake" then
        board.quakeTimer = dur
        board.quakePulse = 0
    elseif effect == "bonk" then
        forceBonk(board)
        board.cementTimer = dur
        VersusRules.refreshLockDelay(board)
    elseif effect == "invisible" then
        board.invisibleTimer = dur
    elseif effect == "lockhold" then
        board.holdLocked = true
        board.holdLockClears = VersusRules.LOCKHOLD_CLEARS
    elseif effect == "cement" then
        board.cementTimer = dur
        VersusRules.refreshLockDelay(board)
    elseif effect == "scramble" then
        scrambleNext(board)
    end
end

function VersusRules.updateBoard(board, dt)
    if not board then return end

    local function tick(field)
        if board[field] and board[field] > 0 then
            local before = board[field]
            board[field] = math.max(0, board[field] - dt)
            return before > 0 and board[field] <= 0
        end
        return false
    end

    tick("fogTimer")
    tick("invertTimer")
    tick("flipHTimer")
    tick("flipVTimer")
    tick("fuzzTimer")
    tick("glitchTimer")
    tick("chromaTimer")
    local molassesEnded = tick("molassesTimer")
    local hyperEnded = tick("hyperTimer")
    tick("iceTimer")
    tick("phantomTimer")
    tick("tunnelTimer")
    tick("invisibleTimer")
    local cementEnded = tick("cementTimer")

    if molassesEnded or hyperEnded then
        VersusRules.refreshDropSpeed(board)
    end
    if cementEnded then
        VersusRules.refreshLockDelay(board)
    end

    -- Quake: pulse shake + safe nudge
    if board.quakeTimer and board.quakeTimer > 0 then
        board.quakeTimer = math.max(0, board.quakeTimer - dt)
        board.quakePulse = (board.quakePulse or 0) + dt
        if board.quakePulse >= VersusRules.QUAKE_INTERVAL then
            board.quakePulse = board.quakePulse - VersusRules.QUAKE_INTERVAL
            local FX = require('src.fx')
            FX:shake(6, 0.12)
            if board.currentPiece and not board.gameOver then
                local Piece = require('src.tetris.piece')
                local dx = (love.math.random(0, 1) == 0) and -1 or 1
                Piece.move(board, dx, 0) -- fails safely on collision
            end
        end
    end

    -- Lottery spin → award power-up into slot
    local lot = board.chaosLottery
    if lot then
        lot.t = (lot.t or 0) + dt
        lot.tickAcc = (lot.tickAcc or 0) + dt
        if lot.tickAcc >= VersusRules.LOTTERY_TICK then
            lot.tickAcc = lot.tickAcc - VersusRules.LOTTERY_TICK
            lot.rolling = VersusRules.pickEffect()
        end
        if lot.t >= (lot.duration or VersusRules.LOTTERY_DURATION) then
            board.chaosPowerUp = lot.result or lot.rolling or VersusRules.pickEffect()
            board.chaosLottery = nil
        end
    end
end

function VersusRules.onLinesCleared(board, lineCount)
    if not board or lineCount <= 0 then return end

    if board.holdLocked then
        board.holdLockClears = (board.holdLockClears or 0) - 1
        if board.holdLockClears <= 0 then
            board.holdLocked = false
            board.holdLockClears = 0
        end
    end

    if not board.chaosEnabled then return end
    if board.chaosPowerUp or board.chaosLottery then return end

    board.chaosCharge = (board.chaosCharge or 0) + lineCount
    if board.chaosCharge >= VersusRules.CHARGE_MAX then
        board.chaosCharge = 0
        local result = VersusRules.pickEffect()
        board.chaosLottery = {
            t = 0,
            duration = VersusRules.LOTTERY_DURATION,
            tickAcc = 0,
            rolling = result,
            result = result,
        }
    end
end

function VersusRules.isBoardEmpty(board)
    if not board or not board.grid then return false end
    for y = 1, board.height do
        for x = 1, board.width do
            if board.grid[y][x] ~= 0 then
                return false
            end
        end
    end
    return true
end

function VersusRules.applyCheese(board, rows)
    rows = rows or VersusRules.CHEESE_ROWS
    local Piece = require('src.tetris.piece')
    local garbageColor = Piece.PIECES.GARBAGE.color
    for i = 1, rows do
        table.remove(board.grid, 1)
        local hole = love.math.random(1, board.width)
        local hole2 = nil
        if love.math.random() < 0.35 then
            hole2 = love.math.random(1, board.width)
            if hole2 == hole then hole2 = (hole % board.width) + 1 end
        end
        local row = {}
        for x = 1, board.width do
            if x == hole or x == hole2 then
                row[x] = 0
            else
                row[x] = garbageColor
            end
        end
        table.insert(board.grid, board.height, row)
    end
    board.cheeseRows = rows
    board.raceWon = false
    board.gridChanged = true
    local PieceMod = require('src.tetris.piece')
    PieceMod.spawn(board)
end

function VersusRules.seedMatchBoards(game)
    VersusRules.enableChaosBoards(game)
    if not VersusRules.isCheese(game) then return end
    local function seed(board)
        if board and not board.cheeseRows then
            VersusRules.applyCheese(board, VersusRules.CHEESE_ROWS)
        end
    end
    if game.localPlayers then
        for _, lp in ipairs(game.localPlayers) do
            seed(lp.board)
        end
    end
    seed(game.localBoard)
end

function VersusRules.checkCheeseWin(game)
    if not VersusRules.isCheese(game) then return nil end
    local TeamMatch = require('src.game.team_match')
    local fmt = TeamMatch.getFormat(game.matchFormat or "1v1")
    local myTeam = TeamMatch.localTeam(game)

    for _, seatId in ipairs(fmt.seats) do
        local board = TeamMatch.getBoard(game, seatId)
        if board then
            local won = board.raceWon
            if not won and TeamMatch.isLocalSeat(game, seatId)
                and not board.gameOver
                and VersusRules.isBoardEmpty(board)
                and (board.linesCleared or 0) > 0 then
                board.raceWon = true
                won = true
            end

            if won then
                local team = TeamMatch.teamOf(seatId)
                if myTeam and team then
                    if team == myTeam then return "WIN" end
                    return "LOSS"
                end
                if TeamMatch.isLocalSeat(game, seatId) then
                    return "WIN"
                end
                return "LOSS"
            end
        end
    end
    return nil
end

function VersusRules.statusLabels(board)
    local labels = {}
    if not board then return labels end
    local function add(timer, name)
        if timer and timer > 0 then
            table.insert(labels, string.format("%s %.0f", name, timer))
        end
    end
    add(board.fogTimer, "MIST")
    add(board.invertTimer, "HEX")
    add(board.flipHTimer, "MIRROR")
    add(board.flipVTimer, "DIVE")
    add(board.fuzzTimer, "STATIC")
    add(board.glitchTimer, "GLITCH")
    add(board.chromaTimer, "PRISM")
    add(board.molassesTimer, "SLOW")
    add(board.hyperTimer, "HASTE")
    add(board.iceTimer, "FROST")
    add(board.phantomTimer, "EYE")
    add(board.tunnelTimer, "VOID")
    add(board.quakeTimer, "QUAKE")
    add(board.invisibleTimer, "CLOAK")
    add(board.cementTimer, "STONE")
    if board.holdLocked then
        table.insert(labels, "BIND x" .. tostring(board.holdLockClears or 0))
    end
    if board.backToBack then
        table.insert(labels, "B2B")
    end
    return labels
end

--- Compact HUD: 3-segment charge bar, or lottery/power-up icon when ready.
function VersusRules.drawPowerUpUI(board, areaX, y, areaW, font)
    if not board or not board.chaosEnabled then return end

    local cx = areaX + areaW / 2

    local effect = nil
    local ready = false
    if board.chaosLottery then
        effect = board.chaosLottery.rolling
    elseif board.chaosPowerUp then
        effect = board.chaosPowerUp
        ready = true
    end

    if effect then
        local box = 20
        local bx = math.floor(cx - box / 2)
        local by = math.floor(y)
        love.graphics.setColor(0.1, 0.1, 0.14, 0.95)
        love.graphics.rectangle("fill", bx, by, box, box)
        local border = ready and {0.35, 1, 0.5, 1} or {1, 1, 0.35, 1}
        love.graphics.setColor(border)
        love.graphics.rectangle("line", bx, by, box, box)

        local icon = VersusRules.getIcon(effect)
        if icon then
            love.graphics.setColor(1, 1, 1, 1)
            local iw, ih = icon:getDimensions()
            local scale = 16 / math.max(iw, ih)
            local dx = bx + (box - iw * scale) / 2
            local dy = by + (box - ih * scale) / 2
            love.graphics.draw(icon, dx, dy, 0, scale, scale)
        else
            if font then love.graphics.setFont(font) end
            love.graphics.setColor(border)
            love.graphics.printf(VersusRules.effectLetter(effect), bx, by + 4, box, "center")
        end
        return
    end

    local segW, segH, gap = 10, 6, 2
    local totalW = VersusRules.CHARGE_MAX * segW + (VersusRules.CHARGE_MAX - 1) * gap
    local startX = math.floor(cx - totalW / 2)
    local charge = board.chaosCharge or 0

    for i = 1, VersusRules.CHARGE_MAX do
        local sx = startX + (i - 1) * (segW + gap)
        local sy = math.floor(y + 4)
        love.graphics.setColor(0.45, 0.45, 0.5, 1)
        love.graphics.rectangle("fill", sx - 1, sy - 1, segW + 2, segH + 2)
        if i <= charge then
            love.graphics.setColor(1.0, 0.78, 0.15, 1)
        else
            love.graphics.setColor(0.18, 0.18, 0.22, 1)
        end
        love.graphics.rectangle("fill", sx, sy, segW, segH)
        if i <= charge then
            love.graphics.setColor(1.0, 0.95, 0.55, 0.85)
            love.graphics.rectangle("fill", sx + 1, sy + 1, segW - 2, 1)
        end
    end
end

return VersusRules
