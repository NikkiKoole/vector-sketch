palettes = {}

pindex = nil
local base1 = {

    '000000', '000000', '000000', '000000', '000000',


}
--'efebd8',
local base2 = {
    '020202',
    '4f3166', '69445D', '613D41', '6f323a', '872f44', '8d184c', 'be193b', 'd2453a', 'd6642f', 'd98524',
    'dca941', 'e6c800', 'f8df00', 'ddc340', 'dbd054', 'ddc490', 'ded29c', 'dad3bf', '9c9d9f',
    '938541', '808b1c', '8A934E', '86a542', '57843d', '45783c', '2a5b3e', '1b4141', '1e294b', '0d5f7f', '065966',
    '1b9079', '3ca37d', '49abac', '5cafc9', '159cb3', '1d80af', '2974a5', '1469a3', '045b9f',
    '9377b2', '686094', '5f4769', '815562', '6e5358', '493e3f', '4a443c', '7c3f37', 'a93d34', 'CB433A', 'a95c42',
    'c37c61', 'd19150', 'de9832', 'bd7a3e', '865d3e', '706140', '7e6f53', '948465',
    '252f38', '42505f', '465059', '57595a', '6e7c8c', '75899c', 'aabdce', '807b7b',
    '857b7e', '8d7e8a', 'b38e91', 'a2958d', 'd2a88d', 'ceb18c', 'cf9267', 'f0644d', 'ff7376', 'd76656', 'b16890',
    '020202', '333233', '814800', 'efebd8',
    '1a5f8f', '66a5bc', '87727b', 'a23d7e',
    'fa8a00', 'fef1d0',
    'ffa8a2', '6e614c', '418090', 'b5d9a4', 'c0b99e',
    '4D391F', '4B6868', '9F7344', '9D7630', 'D3C281',
    '8F4839', 'EEC488',
    'C77D52', 'C2997A', '9C5F43', '9C8D81', '965D64',
    '798091', '4C5575', '6E4431', '626964',

}


function hex2rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber("0x" .. hex:sub(1, 2)) / 255, tonumber("0x" .. hex:sub(3, 4)) / 255,
        tonumber("0x" .. hex:sub(5, 6))
        / 255
end

for i = 1, #base1 do
    local r, g, b = hex2rgb(base1[i])
    table.insert(palettes, { r, g, b, base1[i] })
end

for i = 1, #base2 do
    local r, g, b = hex2rgb(base2[i])
    table.insert(palettes, { r, g, b, base2[i] })
end

function love.mousemoved(x, y)
    local size = 32
    local xindex = math.floor(x / size)
    local yindex = math.floor(y / size)
    local index = (yindex * 16) + xindex
    if index > 0 and index <= #palettes then
        print(palettes[index][4])
        pindex = palettes[index][4]
    end
end

function love.draw()
    local size = 32
    for i = 1, #palettes do
        love.graphics.setColor(palettes[i][1], palettes[i][2], palettes[i][3])
        love.graphics.rectangle('fill', (i % 16) * size, math.floor(i / 16) * size, size, size)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(i, (i % 16) * size, math.floor(i / 16) * size)
    end
    love.graphics.setColor(1, 1, 1)
    if pindex then
        love.graphics.print(pindex, 0, 500)
    end
end

function love.keypressed(k)
    if (k == 'escape') then love.event.quit() end
end
