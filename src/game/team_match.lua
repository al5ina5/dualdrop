-- src/game/team_match.lua
-- Team battle formats, lobby seats, garbage targets, win checks

local TeamMatch = {}

TeamMatch.FORMATS = {
    ["1v1"] = {
        id = "1v1",
        maxSeats = 2,
        seats = { "a1", "b1" },
        teams = { A = { "a1" }, B = { "b1" } },
    },
    ["2v1"] = {
        id = "2v1",
        maxSeats = 3,
        seats = { "a1", "a2", "b1" },
        teams = { A = { "a1", "a2" }, B = { "b1" } },
    },
    ["2v2"] = {
        id = "2v2",
        maxSeats = 4,
        seats = { "a1", "a2", "b1", "b2" },
        teams = { A = { "a1", "a2" }, B = { "b1", "b2" } },
    },
}

TeamMatch.FORMAT_ORDER = { "1v1", "2v2" }

function TeamMatch.getFormat(formatId)
    return TeamMatch.FORMATS[formatId or "1v1"] or TeamMatch.FORMATS["1v1"]
end

function TeamMatch.teamOf(seatId)
    if not seatId then return nil end
    local t = seatId:sub(1, 1)
    if t == "a" then return "A" end
    if t == "b" then return "B" end
    return nil
end

function TeamMatch.createEmptyLobby(formatId, rulesId)
    local VersusRules = require('src.game.versus_rules')
    local fmt = TeamMatch.getFormat(formatId)
    local seats = {}
    for _, id in ipairs(fmt.seats) do
        seats[id] = { peerId = nil, ready = false }
    end
    return {
        format = fmt.id,
        rules = VersusRules.normalize(rulesId),
        seats = seats,
        maxSeats = fmt.maxSeats,
    }
end

function TeamMatch.countFilled(lobby)
    if not lobby then return 0 end
    local n = 0
    for _, seat in pairs(lobby.seats) do
        if seat.peerId then n = n + 1 end
    end
    return n
end

function TeamMatch.isFull(lobby)
    if not lobby then return false end
    return TeamMatch.countFilled(lobby) >= (lobby.maxSeats or 0)
end

-- Host can start once at least one other peer has claimed a seat
function TeamMatch.canStartMatch(lobby)
    if not lobby then return false end
    local peers = {}
    for _, seat in pairs(lobby.seats) do
        if seat.peerId then
            peers[seat.peerId] = true
        end
    end
    local n = 0
    for _ in pairs(peers) do
        n = n + 1
    end
    return n >= 2
end

function TeamMatch.openSeatsOnTeam(lobby, team)
    local open = {}
    if not lobby then return open end
    local fmt = TeamMatch.getFormat(lobby.format)
    local teamSeats = fmt.teams[team] or {}
    for _, id in ipairs(teamSeats) do
        local seat = lobby.seats[id]
        if seat and not seat.peerId then
            table.insert(open, id)
        end
    end
    return open
end

-- Console vs console: never cross teams when preferredTeam is set.
-- (Same-machine split-screen players always share one team.)
function TeamMatch.findClaimableSeats(lobby, count, preferredTeam)
    if not lobby or count < 1 then return nil end
    local teams = preferredTeam and { preferredTeam } or { "A", "B" }
    for _, team in ipairs(teams) do
        local open = TeamMatch.openSeatsOnTeam(lobby, team)
        if #open >= count then
            local claimed = {}
            for i = 1, count do
                claimed[i] = open[i]
            end
            return claimed, team
        end
    end
    return nil
end

-- Team already claimed by this peer (nil if none)
function TeamMatch.peerTeam(lobby, peerId)
    local seats = TeamMatch.seatsForPeer(lobby, peerId)
    if #seats == 0 then return nil end
    return TeamMatch.teamOf(seats[1])
end

-- Host console → Team A. Guest consoles → opposite of host (usually B).
-- If this peer already has seats, stay on that team.
function TeamMatch.consoleTeam(lobby, peerId, isHost)
    local existing = TeamMatch.peerTeam(lobby, peerId)
    if existing then return existing end
    if isHost or peerId == "host" then return "A" end
    local hostSeats = TeamMatch.seatsForPeer(lobby, "host")
    if #hostSeats > 0 and TeamMatch.teamOf(hostSeats[1]) == "B" then
        return "A"
    end
    return "B"
