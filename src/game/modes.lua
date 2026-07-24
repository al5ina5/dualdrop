-- src/game/modes.lua
-- Game mode configurations

local Modes = {
    VERSUS = {
        id = "VERSUS",
        name = "Versus",
        multiplayer = true,
        trackTime = true,
        endCondition = "opponent_loss", -- or team wipe when matchFormat is 2v1/2v2
        statsToTrack = {"score", "lines", "time"}
    },
    SPRINT = {
        id = "SPRINT",
        name = "Sprint",
        multiplayer = false,
        trackTime = true,
        endCondition = "line_goal",
        lineGoal = 40,
        statsToTrack = {"score", "time", "result"}
    },
    MARATHON = {
        id = "MARATHON",
        name = "Marathon",
        multiplayer = false,
        trackTime = true,
        endCondition = "death",
        startLevel = 1,
        statsToTrack = {"score", "level", "lines", "time", "maxCombo", "tspins"}
    }
}

function Modes.get(modeId)
    return Modes[modeId]
end

function Modes.isSinglePlayer(modeId)
    local mode = Modes[modeId]
    return mode and not mode.multiplayer
end

return Modes
