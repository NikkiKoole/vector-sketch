-- Specs for src/recorder.lua — record → replay round-trip.
-- The dispatch bug class this guards against: replay used to fire events
-- only on exact float equality with currentTime, so any dt divergence
-- (panic cap, speed multiplier) silently skipped events and orphaned
-- mouse joints.

if not love then return end

local recorder = require('src.recorder')
local registry = require('src.registry')
local state = require('src.state')

describe('recorder replay', function()
    local world, body
    local BODY_ID = 'rec-spec-body'

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()

        body = love.physics.newBody(world, 100, 100, 'dynamic')
        love.physics.newFixture(body, love.physics.newCircleShape(10), 1)
        body:setUserData({ thing = { id = BODY_ID, body = body } })
        registry.registerBody(BODY_ID, body)

        -- reset recorder state (it's a module-level singleton)
        recorder.isRecording = false
        recorder.isReplaying = false
        recorder.isPaused = false
        recorder.currentTime = 0
        recorder.events = {}
        recorder.recordings = {}
        recorder.replayIndices = {}
        recorder.recordingMouseJoints = {}
        recorder.replayingMouseJoints = {}
    end)

    after_each(function()
        recorder.isReplaying = false
        recorder.isRecording = false
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
        state.physicsWorld = nil
    end)

    local function replayAll(steps, dt)
        recorder:startReplay()
        for _ = 1, steps do
            recorder:update(dt)
        end
    end

    it('fires events even when replay dt never lands exactly on a timestamp', function()
        recorder.recordings = { {
            { timestamp = 0.10, type = 'object_interaction', action = 'position',
                data = { objectId = BODY_ID, x = 11, y = 22 } },
            { timestamp = 0.50, type = 'object_interaction', action = 'position',
                data = { objectId = BODY_ID, x = 33, y = 44 } },
        } }

        -- 0.07 increments never equal 0.10 or 0.50 exactly.
        replayAll(10, 0.07)

        local x, y = body:getPosition()
        assert.equal(33, x)
        assert.equal(44, y)
    end)

    it('processes each event exactly once (cursor advances past them)', function()
        recorder.recordings = { {
            { timestamp = 0.10, type = 'object_interaction', action = 'position',
                data = { objectId = BODY_ID, x = 11, y = 22 } },
        } }

        replayAll(3, 0.07) -- 0.21 > 0.10: event fired
        assert.equal(2, recorder.replayIndices[1])

        -- Body moves on; a later update must NOT re-fire the event.
        -- (Box2D stores positions in meters, so compare with tolerance.)
        body:setPosition(500, 500)
        recorder:update(0.07)
        local x, y = body:getPosition()
        assert.is_true(math.abs(x - 500) < 0.01, 'event re-fired: x = ' .. x)
        assert.is_true(math.abs(y - 500) < 0.01, 'event re-fired: y = ' .. y)
    end)

    it('round-trips a recorded mouse-joint session', function()
        recorder:startRecording(1)
        recorder.currentTime = 0.1
        recorder:recordMouseJointStart({
            pointerID = 'mouse', bodyID = BODY_ID, wx = 100, wy = 100,
            force = 5000, damp = 0.5,
        })
        recorder.currentTime = 0.2
        recorder.events[#recorder.events + 1] = {
            type = 'object_interaction', timestamp = 0.2, action = 'mousejoint-update',
            data = { pointerId = 'mouse', objectId = BODY_ID, x = 150, y = 130 },
        }
        recorder.currentTime = 0.3
        recorder:recordMouseJointFinish('mouse', BODY_ID)
        recorder:stopRecording()

        assert.equal(3, #recorder.recordings[1])

        -- replay halfway: joint should exist and track the update target
        recorder:startReplay()
        recorder:update(0.25)
        local key = 'mouse' .. BODY_ID .. 1
        assert.is_not_nil(recorder.replayingMouseJoints[key])
        local tx, ty = recorder.replayingMouseJoints[key].joint:getTarget()
        assert.equal(150, tx)
        assert.equal(130, ty)

        -- replay past the end event: joint destroyed and forgotten
        recorder:update(0.25)
        assert.is_nil(recorder.replayingMouseJoints[key])
    end)

    it('survives a mousejoint-update whose start event is missing', function()
        recorder.recordings = { {
            { timestamp = 0.1, type = 'object_interaction', action = 'mousejoint-update',
                data = { pointerId = 'mouse', objectId = BODY_ID, x = 1, y = 2 } },
            { timestamp = 0.1, type = 'object_interaction', action = 'mousejoint-end',
                data = { pointerId = 'mouse', objectId = BODY_ID } },
        } }

        recorder:startReplay()
        assert.has_no.errors(function() recorder:update(0.2) end)
    end)

    it('skips events for bodies that no longer resolve', function()
        recorder.recordings = { {
            { timestamp = 0.1, type = 'object_interaction', action = 'position',
                data = { objectId = 'gone-body', x = 1, y = 2 } },
        } }
        recorder:startReplay()
        assert.has_no.errors(function() recorder:update(0.2) end)
    end)

    it('replays pause/unpause world events', function()
        local before = state.world.paused
        recorder.recordings = { {
            { timestamp = 0.1, type = 'world_interaction', action = 'pause',
                data = { state = true } },
            { timestamp = 0.2, type = 'world_interaction', action = 'pause',
                data = { state = false } },
        } }
        recorder:startReplay()
        recorder:update(0.15)
        assert.is_true(state.world.paused)
        recorder:update(0.15)
        assert.is_false(state.world.paused)
        state.world.paused = before
    end)
end)
