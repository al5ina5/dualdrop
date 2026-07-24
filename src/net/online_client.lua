-- src/net/online_client.lua
-- Online multiplayer matchmaker client for the Render service
-- Handles room creation, listing, and joining via REST API

local json = require("src.lib.dkjson")
local Constants = require("src.constants")

-- Try to load HTTPS support (lua-sec - preferred method)
local https
local ltn12
local hasLuaSec = pcall(function()
    https = require("ssl.https")
    ltn12 = require("ltn12")
end)

-- Fallback: Try simple HTTP (curl/wget)
local SimpleHTTP
local hasSimpleHTTP = false
if not hasLuaSec then
    local success, module = pcall(require, "src.net.simple_http")
    if success then
        SimpleHTTP = module
        hasSimpleHTTP = SimpleHTTP.isAvailable()
    end
end

local OnlineClient = {}
OnlineClient.__index = OnlineClient

-- Check if online multiplayer is available
function OnlineClient.isAvailable()
    return hasLuaSec or hasSimpleHTTP
end

-- Probe matchmaking API (cached by caller). False when HTTPS missing or server down.
function OnlineClient.isServerReachable()
    if not OnlineClient.isAvailable() then
        return false
    end
    local client, err = OnlineClient:new()
    if not client then
        return false
    end
    local success = client:httpRequest("GET", client.apiUrl .. "/api/list-rooms")
    return success == true
end

function OnlineClient:new()
    if not OnlineClient.isAvailable() then
        return nil, "Online multiplayer requires HTTPS support (install lua-sec or ensure curl/wget is available)"
    end
    
    local self = setmetatable({}, OnlineClient)
    self.roomCode = nil
    self.connected = false
    self.apiUrl = Constants.API_BASE_URL
    self.httpMethod = hasLuaSec and "luasec" or "simple"
    
    return self
end

-- Helper: Make HTTP request
function OnlineClient:httpRequest(method, url, body)
    if self.httpMethod == "luasec" then
        local response = {}
        local headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = body and tostring(#body) or "0"
        }
        
        local request = {
            url = url,
            method = method,
            headers = headers,
            source = body and ltn12.source.string(body) or nil,
            sink = ltn12.sink.table(response)
        }
        
        local ok, code = https.request(request)
        if not ok then return false, "Request failed: " .. tostring(code) end
        
        local responseBody = table.concat(response)
        if code >= 200 and code < 300 then
            local success, data = pcall(json.decode, responseBody)
            return success, data
        else
            return false, "HTTP " .. code
        end
    else
        return SimpleHTTP.request(method, url, body)
    end
end

-- Matchmaking API
function OnlineClient:createRoom(isPublic, opts)
    opts = opts or {}
    local body = json.encode({
        isPublic = isPublic or false,
        format = opts.format or "1v1",
        maxSeats = opts.maxSeats,
        seatsUsed = opts.seatsUsed or 1,
    })
    local success, response = self:httpRequest("POST", self.apiUrl .. "/api/create-room", body)
    if not success then return false end
    self.roomCode = response.roomCode
    if response.format then self.roomFormat = response.format end
    return true, self.roomCode
end

function OnlineClient:joinRoom(roomCode, seats)
    local success, response = self:httpRequest("POST", self.apiUrl .. "/api/join-room", json.encode({
        roomCode = roomCode:upper(),
        seats = seats or 1,
    }))
    if not success then return false, response end
    self.roomCode = roomCode:upper()
    if type(response) == "table" and response.format then
        self.roomFormat = response.format
    end
    return true
end

function OnlineClient:listRooms()
    local success, response = self:httpRequest("GET", self.apiUrl .. "/api/list-rooms")
    if not success then return {} end
    return response.rooms or {}
end

function OnlineClient:heartbeat(players)
    if not self.roomCode then return false end
    local body = { roomCode = self.roomCode }
    if players ~= nil then body.players = players end
    return self:httpRequest("POST", self.apiUrl .. "/api/heartbeat", json.encode(body))
end

function OnlineClient:disconnect()
    self.roomCode = nil
    self.connected = false
end

return OnlineClient
