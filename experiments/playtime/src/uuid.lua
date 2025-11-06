--uuid.lua



-- very important keep this on, ids will start clashing otherwise since we will be generating the SAME 'random' numbers
math.randomseed(love.timer.getTime())
local random = love.math.random

local lib = {}
require 'string'
require 'src.registry'

function lib.uuid128()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end))
end

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

-- Example: Encode a random 64-bit number
function lib.uuid64_base62()
    -- Generate a random 64-bit integer
    local num = random(0, 0xffffffff) * 0x100000000 + random(0, 0xffffffff)
    return lib.base62_encode(num)
end

function lib.uuid128_base62()
    return lib.uuid64_base62() .. lib.uuid64_base62()
end

function lib.uuid32_base62()
    local num = random(0, 0xffffffff) -- Generate a 32-bit random integer
    return lib.base62_encode(num)
end

function lib.uuid()
    return lib.uuid32_base62() -- does this clash?>?>?? anser: YES
    --return lib.uuid64_base62()
    --return lib.uuid128_base62()
    --return string.guid()
end

function lib.generateID()
    local newID = lib.uuid()
    while registry.taken(newID) do
        newID = lib.uuid()
    end
    return newID
end

return lib
