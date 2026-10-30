-- color.lua
-- Colours as the editor and the renderer use them: hex strings ('rrggbb' or 'rrggbbaa',
-- '#' and the short forms allowed) and the editor's palette.
local lib = {}

lib.palette = {
    '020202', '4f3166', '69445D', '613D41', 'efebd8',
    '6f323a', '872f44', '8d184c', 'be193b', 'd2453a',
    'd6642f', 'd98524', 'dca941', 'e6c800', 'f8df00',
    'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf',
    '9c9d9f', '938541', '808b1c', '8A934E', '86a542',
    '57843d', '45783c', '2a5b3e', '1b4141', '1e294b',
    '0d5f7f', '065966', '1b9079', '3ca37d', '49abac',
    '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3',
    '045b9f', '9377b2', '686094', '5f4769', '815562',
    '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34',
    'CB433A', 'a95c42', 'c37c61', 'd19150', 'de9832',
    'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c',
    '75899c', 'aabdce', '807b7b', '857b7e', '8d7e8a',
    'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267',
    'f0644d', 'ff7376', 'd76656', 'b16890', '020202',
    '333233', '814800', 'efebd8', '1a5f8f', '66a5bc',
    '87727b', 'a23d7e', 'fa8a00', 'fef1d0', 'ffa8a2',
    '6e614c', '418090', 'b5d9a4', 'c0b99e', '4D391F',
    '4B6868', '9F7344', '9D7630', 'D3C281', '8F4839',
    'EEC488', 'C77D52', 'C2997A', '9C5F43', '9C8D81',
    '965D64', '798091', '4C5575', '6E4431', '626964',
}

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

-- hex -> r, g, b, a (0..1); white when it can't be read. Remembered: the renderer asks for
-- the same few colours for every drawable, every frame.
local parsed = {}
function lib.hexToColor(hex)
    if type(hex) ~= 'string' then return 1, 1, 1, 1 end
    local c = parsed[hex]
    if not c then
        c = { parse(hex) }
        parsed[hex] = c
    end
    return c[1], c[2], c[3], c[4]
end

return lib
