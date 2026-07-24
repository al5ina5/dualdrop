-- src/ui/menu/ip_input.lua
-- IP address input screen using digit picker

local DigitPicker = require('src.ui.components.digit_picker')

local IPInput = {}

function IPInput.init(menu)
    -- Create digit picker for IP address (12 digits with dots as separators)
    menu.ipPicker = DigitPicker.new({
        length = 12,
        charset = "0123456789",
        separators = {[3]=".", [6]=".", [9]="."},
        label = "JOIN BY IP"
    })
    
    -- Set default IP from old ipDigits if they exist
    if menu.ipDigits then
        local ipStr = ""
        for i = 1, 12 do
            ipStr = ipStr .. tostring(menu.ipDigits[i])
        end
        menu.ipPicker:setValue(ipStr)
    else
        -- Default to 192.168.001.001
        menu.ipPicker:setValue("192168001001")
    end
end

function IPInput.draw(menu, sw, sh, game)
    -- Initialize picker if not already done
    if not menu.ipPicker then
        IPInput.init(menu)
    end
    
    -- Use the picker's draw method
    menu.ipPicker:draw(game, sw, sh)
    
    -- Instructions
    if menu.fonts then love.graphics.setFont(menu.fonts.small) end
    game:drawText("Port 12345  •  D-PAD to edit IP", 0, sh - 100, sw, "center", {0.6, 0.6, 0.6})
    game:drawText("A/ENTER to JOIN  •  B/ESC to BACK", 0, sh - 60, sw, "center", {0.6, 0.6, 0.6})
end

function IPInput.handleKey(menu, key)
    local Base = require('src.ui.menu.base')
    
    -- Initialize picker if not already done
    if not menu.ipPicker then
        IPInput.init(menu)
    end
    
    -- Let picker handle navigation and input
    if menu.ipPicker:handleKey(key) then
        return true
    end
    
    -- Handle period key to jump to next octet
    if key == "." or key == "kp." then
        local currentOctet = math.floor((menu.ipPicker.selectedIndex - 1) / 3)
        if currentOctet < 3 then
            menu.ipPicker.selectedIndex = (currentOctet + 1) * 3 + 1
        end
        return true
    end

    -- Submit
    if key == "return" or key == "space" or key == "x" then
        return IPInput.submit(menu)
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 3  -- JOIN BY IP is 3rd in LAN submenu
        return true
    end
    return false
end

function IPInput.handleGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    
    -- Initialize picker if not already done
    if not menu.ipPicker then
        IPInput.init(menu)
    end
    
    -- Let picker handle navigation
    if menu.ipPicker:handleGamepad(button) then
        return true
    end
    
    -- Submit
    if button == "a" then
        return IPInput.submit(menu)
    elseif button == "b" or button == "back" then
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 3  -- JOIN BY IP is 3rd in LAN submenu
        return true
    end
    return false
end

function IPInput.submit(menu)
    local Base = require('src.ui.menu.base')
    
    -- Initialize picker if not already done
    if not menu.ipPicker then
        IPInput.init(menu)
    end
    
    -- Get the 12-digit string from picker
    local digitStr = menu.ipPicker:getValue()
    
    -- Convert 12 digits to IP address
    local octets = {}
    for i = 1, 4 do
        local start = (i-1)*3 + 1
        local octetStr = digitStr:sub(start, start+2)
        local val = tonumber(octetStr)
        table.insert(octets, math.min(255, val))
    end
    local ip = table.concat(octets, ".")
    menu.state = Base.STATE.CONNECTING
    menu.connectionError = nil
    menu.selectedServer = {name = "Custom IP", ip = ip, port = 12345}
    
    -- Save the last IP
    if menu.onSettingChanged then
        menu.onSettingChanged("lastIP", ip)
    end

    if menu.onJoin then
        menu.onJoin(ip, 12345)
    end
    return true
end

return IPInput
