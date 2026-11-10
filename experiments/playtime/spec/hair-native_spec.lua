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

    it('a ringlet turn gets ~10 samples, a plain lock 4 a segment', function()
        if not hairNative.available() then pending('no hair_strip in the library') return end
        local straight = nativeVertices(lock(10, 24, 0, 0), { ringlets = 0, ringletPitch = 30 }, 4)
        assert.are.equal((9 * 4 + 1) * 2, #straight)
        local ring = nativeVertices(lock(10, 24, 0, 0), { ringlets = 12, ringletPitch = 24 }, 4)
        assert.are.equal((9 * 10 + 1) * 2, #ring)
    end)
end)

-- A lock's simulation steps in C (hair.c hair_step) and in Lua (hair-locks.lua's stepLock) move it the
-- same: a head at an angle, gravity, the head's oval, the floor, springy and stiff settings.
describe('hair lock steps, C and Lua', function()
    local function newLock(n, drape)
        local points, prev, bends = {}, {}, {}
        for i = 1, n do
            points[2 * i - 1], points[2 * i] = 30 + i * 3, -20 + i * 18
            prev[2 * i - 1], prev[2 * i] = points[2 * i - 1] - 1.5, points[2 * i] - 0.5
            bends[i] = 0.1 * math.sin(i)
        end
        return { points = points, prev = prev, bends = bends, n = n, segment = 20, restAngle = 1.2,
            rx = 25, ry = -30, drape = drape }
    end
    local function copyLock(l)
        local c = {}
        for k, v in pairs(l) do c[k] = v end
        c.points, c.prev = { unpack(l.points) }, { unpack(l.prev) }
        return c
    end
    local STEP_CASES = {
        { name = 'hanging', o = { damping = 0.96, stand = 0, stiffness = 0.1, springy = 0 }, drape = true },
        { name = 'springy, stiff', o = { damping = 0.9, stand = 0.3, stiffness = 0.6, springy = 0.7 }, drape = true },
        { name = 'a bang (no drape)', o = { damping = 0.96, stand = 0, stiffness = 0.2, springy = 0.5 }, drape = false },
        { name = 'on the floor', o = { damping = 0.96, stand = 0, stiffness = 0.1, springy = 0 }, drape = true,
            ground = 160 },
    }
    for _, case in ipairs(STEP_CASES) do
        it('match: ' .. case.name, function()
            if not hairNative.stepAvailable() then
                pending('no native/desound/libdesound.dylib with hair_step (native/desound/build.sh)')
                return
            end
            local world = love.physics.newWorld(0, 0)
            local body = love.physics.newBody(world, 100, 50, 'dynamic')
            body:setAngle(0.4)
            local a, b = newLock(14, case.drape), nil
            b = copyLock(a)
            local bx, by = body:getPosition()
            for _ = 1, 20 do -- 20 frames of 2 steps
                for _ = 1, 2 do
                    hairLocks.stepLockLua(a, case.o, body, 0, 2940, 1 / 120, 45, 60, case.ground)
                end
                assert.is_true(hairNative.step(b, case.o, bx, by, body:getAngle(), 0, 2940, 1 / 120, 45, 60,
                    case.ground, 2))
            end
            local worst = 0
            for i = 1, 2 * a.n do
                worst = math.max(worst, math.abs(a.points[i] - b.points[i]), math.abs(a.prev[i] - b.prev[i]))
            end
            world:destroy()
            -- Box2D's getWorldPoint works in floats, the C in doubles
            assert.is_true(worst < 0.05, 'points differ by ' .. worst)
        end)
    end
end)

-- A whole haircut kept in C (hairNative.newCut, hair.c hair_cut_*): stepping it moves every lock as
-- stepping each lock does, and a layer's joined strip is each lock's strip with the joins between.
describe('a haircut in C', function()
    local function makeLocks()
        local locks = {}
        for k = 1, 4 do
            local n = 6 + k * 2
            local l = { n = n, segment = 18 + k, restAngle = 1 + k * 0.3, rx = -20 + k * 10, ry = -30,
                drape = k ~= 4, front = k % 2 == 0, width = 0.2, phase = k, wave = k == 3 and 8 or 0,
                ring = k == 2 and 10 or 0, ringPitch = 30, points = {}, prev = {}, bends = {} }
            for i = 1, n do
                l.points[2 * i - 1], l.points[2 * i] = l.rx + i * 2, l.ry + i * l.segment
                l.prev[2 * i - 1], l.prev[2 * i] = l.points[2 * i - 1] - 1, l.points[2 * i]
                l.bends[i] = 0.08 * k
            end
            locks[k] = l
        end
        return locks
    end
    local o = { damping = 0.96, stand = 0, stiffness = 0.1, springy = 0.3, ringlets = 0, ringletPitch = 30 }

    it('steps like its locks one by one', function()
        if not hairNative.cutAvailable() then pending('no hair_cut_v1 in native/desound (build.sh)') return end
        local a, b = makeLocks(), makeLocks()
        local cut = hairNative.newCut(a, o, 5)
        for _ = 1, 15 do
            hairNative.cutStep(cut, o, 100, 50, 0.3, 0, 2940, 1 / 120, 45, 60, 150, 2)
            for _, l in ipairs(b) do hairNative.step(l, o, 100, 50, 0.3, 0, 2940, 1 / 120, 45, 60, 150, 2) end
        end
        hairNative.readBack(cut, a)
        for k = 1, #a do
            for i = 1, 2 * a[k].n do
                assert.are.equal(b[k].points[i], a[k].points[i])
                assert.are.equal(b[k].prev[i], a[k].prev[i])
            end
        end
    end)

    it('lays a layer as its locks joined', function()
        if not hairNative.cutAvailable() then pending('no hair_cut_v1 in native/desound (build.sh)') return end
        local locks = makeLocks()
        local cut = hairNative.newCut(locks, o, 5)
        local ffi = require('ffi')
        for _, front in ipairs({ false, true }) do
            local data = love.data.newByteData(4000 * hairNative.BYTES_PER_VERTEX)
            local count = hairNative.cutStrip(cut, front, 0.5, 139, data, 4000)
            local want = love.data.newByteData(4000 * hairNative.BYTES_PER_VERTEX)
            local wcount = 0
            for _, l in ipairs(locks) do
                if (l.front or false) == front then
                    local at = wcount > 0 and wcount + 2 or 0
                    local c = hairNative.strip(l.points, l.n, l.segment, l.ring, l.ringPitch, l.wave, l.segment * 5,
                        l.phase, 0.5, 139 * l.width, want, at)
                    if wcount > 0 then
                        hairNative.copyVertex(want, wcount - 1, wcount)
                        hairNative.copyVertex(want, at, wcount + 1)
                    end
                    wcount = at + c
                end
            end
            assert.are.equal(wcount, count)
            local f, g = ffi.cast('float *', data:getFFIPointer()), ffi.cast('float *', want:getFFIPointer())
            local worst = 0
            for i = 0, count * 8 - 1 do worst = math.max(worst, math.abs(f[i] - g[i])) end
            -- (hair_strip takes the points as floats, the cut as doubles)
            assert.is_true(worst < 0.01, 'vertices differ by ' .. worst)
        end
    end)
end)
