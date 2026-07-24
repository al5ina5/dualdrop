-- src/audio.lua
-- Classic multi-voice chiptune soundtrack (Zelda-inspired original compositions)

local Audio = {
    sounds = {},
    music = {},
    currentMusic = nil,
    currentMusicName = nil,
    sfxVolume = 0.5,
    musicVolume = 0.5,
    baseVolumes = {},
    _initialized = false,
    _soundsGenerated = {},
    _musicGenerated = {}
}

local NOTES = {
    ['C2'] = 65.41,  ['D2'] = 73.42,  ['E2'] = 82.41,  ['F2'] = 87.31,  ['F#2'] = 92.50, ['G2'] = 98.00,
    ['G#2'] = 103.83,['A2'] = 110.00, ['A#2'] = 116.54,['B2'] = 123.47,
    ['C3'] = 130.81, ['C#3'] = 138.59,['D3'] = 146.83, ['D#3'] = 155.56,['E3'] = 164.81, ['F3'] = 174.61,
    ['F#3'] = 185.00,['G3'] = 196.00, ['G#3'] = 207.65,['A3'] = 220.00, ['A#3'] = 233.08,['B3'] = 246.94,
    ['C4'] = 261.63, ['C#4'] = 277.18,['D4'] = 293.66, ['D#4'] = 311.13,['E4'] = 329.63, ['F4'] = 349.23,
    ['F#4'] = 369.99,['G4'] = 392.00, ['G#4'] = 415.30,['A4'] = 440.00, ['A#4'] = 466.16,['B4'] = 493.88,
    ['C5'] = 523.25, ['C#5'] = 554.37,['D5'] = 587.33, ['D#5'] = 622.25,['E5'] = 659.25, ['F5'] = 698.46,
    ['F#5'] = 739.99,['G5'] = 783.99, ['G#5'] = 830.61,['A5'] = 880.00, ['A#5'] = 932.33,['B5'] = 987.77,
    ['C6'] = 1046.50,['D6'] = 1174.66,['E6'] = 1318.51,['F6'] = 1396.91,['G6'] = 1567.98,
    ['R'] = 0
}

---------------------------------------------------------------------------
-- SFX (unchanged character, still square/ding)
---------------------------------------------------------------------------
local SOUND_DEFS = {
    move = { type = "square", freq = 880, duration = 0.05, volume = 1.0, decay = true, baseVol = 0.03 },
    rotate = { type = "square", freq = 660, duration = 0.07, volume = 1.0, decay = true, baseVol = 0.03 },
    lock = { type = "square", freq = 220, duration = 0.1, volume = 1.0, decay = true, baseVol = 0.05 },
    clear = { type = "ding", freqs = {784, 987, 1174, 1568}, duration = 0.4, volume = 1.0, baseVol = 0.05 },
    gameOver = { type = "ding", freqs = {440, 330, 220, 110}, duration = 0.8, volume = 1.0, baseVol = 0.06 },
    beep = { type = "square", freq = 440, duration = 0.1, volume = 1.0, decay = true, baseVol = 0.04 },
    go = { type = "square", freq = 880, duration = 0.2, volume = 1.0, decay = true, baseVol = 0.05 },
    secret = { type = "melody", melody = {{'D5', 1}, {'F5', 1}, {'G#5', 1}, {'A5', 2}, {'F5', 1}, {'D5', 4}}, stepDuration = 0.1, volume = 1.0, baseVol = 0.04 },
    item = { type = "melody", melody = {{'A4', 1}, {'D5', 1}, {'F#5', 1}, {'A5', 4}}, stepDuration = 0.12, volume = 1.0, baseVol = 0.04 }
}

