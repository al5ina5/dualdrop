-- src/settings.lua
-- Persistent settings management for Dualdrop

local json = require("src.lib.dkjson")

local Settings = {}

Settings.FILE_NAME = "settings.txt"

-- Default settings
Settings.current = {
    lastIP = "192.168.1.1",
    shader = "CRT",
    ghost = true,
    musicVolume = 5,
    sfxVolume = 5,
    fullscreen = false,
    -- PIXEL = integer letterbox, FIT = fill max keep 4:3, STRETCH = edge-to-edge
    scaleMode = "STRETCH",
    bgColor = "BLACK",
    controls = nil -- Will be populated by Controls module
}

local function applyLoaded(loadedSettings)
    if type(loadedSettings) ~= "table" then
        return false
    end
    for k, v in pairs(loadedSettings) do
        Settings.current[k] = v
    end
    return true
end

local function parseKeyValue(contents)
    local loaded = {}
    local found = false
    for line in contents:gmatch("[^\r\n]+") do
        local key, value = line:match("^([^=]+)=([^=]*)$")
        if key and value then
            found = true
            if value == "true" then value = true
            elseif value == "false" then value = false
            elseif tonumber(value) then value = tonumber(value)
            end
            loaded[key] = value
        end
    end
    if found then
        return loaded
    end
    return nil
end

function Settings.load()
    if love.filesystem.getInfo(Settings.FILE_NAME) then
        local contents = love.filesystem.read(Settings.FILE_NAME)
        if contents and #contents > 0 then
            -- Prefer JSON (safe). Never execute settings as Lua.
            local decoded = json.decode(contents)
            if not applyLoaded(decoded) then
                local kv = parseKeyValue(contents)
                if not applyLoaded(kv) then
                    print("Settings: corrupt settings.txt ignored; using defaults")
                end
            end
        end
    end
    return Settings.current
end

function Settings.save()
    local encoded = json.encode(Settings.current, { indent = true })
    if encoded then
        love.filesystem.write(Settings.FILE_NAME, encoded)
    end
end

function Settings.update(key, value)
    if Settings.current[key] ~= value then
        Settings.current[key] = value
        Settings.save()
    end
end

return Settings
