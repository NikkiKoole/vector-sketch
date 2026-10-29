-- spec/ui-overflow_spec.lua
-- Do the side panels fit the window? Each panel is drawn fully open (every
-- accordion and '+ more' fold) and ui.contentBottom (src/ui/all.lua: the lowest
-- widget edge, scroll areas excluded) must stay above the panel's bottom edge
-- (y 748 at 1200x768). Panels whose content can be taller sit in a
-- ui.scrollPanel, so they pass by scrolling. Also: the scroll panel itself.
-- Run with: love . --specs spec/ui-overflow_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local joints = require('src.joints')
local fixtures = require('src.fixtures')
local objectManager = require('src.object-manager')
local jointParams = require('src.joint-params')
local ui = require('src.ui.all')
local inspector = require('src.ui.inspector')
local bodyEditor = require('src.ui.body-editor')
local sfixtureEditor = require('src.ui.sfixture-editor')
local uiJointUpdate = require('src.ui.joint-update')
local rightColumn = require('src.ui.right-column')

local WINDOW_H = 768

local function measure(fn)
    local canvas = love.graphics.newCanvas(1200, WINDOW_H)
    love.graphics.setCanvas(canvas)
    ui.contentBottom = 0
    local ok, err = pcall(fn)
    love.graphics.setCanvas()
    canvas:release()
    assert.is_true(ok, tostring(err))
    return ui.contentBottom
end

