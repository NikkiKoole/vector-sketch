-- A hair lock's strip laid in C (native/desound/hair.c via src/hair-native.lua) and in Lua
-- (src/hair-locks.lua's lockPath + stripMesh) come out the same: the game draws whichever is there.
if not love then return end

local hairLocks = require('src.hair-locks')
local hairNative = require('src.hair-native')

-- A lock of `n` points `segment` apart, waving sideways as it falls (a bent one turns sharply).
local function lock(n, segment, bend, phase, wave)
    local points, x, y, a = {}, 0, 0, math.pi / 2
    for i = 1, n do
        points[2 * i - 1], points[2 * i] = x, y
        a = a + bend * math.sin(i * 0.9)
        x, y = x + math.cos(a) * segment, y + math.sin(a) * segment
    end
    return { points = points, n = n, segment = segment, phase = phase, width = 0.06, wave = wave or 0 }
end

local function nativeVertices(l, o, hw)
    local data = love.data.newByteData(hairNative.MAX_SAMPLES * 2 * hairNative.BYTES_PER_VERTEX)
    local count = hairNative.strip(l.points, l.n, l.segment, o.ringlets, o.ringletPitch, l.wave or 0,
        l.segment * 5, l.phase, 0.5, hw, data)
    local f = require('ffi').cast('float *', data:getFFIPointer())
    local out = {}
    for i = 1, count do
        local v = {}
        for k = 1, 8 do v[k] = f[(i - 1) * 8 + k - 1] end
        out[i] = v
    end
    return out
end

local CASES = {
    { name = 'straight', lock = lock(10, 24, 0, 0), o = { ringlets = 0, ringletPitch = 30 } },
    { name = 'curled', lock = lock(16, 24, 0.6, 0), o = { ringlets = 0, ringletPitch = 30 } },
    { name = 'loose ringlets', lock = lock(12, 24, 0.1, 1.3), o = { ringlets = 18, ringletPitch = 50 } },
    { name = 'tight ringlets', lock = lock(16, 24, 0.2, 4.0), o = { ringlets = 12, ringletPitch = 26 } },
    { name = 'two points', lock = lock(2, 20, 0, 0), o = { ringlets = 0, ringletPitch = 30 } },
    { name = 'curly wave', lock = lock(16, 24, 0.1, 2.0, 16), o = { ringlets = 0, ringletPitch = 30 } },
    { name = 'wave and ringlets', lock = lock(12, 24, 0.1, 0.4, 8), o = { ringlets = 14, ringletPitch = 40 } },
}

describe('hair lock strips, C and Lua', function()
    for _, case in ipairs(CASES) do
        it('match: ' .. case.name, function()
            if not hairNative.available() then
                pending('no native/desound/libdesound.dylib with hair_strip (native/desound/build.sh)')
                return
            end
            local hw = 139 * case.lock.width
            local fromLua = hairLocks.luaStripVertices(case.lock, case.o, hw)
            local fromC = nativeVertices(case.lock, case.o, hw)
            assert.are.equal(#fromLua, #fromC)
            local worst = 0
            for i = 1, #fromLua do
                for k = 1, 8 do worst = math.max(worst, math.abs(fromLua[i][k] - fromC[i][k])) end
            end
            assert.is_true(worst < 1e-3, 'largest difference ' .. worst)
        end)
    end

    it('a ringlet turn gets ~10 samples, a straight lock one a segment', function()
        if not hairNative.available() then pending('no hair_strip in the library') return end
        local straight = nativeVertices(lock(10, 24, 0, 0), { ringlets = 0, ringletPitch = 30 }, 4)
        assert.are.equal(10 * 2, #straight)
        local ring = nativeVertices(lock(10, 24, 0, 0), { ringlets = 12, ringletPitch = 24 }, 4)
        assert.are.equal((9 * 10 + 1) * 2, #ring)
    end)
end)
