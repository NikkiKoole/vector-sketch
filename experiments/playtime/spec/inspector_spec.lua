-- spec/inspector_spec.lua
-- The inspector (src/ui/inspector.lua) draws settings declared as data
-- (src/joint-params.lua, src/body-params.lua, src/behaviors.lua), so one loop tests them all:
--   round trip: set(value) on a real joint, then get() returns it;
--   drawing: every panel, '+ more' open, draws without errors.
-- Run with: love . --specs spec/inspector_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local joints = require('src.joints')
local objectManager = require('src.object-manager')
local jointParams = require('src.joint-params')
local bodyParams = require('src.body-params')
local bodyEditor = require('src.ui.body-editor')
local behaviors = require('src.behaviors')
local ui = require('src.ui.all')
local inspector = require('src.ui.inspector')
local uiJointUpdate = require('src.ui.joint-update')

local function resolve(v, target)
    if type(v) == 'function' then return v(target) end
    return v
end

local function renderToCanvas(fn)
    local canvas = love.graphics.newCanvas(1200, 768)
    love.graphics.setCanvas(canvas)
    local ok, err = pcall(fn)
    love.graphics.setCanvas()
    canvas:release()
    return ok, err
end

describe('inspector', function()
    local world, savedMode

    setup(function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
    end)

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        savedMode = state.currentMode
        ui.startFrame()
    end)

    after_each(function()
        state.currentMode = savedMode
        state.selection.selectedJoint = nil
        state.selection.selectedObj = nil
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local function makeJoint(jointType)
        local a = objectManager.addThing('rectangle', { x = 100, y = 100, width = 40, height = 40 })
        local b = objectManager.addThing('rectangle', { x = 200, y = 160, width = 40, height = 40 })
        local joint = joints.createJoint({ jointType = jointType, body1 = a.body, body2 = b.body,
            offsetA = { x = 0, y = 0 }, offsetB = { x = 0, y = 0 } })
        state.selection.selectedJoint = joint
        return joint
    end

    for jointType, params in pairs(jointParams.byType) do
        it(jointType .. ': every setting reads back what was set', function()
            local joint = makeJoint(jointType)
            assert.is_not_nil(joint)
            for _, row in ipairs(params) do
                local name = jointType .. ' ' .. tostring(row.key or row.label)
                local replaced
                if row.kind == 'number' then
                    local min, max = resolve(row.min, joint), resolve(row.max, joint)
                    local v = min + (max - min) * 0.75
                    if row.step then v = math.floor(v) end
                    replaced = row.set(joint, v)
                    joint = replaced or joint
                    local got = row.get(joint)
                    if row.key:find('^axis') then
                        -- Box2D normalizes the axis: only the direction survives
                        assert.is_true((got > 0) == (v > 0), name)
                    else
                        assert.is_true(math.abs(got - v) <= 1e-3 * math.max(1, math.abs(v)),
                            name .. ': set ' .. v .. ', got ' .. tostring(got))
                    end
                elseif row.kind == 'bool' then
                    local v = not row.get(joint)
                    replaced = row.set(joint, v)
                    joint = replaced or joint
                    assert.are.equal(v, row.get(joint), name)
                elseif row.kind == 'action' then
                    replaced = row.run(nil, joint)
                    joint = replaced or joint
                end
                if replaced then
                    -- a rebuilt joint: alive, and the selection follows it
                    assert.is_false(replaced:isDestroyed(), name)
                    assert.are.equal(replaced, state.selection.selectedJoint, name)
                end
            end
        end)

        it(jointType .. ': the panel draws with all rows open', function()
            local joint = makeJoint(jointType)
            state.selection.selectedObj = joint:getBodies():getUserData().thing
            -- show every row: limits and motor on
            for _, row in ipairs(params) do
                if row.key == 'limits' or row.key == 'motor' then row.set(joint, true) end
            end
            inspector.setFoldOpen('joint_' .. tostring(joints.getJointId(joint)), true)
            local ok, err = renderToCanvas(function()
                uiJointUpdate.drawJointUpdateUI(joint, 880, 20, 300, 728)
            end)
            assert.is_true(ok, jointType .. ': ' .. tostring(err))
        end)
    end

    for _, behavior in ipairs(behaviors.allBehaviors) do
        if behavior.params then
            it(behavior.name .. ': the behavior panel draws with all rows open', function()
                local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 40, height = 40 })
                local target = { name = behavior.name }
                thing.behaviors = { target }
                inspector.setFoldOpen('spec_' .. behavior.name, true)
                local ok, err = renderToCanvas(function()
                    inspector.drawParams('spec_' .. behavior.name, behavior.params, target, thing.body, 60, 100, 260)
                end)
                assert.is_true(ok, behavior.name .. ': ' .. tostring(err))
            end)
        end
    end

    -- every shape the size rows know about
    local shapes = {
        rectangle = { width = 100, height = 60 },
        circle = { radius = 40 },
        hexagon = { radius = 40 },
        torso = { width = 100, width2 = 90, width3 = 80, height = 120, height2 = 40, height3 = 40, height4 = 40 },
        capsule = { width = 60, width2 = 10, height = 120 },
        trapezium = { width = 100, width2 = 60, height = 80 },
    }

    for shape, dims in pairs(shapes) do
        local function makeThing()
            local opts = { x = 300, y = 200 }
            for k, v in pairs(dims) do opts[k] = v end
            local thing = objectManager.addThing(shape, opts)
            state.selection.selectedObj = thing
            return thing
        end

        it('body (' .. shape .. '): every visible setting reads back what was set', function()
            local thing = makeThing()
            assert.is_not_nil(thing, shape)
            for _, row in ipairs(bodyParams.rows) do
                if not row.visible or row.visible(thing) then
                    local name = shape .. ' ' .. tostring(row.key or row.label)
                    local replaced, v
                    if row.kind == 'number' then
                        local min, max = resolve(row.min, thing), resolve(row.max, thing)
                        v = min + (max - min) * 0.75
                        if row.step then v = math.floor(v) end
                    elseif row.kind == 'numberText' then
                        v = 123
                    elseif row.kind == 'bool' then
                        v = not row.get(thing)
                    elseif row.kind == 'choice' then
                        v = row.options[#row.options]
                    elseif row.kind == 'text' then
                        v = 'a label'
                    end
                    if row.kind == 'action' then
                        replaced = row.run(thing.body, thing)
                    else
                        replaced = row.set(thing, v)
                    end
                    thing = replaced or thing
                    if v ~= nil then
                        local got = row.get(thing)
                        if type(v) == 'number' then
                            assert.is_true(math.abs(got - v) <= 1e-3 * math.max(1, math.abs(v)),
                                name .. ': set ' .. v .. ', got ' .. tostring(got))
                        else
                            assert.are.equal(v, got, name)
                        end
                    end
                    if replaced then
                        assert.is_false(replaced.body:isDestroyed(), name)
                        assert.are.equal(replaced, state.selection.selectedObj, name)
                    end
                end
            end
        end)

        it('body (' .. shape .. '): the panel draws with all rows open', function()
            local thing = makeThing()
            inspector.setFoldOpen('body_' .. tostring(thing.id), true)
            local ok, err = renderToCanvas(function() bodyEditor.drawUpdateSelectedObjectUI() end)
            assert.is_true(ok, shape .. ': ' .. tostring(err))
        end)
    end

    it('density changes the body mass at once (the old slider needed a rebuild)', function()
        local thing = objectManager.addThing('rectangle', { x = 0, y = 0, width = 100, height = 100 })
        local before = thing.body:getMass()
        for _, row in ipairs(bodyParams.rows) do
            if row.key == 'density' then row.set(thing, row.get(thing) * 2) end
        end
        assert.is_true(math.abs(thing.body:getMass() - 2 * before) < 1e-3 * before)
    end)
end)
