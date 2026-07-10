-- Specs for src/physics/box2d-pointerjoints.lua — mouse-joint lifecycle:
-- create on press, track, release, and dead-reference cleanup. This is the
-- home turf of the stale-body failure mode; previously zero coverage.

if not love then return end

local pj = require('src.physics.box2d-pointerjoints')
local registry = require('src.registry')
local state = require('src.state')

describe('box2d-pointerjoints', function()
    local world, body
    local BODY_ID = 'pj-body'

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        pj.resetPointerJoints()

        body = love.physics.newBody(world, 100, 100, 'dynamic')
        love.physics.newFixture(body, love.physics.newCircleShape(30), 1)
        body:setUserData({ thing = { id = BODY_ID, body = body } })
        registry.registerBody(BODY_ID, body)
    end)

    after_each(function()
        pj.resetPointerJoints()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
        state.physicsWorld = nil
        registry.reset()
    end)

    describe('handlePointerPressed', function()
        it('creates a mouse joint when pressing on a body', function()
            local hit, hitted, data = pj.handlePointerPressed(100, 100, 'mouse', nil, true)

            assert.is_true(hit)
            assert.equal(1, #hitted)
            assert.equal(BODY_ID, data.bodyID)
            assert.equal('mouse', data.pointerID)

            local mj = pj.getPointerJointAttachedTo(body)
            assert.is_not_nil(mj)
            assert.is_false(mj.joint:isDestroyed())
        end)

        it('reports a miss on empty space and keeps no joint', function()
            local hit = pj.handlePointerPressed(5000, 5000, 'mouse', nil, true)
            assert.is_false(hit)
            assert.is_nil(pj.getPointerJointAttachedTo(body))
            assert.equal(0, #pj.getPointerJoints())
        end)

        it('hits but does not grab a sensor-only body', function()
            local ghost = love.physics.newBody(world, 400, 400, 'dynamic')
            local fixture = love.physics.newFixture(ghost, love.physics.newCircleShape(30), 1)
            fixture:setSensor(true)
            ghost:setUserData({ thing = { id = 'pj-ghost', body = ghost } })

            local hit, hitted = pj.handlePointerPressed(400, 400, 'mouse', nil, true)
            assert.is_false(hit)
            assert.equal(1, #hitted) -- the sensor still registers as hit
            assert.is_nil(pj.getPointerJointAttachedTo(ghost))
        end)

        it('respects allowMouseJointMaking = false', function()
            local hit = pj.handlePointerPressed(100, 100, 'mouse', nil, false)
            assert.is_true(hit)
            assert.is_nil(pj.getPointerJointAttachedTo(body))
        end)

        it('lists the grabbed body as interacted', function()
            pj.handlePointerPressed(100, 100, 'mouse', nil, true)
            local interacted = pj.getInteractedWithPointer()
            assert.equal(1, #interacted)
            assert.equal(body, interacted[1])
        end)
    end)

    describe('handlePointerReleased', function()
        it('destroys the joint and reports the released body', function()
            pj.handlePointerPressed(100, 100, 'mouse', nil, true)
            -- capture the joint object itself: release nils the tracking
            -- table's fields before dropping it
            local joint = pj.getPointerJointAttachedTo(body).joint

            local released = pj.handlePointerReleased(100, 100, 'mouse')

            assert.equal(1, #released)
            assert.equal(body, released[1])
            assert.is_true(joint:isDestroyed())
            assert.is_nil(pj.getPointerJointAttachedTo(body))
            assert.equal(0, #pj.getPointerJoints())
        end)

        it('only releases the matching pointer id', function()
            pj.handlePointerPressed(100, 100, 'mouse', nil, true)
            local released = pj.handlePointerReleased(0, 0, 'touch-1')
            assert.equal(0, #released)
            assert.is_not_nil(pj.getPointerJointAttachedTo(body))
        end)
    end)

    describe('dead-reference cleanup', function()
        it('removeDeadPointerJoints drops externally destroyed joints', function()
            pj.handlePointerPressed(100, 100, 'mouse', nil, true)
            local mj = pj.getPointerJointAttachedTo(body)
            mj.joint:destroy()

            pj.removeDeadPointerJoints()

            assert.equal(0, #pj.getPointerJoints())
        end)

        it('getInteractedWithPointer skips a body destroyed mid-drag', function()
            pj.handlePointerPressed(100, 100, 'mouse', nil, true)
            body:destroy() -- also destroys the attached mouse joint

            local interacted
            assert.has_no.errors(function() interacted = pj.getInteractedWithPointer() end)
            assert.equal(0, #interacted)
        end)
    end)
end)
