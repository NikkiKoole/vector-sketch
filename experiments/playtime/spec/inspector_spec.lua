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
local sfixtureParams = require('src.sfixture-params')
local sfixtureEditor = require('src.ui.sfixture-editor')
local fixtures = require('src.fixtures')
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
        state.selection.selectedSFixture = nil
        if world and not world:isDestroyed() then world:destroy() end
    end)

    it('puts two checkboxes in a row, a lone one gets its own row', function()
        local target = { a = true, b = false, c = true, n = 1 }
        local params = {
            { key = 'a', kind = 'bool' }, { key = 'b', kind = 'bool' }, { key = 'c', kind = 'bool' },
            { key = 'n', kind = 'number', min = 0, max = 2 },
        }
        local used
        local ok, err = renderToCanvas(function() used = inspector.drawParams('pairs', params, target, nil, 0, 0, 280) end)
        assert.is_true(ok, tostring(err))
        assert.are.equal(3 * inspector.rowHeight, used) -- a+b, c, n
    end)

    local function makeJoint(jointType)
        local a = objectManager.addThing('rectangle', { x = 100, y = 100, width = 40, height = 40 })
        local b = objectManager.addThing('rectangle', { x = 200, y = 160, width = 40, height = 40 })
        local joint = joints.createJoint({ jointType = jointType, body1 = a.body, body2 = b.body,
            offsetA = { x = 0, y = 0 }, offsetB = { x = 0, y = 0 } })
        state.selection.selectedJoint = joint
        return joint
    end

    it('body panel: changing the width while it draws does not touch the destroyed body', function()
        -- a size change rebuilds the body inside the same thing; the panel used to
        -- go on with the old body and crash ("Attempt to use destroyed body")
        local bodyEditor = require('src.ui.body-editor')
        local thing = objectManager.addThing('rectangle', { x = 300, y = 200, width = 50, height = 50 })
        state.selection.selectedObj = thing
        local oldBody = thing.body
        local slider = ui.sliderWithInput
        ui.sliderWithInput = function(id, ...)
            local v = slider(id, ...)
            if id:find('width$') then return 120 end
            return v
        end
        local ok, err = renderToCanvas(function() bodyEditor.drawUpdateSelectedObjectUI() end)
        ui.sliderWithInput = slider
        assert.is_true(ok, tostring(err))
        assert.is_true(oldBody:isDestroyed())
        assert.are.equal(120, thing.width)
    end)

    it('body: label comes first, clone selects the copy, destroy removes the body', function()
        assert.are.equal('label', bodyParams.rows[1].key)
        local byLabel = {}
        for _, row in ipairs(bodyParams.rows) do if row.label then byLabel[row.label] = row end end
        local thing = objectManager.addThing('rectangle', { x = 300, y = 200, width = 50, height = 50 })
        thing.label = 'crate'
        assert.is_true(byLabel.clone.run(thing.body, thing))
        local copy = state.selection.selectedBodies and state.selection.selectedBodies[1]
        assert.is_not_nil(copy)
        assert.are_not.equal(thing, copy)
        assert.are.equal('crate', copy.label)
        state.selection.selectedBodies = nil
        state.selection.selectedObj = thing
        assert.is_true(byLabel.destroy.run(thing.body, thing))
        assert.is_true(thing.body:isDestroyed())
        assert.is_nil(state.selection.selectedObj)
    end)

    it('joint: label reads back and survives a rebuild; destroy removes it', function()
        local joint = makeJoint('revolute')
        local labelRow, destroyRow = jointParams.header[1], jointParams.header[2]
        labelRow.set(joint, 'hinge')
        assert.are.equal('hinge', labelRow.get(joint))
        local rebuilt = joints.recreateJoint(joint, { collideConnected = true })
        assert.are.equal('hinge', labelRow.get(rebuilt))
        local saved = require('src.io').gatherSaveData(world, require('src.camera').getInstance())
        assert.are.equal('hinge', saved.joints[1].label) -- saved with the scene
        local id = joints.getJointId(rebuilt)
        assert.is_true(destroyRow.run(nil, rebuilt))
        assert.is_true(rebuilt:isDestroyed())
        assert.is_nil(registry.getJointByID(id))
    end)

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
                local endsPanel = row.label == 'clone' or row.label == 'destroy' -- own spec below
                if not endsPanel and (not row.visible or row.visible(thing)) then
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

    -- Their hand-made panel had its own copy of N/E/S/W/C that forgot to register the
    -- new fixture (BUG10); its buttons now call placeOnEdge.
    for _, subtype in ipairs({ 'connected-texture', 'trace-vertices' }) do
        it('sfixture (' .. subtype .. '): N/E/S/W/C keep it registered and selected', function()
            local thing = objectManager.addThing('rectangle', { x = 300, y = 200, width = 100, height = 100 })
            local fixture = fixtures.createSFixture(thing.body, 0, 0, subtype, { radius = 20 })
            local id = fixture:getUserData().id
            for _, place in ipairs({ 'N', 'E', 'S', 'W', 'C' }) do
                fixture = sfixtureParams.placeOnEdge(fixture, place)
                assert.is_false(fixture:isDestroyed(), place)
                assert.are.equal(fixture, registry.getSFixtureByID(id), place)
                assert.are.equal(fixture, state.selection.selectedSFixture, place)
            end
        end)
    end

    for subtype, subtypeRows in pairs(sfixtureParams.bySubtype) do
        local function makeFixture()
            local thing = objectManager.addThing('rectangle', { x = 300, y = 200, width = 100, height = 100 })
            local fixture = fixtures.createSFixture(thing.body, 0, 0, subtype, { radius = 20, width = 40, height = 40 })
            state.selection.selectedSFixture = fixture
            return fixture
        end

        it('sfixture (' .. subtype .. '): every setting reads back; moves keep it registered', function()
            local fixture = makeFixture()
            local id = fixture:getUserData().id
            local rows = {}
            for _, row in ipairs(sfixtureParams.header) do rows[#rows + 1] = row end
            for _, row in ipairs(subtypeRows) do rows[#rows + 1] = row end
            for _, row in ipairs(rows) do
                local name = subtype .. ' ' .. tostring(row.key or row.label)
                local results = {}
                if row.kind == 'number' then
                    local v = row.min + (row.max - row.min) * 0.75
                    if row.step then v = math.floor(v) end
                    fixture = row.set(fixture, v) or fixture
                    local got = row.get(fixture)
                    assert.is_true(math.abs(got - v) <= 1e-3 * math.max(1, math.abs(v)),
                        name .. ': set ' .. v .. ', got ' .. tostring(got))
                elseif row.kind == 'text' or row.kind == 'file' or row.kind == 'color' or row.kind == 'choice' then
                    local v = ({ text = 'a label', file = 'x.png', color = 'ff0000ff' })[row.kind]
                        or row.options[#row.options]
                    fixture = row.set(fixture, v) or fixture
                    assert.are.equal(v, row.get(fixture), name)
                elseif row.kind == 'buttons' then
                    for _, option in ipairs(row.options) do
                        fixture = row.run(nil, fixture, option) or fixture
                        results[#results + 1] = fixture
                    end
                elseif row.kind == 'action' and row.label ~= 'destroy' then
                    results[1] = row.run(nil, fixture)
                end
                for _, replaced in ipairs(results) do
                    if replaced then fixture = replaced end
                end
                if #results > 0 or row.kind == 'number' then
                    -- a replaced fixture: alive, selected, registered, same id and label
                    assert.is_false(fixture:isDestroyed(), name)
                    assert.are.equal(fixture, state.selection.selectedSFixture, name)
                    assert.are.equal(fixture, registry.getSFixtureByID(id), name)
                    assert.are.equal(id, fixture:getUserData().id, name)
                end
            end
            assert.are.equal('a label', fixture:getUserData().label)
        end)

        it('sfixture (' .. subtype .. '): destroy removes it and clears the selection', function()
            local fixture = makeFixture()
            for _, row in ipairs(sfixtureParams.footer) do
                if row.label == 'destroy' then assert.is_true(row.run(nil, fixture)) end
            end
            assert.is_true(fixture:isDestroyed())
            assert.is_nil(state.selection.selectedSFixture)
        end)

        it('sfixture (' .. subtype .. '): the panel draws with all rows open', function()
            local fixture = makeFixture()
            inspector.setFoldOpen('sfixture_' .. tostring(fixture:getUserData().id), true)
            local ok, err = renderToCanvas(function() sfixtureEditor.drawSelectedSFixture() end)
            assert.is_true(ok, subtype .. ': ' .. tostring(err))
        end)
    end

    describe('texfixture', function()
        local texfixtureParams = require('src.texfixture-params')

        local function makeTexfixture()
            local thing = objectManager.addThing('rectangle', { x = 300, y = 200, width = 100, height = 100 })
            local fixture = fixtures.createSFixture(thing.body, 0, 0, 'texfixture', { width = 40, height = 40 })
            state.selection.selectedSFixture = fixture
            return fixture
        end

        local sections = {
            position = texfixtureParams.position, texture = texfixtureParams.texture,
            hairs = texfixtureParams.hairs, plasticine = texfixtureParams.plasticine,
            patch1 = texfixtureParams.patch('patch1'),
        }

        for name, rows in pairs(sections) do
            it(name .. ': every setting round-trips', function()
                local fixture = makeTexfixture()
                local savedEdit = { lockedVerts = state.texFixtureEdit.lockedVerts }
                for _, row in ipairs(rows) do
                    local value
                    if row.kind == 'number' then
                        value = math.floor((resolve(row.min, fixture) + resolve(row.max, fixture)) / 2)
                    elseif row.kind == 'bool' then
                        value = not row.get(fixture)
                    elseif row.kind == 'choice' then
                        value = row.options[#row.options]
                    elseif row.kind == 'color' then
                        value = 'ff0000ff'
                    elseif row.kind == 'file' then
                        value = 'spec.png'
                    end
                    if value ~= nil then
                        local replaced = row.set(fixture, value)
                        if replaced then fixture = replaced end
                        local got = row.get(fixture)
                        if type(value) == 'number' then
                            assert.is_true(math.abs(got - value) <= 1, name .. ' ' .. row.key .. ': ' .. tostring(got))
                        else
                            assert.are.equal(value, got, name .. ' ' .. row.key)
                        end
                    end
                end
                state.texFixtureEdit.lockedVerts = savedEdit.lockedVerts
                state.texFixtureEdit.tempVerts = nil
            end)
        end

        it('a new image marks the texture dirty; a colour drops the cached composite', function()
            local fixture = makeTexfixture()
            local extra = fixture:getUserData().extra
            extra.dirty = false
            extra.main = { cached = 'old' }
            for _, row in ipairs(texfixtureParams.texture) do
                if row.label == 'bg' then row.set(fixture, 'a.png') end
            end
            assert.is_true(extra.dirty)
            for _, row in ipairs(texfixtureParams.texture) do
                if row.label == 'bg color' then row.set(fixture, 'ffffffff') end
            end
            assert.is_nil(extra.main.cached)
        end)

        it('size from body replaces the fixture and selects it', function()
            local fixture = makeTexfixture()
            for _, row in ipairs(texfixtureParams.position) do
                if row.key == 'size from' then
                    local newFixture = row.run(nil, fixture, 'body')
                    assert.is_true(fixture:isDestroyed())
                    assert.are.equal(newFixture, state.selection.selectedSFixture)
                    local w = select(1, require('src.math-utils').getPolygonDimensions({ newFixture:getShape():getPoints() }))
                    assert.is_true(math.abs(w - 100) < 1, 'width ' .. w)
                end
            end
            state.texFixtureEdit.tempVerts = nil
        end)

        it('the panel draws with everything open (hairs, plasticine, OMP)', function()
            local fixture = makeTexfixture()
            local extra = fixture:getUserData().extra
            extra.hairs, extra.plasticine = true, true
            sfixtureEditor.setAllAccordions(true)
            local id = tostring(fixture:getUserData().id)
            for _, name in ipairs({ 'position', 'texture', 'hairs', 'plasticine', 'patch1', 'patch2', 'patch3' }) do
                inspector.setFoldOpen('texfix_' .. name .. '_' .. id, true)
            end
            for _, omp in ipairs({ false, true }) do
                extra.OMP = omp
                local ok, err = renderToCanvas(function() sfixtureEditor.drawSelectedSFixture() end)
                assert.is_true(ok, tostring(err))
            end
            sfixtureEditor.setAllAccordions(false)
        end)
    end)

    describe('world settings', function()
        local worldParams = require('src.world-params')
        local uiWorldSettings = require('src.ui.world-settings')

        it('every setting round-trips (gravity reaches the physics world)', function()
            local target = {}
            for k, v in pairs(state.world) do target[k] = v end
            local savedGrid = state.editorPreferences.showGrid
            for _, row in ipairs(worldParams.rows) do
                if row.kind == 'number' then
                    local v = (resolve(row.min, target) + resolve(row.max, target)) / 2
                    row.set(target, v)
                    assert.are.equal(v, row.get(target), row.key)
                elseif row.kind == 'bool' then
                    for _, v in ipairs({ true, false }) do
                        row.set(target, v)
                        assert.are.equal(v, row.get(target), row.key)
                    end
                end
            end
            local _, gy = world:getGravity()
            assert.is_true(math.abs(target.gravity * target.meter - gy) < 0.01)
            state.editorPreferences.showGrid = savedGrid
        end)

        it('the panel draws with all rows open', function()
            inspector.setFoldOpen('world', true)
            local ok, err = renderToCanvas(function() uiWorldSettings.drawWorldSettingsUI() end)
            inspector.setFoldOpen('world', false)
            assert.is_true(ok, tostring(err))
        end)

        it('backdrop rows default to scale 1, off, and write the backdrop', function()
            local bd = { url = 'x.png' }
            local byKey = {}
            for _, row in ipairs(worldParams.backdropRows) do byKey[row.key] = row end
            assert.are.equal(false, byKey.foreground.get(bd))
            local ok = renderToCanvas(function()
                inspector.drawParams('backdrop', worldParams.backdropRows, bd, nil, 0, 0, 280)
            end)
            assert.is_true(ok)
            bd.foreground, bd.border = true, true
            assert.is_true(byKey.foreground.get(bd) and byKey.border.get(bd))
        end)
    end)
end)