end

function TeamMatch.claimSeats(lobby, peerId, seatIds)
    if not lobby or not peerId or not seatIds or #seatIds == 0 then return false end
    local team = TeamMatch.teamOf(seatIds[1])
    for _, id in ipairs(seatIds) do
        local seat = lobby.seats[id]
        if not seat or (seat.peerId and seat.peerId ~= peerId) then
            return false
        end
        -- Reject mixed-team claims (split-screen must stay console vs console)
        if TeamMatch.teamOf(id) ~= team then
            return false
        end
    end
    for _, id in ipairs(seatIds) do
        lobby.seats[id].peerId = peerId
        lobby.seats[id].ready = false
    end
    return true
end

function TeamMatch.releasePeer(lobby, peerId)
    if not lobby or not peerId then return {} end
    local freed = {}
    for id, seat in pairs(lobby.seats) do
        if seat.peerId == peerId then
            seat.peerId = nil
            seat.ready = false
            table.insert(freed, id)
        end
    end
    return freed
end

function TeamMatch.seatsForPeer(lobby, peerId)
    local ids = {}
    if not lobby or not peerId then return ids end
    local fmt = TeamMatch.getFormat(lobby.format)
    for _, id in ipairs(fmt.seats) do
        local seat = lobby.seats[id]
        if seat and seat.peerId == peerId then
            table.insert(ids, id)
        end
    end
    return ids
end

function TeamMatch.setPeerReady(lobby, peerId, ready)
    if not lobby then return end
    for _, seat in pairs(lobby.seats) do
        if seat.peerId == peerId then
            seat.ready = ready and true or false
        end
    end
end

function TeamMatch.allReady(lobby)
    if not lobby or not TeamMatch.isFull(lobby) then return false end
    for _, seat in pairs(lobby.seats) do
        if seat.peerId and not seat.ready then
            return false
        end
    end
    return true
end

function TeamMatch.encodeLobby(lobby)
    -- format;rules;seat=peer:ready,...  (no "|" — protocol delimiter)
    local VersusRules = require('src.game.versus_rules')
    local parts = {}
    local fmt = TeamMatch.getFormat(lobby.format)
    for _, id in ipairs(fmt.seats) do
        local seat = lobby.seats[id]
        local peer = (seat and seat.peerId) or ""
        local ready = (seat and seat.ready) and "1" or "0"
        table.insert(parts, id .. "=" .. peer .. ":" .. ready)
    end
    local rules = VersusRules.normalize(lobby.rules)
    return lobby.format .. ";" .. rules .. ";" .. table.concat(parts, ",")
end

function TeamMatch.decodeLobby(data)
    if not data or data == "" then return nil end
    local VersusRules = require('src.game.versus_rules')
    local format, rules, rest

    -- New: format;rules;seats
    local f, r, rem = data:match("^([^;|]+);([^;]+);(.*)$")
    if f and r then
        format, rules, rest = f, VersusRules.normalize(r), rem
    else
        -- Legacy: format|rules;seats  or  format;seats  or  bare format
        local fmtPart, seatPart = data:match("^([^;]+);(.*)$")
        if not fmtPart then
            fmtPart = data
            seatPart = ""
        end
        local bareFormat, rulesPart = fmtPart:match("^([^|]+)|(.+)$")
        if bareFormat then
            format = bareFormat
            rules = VersusRules.normalize(rulesPart)
        else
            format = fmtPart
            rules = "classic"
        end
        rest = seatPart
    end

    local lobby = TeamMatch.createEmptyLobby(format, rules)
    for token in string.gmatch(rest or "", "[^,]+") do
        local id, peer, ready = token:match("^([^=]+)=([^:]*):([01])$")
        if id and lobby.seats[id] then
            lobby.seats[id].peerId = (peer ~= "" and peer) or nil
            lobby.seats[id].ready = ready == "1"
        end
    end
    return lobby
end

function TeamMatch.isLocalSeat(game, seatId)
    if not game.ownedSeats then return false end
    for _, id in ipairs(game.ownedSeats) do
        if id == seatId then return true end
    end
    return false
end

