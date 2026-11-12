-- color.lua
-- Colours as the editor and the renderer use them: hex strings ('rrggbb' or 'rrggbbaa',
-- '#' and the short forms allowed) and the editor's palette.
local lib = {}

-- The editor's palette (src/ui/palette.lua), one row per family of colours, each light to dark.
-- Pictures and scenes keep the hex itself, never a place in this list, so it can be reordered.
lib.paletteRows = {
    { -- greys
        '9c9d9f', 'a2958d', '8d7e8a', '857b7e', '807b7b', '87727b', '626964', '57595a', '465059', '4a443c',
        '493e3f', '333233', '252f38', '020202',
    },
    { -- reds and pinks
        'ffa8a2', 'b38e91', 'ff7376', 'f0644d', 'd76656', 'b16890', '965d64', 'd2453a', '815562', 'cb433a',
        '6e5358', 'a23d7e', '8f4839', 'a93d34', '69445d', '7c3f37', '613d41', '872f44', '6f323a', 'be193b',
        '8d184c',
    },
    { -- oranges
        'eec488', 'dca941', 'de9832', 'cf9267', 'd19150', 'fa8a00', 'd98524', 'c77d52', 'c37c61', 'bd7a3e',
        '9d7630', '9f7344', 'd6642f', 'a95c42', '814800',
    },
    { -- creams and browns
        'fef1d0', 'efebd8', 'dad3bf', 'ded29c', 'ddc490', 'd3c281', 'c0b99e', 'ceb18c', 'd2a88d', 'c2997a',
        '9c8d81', '948465', '7e6f53', '9c5f43', '865d3e', '6e614c', '706140', '6e4431', '4d391f',
    },
    { -- yellows and greens
        'f8df00', 'b5d9a4', 'dbd054', 'e6c800', 'ddc340', '86a542', '8a934e', '3ca37d', '938541', '808b1c',
        '57843d', '45783c', '2a5b3e',
    },
    { -- teals
        '5cafc9', '49abac', '159cb3', '1b9079', '418090', '4b6868', '065966', '1b4141',
    },
    { -- blues and purples
        'aabdce', '66a5bc', '75899c', '9377b2', '798091', '6e7c8c', '1d80af', '2974a5', '686094', '1469a3',
        '4c5575', '1a5f8f', '0d5f7f', '5f4769', '42505f', '045b9f', '4f3166', '1e294b',
    },
}

-- the same colours as one list
lib.palette = {}
for _, row in ipairs(lib.paletteRows) do
    for _, hex in ipairs(row) do lib.palette[#lib.palette + 1] = hex end
end

local function parse(hex)
    if type(hex) ~= "string" then
        return 1, 1, 1, 1
    end

    -- Remove any leading hash symbol.
    hex = hex:gsub("#", "")

    -- Expand shorthand forms:
    if #hex == 3 then
        -- Example: "f00" becomes "ff0000"
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
        -- Append full opacity.
        hex = hex .. "FF"
    elseif #hex == 4 then
        -- Example: "f00a" becomes "ff0000aa"
        hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2) .. hex:sub(4, 4):rep(2)
    elseif #hex == 6 then
        -- Append alpha if missing.
        hex = hex .. "FF"
    elseif #hex ~= 8 then
        return 1, 1, 1, 1
    end

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = tonumber(hex:sub(7, 8), 16)

    -- If any conversion failed, return white.
    if not (r and g and b and a) then
        return 1, 1, 1, 1
    end

    return r / 255, g / 255, b / 255, a / 255
end

-- A colour per index (bones, triangle groups): the same index always gets the same colour.
function lib.boneColor(i)
    return ((i * 97) % 256) / 255, ((i * 163) % 256) / 255, ((i * 211) % 256) / 255
end

function lib.groupColor(i)
    return ((i * 73) % 256) / 255, ((i * 151) % 256) / 255, ((i * 211) % 256) / 255
end

-- hex -> r, g, b, a (0..1); white when it can't be read. Remembered: the renderer asks for
-- the same few colours for every drawable, every frame. Up to PARSED_MAX, then started afresh:
-- every randomize brings new colours, and they were all kept.
local PARSED_MAX = 4096
local parsed, parsedCount = {}, 0
function lib.hexToColor(hex)
    if type(hex) ~= 'string' then return 1, 1, 1, 1 end
    local c = parsed[hex]
    if not c then
        if parsedCount >= PARSED_MAX then parsed, parsedCount = {}, 0 end
        c = { parse(hex) }
        parsed[hex] = c
        parsedCount = parsedCount + 1
    end
    return c[1], c[2], c[3], c[4]
end

-- The same colour a tint darker ('RRGGBBAA'): r, g and b times `factor` (default 0.75),
-- alpha kept. Eyebrows are the hair colour this much darker (mipo-randomize).
function lib.darkerHex(hex, factor)
    factor = factor or 0.75
    local r, g, b, a = parse(hex)
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return string.format('%02X%02X%02X%02X', byte(r * factor), byte(g * factor), byte(b * factor), byte(a))
end

-- for spec/color_spec.lua: how many colours are remembered
lib._test = { parsedCount = function()
    local n = 0
    for _ in pairs(parsed) do n = n + 1 end
    return n
end }

return lib
