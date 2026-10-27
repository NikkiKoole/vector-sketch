-- spec/on-stage_spec.lua
-- The "on stage" list (src/ui/on-stage.lua): same-label bodies are one row,
-- wires get a row, clicking a group again steps through it, and selecting
-- clears any joint/sfixture selection.
-- Run with: love . --specs spec/on-stage_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local onStage = require('src.ui.on-stage')

describe('on stage list', function()
    local world

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
    end)

    after_each(function()
        state.selection.selectedObj = nil
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function add(label, behaviors)
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40, label = label })
        thing.label = label
        thing.behaviors = behaviors
        return thing
    end

    local function rowByLabel(prefix)
        for _, row in ipairs(onStage.rows()) do
            if row.label and row.label:sub(1, #prefix) == prefix then return row end
        end
    end

    it('groups bodies by label', function()
        add('box'); add('box'); add('box'); add('plank')
        assert.are.equal(3, #rowByLabel('box').bodies)
        assert.are.equal('box  x3', rowByLabel('box').label)
        assert.are.equal('plank', rowByLabel('plank').label)
    end)

    it('lists wires as trigger -> signal -> receiver', function()
        add('button', { { name = 'SIGNAL_BUTTON', signal = 'gate1' } })
        add('gate', { { name = 'SIGNAL_GATE', signal = 'gate1' } })
        assert.is_not_nil(rowByLabel('button -> gate1 -> gate'))
    end)

    it('clicking a group again steps to the next body, then wraps', function()
        add('box'); add('box')
        local row = rowByLabel('box')
        onStage.select(onStage.nextBody(row))
        local first = state.selection.selectedObj.body
        onStage.select(onStage.nextBody(row))
        local second = state.selection.selectedObj.body
        onStage.select(onStage.nextBody(row))
        assert.are_not.equal(first, second)
        assert.are.equal(first, state.selection.selectedObj.body)
    end)

    it('selecting clears a joint or sfixture selection', function()
        local thing = add('box')
        state.selection.selectedJoint = 'joint'
        state.selection.selectedSFixture = 'sfixture'
        onStage.select(thing.body)
        assert.are.equal(thing, state.selection.selectedObj)
        assert.is_nil(state.selection.selectedJoint)
        assert.is_nil(state.selection.selectedSFixture)
    end)
end)