function TeamMatch.getBoard(game, seatId)
    if TeamMatch.isLocalSeat(game, seatId) then
        for _, lp in ipairs(game.localPlayers or {}) do
            if lp.id == seatId then return lp.board end
        end
        if game.localBoard and (not game.ownedSeats or game.ownedSeats[1] == seatId) then
            return game.localBoard
        end
    end
    return game.remoteBoards and game.remoteBoards[seatId]
end

function TeamMatch.isEnemy(fromSeat, toSeat)
    local t1, t2 = TeamMatch.teamOf(fromSeat), TeamMatch.teamOf(toSeat)
    return t1 and t2 and t1 ~= t2
end

-- All alive enemy seats (2v1: both opponents get garbage/effects)
function TeamMatch.listEnemyTargets(game, fromSeat)
    local enemies = {}
    local fmt = TeamMatch.getFormat(game.matchFormat or (game.lobby and game.lobby.format) or "1v1")
    local fromTeam = TeamMatch.teamOf(fromSeat)
    for _, seatId in ipairs(fmt.seats) do
        if TeamMatch.teamOf(seatId) ~= fromTeam then
            local board = TeamMatch.getBoard(game, seatId)
            if board and not board.gameOver then
                table.insert(enemies, seatId)
            end
        end
    end
    return enemies
end

function TeamMatch.pickGarbageTarget(game, fromSeat)
    local enemies = TeamMatch.listEnemyTargets(game, fromSeat)
    return enemies[1]
end

TeamMatch.ENEMY_WATCH_HOLD = 30
TeamMatch.ENEMY_WATCH_FADE = 1.25
TeamMatch.ENEMY_OVERLAY_HOLD = 15
TeamMatch.ENEMY_OVERLAY_ALPHA = 0.42
TeamMatch.ENEMY_OVERLAY_SCALE = 0.48

-- All filled enemy seats (alive first) for the solo-console ghost view
function TeamMatch.listEnemyGhosts(game)
    local myTeam = TeamMatch.localTeam(game)
    local alive, dead = {}, {}
    local fmt = TeamMatch.getFormat(game.matchFormat or (game.lobby and game.lobby.format) or "1v1")

    local function consider(seatId)
        local board = TeamMatch.getBoard(game, seatId)
        if not board then return end
        if board.gameOver then
            table.insert(dead, { id = seatId, board = board })
        else
            table.insert(alive, { id = seatId, board = board })
        end
    end

    if myTeam then
        local enemy = myTeam == "A" and "B" or "A"
        for _, seatId in ipairs(fmt.teams[enemy] or {}) do
            consider(seatId)
        end
    else
        local ids = {}
        for id in pairs(game.remoteBoards or {}) do
            table.insert(ids, id)
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            consider(id)
        end
    end

    if #alive > 0 then return alive end
    return dead
end

function TeamMatch.resetEnemyWatch(game)
    game.enemyOverlay = false
    game.enemyWatch = {
        index = 1,
        holdT = 0,
        fadeT = 0,
        fading = false,
        fromIndex = 1,
        toIndex = 1,
    }
end

function TeamMatch.canScoutOverlay(game)
    local localCount = game.localPlayers and #game.localPlayers or 1
    if localCount < 2 then return false end
    if game.localVersus then return false end
    if not game.network then return false end
    if game.state ~= "playing" and game.state ~= "countdown" then return false end
    for _, g in ipairs(TeamMatch.listEnemyGhosts(game)) do
        if not TeamMatch.isLocalSeat(game, g.id) then
            return true
        end
    end
    return false
end

function TeamMatch.tryToggleEnemyOverlay(game)
    if not TeamMatch.canScoutOverlay(game) then return false end
    local Controls = require('src.input.controls')
    local Input = require('src.input.input_state')
    local Audio = require('src.audio')

    local pressed = false
    for _, lp in ipairs(game.localPlayers or {}) do
        if Controls.isActionPressed("scout", Input, lp.device) then
            pressed = true
            break
        end
    end
    if not pressed then return false end

    game.enemyOverlay = not game.enemyOverlay
    if game.enemyOverlay then
        if not game.enemyWatch then
            game.enemyWatch = {
                index = 1, holdT = 0, fadeT = 0, fading = false,
                fromIndex = 1, toIndex = 1,
            }
        else
            game.enemyWatch.holdT = 0
            game.enemyWatch.fading = false
            game.enemyWatch.fadeT = 0
        end
    end
    Audio:play('move')
    return true