---------------------------------------------------------------------------
-- Soundtrack: multi-voice NES-style arrangements
-- Each track: voices with wave (pulse/triangle/square), duty, vol, melody
-- Melodies are longer AABA / verse-chorus forms so loops stay fresh
---------------------------------------------------------------------------
local MUSIC_DEFS = {
    -- Title / menus: serene, regal "Legend's Call"
    menu = {
        stepDuration = 0.14,
        baseVol = 0.028,
        voices = {
            {
                wave = "pulse", duty = 0.5, vol = 0.55,
                melody = {
                    -- A: rising call
                    {'D4', 4}, {'A4', 4}, {'D5', 6}, {'E5', 2}, {'F5', 8},
                    {'E5', 4}, {'D5', 4}, {'C5', 4}, {'A4', 4}, {'G4', 8},
                    {'A4', 4}, {'C5', 4}, {'D5', 12}, {'R', 4},
                    -- A2
                    {'D4', 4}, {'A4', 4}, {'D5', 6}, {'E5', 2}, {'F5', 8},
                    {'G5', 4}, {'F5', 4}, {'E5', 4}, {'D5', 4}, {'C5', 8},
                    {'A4', 4}, {'G4', 4}, {'A4', 12}, {'R', 4},
                    -- B: pastoral answer
                    {'F4', 4}, {'A4', 4}, {'C5', 8}, {'D5', 4}, {'C5', 4}, {'A4', 8},
                    {'G4', 4}, {'A4', 4}, {'A#4', 8}, {'A4', 4}, {'G4', 4}, {'F4', 8},
                    {'E4', 4}, {'G4', 4}, {'A4', 8}, {'G4', 4}, {'E4', 4}, {'D4', 12}, {'R', 4},
                    -- A' heroic close
                    {'D4', 4}, {'F4', 4}, {'A4', 4}, {'D5', 4}, {'F5', 8}, {'E5', 4}, {'D5', 4},
                    {'C5', 4}, {'A4', 4}, {'G4', 4}, {'F4', 4}, {'E4', 8}, {'D4', 16},
                }
            },
            {
                wave = "pulse", duty = 0.25, vol = 0.28,
                melody = {
                    {'A3', 8}, {'D4', 8}, {'F4', 8}, {'E4', 8},
                    {'D4', 8}, {'C4', 8}, {'A3', 8}, {'G3', 8},
                    {'A3', 8}, {'C4', 8}, {'D4', 16},
                    {'A3', 8}, {'D4', 8}, {'F4', 8}, {'G4', 8},
                    {'A4', 8}, {'G4', 8}, {'E4', 8}, {'C4', 8},
                    {'D4', 8}, {'C4', 8}, {'A3', 16},
                    {'C4', 8}, {'F4', 8}, {'A4', 8}, {'F4', 8},
                    {'D4', 8}, {'G4', 8}, {'A#4', 8}, {'G4', 8},
                    {'A4', 8}, {'E4', 8}, {'F4', 8}, {'D4', 16},
                    {'D4', 8}, {'F4', 8}, {'A4', 8}, {'F4', 8},
                    {'E4', 8}, {'C4', 8}, {'A3', 8}, {'D4', 16},
                }
            },
            {
                wave = "triangle", vol = 0.40,
                melody = {
                    {'D3', 8}, {'D3', 8}, {'A2', 8}, {'A2', 8},
                    {'A#2', 8}, {'A#2', 8}, {'C3', 8}, {'C3', 8},
                    {'D3', 8}, {'A2', 8}, {'D3', 16},
                    {'D3', 8}, {'D3', 8}, {'A2', 8}, {'A2', 8},
                    {'G2', 8}, {'G2', 8}, {'A2', 8}, {'A2', 8},
                    {'D3', 8}, {'C3', 8}, {'D3', 16},
                    {'F2', 8}, {'F2', 8}, {'A2', 8}, {'A2', 8},
                    {'G2', 8}, {'G2', 8}, {'A#2', 8}, {'A#2', 8},
                    {'A2', 8}, {'A2', 8}, {'D3', 16},
                    {'A#2', 8}, {'A#2', 8}, {'F2', 8}, {'F2', 8},
                    {'C3', 8}, {'C3', 8}, {'D3', 16},
                }
            },
        }
    },

    -- Overworld adventure
    legend = {
        stepDuration = 0.12,
        baseVol = 0.026,
        voices = {
            {
                wave = "pulse", duty = 0.5, vol = 0.52,
                melody = {
                    {'D4', 2}, {'E4', 2}, {'F4', 4}, {'A4', 4}, {'D5', 6}, {'C5', 2}, {'A4', 8},
                    {'G4', 4}, {'A4', 4}, {'A#4', 4}, {'A4', 4}, {'G4', 4}, {'F4', 4}, {'E4', 8},
                    {'D4', 2}, {'E4', 2}, {'F4', 4}, {'A4', 4}, {'D5', 6}, {'E5', 2}, {'F5', 8},
                    {'E5', 4}, {'D5', 4}, {'C5', 4}, {'A4', 4}, {'G4', 8}, {'A4', 8},
                    -- B
                    {'C5', 4}, {'D5', 4}, {'E5', 8}, {'F5', 4}, {'E5', 4}, {'D5', 8},
                    {'A4', 4}, {'C5', 4}, {'D5', 8}, {'E5', 4}, {'D5', 4}, {'C5', 8},
                    {'A#4', 4}, {'A4', 4}, {'G4', 8}, {'F4', 4}, {'G4', 4}, {'A4', 8},
                    {'G4', 4}, {'F4', 4}, {'E4', 4}, {'D4', 4}, {'C4', 8}, {'D4', 8},
                    -- A'
                    {'D4', 2}, {'E4', 2}, {'F4', 4}, {'A4', 4}, {'D5', 6}, {'F5', 2}, {'E5', 8},
                    {'D5', 4}, {'C5', 4}, {'A4', 4}, {'G4', 4}, {'F4', 8}, {'D4', 16},
                }
            },
            {
                wave = "pulse", duty = 0.25, vol = 0.24,
                melody = {
                    {'A3', 8}, {'D4', 8}, {'F4', 8}, {'D4', 8},
                    {'G3', 8}, {'C4', 8}, {'E4', 8}, {'C4', 8},
                    {'A3', 8}, {'D4', 8}, {'F4', 8}, {'A4', 8},
                    {'G4', 8}, {'E4', 8}, {'C4', 8}, {'A3', 8},
                    {'E4', 8}, {'G4', 8}, {'A4', 8}, {'G4', 8},
                    {'F4', 8}, {'A4', 8}, {'C5', 8}, {'A4', 8},
                    {'G4', 8}, {'D4', 8}, {'F4', 8}, {'A4', 8},
                    {'E4', 8}, {'C4', 8}, {'A3', 8}, {'D4', 8},
                    {'A3', 8}, {'D4', 8}, {'F4', 8}, {'A4', 8},
                    {'G4', 8}, {'E4', 8}, {'A3', 8}, {'D4', 16},
                }
            },
            {
                wave = "triangle", vol = 0.38,
                melody = {
                    {'D3', 4}, {'D3', 4}, {'A2', 4}, {'A2', 4}, {'A#2', 4}, {'A#2', 4}, {'C3', 4}, {'C3', 4},
                    {'D3', 4}, {'D3', 4}, {'A2', 4}, {'A2', 4}, {'G2', 4}, {'G2', 4}, {'A2', 4}, {'A2', 4},
                    {'D3', 4}, {'D3', 4}, {'A2', 4}, {'A2', 4}, {'A#2', 4}, {'A#2', 4}, {'C3', 4}, {'C3', 4},
                    {'F2', 4}, {'F2', 4}, {'C3', 4}, {'C3', 4}, {'G2', 4}, {'G2', 4}, {'A2', 4}, {'A2', 4},
                    {'C3', 4}, {'C3', 4}, {'G2', 4}, {'G2', 4}, {'D3', 4}, {'D3', 4}, {'A2', 4}, {'A2', 4},
                    {'A#2', 4}, {'A#2', 4}, {'F2', 4}, {'F2', 4}, {'C3', 4}, {'C3', 4}, {'D3', 4}, {'D3', 4},
                    {'D3', 4}, {'D3', 4}, {'A2', 4}, {'A2', 4}, {'G2', 4}, {'G2', 4}, {'D3', 8}, {'R', 8},
                }
            },
        }
    },

    -- Peaceful village / town
    village = {
        stepDuration = 0.13,
        baseVol = 0.024,
        voices = {
            {
                wave = "pulse", duty = 0.5, vol = 0.48,
                melody = {
                    {'G4', 6}, {'A4', 2}, {'B4', 8}, {'D5', 4}, {'C5', 4}, {'B4', 8},
                    {'A4', 4}, {'G4', 4}, {'F#4', 8}, {'E4', 4}, {'F#4', 4}, {'G4', 8},
                    {'B4', 6}, {'A4', 2}, {'G4', 8}, {'E4', 4}, {'F#4', 4}, {'G4', 8},
                    {'A4', 4}, {'B4', 4}, {'D5', 8}, {'C5', 4}, {'B4', 4}, {'A4', 8},
                    -- Bridge
                    {'E5', 4}, {'D5', 4}, {'C5', 4}, {'B4', 4}, {'A4', 8}, {'G4', 8},
                    {'F#4', 4}, {'G4', 4}, {'A4', 8}, {'B4', 4}, {'A4', 4}, {'G4', 16},
                    -- Return
                    {'G4', 6}, {'A4', 2}, {'B4', 8}, {'D5', 6}, {'E5', 2}, {'D5', 8},
                    {'C5', 4}, {'B4', 4}, {'A4', 4}, {'G4', 4}, {'F#4', 8}, {'G4', 16},
                }
            },
            {
                wave = "pulse", duty = 0.25, vol = 0.22,
                melody = {
                    {'D4', 8}, {'G4', 8}, {'B4', 8}, {'G4', 8},
                    {'C4', 8}, {'E4', 8}, {'A4', 8}, {'E4', 8},
                    {'D4', 8}, {'G4', 8}, {'B4', 8}, {'D5', 8},
                    {'E4', 8}, {'A4', 8}, {'C5', 8}, {'A4', 8},
                    {'G4', 8}, {'E4', 8}, {'C4', 8}, {'E4', 8},
                    {'D4', 8}, {'F#4', 8}, {'A4', 8}, {'D4', 8},
                    {'D4', 8}, {'G4', 8}, {'B4', 8}, {'G4', 8},
                    {'E4', 8}, {'A4', 8}, {'D4', 8}, {'G4', 16},
                }
            },
            {
                wave = "triangle", vol = 0.36,
                melody = {
                    {'G2', 8}, {'G2', 8}, {'D3', 8}, {'D3', 8},
                    {'C3', 8}, {'C3', 8}, {'A2', 8}, {'A2', 8},
                    {'G2', 8}, {'G2', 8}, {'E2', 8}, {'E2', 8},
                    {'A2', 8}, {'A2', 8}, {'D3', 8}, {'D3', 8},
                    {'C3', 8}, {'C3', 8}, {'A2', 8}, {'A2', 8},
                    {'D3', 8}, {'D3', 8}, {'G2', 16},
                    {'G2', 8}, {'G2', 8}, {'D3', 8}, {'D3', 8},
                    {'C3', 8}, {'A2', 8}, {'D3', 8}, {'G2', 16},
                }
            },
        }
    },

    -- Storm / dungeon urgency
    tempest = {
        stepDuration = 0.11,
        baseVol = 0.026,
        voices = {
            {
                wave = "pulse", duty = 0.25, vol = 0.50,
                melody = {
                    {'A3', 4}, {'C4', 4}, {'E4', 4}, {'A4', 4}, {'G4', 4}, {'E4', 4}, {'C4', 4}, {'A3', 4},
                    {'A#3', 4}, {'D4', 4}, {'F4', 4}, {'A#4', 4}, {'A4', 4}, {'F4', 4}, {'D4', 4}, {'A#3', 4},
                    {'A3', 4}, {'C4', 4}, {'E4', 4}, {'A4', 4}, {'C5', 4}, {'A4', 4}, {'E4', 4}, {'C4', 4},
                    {'G4', 6}, {'F4', 2}, {'E4', 4}, {'D4', 4}, {'C4', 8}, {'A3', 8},
                    -- Climb
                    {'E4', 2}, {'F4', 2}, {'G4', 2}, {'A4', 2}, {'A#4', 4}, {'A4', 4}, {'G4', 8},
                    {'F4', 4}, {'E4', 4}, {'D4', 4}, {'C4', 4}, {'A#3', 8}, {'A3', 8},
                    {'A3', 4}, {'C4', 4}, {'E4', 4}, {'G4', 4}, {'A4', 8}, {'G4', 4}, {'E4', 4},
                    {'F4', 4}, {'E4', 4}, {'D4', 4}, {'C4', 4}, {'A3', 16},
                }
            },
            {
                wave = "pulse", duty = 0.5, vol = 0.22,
                melody = {
                    {'E3', 8}, {'A3', 8}, {'C4', 8}, {'A3', 8},
                    {'F3', 8}, {'A#3', 8}, {'D4', 8}, {'A#3', 8},
                    {'E3', 8}, {'A3', 8}, {'C4', 8}, {'E4', 8},
                    {'D4', 8}, {'C4', 8}, {'A3', 8}, {'E3', 8},
                    {'G3', 8}, {'A#3', 8}, {'D4', 8}, {'A#3', 8},
                    {'F3', 8}, {'A3', 8}, {'C4', 8}, {'A3', 8},
                    {'E3', 8}, {'A3', 8}, {'C4', 8}, {'E4', 8},
                    {'D4', 8}, {'C4', 8}, {'A3', 16},
                }
            },
            {
                wave = "triangle", vol = 0.42,
                melody = {
                    {'A2', 4}, {'A2', 4}, {'A2', 4}, {'E2', 4}, {'A2', 4}, {'A2', 4}, {'A2', 4}, {'E2', 4},
                    {'A#2', 4}, {'A#2', 4}, {'A#2', 4}, {'F2', 4}, {'A#2', 4}, {'A#2', 4}, {'A#2', 4}, {'F2', 4},
                    {'A2', 4}, {'A2', 4}, {'A2', 4}, {'E2', 4}, {'C3', 4}, {'C3', 4}, {'A2', 4}, {'E2', 4},
                    {'G2', 4}, {'G2', 4}, {'F2', 4}, {'F2', 4}, {'E2', 8}, {'A2', 8},
                    {'G2', 4}, {'G2', 4}, {'A#2', 4}, {'A#2', 4}, {'A2', 4}, {'A2', 4}, {'E2', 4}, {'E2', 4},
                    {'F2', 4}, {'F2', 4}, {'D2', 4}, {'D2', 4}, {'A#2', 8}, {'A2', 8},
                    {'A2', 4}, {'A2', 4}, {'E2', 4}, {'E2', 4}, {'A2', 4}, {'A2', 4}, {'C3', 4}, {'C3', 4},
                    {'D3', 4}, {'C3', 4}, {'A#2', 4}, {'G2', 4}, {'A2', 16},
                }
            },
        }
    },

    -- Forest grove (6/8 lilt feel via grouping)
    grove = {
        stepDuration = 0.115,
        baseVol = 0.024,
        voices = {
            {
                wave = "pulse", duty = 0.5, vol = 0.48,
                melody = {
                    {'E4', 4}, {'F#4', 2}, {'G4', 6}, {'B4', 4}, {'A4', 4}, {'G4', 8},
                    {'E4', 4}, {'F#4', 2}, {'G4', 6}, {'D5', 4}, {'C5', 4}, {'B4', 8},
                    {'A4', 4}, {'G4', 4}, {'F#4', 4}, {'D4', 4}, {'E4', 8}, {'G4', 8},
                    {'A4', 4}, {'B4', 4}, {'D5', 8}, {'C5', 4}, {'B4', 4}, {'A4', 8},
                    {'G4', 6}, {'A4', 2}, {'B4', 8}, {'E5', 4}, {'D5', 4}, {'B4', 8},
                    {'A4', 4}, {'G4', 4}, {'F#4', 8}, {'E4', 4}, {'D4', 4}, {'E4', 16},
                    {'E4', 4}, {'G4', 4}, {'B4', 8}, {'A4', 4}, {'F#4', 4}, {'G4', 8},
                    {'E4', 4}, {'D4', 4}, {'B3', 4}, {'D4', 4}, {'E4', 16}, {'R', 8},
                }
            },
            {
                wave = "pulse", duty = 0.25, vol = 0.20,
                melody = {
                    {'B3', 8}, {'E4', 8}, {'G4', 8}, {'E4', 8},
                    {'A3', 8}, {'D4', 8}, {'F#4', 8}, {'D4', 8},
                    {'G3', 8}, {'B3', 8}, {'E4', 8}, {'B3', 8},
                    {'A3', 8}, {'D4', 8}, {'F#4', 8}, {'A4', 8},
                    {'E4', 8}, {'G4', 8}, {'B4', 8}, {'G4', 8},
                    {'D4', 8}, {'F#4', 8}, {'A4', 8}, {'E4', 8},
                    {'B3', 8}, {'E4', 8}, {'G4', 8}, {'D4', 8},
                    {'B3', 8}, {'A3', 8}, {'G3', 8}, {'E3', 16},
                }
            },
            {
                wave = "triangle", vol = 0.34,
                melody = {
                    {'E3', 8}, {'E3', 8}, {'B2', 8}, {'B2', 8},
                    {'A2', 8}, {'A2', 8}, {'D3', 8}, {'D3', 8},
                    {'G2', 8}, {'G2', 8}, {'E3', 8}, {'E3', 8},
                    {'A2', 8}, {'A2', 8}, {'D3', 8}, {'D3', 8},
                    {'E3', 8}, {'E3', 8}, {'G2', 8}, {'G2', 8},
                    {'D3', 8}, {'D3', 8}, {'E3', 16},
                    {'E3', 8}, {'B2', 8}, {'A2', 8}, {'D3', 8},
                    {'E3', 8}, {'B2', 8}, {'E2', 16}, {'R', 8},
                }
            },
        }
    },

    -- Magical sparkle / fairy fountain energy
    sparkle = {
        stepDuration = 0.10,
        baseVol = 0.022,
        voices = {
            {
                wave = "pulse", duty = 0.125, vol = 0.42,
                melody = {
                    {'C5', 2}, {'E5', 2}, {'G5', 2}, {'B5', 2}, {'C6', 2}, {'B5', 2}, {'G5', 2}, {'E5', 2},
                    {'A4', 2}, {'C5', 2}, {'E5', 2}, {'G5', 2}, {'A5', 2}, {'G5', 2}, {'E5', 2}, {'C5', 2},
                    {'F4', 2}, {'A4', 2}, {'C5', 2}, {'E5', 2}, {'F5', 2}, {'E5', 2}, {'C5', 2}, {'A4', 2},
                    {'G4', 2}, {'B4', 2}, {'D5', 2}, {'F5', 2}, {'G5', 2}, {'F5', 2}, {'D5', 2}, {'B4', 2},
                    -- Melody lift
                    {'E5', 4}, {'G5', 4}, {'B5', 4}, {'G5', 4}, {'A5', 4}, {'E5', 4}, {'C5', 8},
                    {'D5', 4}, {'F5', 4}, {'A5', 4}, {'F5', 4}, {'G5', 4}, {'D5', 4}, {'B4', 8},
                    {'C5', 2}, {'E5', 2}, {'G5', 2}, {'C6', 2}, {'B5', 4}, {'G5', 4}, {'E5', 8},
                    {'A4', 2}, {'C5', 2}, {'E5', 2}, {'A5', 2}, {'G5', 4}, {'E5', 4}, {'C5', 16},
                }
            },
            {
                wave = "pulse", duty = 0.5, vol = 0.18,
                melody = {
                    {'C4', 8}, {'G4', 8}, {'E4', 8}, {'G4', 8},
                    {'A3', 8}, {'E4', 8}, {'C4', 8}, {'E4', 8},
                    {'F3', 8}, {'C4', 8}, {'A3', 8}, {'C4', 8},
                    {'G3', 8}, {'D4', 8}, {'B3', 8}, {'D4', 8},
                    {'E4', 8}, {'B4', 8}, {'A4', 8}, {'E4', 8},
                    {'D4', 8}, {'A4', 8}, {'G4', 8}, {'D4', 8},
                    {'C4', 8}, {'G4', 8}, {'E4', 8}, {'G4', 8},
                    {'A3', 8}, {'E4', 8}, {'C4', 16},
                }
            },
            {
                wave = "triangle", vol = 0.28,
                melody = {
                    {'C3', 8}, {'C3', 8}, {'G2', 8}, {'G2', 8},
                    {'A2', 8}, {'A2', 8}, {'E2', 8}, {'E2', 8},
                    {'F2', 8}, {'F2', 8}, {'C3', 8}, {'C3', 8},
                    {'G2', 8}, {'G2', 8}, {'D3', 8}, {'D3', 8},
                    {'E3', 8}, {'E3', 8}, {'A2', 8}, {'A2', 8},
                    {'D3', 8}, {'D3', 8}, {'G2', 8}, {'G2', 8},
                    {'C3', 8}, {'C3', 8}, {'G2', 8}, {'G2', 8},
                    {'A2', 8}, {'E2', 8}, {'C3', 16},
                }
            },
        }
    },

    -- Open plains / pastoral
    plains = {
        stepDuration = 0.135,
        baseVol = 0.024,
        voices = {
            {
                wave = "pulse", duty = 0.5, vol = 0.48,
                melody = {
                    {'A4', 8}, {'G4', 4}, {'F4', 4}, {'E4', 8}, {'D4', 8},
                    {'A4', 8}, {'G4', 4}, {'F4', 4}, {'E4', 16},
                    {'D4', 4}, {'E4', 4}, {'F4', 4}, {'G4', 4}, {'A4', 8}, {'C5', 8},
                    {'A4', 4}, {'G4', 4}, {'F4', 4}, {'E4', 4}, {'D4', 16},
                    -- Chorus
                    {'F4', 4}, {'A4', 4}, {'C5', 8}, {'D5', 4}, {'C5', 4}, {'A4', 8},
                    {'G4', 4}, {'A4', 4}, {'A#4', 8}, {'A4', 4}, {'G4', 4}, {'F4', 8},
                    {'E4', 4}, {'F4', 4}, {'G4', 8}, {'A4', 4}, {'G4', 4}, {'F4', 8},
                    {'E4', 4}, {'D4', 4}, {'C4', 4}, {'E4', 4}, {'D4', 16}, {'R', 8},
                }
            },
            {
                wave = "pulse", duty = 0.25, vol = 0.22,
                melody = {
                    {'F3', 8}, {'A3', 8}, {'C4', 8}, {'A3', 8},
                    {'E3', 8}, {'G3', 8}, {'C4', 8}, {'G3', 8},
                    {'D3', 8}, {'F3', 8}, {'A3', 8}, {'C4', 8},
                    {'A3', 8}, {'G3', 8}, {'F3', 8}, {'D3', 8},
                    {'F3', 8}, {'A3', 8}, {'C4', 8}, {'F4', 8},
                    {'G3', 8}, {'A#3', 8}, {'D4', 8}, {'A#3', 8},
                    {'A3', 8}, {'C4', 8}, {'E4', 8}, {'C4', 8},
                    {'A3', 8}, {'G3', 8}, {'F3', 16},
                }
            },
            {
                wave = "triangle", vol = 0.36,
                melody = {
                    {'D3', 8}, {'D3', 8}, {'A2', 8}, {'A2', 8},
                    {'C3', 8}, {'C3', 8}, {'G2', 8}, {'G2', 8},
                    {'A#2', 8}, {'A#2', 8}, {'F2', 8}, {'F2', 8},
                    {'C3', 8}, {'C3', 8}, {'D3', 16},
                    {'F2', 8}, {'F2', 8}, {'A2', 8}, {'A2', 8},
                    {'G2', 8}, {'G2', 8}, {'A#2', 8}, {'A#2', 8},
                    {'A2', 8}, {'A2', 8}, {'C3', 8}, {'C3', 8},
                    {'D3', 8}, {'A2', 8}, {'D3', 16},
                }
            },
        }
    },
}

