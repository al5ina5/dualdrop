-- Minimal ENet LAN smoke test for Dualdrop ports
--   ./love.AppImage enet_smoke.love host
--   ./love.AppImage enet_smoke.love client 10.0.0.165

local enet = require("enet")

print("SMOKE_ARGS", table.concat(arg or {}, " | "))

local mode = "host"
local address = "127.0.0.1"
-- LÖVE: arg[1] is game path; user args start at arg[2]
if arg then
    if arg[2] == "client" or arg[2] == "host" then
        mode = arg[2]
        address = arg[3] or address
    elseif arg[1] == "client" or arg[1] == "host" then
        mode = arg[1]
        address = arg[2] or address
    end
end

local port = 12345
local deadline = 0
local done = false
local ok = false
local host

function love.load()
    deadline = love.timer.getTime() + 10
    print("SMOKE_MODE", mode, address)
    if mode == "host" then
        host = enet.host_create("*:" .. port, 4)
        if not host then
            print("SMOKE_FAIL host_create")
            love.event.quit(1)
            return
        end
        print("SMOKE_HOST_LISTEN " .. port)
    else
        host = enet.host_create()
        if not host then
            print("SMOKE_FAIL client_host")
            love.event.quit(1)
            return
        end
        local peer = host:connect(address .. ":" .. port, 4)
        if not peer then
            print("SMOKE_FAIL connect_init")
            love.event.quit(1)
            return
        end
        print("SMOKE_CLIENT_CONNECT " .. address .. ":" .. port)
    end
end

function love.update(dt)
    if done or not host then return end
    local event = host:service(0)
    while event do
        if event.type == "connect" then
            print("SMOKE_CONNECT peer=" .. tostring(event.peer))
            if mode == "host" then
                event.peer:send("hello|host", 0, "reliable")
                ok = true
            else
                event.peer:send("hello|client", 0, "reliable")
                ok = true
                done = true
            end
        elseif event.type == "receive" then
            print("SMOKE_RECV " .. tostring(event.data))
            ok = true
            done = true
        elseif event.type == "disconnect" then
            print("SMOKE_DISCONNECT")
        end
        event = host:service(0)
    end
    host:flush()

    if done or love.timer.getTime() > deadline then
        print(ok and "SMOKE_OK" or "SMOKE_TIMEOUT")
        done = true
        love.event.quit(ok and 0 or 1)
    end
end

function love.draw()
    love.graphics.print(mode .. " " .. (ok and "ok" or "..."), 10, 10)
end
