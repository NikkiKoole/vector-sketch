-- spec/fluid_spec.lua
-- Particle water (src/fluid.lua, native/desound/fluid.c, scene waterjar, docs/WATERJAR.md): water
-- in a tank settles calm and level and stays in; tipped fast it sloshes up the far wall; a light
-- crate floats, a heavy one sinks; the Lua step and the C step agree on the rest.
-- Run with: love . --specs spec/fluid_spec.lua

if not love then return end

local state = require('src.state')
local fluid = require('src.fluid')

local HW, DEPTH, WALL = 760, 640, 46

local function box(body, x1, y1, x2, y2, density)
    return love.physics.newFixture(body, love.physics.newPolygonShape(x1, y1, x2, y1, x2, y2, x1, y2), density)
end

local function setup(useNative)
    local world = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
    state.physicsWorld = world
    local tank = love.physics.newBody(world, 0, 0, 'kinematic')
    box(tank, -HW - WALL, 0, HW + WALL, WALL)
    box(tank, -HW - WALL, -DEPTH, -HW, 0)
    box(tank, HW, -DEPTH, HW + WALL, 0)
    local was = fluid.useNative
    fluid.useNative = useNative
    local f = fluid.new({ tank = tank, tankHalfWidth = HW, tankDepth = DEPTH })
    fluid.useNative = was
    local level = f.native and 0.55 or 0.25
    fluid.fill(f, -HW, -DEPTH * level, HW, 0)
    return world, tank, f
end

local function frames(world, f, n, each)
    for k = 1, n do
        if each then each(k) end
        fluid.update(f, 1 / 60)
        world:update(1 / 60)
    end
end

local function stats(f)
    local inside, top, sum, vmax = 0, math.huge, 0, 0
    for i = 0, f.n - 1 do
        local x, y = f.x[i], f.y[i]
        if math.abs(x) < HW and y < 0 and y > -DEPTH then inside = inside + 1 end
        if y < top then top = y end
        local v = math.sqrt((x - f.px[i]) ^ 2 + (y - f.py[i]) ^ 2)
        sum, vmax = sum + v, math.max(vmax, v)
    end
    return { inside = inside, top = top, avg = sum / math.max(1, f.n), vmax = vmax }
end

-- the surface height in columns across the tank: the highest point in each
local function surface(f, cols)
    local tops = {}
    for c = 1, cols do tops[c] = 0 end
    for i = 0, f.n - 1 do
        local c = math.floor((f.x[i] + HW) / (2 * HW) * cols) + 1
        if c >= 1 and c <= cols then tops[c] = math.min(tops[c], f.y[i]) end
    end
    return tops
end

for _, useNative in ipairs({ true, false }) do
    local name = useNative and 'C' or 'Lua'
    describe('fluid (' .. name .. ')', function()
        it('settles calm and level, and stays in the tank', function()
            if useNative and not fluid.nativeAvailable() then pending('no native library'); return end
            local world, _, f = setup(useNative)
            local n = f.n
            assert.is_true(n > 100)
            local t0 = love.timer.getTime()
            frames(world, f, 180)
            local ms = (love.timer.getTime() - t0) * 1000 / 180
            local st = stats(f)
            print(string.format('[fluid %s] %d points, %.2f ms a frame, avg speed %.3f, max %.3f', name, n, ms,
                st.avg, st.vmax))
            assert.are.equal(n, st.inside)
            assert.is_true(st.avg < 0.3, 'avg speed ' .. st.avg)
            local tops = surface(f, 8)
            local lo, hi = math.huge, -math.huge
            for _, y in ipairs(tops) do lo, hi = math.min(lo, y), math.max(hi, y) end
            print(string.format('[fluid %s] surface from %.0f to %.0f', name, lo, hi))
            assert.is_true(hi - lo < f.h * 1.5, 'surface not level: ' .. (hi - lo))
        end)

        it('tipped fast, the water climbs the far wall', function()
            if useNative and not fluid.nativeAvailable() then pending('no native library'); return end
            local world, tank, f = setup(useNative)
            frames(world, f, 60)
            local restTop = stats(f).top
            local tilt, highest = 0, 0
            local maxTilt = math.rad(35)
            frames(world, f, 150, function(k)
                -- right for 0.4 s (the left end goes up), then hard left: the water runs left and up
                local target = k < 25 and maxTilt or -maxTilt
                local step = math.rad(3.5)
                tilt = tilt + math.max(-step, math.min(step, target - tilt))
                tank:setAngularVelocity((tilt - tank:getAngle()) * 60)
                local top = stats(f).top
                highest = math.min(highest, top)
            end)
            print(string.format('[fluid %s] rest top %.0f, highest during the slosh %.0f', name, restTop, highest))
            assert.is_true(highest < restTop - 200)
        end)
    end)
end

describe('fluid and bodies (C)', function()
    it('a light crate floats, a heavy one sinks', function()
        if not fluid.nativeAvailable() then pending('no native library'); return end
        local world, _, f = setup(true)
        local light = love.physics.newBody(world, -300, -DEPTH, 'dynamic')
        box(light, -80, -60, 80, 60, 0.3)
        local heavy = love.physics.newBody(world, 300, -DEPTH, 'dynamic')
        box(heavy, -60, -40, 60, 40, 6)
        local waterTop = stats(f).top
        frames(world, f, 360)
        local _, ly = light:getPosition()
        local _, hy = heavy:getPosition()
        print(string.format('[fluid] water top %.0f, light crate at %.0f, heavy crate at %.0f', waterTop, ly, hy))
        assert.is_true(ly < waterTop + 80, 'light crate sank')
        assert.is_true(hy > -150, 'heavy crate floats')
    end)
end)