---------------------------------------------------------------------------
-- Synthesis
---------------------------------------------------------------------------
local function waveSample(wave, phase, duty)
    local t = phase % (2 * math.pi)
    local n = t / (2 * math.pi)
    if wave == "triangle" then
        if n < 0.5 then
            return n * 4 - 1
        end
        return 3 - n * 4
    elseif wave == "pulse" then
        duty = duty or 0.5
        return n < duty and 1 or -1
    else -- square
        return math.sin(phase) > 0 and 1 or -1
    end
end

local function noteEnvelope(i, length, rate)
    local attack = math.floor(rate * 0.008)
    local release = math.floor(rate * 0.035)
    local v = 1
    if i < attack then
        v = i / math.max(1, attack)
    elseif i > length - release then
        v = math.max(0, (length - i) / math.max(1, release))
    else
        -- Soft decay toward sustain
        local sustain = 0.78
        local decayLen = math.floor(rate * 0.08)
        if i < attack + decayLen then
            local t = (i - attack) / math.max(1, decayLen)
            v = 1 - t * (1 - sustain)
        else
            v = sustain
        end
    end
    return v
end

local function countSteps(melody)
    local total = 0
    for _, step in ipairs(melody) do
        total = total + step[2]
    end
    return total
end

local function generatePolyphonic(def)
    local rate = 44100
    local stepDuration = def.stepDuration or 0.12
    local maxSteps = 0
    for _, voice in ipairs(def.voices) do
        maxSteps = math.max(maxSteps, countSteps(voice.melody))
    end

    local totalLength = math.floor(rate * stepDuration * maxSteps)
    local soundData = love.sound.newSoundData(totalLength, rate, 16, 1)
    local mix = {}
    for i = 0, totalLength - 1 do
        mix[i] = 0
    end

    for _, voice in ipairs(def.voices) do
        local wave = voice.wave or "pulse"
        local duty = voice.duty or 0.5
        local voiceVol = voice.vol or 0.4
        local pos = 0
        local phase = 0

        for _, step in ipairs(voice.melody) do
            local freq = NOTES[step[1]] or 0
            local length = math.floor(rate * stepDuration * step[2])
            for i = 0, length - 1 do
                if pos + i >= totalLength then break end
                if freq > 0 then
                    phase = phase + (freq * 2 * math.pi / rate)
                    local env = noteEnvelope(i, length, rate)
                    mix[pos + i] = mix[pos + i] + waveSample(wave, phase, duty) * voiceVol * env
                end
            end
            pos = pos + length
            -- Soft reset phase between notes for cleaner attacks
            if freq == 0 then phase = 0 end
        end
    end

    -- Soft peak normalize + gentle master gain
    local peak = 0.0001
    for i = 0, totalLength - 1 do
        local a = math.abs(mix[i])
        if a > peak then peak = a end
    end
    local gain = 0.72 / peak
    for i = 0, totalLength - 1 do
        local s = mix[i] * gain
        if s > 1 then s = 1 elseif s < -1 then s = -1 end
        soundData:setSample(i, s)
    end

    return love.audio.newSource(soundData, "static")
