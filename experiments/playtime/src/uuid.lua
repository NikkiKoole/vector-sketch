--uuid.lua



-- IDs must differ ACROSS sessions. Don't use the global love.math.random
-- here: game-loop.lua seeds it to a constant (123456) for deterministic
-- replay, so every session generated the exact same id sequence. (The old
-- math.randomseed call seeded the wrong RNG and protected nothing.)
-- A private generator keeps ids random without breaking replay determinism.
local rng = love.math.newRandomGenerator(os.time() * 1000 + math.floor((os.clock() % 1) * 1000))
local function random(a, b) return rng:random(a, b) end

local lib = {}
require 'string'
local registry = require 'src.registry'

-- Base62 character set
local base62_chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
-- Function to encode a number into Base62
function lib.base62_encode(num)
    local result = ""
    local base = 62
    repeat
        local remainder = num % base
        result = string.sub(base62_chars, remainder + 1, remainder + 1) .. result
        num = math.floor(num / base)
    until num == 0
    return result
end

function lib.uuid32_base62()
    local num = random(0, 0xffffffff) -- Generate a 32-bit random integer
    return lib.base62_encode(num)
end

function lib.uuid()
    return lib.uuid32_base62() -- 32 bits can clash: generateID checks the registry
end

function lib.generateID()
    local newID = lib.uuid()
    while registry.taken(newID) do
        newID = lib.uuid()
    end
    return newID
end

return lib
