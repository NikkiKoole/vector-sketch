-- spec/ui-smoke_spec.lua
-- Smoke tests for UI panels: render each panel to a canvas and verify no errors.
-- Requires LÖVE — run via: love . --specs spec/ui-smoke_spec.lua

if not love then return end

local state = require('src.state')
local ui = require('src.ui-all')
local registry = require('src.registry')
local fixtures = require('src.fixtures')
local joints = require('src.joints')
local objectManager = require('src.object-manager')

-- We require playtime-ui inside a setup block so state.physicsWorld is ready
local playtimeui

local WINDOW_W, WINDOW_H = 1200, 768

-- Helper: render a function to an offscreen canvas, return ok + error
local function renderToCanvas(fn)
    local canvas = love.graphics.newCanvas(WINDOW_W, WINDOW_H)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    local ok, err = pcall(fn)
    love.graphics.setCanvas()
    canvas:release()
    return ok, err
end

-- Helper: create a physics body with proper thing/userdata
local function createBody(world, shape, opts)
    opts = opts or {}
    opts.x = opts.x or 100
    opts.y = opts.y or 100
    opts.width = opts.width or 40
    opts.height = opts.height or 40
    opts.radius = opts.radius or 20
    return objectManager.addThing(shape or 'rectangle', opts)
end

