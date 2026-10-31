-- keep-angle remembers each body's thing (it never changes for a body) but reads its behaviors
-- live: a KEEP_ANGLE added later, switched off, or on a body the editor rebuilt still counts.
if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local keepAngle = require('src.keep-angle')

local DT = 1 / 84

describe('keep-angle', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
    end)

    after_each(function()
        if world and not world:isDestroyed() then world:destroy() end
    end)

    -- a plank tilted 1 radian, at rest: does keep-angle turn it back?
    local function tiltedPlank()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 100, height = 20,
            bodyType = 'dynamic' })
        thing.body:setAngle(1)
        thing.body:setAngularVelocity(0)
        return thing
    end
    local function turned(body)
        body:setAngularVelocity(0)
        keepAngle.update(DT, {})
        return body:getAngularVelocity() ~= 0
    end

    it('leaves a body without KEEP_ANGLE alone, and steers it once one is added', function()
        local thing = tiltedPlank()
        assert.is_false(turned(thing.body))
        thing.behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } }
        assert.is_true(turned(thing.body))
        assert.is_true(thing.body:getAngularVelocity() < 0) -- back towards 0
    end)

    it('stops when the behavior is switched off or taken away', function()
        local thing = tiltedPlank()
        thing.behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } }
        assert.is_true(turned(thing.body))
        thing.behaviors[1].enabled = false
        assert.is_false(turned(thing.body))
        thing.behaviors = {}
        assert.is_false(turned(thing.body))
    end)

    it('steers a body the editor rebuilt', function()
        local thing = tiltedPlank()
        thing.behaviors = { { name = 'KEEP_ANGLE', angle = 0, kp = 40 } }
        assert.is_true(turned(thing.body))
        local rebuilt = objectManager.recreateThingFromBody(thing.body, { width = 140 })
        rebuilt.body:setAngle(1)
        assert.is_true(turned(rebuilt.body))
    end)
end)
