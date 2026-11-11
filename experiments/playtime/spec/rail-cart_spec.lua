-- spec/rail-cart_spec.lua
-- Carts on coaster tracks (src/rail-cart.lua, docs/COASTER.md CO3): a RAIL_CART body let go near a
-- track locks on and rides it: down a slope by gravity, round a vertical loop upside down without
-- falling off, off an open end into the air; it keeps its energy (no drag) over a hump; it rides
-- through a crossing in either lane without touching the other rail.
-- Run with: love . --specs spec/rail-cart_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local track = require('src.track')
local railCart = require('src.rail-cart')
local callbacks = require('src.physics.physics-callbacks')
local polygon = require('src.polygon')

local DT = 1 / 60

local function makeTrack(flat, closed)
    local cx, cy = polygon.getCenterOfPoints(flat)
    return objectManager.addThing('track', {
        x = cx, y = cy, bodyType = 'static', vertices = flat, track = { closed = closed or false, flips = {} },
    })
end

-- a polyline through the given corners, a point every `step`
local function line(corners, step)
    local flat = {}
    for k = 1, #corners - 1 do
        local a, b = corners[k], corners[k + 1]
        local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        local n = math.max(1, math.floor(len / step))
        for s = 0, n - 1 do
            flat[#flat + 1] = a[1] + (b[1] - a[1]) * s / n
            flat[#flat + 1] = a[2] + (b[2] - a[2]) * s / n
        end
    end
    flat[#flat + 1], flat[#flat + 2] = corners[#corners][1], corners[#corners][2]
    return flat
end

local function cart(x, y)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = 60, height = 30 })
    thing.behaviors = { { name = railCart.BEHAVIOR, enabled = true } }
    return thing.body
end

local function step(n)
    for _ = 1, n do
        state.physicsWorld:update(DT)
        railCart.afterStep(DT)
        track.update(DT)
        railCart.update()
    end
end

describe('rail cart', function()
    local drag, airDrag
    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld:setCallbacks(unpack(callbacks))
        state.trackMovers, state.railCarts, state.railCartsFlown = nil, nil, nil
        registry.reset()
        drag, airDrag = railCart.DRAG, railCart.AIR_DRAG
    end)

    after_each(function()
        railCart.DRAG, railCart.AIR_DRAG = drag, airDrag
        state.physicsWorld:setCallbacks()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        state.trackMovers, state.railCarts, state.railCartsFlown = nil, nil, nil
        registry.reset()
    end)

    it('locks on when let go near a track, rides down it on top, and flies off its open end', function()
        local t = makeTrack(line({ { -600, -300 }, { 600, 300 } }, 20))
        local body = cart(-500, -300) -- just above the rail near its top
        step(1)
        local lock = railCart.lockOf(body)
        assert.is_truthy(lock, 'locked on')
        assert.are.equal(t, lock.track)
        assert.are.equal(1, lock.side) -- on top: the left of a line going right and down is up
        assert.is_near(15, lock.height, 0.01)
        local s0 = lock.s
        step(30)
        assert.is_true(lock.s > s0 + 50, 'rolled down')
        assert.is_true(lock.speed > 0)
        -- its centre stays 15 above the rail, and it lies along it
        local layout = track.layout(t)
        local lx, ly = t.body:getLocalPoint(body:getPosition())
        local _, d = track.nearestArc(layout, lx, ly)
        assert.is_near(15, d, 0.5)
        assert.is_near(math.atan2(300, 600), body:getAngle(), 0.02)
        step(240)
        assert.is_nil(railCart.lockOf(body), 'off the end: let go')
        assert.is_true(body:getX() > 600)
    end)

    it('goes round a vertical loop upside down without falling off', function()
        -- a run-in, then a circle of radius 300 drawn as part of the line, then a run-out
        local corners = { { -1200, 0 }, { -100, 0 } }
        local flat = line(corners, 20)
        flat[#flat], flat[#flat - 1] = nil, nil
        for k = 0, 94 do -- round from the bottom, up the far side, over the top, back down
            local a = k / 95 * 2 * math.pi
            flat[#flat + 1] = -100 + math.sin(a) * 300
            flat[#flat + 1] = -300 + math.cos(a) * 300
        end
        local out = line({ { -100, 0 }, { 1200, 0 } }, 20)
        for i = 3, #out do flat[#flat + 1] = out[i] end
        local t = makeTrack(flat)
        local body = cart(-1100, -15)
        step(1)
        local lock = railCart.lockOf(body)
        assert.is_truthy(lock)
        railCart.setSpeed(body, 3000) -- enough for the loop at 200 px/m: v^2 > 5 g r
        local minY = math.huge
        local upsideDown = false
        for _ = 1, 200 do
            step(1)
            if not railCart.lockOf(body) then break end
            minY = math.min(minY, body:getY())
            local a = body:getAngle() % (2 * math.pi)
            if math.abs(a - math.pi) < 0.3 then upsideDown = true end
            if upsideDown and body:getX() > 400 then break end -- out of the loop, on the run-out
        end
        assert.is_truthy(railCart.lockOf(body), 'still on the rail')
        assert.is_true(minY < -550, 'went up to the loop top')
        assert.is_true(upsideDown, 'upside down over the top')
        assert.is_true(body:getX() > -100, 'came out of the loop going on')
        assert.are.equal(t, railCart.lockOf(body).track)
    end)

    it('keeps its energy over a hump with no drag', function()
        railCart.DRAG, railCart.AIR_DRAG = 0, 0
        local flat = {}
        for k = 0, 120 do
            local x = -1200 + k * 20
            flat[#flat + 1] = x
            flat[#flat + 1] = 200 * math.cos(x / 1200 * math.pi) -- a valley between two hills
        end
        makeTrack(flat)
        local body = cart(-1150, -212)
        step(1)
        local lock = railCart.lockOf(body)
        assert.is_truthy(lock)
        local startY = body:getY()
        local highest = math.huge
        for _ = 1, 400 do
            step(1)
            if body:getX() > 600 then highest = math.min(highest, body:getY()) end
        end
        -- it climbs the far hill to about where it started (the gravity potential), within 4%
        assert.is_near(startY, highest, 400 * 0.04)
    end)

    it('rides through a crossing in either lane without touching the other rail', function()
        -- an open figure: down to the right, up and back across its own way
        local t = makeTrack(line({ { -700, -200 }, { 700, 300 }, { 800, 0 }, { 0, 400 }, { -200, 600 } }, 20))
        assert.are.equal(1, #track.layout(t).crossings)
        local body = cart(-650, -215)
        step(1)
        local lock = railCart.lockOf(body)
        assert.is_truthy(lock)
        railCart.setSpeed(body, 1400)
        local passed = 0
        local lastS = lock.s
        for _ = 1, 400 do
            step(1)
            local l = railCart.lockOf(body)
            if not l then break end
            assert.is_true(l.s >= lastS - 1, 'never pushed back by a rail')
            lastS = l.s
            passed = l.s
        end
        local c = track.layout(t).crossings[1]
        assert.is_true(passed > c.s2, 'went past the crossing on both stretches')
    end)
end)
