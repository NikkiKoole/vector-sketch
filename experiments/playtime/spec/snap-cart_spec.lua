-- spec/snap-cart_spec.lua
-- A cart snapped together from props.makePlank + two props.makeWheel: the snap
-- joints are free axles, and crashing into a wall doesn't break them (snap
-- joints only break while a piece is dragged).
-- Run with: love . --specs spec/snap-cart_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local props = require('src.props')
local snap = require('src.physics.snap')

describe('snap-together cart', function()
    local world, saved

    before_each(function()
        world = love.physics.newWorld(0, 980, true)
        state.physicsWorld = world
        registry.reset()
        snap.reset()
        saved = { state.snap.onlyConnectWhenInteracted, state.snap.onlyBreakWhenInteracted }
        -- a 15 degree slope down to the right, onto a floor, into a wall
        local ground = love.physics.newBody(world, 0, 0, 'static')
        local a = math.rad(15)
        love.physics.newFixture(ground, love.physics.newEdgeShape(-2000, -2000 * math.tan(a) + 600, 0, 600))
        love.physics.newFixture(ground, love.physics.newEdgeShape(0, 600, 3000, 600))
        love.physics.newFixture(ground, love.physics.newEdgeShape(3000, 600, 3000, -400))
        for _, f in ipairs(ground:getFixtures()) do f:setFriction(0.9) end
    end)

    after_each(function()
        state.snap.onlyConnectWhenInteracted, state.snap.onlyBreakWhenInteracted = saved[1], saved[2]
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function tick(n)
        for _ = 1, n do
            world:update(1 / 60)
            snap.update(1 / 60)
        end
    end

    it('rolls down a slope and crashes into a wall without falling apart', function()
        local px, py = -1500, -100
        local plank = props.makePlank(px, py)
        local w1 = props.makeWheel(px - 210, py + 20)
        local w2 = props.makeWheel(px + 210, py + 20)
        -- assemble without dragging, then back to the game's rules
        state.snap.onlyConnectWhenInteracted = false
        tick(1)
        state.snap.onlyConnectWhenInteracted = true
        assert.are.equal(2, #snap.joints())
        -- a load on top, like a Mipo
        local load = love.physics.newBody(world, px, py - 120, 'dynamic')
        love.physics.newFixture(load, love.physics.newRectangleShape(200, 200), 2)
        tick(60 * 8)
        assert.are.equal(2, #snap.joints())
        local x = plank.body:getX()
        assert.is_true(x > 1500, 'cart only got to x=' .. math.floor(x))
        -- the wheels actually turned (they are axles, not welded)
        assert.is_true(math.abs(w1.body:getAngle()) > 2 * math.pi)
        assert.is_true(math.abs(w2.body:getAngle()) > 2 * math.pi)
    end)
end)
