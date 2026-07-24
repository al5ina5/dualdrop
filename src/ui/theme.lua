-- src/ui/theme.lua
-- Smart background / UI color themes (incl. light modes that invert contrast)

local Theme = {}

Theme.OPTIONS = { "BLACK", "NAVY", "FOREST", "SLATE", "WHITE", "PINK", "LIME", "SKY" }

Theme.PALETTES = {
    BLACK = {
        bg = { 0.00, 0.00, 0.00 },
        playfield = { 0.06, 0.06, 0.08 },
        gridBrightness = 0.42,
        gridMinAlpha = 0.12,
        gridMaxAlpha = 0.35,
        menuBlockOpacityScale = 1.0,
        fog = { 0.15, 0.15, 0.20, 0.45 },
        barBg = { 0.25, 0.25, 0.28, 0.85 },
        light = false,
    },
    NAVY = {
        bg = { 0.04, 0.06, 0.14 },
        playfield = { 0.05, 0.08, 0.16 },
        gridBrightness = 0.48,
        gridMinAlpha = 0.10,
        gridMaxAlpha = 0.32,
        menuBlockOpacityScale = 1.0,
        fog = { 0.10, 0.12, 0.22, 0.45 },
        barBg = { 0.18, 0.22, 0.35, 0.85 },
        light = false,
    },
    FOREST = {
        bg = { 0.04, 0.09, 0.05 },
        playfield = { 0.05, 0.10, 0.06 },
        gridBrightness = 0.40,
        gridMinAlpha = 0.10,
        gridMaxAlpha = 0.30,
        menuBlockOpacityScale = 1.0,
        fog = { 0.10, 0.16, 0.12, 0.45 },
        barBg = { 0.18, 0.28, 0.20, 0.85 },
        light = false,
    },
    SLATE = {
        bg = { 0.12, 0.13, 0.15 },
        playfield = { 0.14, 0.15, 0.17 },
        gridBrightness = 0.55,
        gridMinAlpha = 0.14,
        gridMaxAlpha = 0.38,
        menuBlockOpacityScale = 0.9,
        fog = { 0.20, 0.20, 0.24, 0.40 },
        barBg = { 0.30, 0.32, 0.36, 0.85 },
        light = false,
    },
    WHITE = {
        bg = { 0.96, 0.96, 0.94 },
        playfield = { 0.90, 0.90, 0.88 },
        gridBrightness = 0.28,
        gridMinAlpha = 0.18,
        gridMaxAlpha = 0.50,
        menuBlockOpacityScale = 0.55,
        fog = { 0.75, 0.75, 0.78, 0.40 },
        barBg = { 0.78, 0.78, 0.80, 0.90 },
        light = true,
    },
    PINK = {
        bg = { 1.00, 0.86, 0.92 },
        playfield = { 0.98, 0.78, 0.86 },
        gridBrightness = 0.32,
        gridMinAlpha = 0.16,
        gridMaxAlpha = 0.48,
        menuBlockOpacityScale = 0.55,
        fog = { 0.92, 0.70, 0.80, 0.38 },
        barBg = { 0.90, 0.62, 0.74, 0.90 },
        light = true,
    },
    LIME = {
        bg = { 0.88, 0.98, 0.72 },
        playfield = { 0.80, 0.94, 0.62 },
        gridBrightness = 0.30,
        gridMinAlpha = 0.16,
        gridMaxAlpha = 0.48,
        menuBlockOpacityScale = 0.55,
        fog = { 0.72, 0.88, 0.52, 0.38 },
        barBg = { 0.62, 0.82, 0.40, 0.90 },
        light = true,
    },
    SKY = {
        bg = { 0.78, 0.92, 1.00 },
        playfield = { 0.68, 0.86, 0.98 },
        gridBrightness = 0.30,
        gridMinAlpha = 0.16,
        gridMaxAlpha = 0.48,
        menuBlockOpacityScale = 0.55,
        fog = { 0.58, 0.78, 0.92, 0.38 },
        barBg = { 0.48, 0.70, 0.88, 0.90 },
        light = true,
    },
}

local currentName = "BLACK"

function Theme.set(name)
    if Theme.PALETTES[name] then
        currentName = name
    end
end

function Theme.getName()
    return currentName
end

function Theme.get()
    return Theme.PALETTES[currentName] or Theme.PALETTES.BLACK
end

function Theme.isLight()
    return Theme.get().light == true
end

-- Adapt UI text colors for light backgrounds (keeps selection tint readable)
function Theme.adaptColor(color)
    if not color or not Theme.isLight() then
        return color
    end
    local r, g, b, a = color[1] or 1, color[2] or 1, color[3] or 1, color[4]
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    if lum < 0.45 then
        return color
    end
    -- Bright → dark; scale luminance so hue bias (yellow select, green HUD) survives
    local targetLum = math.max(0.12, 1 - lum * 0.78)
    local factor = targetLum / math.max(lum, 0.001)
    local out = {
        math.max(0.05, math.min(0.55, r * factor)),
        math.max(0.05, math.min(0.55, g * factor)),
        math.max(0.05, math.min(0.55, b * factor)),
    }
    if a ~= nil then out[4] = a end
    return out
end

function Theme.textShadow()
    if Theme.isLight() then
        return { 1, 1, 1, 0.85 }
    end
    return { 0, 0, 0, 1 }
end

function Theme.textOutline()
    if Theme.isLight() then
        return { 1, 1, 1, 0.95 }
    end
    return { 0, 0, 0, 1 }
end

-- Slightly darken piece colors on light themes for contrast on white playfield
function Theme.adaptBlockColor(color)
    if not color or not Theme.isLight() then
        return color
    end
    local r, g, b = color[1], color[2], color[3]
    return {
        r * 0.82,
        g * 0.82,
        b * 0.82,
    }
end

return Theme
