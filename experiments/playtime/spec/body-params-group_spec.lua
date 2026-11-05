-- spec/body-params-group_spec.lua
-- The inspector's 'group' row (src/body-params.lua) shows a body's collision group. It read the
-- body's first fixture, which is a sensor sfixture on bodies that carry one (they come first), so
-- it showed the sensor's group, not the one that collides; and it assumed a body has a fixture
-- at all. It reads the first collision fixture now, like the rows beside it.
-- Run with: love . --specs spec/body-params-group_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local bodyParams = require('src.body-params')

describe("the inspector's group row", function()
    local world, row

    before_each(function()
        registry.reset()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        for _, r in ipairs(bodyParams.rows) do if r.key == 'group' then row = r end end
    end)

    after_each(function()
        world:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it("shows the collision fixture's group on a body with a sensor sfixture first", function()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 50, height = 50 })
        fixtures.createSFixture(thing.body, 0, 0, 'texfixture', { label = 'x', width = 20, height = 20 })
        local list = thing.body:getFixtures()
        assert.is_truthy(list[1]:getUserData(), 'the sfixture comes first')
        for _, fixture in ipairs(list) do
            fixture:setGroupIndex(fixture:getUserData() and 0 or -7)
        end
        assert.are.equal(-7, row.get(thing))
    end)

    it('is not shown, and reads nothing, on a body without fixtures', function()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 50, height = 50 })
        for _, fixture in ipairs(thing.body:getFixtures()) do fixture:destroy() end
        assert.is_false(row.visible(thing))
        assert.has_no.errors(function() row.get(thing) end)
    end)
end)
