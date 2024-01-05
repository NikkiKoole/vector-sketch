local function randInt(max)
    return math.ceil(love.math.random() * max)
end

local function randElement(array, maxLength)
    return array[randInt(maxLength or #array)]
end

local function lengthsLookup(version)
    if version == 1 then
        return { 3, 3, 3 }
    end
    if version == 2 then
        return { 10, 10, 10 }
    end
end

function getResults(values, seed, version)
    love.math.setRandomSeed(seed)
    local lengths = lengthsLookup(version)

    print(
        randElement(values.first, lengths[1]),
        randElement(values.second, lengths[2]),
        randElement(values.third, lengths[3])
    )
end

local function decToHex(value)
    return string.format("%x", value)
end
local function hexToDecimal(hexString)
    return tonumber(hexString, 16)
end

function love.load()
    local seed = 121212
    local values = {
        first = { 1, 2, 3 },
        second = { 1, 2, 3 },
        third = { 1, 2, 3 }
    }
    getResults(values, seed, 1)

    for i = 4, 10 do
        table.insert(values.first, i)
        table.insert(values.second, i)
        table.insert(values.third, i)
    end

    getResults(values, seed, 1)

    print(decToHex(seed))
    print(hexToDecimal(decToHex(seed)))
    -- print(enc('1123212'))
    -- print(dec('MTEyMzIxMg=='))
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
end