end

local function generateSquareWave(freq, duration, volume, decay)
    local rate = 44100
    local length = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(length, rate, 16, 1)
    local phase = 0
    for i = 0, length - 1 do
        local v = volume or 0.1
        if decay then
            v = v * (1 - i / length)
        end
        phase = phase + (freq * 2 * math.pi / rate)
        local sample = math.sin(phase) > 0 and v or -v
        soundData:setSample(i, sample)
    end
    return love.audio.newSource(soundData, "static")
end

local function generateDing(freqs, duration, volume)
    local rate = 44100
    local length = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(length, rate, 16, 1)
    local phase = 0
    local numFreqs = #freqs
    for i = 0, length - 1 do
        local v = (volume or 0.1) * (1 - i / length)
        local freqIdx = math.min(math.floor((i / length) * numFreqs) + 1, numFreqs)
        phase = phase + (freqs[freqIdx] * 2 * math.pi / rate)
        local sample = math.sin(phase) > 0 and v or -v
        soundData:setSample(i, sample)
    end
    return love.audio.newSource(soundData, "static")
end

local function generateMelody(melody, stepDuration, volume)
    return generatePolyphonic({
        stepDuration = stepDuration,
        voices = {{ wave = "square", vol = volume or 0.05, melody = melody }}
    })
