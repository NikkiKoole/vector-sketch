-- spec/rail-rider_spec.lua
-- Mipos riding coaster carts (src/rail-rider.lua, docs/COASTER.md CO5): seated in a cart, a Mipo (scale
-- 0.3) stays on its seat, upright in the cart, round a vertical loop and through a roll; it doesn't touch
-- its cart; the cart still makes the loop; off again, the cart is as it was.
-- Run with: love . --specs spec/rail-rider_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local track = require('src.track')
local railCart = require('src.rail-cart')
local railRider = require('src.rail-rider')
local callbacks = require('src.physics.physics-callbacks')
local polygon = require('src.polygon')
local mipoRegistry = require('src.mipo-registry')
local CM = require('src.character-manager')
local mipoActions = require('src.mipo-actions')
local keepAngle = require('src.keep-angle')

local DT = 1 / 60

local function makeTrack(flat, marks)
    local cx, cy = polygon.getCenterOfPoints(flat)
    return objectManager.addThing('track', {
        x = cx, y = cy, bodyType = 'static', vertices = flat, track = { closed = false, flips = {}, marks = marks },
    })
end

-- a run-in, a vertical loop of radius r from (x0, 0), a run-out
local function loopCourse(r)
    local flat = {}
    for x = -4000, 0, 20 do flat[#flat + 1] = x; flat[#flat + 1] = 0 end
    local steps = math.floor(2 * math.pi * r / 20)
    for k = 1, steps - 1 do
        local a = k / steps * 2 * math.pi
        flat[#flat + 1] = math.sin(a) * r
        flat[#flat + 1] = -r + math.cos(a) * r
    end
    for x = 0, 6000, 20 do flat[#flat + 1] = x; flat[#flat + 1] = 0 end
    return flat
end

local function cart(x, y)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = 260, height = 90 })
    thing.behaviors = { { name = railCart.BEHAVIOR, enabled = true } }
    return thing.body
end

local function step(n, each)
    for _ = 1, n do
        state.physicsWorld:update(DT)
        railCart.afterStep(DT)
        track.update(DT)
        railCart.update()
        railRider.update()
        mipoActions.update()
        keepAngle.update(DT, {})
        if each and each() then return end
    end
end

local function hips(inst)
    for _, joint in ipairs(inst.parts.luleg.body:getJoints()) do
        local a, b = joint:getBodies()
        if a == inst.parts.torso1.body and b == inst.parts.luleg.body then return joint:getAnchors() end
    end
end

local function angleOff(a, b) return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi) end

describe('rail rider', function()
    before_each(function()
        state.physicsWorld = love.physics.newWorld(0, 9.8 * love.physics.getMeter(), true)
        state.physicsWorld:setCallbacks(unpack(callbacks))
        state.trackMovers, state.railCarts, state.railCartsFlown = nil, nil, nil
        state.railRiders, state.railRiderBodies = nil, nil
        registry.reset()
        mipoRegistry.reset()
    end)

    after_each(function()
        mipoRegistry.reset()
        state.physicsWorld:setCallbacks()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        state.railRiders, state.railRiderBodies, state.railCarts = nil, nil, nil
        registry.reset()
    end)

    it('stays on its seat, upright in the cart, round a loop the cart still makes', function()
        local t = makeTrack(loopCourse(900))
        local c = cart(-700, -45) -- close to the loop: air drag at 3500 a second takes a quarter in 4000
        step(1)
        assert.is_truthy(railCart.lockOf(c))
        local inst = CM.createCharacter('humanoid', -700, -700, 0.3)
        local massBefore = c:getMass()
        assert.is_truthy(railRider.seat(c, inst))
        assert.are.equal(inst, railRider.riderOf(c))
        assert.is_true(c:getMass() > massBefore * 5, 'ballast')
        for _, f in ipairs(c:getFixtures()) do assert.are.equal(inst.groupIndex, f:getGroupIndex()) end
        railCart.setSpeed(c, 3500)
        local worstSeat, worstTilt, upsideDown, top = 0, 0, false, 0
        step(60 * 6, function()
            local lock = railCart.lockOf(c)
            if not lock then return true end
            local hx, hy = hips(inst)
            local sx, sy = c:getWorldPoint(0, -45)
            worstSeat = math.max(worstSeat, math.sqrt((hx - sx) ^ 2 + (hy - sy) ^ 2))
            worstTilt = math.max(worstTilt, angleOff(inst.parts.torso1.body:getAngle(), c:getAngle()))
            if angleOff(c:getAngle(), math.pi) < 0.3 then upsideDown = true end
            top = math.min(top, c:getY())
            return c:getX() > 2500
        end)
        print(string.format('rider: hips off the seat at most %.1f, torso off the cart at most %.0f deg, top %.0f',
            worstSeat, math.deg(worstTilt), top))
        assert.is_truthy(railCart.lockOf(c), 'the cart is still on the rail')
        assert.is_true(upsideDown, 'went over the top of the loop')
        assert.is_true(c:getX() > 2500, 'made the loop and came out')
        assert.is_true(worstSeat < 20, 'hips stayed on the seat')
        assert.is_true(worstTilt < math.rad(30), 'torso upright in the cart')
        assert.are.equal(t, railCart.lockOf(c).track)
    end)

    it('rolls round the rail with its cart, and comes off again leaving the cart as it was', function()
        -- a straight track with a roll in the middle
        local flat = {}
        for x = -3000, 3000, 20 do flat[#flat + 1] = x; flat[#flat + 1] = 0 end
        local t = makeTrack(flat)
        track.paint(t, 0, 0, 300, 'roll')
        local c = cart(-1200, -45)
        step(1)
        local groupsBefore, massBefore = {}, c:getMass()
        for _, f in ipairs(c:getFixtures()) do groupsBefore[f] = f:getGroupIndex() end
        local inst = CM.createCharacter('humanoid', -1200, -700, 0.3)
        railRider.seat(c, inst)
        railCart.setSpeed(c, 1200)
        step(60 * 4, function() return c:getX() > 900 end)
        assert.is_true(c:getX() > 900)
        assert.is_true(c:getY() > 20, 'the cart under the rail')
        assert.is_true(inst.parts.torso1.body:getY() > c:getY(), 'the rider hanging under it')
        assert.is_true(angleOff(inst.parts.torso1.body:getAngle(), c:getAngle()) < math.rad(30))
        -- off
        railRider.unseat(c)
        assert.is_nil(railRider.riderOf(c))
        assert.is_near(massBefore, c:getMass(), massBefore * 0.01)
        for f, g in pairs(groupsBefore) do assert.are.equal(g, f:getGroupIndex()) end
        assert.is_false(railRider.isRiderBody(inst.parts.torso1.body))
        assert.is_true(inst._railOff)
    end)
end)
