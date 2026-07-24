-- src/systems/input.lua
-- Input handling with DAS/ARR
-- Supports keyboard and per-gamepad device tracking

local Input = {
    keysJustPressed = {},
    buttonsJustPressed = {}, -- button -> true (any pad, menus)
    buttonsJustPressedByPad = {}, -- padIndex -> { button -> true }
    keyTimers = {},
    buttonTimers = {}, -- button -> timer (any pad)
    buttonTimersByPad = {}, -- padIndex -> { button -> timer }
    lastPressTimes = {},
    throttleDelay = 0.05,
    das = 0.167,
    arr = 0.033,
}

local function getJoysticks()
    return love.joystick.getJoysticks()
end

local function isPadDown(padIndex, button)
    local joysticks = getJoysticks()
    local joystick = joysticks[padIndex]
    if not joystick then return false end
    local success, down = pcall(joystick.isGamepadDown, joystick, button)
    return success and down
end

local function isAnyGamepadDown(button)
    for i, joystick in ipairs(getJoysticks()) do
        local success, down = pcall(joystick.isGamepadDown, joystick, button)
        if success and down then
            return true
        end
    end
    return false
end

function Input:update(dt)
    for key, _ in pairs(self.keyTimers) do
        if love.keyboard.isDown(key) then
            self.keyTimers[key] = self.keyTimers[key] + dt
        else
            self.keyTimers[key] = nil
        end
    end
    for button, _ in pairs(self.buttonTimers) do
        if isAnyGamepadDown(button) then
            self.buttonTimers[button] = self.buttonTimers[button] + dt
        else
            self.buttonTimers[button] = nil
        end
    end
    for padIndex, timers in pairs(self.buttonTimersByPad) do
        for button, _ in pairs(timers) do
            if isPadDown(padIndex, button) then
                timers[button] = timers[button] + dt
            else
                timers[button] = nil
            end
        end
    end
end

function Input:postUpdate()
    self.keysJustPressed = {}
    self.buttonsJustPressed = {}
    self.buttonsJustPressedByPad = {}
end

function Input:wasKeyPressed(key)
    return self.keysJustPressed[key] == true
end

function Input:wasButtonPressed(button, padIndex)
    if padIndex then
        local byPad = self.buttonsJustPressedByPad[padIndex]
        return byPad and byPad[button] == true
    end
    return self.buttonsJustPressed[button] == true
end

function Input:shouldRepeat(keyOrButton, isGamepad, padIndex)
    if isGamepad then
        if self:wasButtonPressed(keyOrButton, padIndex) then return true end
        local timer
        if padIndex then
            local timers = self.buttonTimersByPad[padIndex]
            timer = timers and timers[keyOrButton]
        else
            timer = self.buttonTimers[keyOrButton]
        end
        if timer and timer >= self.das then
            local repeatTime = timer - self.das
            if repeatTime >= self.arr then
                if padIndex then
                    self.buttonTimersByPad[padIndex][keyOrButton] = self.das
                else
                    self.buttonTimers[keyOrButton] = self.das
                end
                return true
            end
        end
    else
        if self:wasKeyPressed(keyOrButton) then return true end
        local timer = self.keyTimers[keyOrButton]
        if timer and timer >= self.das then
            local repeatTime = timer - self.das
            if repeatTime >= self.arr then
                self.keyTimers[keyOrButton] = self.das
                return true
            end
        end
    end
    return false
end

function Input:keyPressed(key)
    local now = love.timer.getTime()
    if self.lastPressTimes[key] and (now - self.lastPressTimes[key]) < self.throttleDelay then
        return
    end
    self.lastPressTimes[key] = now
    self.keysJustPressed[key] = true
    self.keyTimers[key] = 0
end

function Input:keyReleased(key)
    self.keyTimers[key] = nil
end

function Input:gamepadPressed(button, joystick)
    local padIndex = nil
    if joystick then
        local joysticks = getJoysticks()
        for i, j in ipairs(joysticks) do
            if j == joystick then
                padIndex = i
                break
            end
        end
    end

    local now = love.timer.getTime()
    local throttleKey = padIndex and ("pad" .. padIndex .. ":" .. button) or button
    if self.lastPressTimes[throttleKey] and (now - self.lastPressTimes[throttleKey]) < self.throttleDelay then
        return
    end
    self.lastPressTimes[throttleKey] = now

    self.buttonsJustPressed[button] = true
    self.buttonTimers[button] = 0

    if padIndex then
        self.buttonsJustPressedByPad[padIndex] = self.buttonsJustPressedByPad[padIndex] or {}
        self.buttonsJustPressedByPad[padIndex][button] = true
        self.buttonTimersByPad[padIndex] = self.buttonTimersByPad[padIndex] or {}
        self.buttonTimersByPad[padIndex][button] = 0
    end
end

function Input:gamepadReleased(button, joystick)
    self.buttonTimers[button] = nil
    if joystick then
        local joysticks = getJoysticks()
        for i, j in ipairs(joysticks) do
            if j == joystick and self.buttonTimersByPad[i] then
                self.buttonTimersByPad[i][button] = nil
                break
            end
        end
    end
end

return Input