end

local function ensureSound(self, name)
    if self._soundsGenerated[name] then return end
    local def = SOUND_DEFS[name]
    if not def then return end
    self.baseVolumes[name] = def.baseVol
    if def.type == "square" then
        self.sounds[name] = generateSquareWave(def.freq, def.duration, def.volume, def.decay)
    elseif def.type == "ding" then
        self.sounds[name] = generateDing(def.freqs, def.duration, def.volume)
    elseif def.type == "melody" then
        self.sounds[name] = generateMelody(def.melody, def.stepDuration, def.volume)
    end
    self._soundsGenerated[name] = true
end

local function ensureMusic(self, name)
    if self._musicGenerated[name] then return end
    local def = MUSIC_DEFS[name]
    if not def then return end
    self.baseVolumes[name] = def.baseVol
    self.music[name] = generatePolyphonic(def)
    self.music[name]:setLooping(true)
    self._musicGenerated[name] = true
end

function Audio:init()
    self.gameTracks = {'legend', 'village', 'tempest', 'grove', 'sparkle', 'plains'}
    self._initialized = true
    -- Warm the menu theme so first listen isn't a hitch
    ensureMusic(self, 'menu')
end

function Audio:play(name)
    ensureSound(self, name)
    if self.sounds[name] then
        local s = self.sounds[name]
        if name == 'move' or name == 'rotate' then
            s = self.sounds[name]:clone()
        else
            s:stop()
        end
        s:setVolume(self.sfxVolume * (self.baseVolumes[name] or 1))
        s:play()
    end
end

function Audio:playMusic(name)
    ensureMusic(self, name)
    if self.music[name] then
        if self.currentMusicName == name then return end
        if self.currentMusic then
            self.currentMusic:stop()
        end
        self.currentMusic = self.music[name]
        self.currentMusicName = name
        self.currentMusic:setVolume(self.musicVolume * (self.baseVolumes[name] or 1))
        self.currentMusic:play()
    end
end

function Audio:playRandomGameMusic()
    local track = self.gameTracks[love.math.random(#self.gameTracks)]
    self:playMusic(track)
end

function Audio:setSFXVolume(v)
    self.sfxVolume = v
end

function Audio:setMusicVolume(v)
    self.musicVolume = v
    if self.currentMusic and self.currentMusicName then
        local baseVol = self.baseVolumes[self.currentMusicName] or 1
        self.currentMusic:setVolume(self.musicVolume * baseVol)
    end
end

function Audio:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.currentMusic = nil
        self.currentMusicName = nil
    end
end

function Audio:pauseMusic()
    if self.currentMusic then
        self.currentMusic:pause()
    end
end

function Audio:resumeMusic()
    if self.currentMusic then
        self.currentMusic:play()
    end
end

return Audio
