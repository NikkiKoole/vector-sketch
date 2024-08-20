--https://pico-8.fandom.com/wiki/Palette

palette = {
    { 0,   0,   0 },
    { 29,  43,  83 },
    { 126, 37,  83 },
    { 0,   135, 81 },
    { 171, 82,  54 },
    { 95,  87,  79 },
    { 194, 195, 199 },
    { 255, 241, 232 },
    { 255, 0,   77 },
    { 255, 163, 0 },
    { 255, 236, 39 },
    { 0,   228, 54 },
    { 41,  173, 255 },
    { 131, 118, 156 },
    { 255, 119, 168 },
    { 255, 204, 170 },
    --
    { 41,  24,  20 },
    { 17,  29,  53 },
    { 66,  33,  54 },
    { 18,  83,  89 },
    { 116, 47,  41 },
    { 73,  51,  59 },
    { 162, 136, 121 },
    { 243, 239, 125 },
    { 190, 18,  80 },
    { 255, 108, 36 },
    { 168, 231, 46 },
    { 0,   181, 67 },
    { 6,   90,  181 },
    { 117, 70,  101 },
    { 255, 110, 89 },
    { 255, 157, 129 },
}

colors = {
    -- basic 16 pico colors
    ['black'] = 1,
    ['dark-blue'] = 2,
    ['dark-purple'] = 3,
    ['dark-green'] = 4,
    ['brown'] = 5,
    ['dark-grey'] = 6,
    ['light-grey'] = 7,
    ['white'] = 8,
    ['red'] = 9,
    ['orange'] = 10,
    ['yellow'] = 11,
    ['green'] = 12,
    ['blue'] = 13,
    ['lavender'] = 14,
    ['pink'] = 15,
    ['light-peach'] = 16,
    -- extended 16 other colors
    ['brownish-black'] = 17,
    ['darker-blue'] = 18,
    ['darker-purple'] = 19,
    ['blue-green'] = 20,
    ['dark-brown'] = 21,
    ['darker-grey'] = 22,
    ['medium-grey'] = 23,
    ['light-yellow'] = 24,
    ['dark-red'] = 25,
    ['dark-orange'] = 26,
    ['lime-green'] = 27,
    ['medium-green'] = 28,
    ['true-blue'] = 29,
    ['mauve'] = 30,
    ['dark-peach'] = 31,
    ['peach'] = 32
}

for i = 1, #palette do
    palette[i] = { palette[i][1] / 255, palette[i][2] / 255, palette[i][3] / 255 }
end

fromIndex = function(index)
    local data = palette[index]
    return unpack(data)
end

fromName = function(name)
    local index = colors[name]
    local data = palette[index]
    return unpack(data)
end
