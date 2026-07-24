-- src/scores.lua
-- Persistent match history and statistics management

local Scores = {}

Scores.FILE_NAME = "history.txt"
Scores.MAX_HISTORY = 50 -- Keep last 50 matches

Scores.history = {}
Scores.stats = {
    bestSprint = 0,
    highScore = 0,
    highLines = 0,
    totalGames = 0,
    versusWins = 0,
    versusLosses = 0,
    marathonHighScore = 0,
    marathonHighLevel = 0,
    marathonHighLines = 0
}

function Scores.load()
    Scores.history = {}
    Scores.stats = {
        bestSprint = 0,
        highScore = 0,
        highLines = 0,
        totalGames = 0,
        versusWins = 0,
        versusLosses = 0,
        marathonHighScore = 0,
        marathonHighLevel = 0,
        marathonHighLines = 0
    }

    if love.filesystem.getInfo(Scores.FILE_NAME) then
        local contents = love.filesystem.read(Scores.FILE_NAME)
        if contents then
            for line in contents:gmatch("[^\r\n]+") do
                local parts = {}
                for part in line:gmatch("([^|]+)") do
                    table.insert(parts, part)
                end
                
                if #parts >= 5 then
                    local match = {
                        mode = parts[1],
                        score = tonumber(parts[2]) or 0,
                        time = tonumber(parts[3]) or 0,
                        result = parts[4],
                        timestamp = parts[5]
                    }
                    
                    -- Parse extra data if present (format: key=value,key=value)
                    if parts[6] then
                        for kvpair in parts[6]:gmatch("([^,]+)") do
                            local key, value = kvpair:match("([^=]+)=([^=]+)")
                            if key and value then
                                match[key] = tonumber(value) or value
                            end
                        end
                    end
                    
                    table.insert(Scores.history, 1, match) -- Newest first
                end
            end
        end
    end

    Scores.calculateStats()
    return Scores.history
end

function Scores.calculateStats()
    Scores.stats.totalGames = #Scores.history
    Scores.stats.bestSprint = 0
    Scores.stats.highScore = 0
    Scores.stats.highLines = 0
    Scores.stats.versusWins = 0
    Scores.stats.versusLosses = 0
    Scores.stats.marathonHighScore = 0
    Scores.stats.marathonHighLevel = 0
    Scores.stats.marathonHighLines = 0

    for _, match in ipairs(Scores.history) do
        if match.mode == "SPRINT" then
            if match.result == "FINISHED" then
                if Scores.stats.bestSprint == 0 or match.time < Scores.stats.bestSprint then
                    Scores.stats.bestSprint = match.time
                end
            end
        end
        
        if match.mode == "MARATHON" then
            if match.score > Scores.stats.marathonHighScore then
                Scores.stats.marathonHighScore = match.score
            end
            if (match.level or 0) > Scores.stats.marathonHighLevel then
                Scores.stats.marathonHighLevel = match.level or 0
            end
            if (match.lines or 0) > Scores.stats.marathonHighLines then
                Scores.stats.marathonHighLines = match.lines or 0
            end
        end
        
        if match.score > Scores.stats.highScore then
            Scores.stats.highScore = match.score
        end

        if (match.lines or 0) > Scores.stats.highLines then
            Scores.stats.highLines = match.lines or 0
        end

        if match.mode == "VERSUS" then
            if match.result == "WIN" then
                Scores.stats.versusWins = Scores.stats.versusWins + 1
            elseif match.result == "LOSS" then
                Scores.stats.versusLosses = Scores.stats.versusLosses + 1
            end
        end
    end
end

-- Best score/lines for end-of-match display (includes current values)
function Scores.getHighsForMode(mode, score, lines)
    local stats = Scores.stats
    local highScore = stats.highScore or 0
    local highLines = stats.highLines or 0

    if mode == "MARATHON" then
        highScore = stats.marathonHighScore or 0
        highLines = stats.marathonHighLines or 0
    end

    return math.max(score or 0, highScore), math.max(lines or 0, highLines)
end

function Scores.addMatch(mode, score, time, result, extraStats)
    local timestamp = os.date("%Y-%m-%d %H:%M")
    local match = {
        mode = mode,
        score = score,
        time = time,
        result = result,
        timestamp = timestamp
    }
    
    -- Add mode-specific stats
    if extraStats then
        for k, v in pairs(extraStats) do
            match[k] = v
        end
    end
    
    table.insert(Scores.history, 1, match)
    
    -- Trim history
    while #Scores.history > Scores.MAX_HISTORY do
        table.remove(Scores.history)
    end
    
    Scores.calculateStats()
    Scores.save()
end

function Scores.save()
    local lines = {}
    -- Save in chronological order (reverse of history table)
    for i = #Scores.history, 1, -1 do
        local m = Scores.history[i]
        local line = string.format("%s|%d|%f|%s|%s", 
            m.mode, m.score, m.time, m.result, m.timestamp)
        
        -- Add extra data if present
        local extraData = {}
        for k, v in pairs(m) do
            if k ~= "mode" and k ~= "score" and k ~= "time" and k ~= "result" and k ~= "timestamp" then
                table.insert(extraData, string.format("%s=%s", k, tostring(v)))
            end
        end
        if #extraData > 0 then
            line = line .. "|" .. table.concat(extraData, ",")
        end
        
        table.insert(lines, line)
    end
    
    love.filesystem.write(Scores.FILE_NAME, table.concat(lines, "\n"))
end

return Scores