describe("UI smoke tests", function()
    local world
    local font

    setup(function()
        -- Init font and UI once
        font = love.graphics.newFont(12)
        love.graphics.setFont(font)
        ui.init(font, font:getHeight())
        playtimeui = require('src.playtime-ui')
    end)

    before_each(function()
        -- Fresh world and registry per test
        world = love.physics.newWorld(0, 0, true)
        state.physicsWorld = world
        registry.reset()

        -- Clear selection
        state.selection.selectedObj = nil
        state.selection.selectedJoint = nil
        state.selection.selectedSFixture = nil
        state.selection.selectedBodies = nil

        -- Clear all panel visibility
        state.panelVisibility.addShapeOpened = false
        state.panelVisibility.addJointOpened = false
        state.panelVisibility.worldSettingsOpened = false
        state.panelVisibility.bgSettingsOpened = false
        state.panelVisibility.recordingPanelOpened = false
        state.panelVisibility.saveDialogOpened = false
        state.panelVisibility.quitDialogOpened = false
        state.panelVisibility.showPalette = nil
        state.panelVisibility.addBehavior = false
        state.panelVisibility.customBehavior = false
        state.panelVisibility.customBehaviorDescription = false

        -- Clear modes
        state.currentMode = nil
        state.jointParams = nil
        state.showPaletteFunc = nil
        state.pickAutoRopifyModeHitted = nil

        -- Reset edit states
        state.texFixtureEdit.tempVerts = nil
        state.texFixtureEdit.centroid = nil
        state.texFixtureEdit.lockedVerts = true
        state.texFixtureEdit.dragIdx = 0

        state.polyEdit.tempVerts = nil
        state.polyEdit.centroid = nil
        state.polyEdit.lockedVerts = true
        state.polyEdit.dragIdx = 0

        -- Reset interaction state
        state.interaction.polyVerts = {}
        state.interaction.lastPolyPt = nil

        -- Start a UI frame (sets mouse state, resets IDs)
        ui.startFrame()
    end)

    after_each(function()
        -- Destroy all bodies before destroying world
        if world and not world:isDestroyed() then
            local bodies = world:getBodies()
            for _, body in ipairs(bodies) do
                body:setUserData(nil)
                body:destroy()
            end
            world:destroy()
        end
        world = nil
        state.physicsWorld = nil
    end)

    -- === Panels that need no selection ===

    it("drawUI renders with no selection (base toolbar)", function()
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawUI base failed: " .. tostring(err))
    end)

    it("drawAddShapeUI renders", function()
        state.panelVisibility.addShapeOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawAddShapeUI failed: " .. tostring(err))
    end)

    it("drawAddJointUI renders", function()
        state.panelVisibility.addJointOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawAddJointUI failed: " .. tostring(err))
    end)

    it("drawWorldSettingsUI renders", function()
        state.panelVisibility.worldSettingsOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawWorldSettingsUI failed: " .. tostring(err))
    end)

    it("drawBGSettingsUI renders", function()
        state.panelVisibility.bgSettingsOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawBGSettingsUI failed: " .. tostring(err))
    end)

    it("drawRecordingUI renders", function()
        state.panelVisibility.recordingPanelOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawRecordingUI failed: " .. tostring(err))
    end)

    it("save dialog renders", function()
        state.panelVisibility.saveDialogOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "save dialog failed: " .. tostring(err))
    end)

    it("quit dialog renders", function()
        state.panelVisibility.quitDialogOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "quit dialog failed: " .. tostring(err))
    end)

    -- === Panels that need a selected body ===

    it("drawUpdateSelectedObjectUI renders with selected body", function()
        local thing = createBody(world, 'rectangle')
        state.selection.selectedObj = thing
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawUpdateSelectedObjectUI failed: " .. tostring(err))
    end)

    it("drawSelectedBodiesUI renders with multiple bodies selected", function()
        local thing1 = createBody(world, 'rectangle', { x = 100, y = 100 })
        local thing2 = createBody(world, 'circle', { x = 200, y = 200 })
        state.selection.selectedBodies = { thing1, thing2 }
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawSelectedBodiesUI failed: " .. tostring(err))
    end)

    -- === Joint panels ===

    it("drawJointUpdateUI renders with selected joint", function()
        local thing1 = createBody(world, 'rectangle', { x = 100, y = 100 })
        local thing2 = createBody(world, 'rectangle', { x = 200, y = 200 })
        local joint = joints.createJoint({
            jointType = 'revolute',
            body1 = thing1.body,
            body2 = thing2.body,
            offsetA = { x = 0, y = 0 },
            offsetB = { x = 0, y = 0 },
        })
        state.selection.selectedObj = thing1
        state.selection.selectedJoint = joint
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawJointUpdateUI (revolute) failed: " .. tostring(err))
    end)

    it("drawJointUpdateUI renders with distance joint", function()
        local thing1 = createBody(world, 'rectangle', { x = 100, y = 100 })
        local thing2 = createBody(world, 'rectangle', { x = 200, y = 200 })
        local joint = joints.createJoint({
            jointType = 'distance',
            body1 = thing1.body,
            body2 = thing2.body,
            offsetA = { x = 0, y = 0 },
            offsetB = { x = 0, y = 0 },
            p1 = { 0, 0 },
            p2 = { 0, 0 },
        })
        state.selection.selectedObj = thing1
        state.selection.selectedJoint = joint
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawJointUpdateUI (distance) failed: " .. tostring(err))
    end)

    it("drawJointUpdateUI renders with rope joint", function()
        local thing1 = createBody(world, 'rectangle', { x = 100, y = 100 })
        local thing2 = createBody(world, 'rectangle', { x = 200, y = 200 })
        local joint = joints.createJoint({
            jointType = 'rope',
            body1 = thing1.body,
            body2 = thing2.body,
            offsetA = { x = 0, y = 0 },
            offsetB = { x = 0, y = 0 },
            p1 = { 0, 0 },
            p2 = { 0, 0 },
        })
        state.selection.selectedObj = thing1
        state.selection.selectedJoint = joint
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawJointUpdateUI (rope) failed: " .. tostring(err))
    end)

    it("joint creation UI renders", function()
        local thing1 = createBody(world, 'rectangle', { x = 100, y = 100 })
        local thing2 = createBody(world, 'rectangle', { x = 200, y = 200 })
        state.currentMode = 'jointCreationMode'
        state.jointParams = {
            body1 = thing1.body,
            body2 = thing2.body,
            jointType = 'revolute',
        }
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "joint creation UI failed: " .. tostring(err))
    end)

    -- === SFixture panels ===

    describe("drawSelectedSFixture", function()
        local subtypes = { 'snap', 'anchor', 'texfixture', 'connected-texture',
                           'trace-vertices', 'tile-repeat', 'resource', 'uvusert', 'meshusert' }

        for _, subtype in ipairs(subtypes) do
            it("renders with " .. subtype .. " sfixture selected", function()
                local thing = createBody(world, 'rectangle')
                local fixture = fixtures.createSFixture(thing.body, 0, 0, subtype, {
                    radius = 20, width = 40, height = 40
                })
                state.selection.selectedSFixture = fixture
                local ok, err = renderToCanvas(function()
                    playtimeui.drawUI()
                end)
                assert.is_true(ok, "drawSelectedSFixture (" .. subtype .. ") failed: " .. tostring(err))
            end)
        end
    end)

    -- === Mode-specific hint panels ===

    it("pickAutoRopifyMode panel renders", function()
        state.currentMode = 'pickAutoRopifyMode'
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "pickAutoRopifyMode failed: " .. tostring(err))
    end)

    it("drawClickMode panel renders", function()
        state.currentMode = 'drawClickMode'
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "drawClickMode failed: " .. tostring(err))
    end)

    it("setOffsetA hint panel renders", function()
        state.currentMode = 'setOffsetA'
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "setOffsetA hint failed: " .. tostring(err))
    end)

    it("joint creation pick-body panels render", function()
        state.currentMode = 'jointCreationMode'
        state.jointParams = { body1 = nil, body2 = nil }
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "joint pick-body panels failed: " .. tostring(err))
    end)

    -- === Modal dialogs ===

    it("customBehaviorDescription modal renders", function()
        state.panelVisibility.customBehaviorDescription = "This is a test behavior description."
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "customBehaviorDescription failed: " .. tostring(err))
    end)

    -- === Combined panels (stress test) ===

    it("multiple panels open simultaneously", function()
        state.panelVisibility.addShapeOpened = true
        state.panelVisibility.worldSettingsOpened = true
        state.panelVisibility.recordingPanelOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "multiple panels failed: " .. tostring(err))
    end)

    it("body panel with all toolbar panels open", function()
        local thing = createBody(world, 'rectangle')
        state.selection.selectedObj = thing
        state.panelVisibility.addShapeOpened = true
        state.panelVisibility.addJointOpened = true
        state.panelVisibility.worldSettingsOpened = true
        local ok, err = renderToCanvas(function()
            playtimeui.drawUI()
        end)
        assert.is_true(ok, "body + toolbars failed: " .. tostring(err))
    end)
end)
