-- src/ui/menu/title_animation.lua
-- Animated title with falling letters and floating effect

local TitleAnimation = {}

-- Initialize animation state for a title
function TitleAnimation.init()
    local state = {
        letters = {},
        initialized = false,
        allLanded = false,
        time = 0,
    }
    return state
end

-- Setup letters for animation (call when showing menu)
function TitleAnimation.setup(state, title, font)
    state.letters = {}
    state.allLanded = false
    state.time = 0
    
    -- Calculate individual letter positions
    local totalWidth = 0
    local letterWidths = {}
    
    for i = 1, #title do
        local char = title:sub(i, i)
        local width = font:getWidth(char)
        letterWidths[i] = width
        totalWidth = totalWidth + width
    end
    
    -- Add spacing between letters
    local spacing = 4
    totalWidth = totalWidth + spacing * (#title - 1)
    
    local startX = -totalWidth / 2  -- Centered around 0
    local currentX = startX
    
    for i = 1, #title do
        local char = title:sub(i, i)
        local letter = {
            char = char,
            targetX = currentX + letterWidths[i] / 2,
            targetY = 0,
            x = currentX + letterWidths[i] / 2,
            y = -200 - (i - 1) * 60,  -- Staggered start positions above screen
            width = letterWidths[i],
            
            -- Fall animation
            falling = true,
            fallSpeed = 0,
            fallAccel = 1800,  -- Gravity
            fallDelay = (i - 1) * 0.12,  -- Staggered timing
            
            -- Land effect
            landed = false,
            landTime = 0,
            bounceOffset = 0,
            squashFactor = 1,
            
            -- Float/sway animation (after landing)
            floatPhase = i * 0.8,  -- Different phase per letter
            floatAmplitude = 3,
            swayAmplitude = 0.03,
        }
        
        table.insert(state.letters, letter)
        currentX = currentX + letterWidths[i] + spacing
    end
    
    state.initialized = true
end

-- Reset animation (for when returning to main menu)
function TitleAnimation.reset(state)
    for _, letter in ipairs(state.letters) do
        letter.y = -200 - (_ - 1) * 60
        letter.falling = true
        letter.fallSpeed = 0
        letter.landed = false
        letter.landTime = 0
        letter.bounceOffset = 0
        letter.squashFactor = 1
    end
    state.allLanded = false
    state.time = 0
end

-- Update animation
function TitleAnimation.update(state, dt)
    if not state.initialized then return end
    
    state.time = state.time + dt
    local allLanded = true
    
    for i, letter in ipairs(state.letters) do
        if letter.falling then
            -- Wait for fall delay
            if state.time >= letter.fallDelay then
                -- Apply gravity
                letter.fallSpeed = letter.fallSpeed + letter.fallAccel * dt
                letter.y = letter.y + letter.fallSpeed * dt
                
                -- Check for landing
                if letter.y >= letter.targetY then
                    letter.y = letter.targetY
                    letter.falling = false
                    letter.landed = true
                    letter.landTime = state.time
                    letter.bounceOffset = -15  -- Initial bounce up
                    letter.squashFactor = 0.7  -- Squash on impact
                end
            end
            allLanded = false
        elseif letter.landed then
            -- Landing animation
            local timeSinceLand = state.time - letter.landTime
            
            if timeSinceLand < 0.3 then
                -- Bounce and squash recovery
                local t = timeSinceLand / 0.3
                letter.bounceOffset = -15 * (1 - t) * math.cos(t * math.pi * 2)
                letter.squashFactor = 0.7 + 0.3 * t + 0.1 * math.sin(t * math.pi)
                
                -- Settle squash back to 1
                if t > 0.5 then
                    letter.squashFactor = 1 + (letter.squashFactor - 1) * (1 - (t - 0.5) * 2)
                end
            else
                -- Floating/swaying animation
                local floatTime = state.time - letter.landTime - 0.3
                letter.bounceOffset = math.sin(floatTime * 1.5 + letter.floatPhase) * letter.floatAmplitude
                letter.squashFactor = 1
            end
        end
    end
    
    state.allLanded = allLanded
end

-- Draw the animated title
function TitleAnimation.draw(state, centerX, centerY, font, game, shadowColor)
    if not state.initialized or #state.letters == 0 then return end

    local Theme = require('src.ui.theme')
    local letterColor = Theme.adaptColor({1, 1, 1, 1})
    shadowColor = shadowColor or (Theme.isLight() and {0.75, 0.75, 0.72, 1} or {0.3, 0.3, 0.3, 1})
    
    love.graphics.setFont(font)
    
    for _, letter in ipairs(state.letters) do
        local x = centerX + letter.x
        local y = centerY + letter.y + letter.bounceOffset
        
        -- Calculate sway rotation
        local rotation = 0
        if letter.landed and not letter.falling then
            local timeSinceLand = state.time - letter.landTime
            if timeSinceLand > 0.3 then
                local floatTime = timeSinceLand - 0.3
                rotation = math.sin(floatTime * 2 + letter.floatPhase * 1.3) * letter.swayAmplitude
            end
        end
        
        -- Draw with transformation
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(rotation)
        love.graphics.scale(1, letter.squashFactor)
        
        -- Draw shadow
        if shadowColor then
            love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 1)
            love.graphics.print(letter.char, 2, 2, 0, 1, 1, letter.width / 2, font:getHeight() / 2)
        end
        
        -- Draw letter
        love.graphics.setColor(letterColor[1], letterColor[2], letterColor[3], letterColor[4] or 1)
        love.graphics.print(letter.char, 0, 0, 0, 1, 1, letter.width / 2, font:getHeight() / 2)
        
        love.graphics.pop()
    end
end

return TitleAnimation