describe('panels fit the window (1200x768, fully open)', function()
    local world

    setup(function()
        local font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        bodyEditor.setAllAccordions(true)
        sfixtureEditor.setAllAccordions(true)
    end)

    teardown(function()
        bodyEditor.setAllAccordions(false)
        sfixtureEditor.setAllAccordions(false)
    end)

    before_each(function()
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()
        ui.startFrame()
    end)

    after_each(function()
        state.selection.selectedObj = nil
        state.selection.selectedJoint = nil
        state.selection.selectedSFixture = nil
        if world and not world:isDestroyed() then world:destroy() end
    end)

    local PANEL_BOTTOM = WINDOW_H - 20
    local function check(name, bottom)
        assert.is_true(bottom <= PANEL_BOTTOM, name .. ' runs off the panel: bottom ' .. bottom .. ' > ' .. PANEL_BOTTOM)
    end

    for _, shape in ipairs({ 'rectangle', 'torso', 'custom' }) do
        it('body panel: ' .. shape, function()
            local thing = objectManager.addThing(shape, { x = 300, y = 200, width = 100, height = 100, width2 = 90, width3 = 80, height2 = 30, height3 = 30, height4 = 30,
                vertices = { -50, -50, 50, -50, 50, 50, -50, 50 } })
            local other = objectManager.addThing('rectangle', { x = 500, y = 200, width = 40, height = 40 })
            thing.behaviors = { { name = 'KEEP_ANGLE', angle = 0 }, { name = 'SQUISHY' } }
            joints.createJoint({ jointType = 'revolute', body1 = thing.body, body2 = other.body,
                offsetA = { x = 0, y = 0 }, offsetB = { x = 0, y = 0 } })
            fixtures.createSFixture(thing.body, 0, 0, 'snap', { radius = 10 })
            fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            state.selection.selectedObj = thing
            inspector.setFoldOpen('body_' .. tostring(thing.id), true)
            check('body ' .. shape, measure(function() bodyEditor.drawUpdateSelectedObjectUI() end))
            check('body in column ' .. shape, measure(function()
                bodyEditor.drawUpdateSelectedObjectUI(rightColumn.contentRect())
            end))
        end)
    end

    for jointType in pairs(jointParams.byType) do
        it('joint panel: ' .. jointType, function()
            local a = objectManager.addThing('rectangle', { x = 100, y = 100, width = 40, height = 40 })
            local b = objectManager.addThing('rectangle', { x = 200, y = 160, width = 40, height = 40 })
            local joint = joints.createJoint({ jointType = jointType, body1 = a.body, body2 = b.body,
                offsetA = { x = 0, y = 0 }, offsetB = { x = 0, y = 0 } })
            for _, row in ipairs(jointParams.byType[jointType]) do
                if row.key == 'limits' or row.key == 'motor' then row.set(joint, true) end
            end
            inspector.setFoldOpen('joint_' .. tostring(joints.getJointId(joint)), true)
            check('joint ' .. jointType, measure(function()
                uiJointUpdate.drawJointUpdateUI(joint, 880, 20, 300, WINDOW_H - 40)
            end))
            check('joint in column ' .. jointType, measure(function()
                uiJointUpdate.drawJointUpdateUI(joint, rightColumn.contentRect())
            end))
        end)
    end

    for _, subtype in ipairs({ 'snap', 'anchor', 'texfixture', 'connected-texture', 'trace-vertices',
        'tile-repeat', 'resource', 'uvusert', 'meshusert', 'light', 'grass', 'liquid' }) do
        it('sfixture panel: ' .. subtype, function()
            local thing = objectManager.addThing('rectangle', { x = 300, y = 200, width = 100, height = 100 })
            local fixture = fixtures.createSFixture(thing.body, 0, 0, subtype, { radius = 20, width = 40, height = 40 })
            assert.is_not_nil(fixture, subtype)
            state.selection.selectedSFixture = fixture
            check('sfixture ' .. subtype, measure(function() sfixtureEditor.drawSelectedSFixture() end))
            check('sfixture in column ' .. subtype, measure(function()
                sfixtureEditor.drawSelectedSFixture(rightColumn.contentRect())
            end))
        end)
    end

    it('world settings panel', function()
        inspector.setFoldOpen('world', true)
        local uiWorldSettings = require('src.ui.world-settings')
        measure(function() uiWorldSettings.drawWorldSettingsUI() end) -- first frame sizes the panel
        check('world settings', measure(function() uiWorldSettings.drawWorldSettingsUI() end))
        inspector.setFoldOpen('world', false)
    end)

    it('settings camera section, with bounds and the advanced rows', function()
        local state = require('src.state')
        local cameraFollow = require('src.camera-follow')
        local folds = state.settingsFolds
        state.settingsFolds = { camera = true }
        cameraFollow.settings().bounds = { -500, -400, 500, 400 }
        inspector.setFoldOpen('camera', true)
        local uiWorldSettings = require('src.ui.world-settings')
        measure(function() uiWorldSettings.drawWorldSettingsUI() end)
        check('camera settings', measure(function() uiWorldSettings.drawWorldSettingsUI() end))
        inspector.setFoldOpen('camera', false)
        cameraFollow.settings().bounds = nil
        state.settingsFolds = folds
    end)

    describe('ui.scrollPanel', function()
        local function frame(mx, my, pressed, released, draw)
            ui.startFrame()
            ui.mouseX, ui.mouseY = mx, my
            ui.mousePressed, ui.mouseReleased = pressed, released
            local result
            measure(function() result = draw() end)
            return result
        end

        -- a 200 px high region holding buttons every 50 px down to y 1000
        local function tallContent()
            local clicked
            ui.scrollPanel('spec-scroll', 0, 100, 300, 200, function()
                for i = 0, 18 do
                    if ui.button(10, 100 + i * 50, 200, 'b' .. i) then clicked = i end
                end
            end)
            return clicked
        end

        it('scrolls tall content, counts it as fitting, and clicks follow the scroll', function()
            ui._scrollers['spec-scroll'] = nil
            frame(0, 0, false, false, tallContent) -- first frame measures the content
            assert.is_true(ui._scrollers['spec-scroll'].contentHeight > 200)
            assert.is_true(ui.contentBottom <= 300, 'scrolled content must not count as overflow')
            ui._scrollers['spec-scroll'].value = 500
            -- the pointer at screen y 110 is content y 610: button 10 (y 600..625)
            frame(50, 110, true, false, tallContent)
            assert.are.equal(10, frame(50, 110, false, true, tallContent))
        end)

        it('a pointer outside the region reaches no hidden button', function()
            ui._scrollers['spec-scroll'] = { value = 500, contentHeight = 1000 }
            -- screen y 50 is above the region; unshifted it would hit hidden button 0..
            frame(50, 50, true, false, tallContent)
            assert.is_nil(frame(50, 50, false, true, tallContent))
        end)
    end)
end)
