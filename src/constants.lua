-- src/constants.lua
-- Common constants and data for the game

local Constants = {}

Constants.SW = 640
Constants.SH = 480

Constants.GRID_WIDTH = 10
Constants.GRID_HEIGHT = 20
Constants.BLOCK_SIZE_W = 32
Constants.BLOCK_SIZE_H = 24 -- 20 rows × 24 = 480 (fills canvas height)

-- Custom color palette for game pieces
Constants.PIECES = {
    I = {
        {0,0,0,0},
        {1,1,1,1},
        {0,0,0,0},
        {0,0,0,0},
        color = {0.4, 0.85, 0.9}, -- Soft teal
        id = 1
    },
    J = {
        {1,0,0},
        {1,1,1},
        {0,0,0},
        color = {0.35, 0.45, 0.85}, -- Periwinkle blue
        id = 2
    },
    L = {
        {0,0,1},
        {1,1,1},
        {0,0,0},
        color = {0.95, 0.65, 0.35}, -- Peach orange
        id = 3
    },
    O = {
        {1,1},
        {1,1},
        color = {0.95, 0.85, 0.45}, -- Soft gold
        id = 4
    },
    S = {
        {0,1,1},
        {1,1,0},
        {0,0,0},
        color = {0.45, 0.85, 0.55}, -- Mint green
        id = 5
    },
    T = {
        {0,1,0},
        {1,1,1},
        {0,0,0},
        color = {0.85, 0.45, 0.75}, -- Rose pink
        id = 6
    },
    Z = {
        {1,1,0},
        {0,1,1},
        {0,0,0},
        color = {0.9, 0.45, 0.45}, -- Coral
        id = 7
    },
    GARBAGE = {
        color = {0.5, 0.5, 0.5}, -- Gray
        id = 8
    }
}

-- SRS Wall Kick Data
Constants.WALL_KICKS = {
    ["01"] = {{0,0}, {-1,0}, {-1,-1}, {0,2}, {-1,2}},
    ["10"] = {{0,0}, {1,0}, {1,1}, {0,-2}, {1,-2}},
    ["12"] = {{0,0}, {1,0}, {1,1}, {0,-2}, {1,-2}},
    ["21"] = {{0,0}, {-1,0}, {-1,-1}, {0,2}, {-1,2}},
    ["23"] = {{0,0}, {1,0}, {1,-1}, {0,2}, {1,2}},
    ["32"] = {{0,0}, {-1,0}, {-1,1}, {0,-2}, {-1,-2}},
    ["30"] = {{0,0}, {-1,0}, {-1,1}, {0,-2}, {-1,-2}},
    ["03"] = {{0,0}, {1,0}, {1,-1}, {0,2}, {1,2}}
}

Constants.WALL_KICKS_I = {
    ["01"] = {{0,0}, {-2,0}, {1,0}, {-2,1}, {1,-2}},
    ["10"] = {{0,0}, {2,0}, {-1,0}, {2,-1}, {-1,2}},
    ["12"] = {{0,0}, {-1,0}, {2,0}, {-1,-2}, {2,1}},
    ["21"] = {{0,0}, {1,0}, {-2,0}, {1,2}, {-2,-1}},
    ["23"] = {{0,0}, {2,0}, {-1,0}, {2,-1}, {-1,2}},
    ["32"] = {{0,0}, {-2,0}, {1,0}, {-2,1}, {1,-2}},
    ["30"] = {{0,0}, {1,0}, {-2,0}, {1,2}, {-2,-1}},
    ["03"] = {{0,0}, {-1,0}, {2,0}, {-1,-2}, {2,1}}
}

-- Online multiplayer API endpoint
Constants.API_BASE_URL = "https://blockdrop-multiplayer-production.up.railway.app"
Constants.RELAY_HOST = "turntable.proxy.rlwy.net" 
Constants.RELAY_PORT = 32378

return Constants