end

function TeamMatch.updateEnemyWatch(game, dt)
    if not game then return end
    local localCount = game.localPlayers and #game.localPlayers or 1
    local solo = localCount < 2
    local duoOverlay = localCount >= 2 and game.enemyOverlay
    if not solo and not duoOverlay then return end
    if game.state ~= "playing" and game.state ~= "countdown" then return end

    local ghosts = TeamMatch.listEnemyGhosts(game)
    if #ghosts <= 1 then
        if game.enemyWatch then
            game.enemyWatch.fading = false
            game.enemyWatch.fadeT = 0
            game.enemyWatch.index = 1
        end
        return
    end

    local watch = game.enemyWatch
    if not watch then
        TeamMatch.resetEnemyWatch(game)
        watch = game.enemyWatch
        if duoOverlay then game.enemyOverlay = true end
    end

    -- Keep index in range if roster shrank
    if watch.index > #ghosts then watch.index = 1 end
    if watch.fromIndex > #ghosts then watch.fromIndex = watch.index end
    if watch.toIndex > #ghosts then watch.toIndex = watch.index end

    local holdDur = duoOverlay and TeamMatch.ENEMY_OVERLAY_HOLD or TeamMatch.ENEMY_WATCH_HOLD

    if watch.fading then
        watch.fadeT = (watch.fadeT or 0) + dt
        local dur = TeamMatch.ENEMY_WATCH_FADE
        if watch.fadeT >= dur then
            watch.fading = false
            watch.fadeT = 0
            watch.index = watch.toIndex
            watch.fromIndex = watch.index
            watch.holdT = 0
        end
        return
    end

    watch.holdT = (watch.holdT or 0) + dt
    if watch.holdT >= holdDur then
        watch.fading = true
        watch.fadeT = 0
        watch.fromIndex = watch.index
        watch.toIndex = (watch.index % #ghosts) + 1
    end
end

-- Returns id, board, blend (0..1 toward next), nextId, nextBoard
function TeamMatch.enemyWatchView(game)
    local ghosts = TeamMatch.listEnemyGhosts(game)
    if #ghosts == 0 then return nil, nil, 0, nil, nil end

    local watch = game.enemyWatch
    if not watch then
        return ghosts[1].id, ghosts[1].board, 0, nil, nil
    end

    local fromIdx = math.min(watch.fromIndex or watch.index or 1, #ghosts)
    local cur = ghosts[fromIdx]
    if not watch.fading or #ghosts < 2 then
        return cur.id, cur.board, 0, nil, nil
    end

    local toIdx = math.min(watch.toIndex or 1, #ghosts)
    local nxt = ghosts[toIdx]
    local t = math.min(1, (watch.fadeT or 0) / TeamMatch.ENEMY_WATCH_FADE)
    -- Smoothstep — soft in/out, no snap
    local blend = t * t * (3 - 2 * t)
    return cur.id, cur.board, blend, nxt.id, nxt.board
end

-- Prefer current watch target, else first enemy (HUD / fallback)
function TeamMatch.primaryEnemy(game)
    local id, board, blend, nextId, nextBoard = TeamMatch.enemyWatchView(game)
    if blend and blend > 0.5 and nextBoard then
        return nextId, nextBoard
    end
    if id then return id, board end
    return nil, nil
end

function TeamMatch.teamEliminated(game, team)
    local fmt = TeamMatch.getFormat(game.matchFormat or "1v1")
    local seats = fmt.teams[team] or {}
    local participating = 0
    local alive = 0
    local inMatch = game.state == "playing" or game.state == "countdown" or game.state == "over"

    for _, seatId in ipairs(seats) do
        local lobbySeat = game.lobby and game.lobby.seats and game.lobby.seats[seatId]
        local claimed = lobbySeat and lobbySeat.peerId
        local board = TeamMatch.getBoard(game, seatId)

        -- Without a lobby, any existing board counts as a participant
        if not game.lobby then
            if board then
                participating = participating + 1
                if not board.gameOver then
                    alive = alive + 1
                end
            end
        elseif claimed then
            participating = participating + 1
            if not board then
                -- Claimed but not synced yet — still in the match
                alive = alive + 1
            elseif not board.gameOver then
                alive = alive + 1
            end
        elseif inMatch and board then
            -- Board present without lobby claim (e.g. truncated lobby sync) — still count
            participating = participating + 1
            if not board.gameOver then
                alive = alive + 1
            end
        end
        -- Unclaimed empty seats are ignored
    end

    -- No participants on this team → not eliminated (don't auto-win)
    if participating == 0 then
        return false
    end
    return alive == 0
end

function TeamMatch.localTeam(game)
    local seat = game.ownedSeats and game.ownedSeats[1]
    return TeamMatch.teamOf(seat)
end

-- Returns "WIN", "LOSS", or nil if match continues
function TeamMatch.versusResult(game)
    local myTeam = TeamMatch.localTeam(game)
    if not myTeam then
        -- Fallback 1v1 legacy
        if game.localBoard and game.localBoard.gameOver then return "LOSS" end
        for _, board in pairs(game.remoteBoards or {}) do
            if board.gameOver then return "WIN" end
        end
        return nil
    end

    local enemy = myTeam == "A" and "B" or "A"
    -- Need a real opponent (lobby claim or live remote board) before anyone can win
    if not TeamMatch.teamHasParticipants(game, enemy) then
        return nil
    end

    local myDead = TeamMatch.teamEliminated(game, myTeam)
    local enemyDead = TeamMatch.teamEliminated(game, enemy)
    if enemyDead and not myDead then return "WIN" end
    if myDead and not enemyDead then return "LOSS" end
    if myDead and enemyDead then return "LOSS" end -- simultaneous
    return nil
end

function TeamMatch.teamHasParticipants(game, team)
    local fmt = TeamMatch.getFormat(game.matchFormat or "1v1")
    for _, seatId in ipairs(fmt.teams[team] or {}) do
        local seat = game.lobby and game.lobby.seats and game.lobby.seats[seatId]
        if seat and seat.peerId then
            return true
        end
        -- Fallback when lobby claims were lost but boards are synced
        if TeamMatch.getBoard(game, seatId) then
            return true
        end
    end
    return false
end

-- Max split-screen players for a format (or a specific team).
-- Console vs console: locals cap at seats on THEIR team.
function TeamMatch.maxLocalPlayers(formatId, team)
    local fmt = TeamMatch.getFormat(formatId)
    if team then
        local seats = fmt.teams[team] or {}
        return math.min(2, #seats)
    end
    local a = #(fmt.teams.A or {})
    local b = #(fmt.teams.B or {})
    return math.min(2, math.max(a, b, 1))
end

function TeamMatch.defaultDevices(localCount)
    if localCount >= 2 then
        return { "keyboard", 1 } -- P1 keyboard, P2 first gamepad (or 2nd pad if remapped later)
    end
    return { "any" }
end

function TeamMatch.setupLocalPlayers(game, seatIds, devices)
    local TetrisBoard = require('src.tetris.board')
    game.ownedSeats = {}
    game.localPlayers = {}
    devices = devices or TeamMatch.defaultDevices(#seatIds)
    for i, seatId in ipairs(seatIds) do
        local board = TetrisBoard:new(10, 20)
        table.insert(game.localPlayers, {
            id = seatId,
            board = board,
            device = devices[i] or "any",
            sentGameOver = false,
            lastSentScore = 0,
            lastSentMove = { x = 0, y = 0, rot = 0, type = "" },
        })
        table.insert(game.ownedSeats, seatId)
    end
    game.localBoard = game.localPlayers[1] and game.localPlayers[1].board or TetrisBoard:new(10, 20)
    game.playerId = seatIds[1]
end

function TeamMatch.refreshLocalBoards(game)
    local TetrisBoard = require('src.tetris.board')
    if not game.localPlayers or #game.localPlayers == 0 then
        game.localBoard = TetrisBoard:new(10, 20)
        return
    end
    for _, lp in ipairs(game.localPlayers) do
        lp.board = TetrisBoard:new(10, 20)
        lp.sentGameOver = false
        lp.lastSentScore = 0
        lp.lastSentMove = { x = 0, y = 0, rot = 0, type = "" }
        -- keep lp.device / lp.id
    end
    game.localBoard = game.localPlayers[1].board
    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = { x = 0, y = 0, rot = 0, type = "" }
end

return TeamMatch
