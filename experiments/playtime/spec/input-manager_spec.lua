-- spec/input-manager_spec.lua
-- Integration tests for handlePointer mode dispatch in input-manager.lua
-- Tests exercise the public InputManager API (handleMousePressed/Released)
-- with state.currentMode set to each mode, verifying state changes.
-- Run with: love . --specs spec/input-manager_spec.lua

if not love then return end

-- Fresh-require modules
package.loaded['src.registry'] = nil
package.loaded['src.object-manager'] = nil
package.loaded['src.joints'] = nil
package.loaded['src.fixtures'] = nil
package.loaded['src.state'] = nil
package.loaded['src.input-manager'] = nil
package.loaded['src.camera'] = nil
package.loaded['src.physics.box2d-pointerjoints'] = nil

local registry = require('src.registry')
local objectManager = require('src.object-manager')
local joints = require('src.joints')
local fixtures = require('src.fixtures')
local state = require('src.state')
local InputManager = require('src.input-manager')
local camera = require('src.camera')
local cam = camera.getInstance()

-- ─── Helpers ───

local function makeWorld()
    return love.physics.newWorld(0, 0, true) -- no gravity for predictable positions
end

-- Convert screen coordinates to world coordinates (accounts for camera offset)
local function s2w(sx, sy)
    return cam:getWorldCoordinates(sx, sy)
end

local function addBody(shapeType, x, y, opts)
    opts = opts or {}
    return objectManager.addThing(shapeType, {
        x = x or 100, y = y or 100,
        bodyType = opts.bodyType or 'dynamic',
        radius = opts.radius or 20,
        width = opts.width or 40,
        width2 = opts.width2 or 40,
        width3 = opts.width3 or 40,
        height = opts.height or 40,
        height2 = opts.height2 or 40,
        height3 = opts.height3 or 40,
        height4 = opts.height4 or 40,
        label = opts.label or '',
    })
end

-- Add a body at the world position that screen coords (sx, sy) map to
local function addBodyAtScreen(shapeType, sx, sy, opts)
    local wx, wy = s2w(sx, sy)
    return addBody(shapeType, wx, wy, opts)
end

local function resetInteractionState()
    state.selection.selectedObj = nil
    state.selection.selectedJoint = nil
    state.selection.selectedSFixture = nil
    state.selection.selectedBodies = nil
    state.currentMode = nil
    state.interaction.draggingObj = nil
    state.interaction.offsetDragging = { nil, nil }
    state.interaction.polyVerts = {}
    state.interaction.lastPolyPt = nil
    state.interaction.startSelection = nil
    state.interaction.pressMissedEverything = false
    state.interaction.capturingPoly = false
    state.polyEdit.dragIdx = 0
    state.polyEdit.tempVerts = nil
    state.polyEdit.lockedVerts = true
    state.polyEdit.centroid = nil
    state.texFixtureEdit.dragIdx = 0
    state.texFixtureEdit.tempVerts = nil
    state.texFixtureEdit.lockedVerts = true
    state.texFixtureEdit.centroid = nil
    state.panelVisibility.saveDialogOpened = false
    state.panelVisibility.showPalette = false
    state.panelVisibility.addBehavior = false
    state.panelVisibility.customBehavior = false
    state.panelVisibility.addJointOpened = false
    state.panelVisibility.addShapeOpened = false
    state.panelVisibility.bgSettingsOpened = false
    state.panelVisibility.worldSettingsOpened = false
    state.panelVisibility.recordingPanelOpened = false
    state.world.paused = true
    state.world.mouseForce = 100
    state.world.mouseDamping = 0.5
    state.jointParams = {}
    state.pickAutoRopifyModeHitted = nil
    state.scene = state.scene or {}
    state.scene.sceneScript = nil
end

local function press(x, y)
    InputManager.handleMousePressed(x, y, 1, false)
end

local function release(x, y)
    InputManager.handleMouseReleased(x, y, 1, false)
end

-- Screen positions for testing (left half, away from right panel)
-- These are screen coords; bodies placed with addBodyAtScreen will be at matching world pos
local SX1, SY1 = 300, 300  -- first click position
local SX2, SY2 = 500, 300  -- second click position (different body)
local EMPTY_SX, EMPTY_SY = 100, 100 -- empty space (no bodies here)

-- ─── Tests ───

describe("input-manager: handlePointer mode dispatch", function()

    before_each(function()
        state.physicsWorld = makeWorld()
        registry.reset()
        cam:setTranslation(0, 0)
        cam:setScale(1)
        resetInteractionState()
    end)

    after_each(function()
        if state.physicsWorld and not state.physicsWorld:isDestroyed() then
            state.physicsWorld:destroy()
        end
    end)

    -- ═══════════════════════════════════════════════════════
    -- GUARD CLAUSES
    -- ═══════════════════════════════════════════════════════

    describe("guard clauses", function()
        it("ignores press in editMeshTriangles mode", function()
            addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.currentMode = 'editMeshTriangles'
            press(SX1, SY1)
            assert.is_nil(state.selection.selectedObj)
        end)

        it("ignores press when save dialog is open", function()
            addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.panelVisibility.saveDialogOpened = true
            press(SX1, SY1)
            assert.is_nil(state.selection.selectedObj)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- drawClickMode
    -- ═══════════════════════════════════════════════════════

    describe("drawClickMode", function()
        it("adds world coordinates to polyVerts on press", function()
            state.currentMode = 'drawClickMode'
            state.interaction.polyVerts = {}
            press(SX1, SY1)
            assert.are.equal(2, #state.interaction.polyVerts)
        end)

        it("does not add verts when pressing in right panel area", function()
            state.currentMode = 'drawClickMode'
            state.interaction.polyVerts = {}
            -- Press in the right panel area (x > w - 300 = 900)
            press(950, 200)
            assert.are.equal(0, #state.interaction.polyVerts)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- setOffsetA
    -- ═══════════════════════════════════════════════════════

    describe("setOffsetA", function()
        it("updates joint offset A and clears mode", function()
            local wx1, wy1 = s2w(SX1, SY1)
            local wx2, wy2 = s2w(SX2, SY2)
            local t1 = addBody('rectangle', wx1, wy1)
            local t2 = addBody('rectangle', wx2, wy2)
            local joint = joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })
            state.selection.selectedJoint = joint
            state.currentMode = 'setOffsetA'

            press(SX1, SY1)

            assert.is_nil(state.currentMode)
            assert.is_not_nil(state.selection.selectedJoint)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- setOffsetB
    -- ═══════════════════════════════════════════════════════

    describe("setOffsetB", function()
        it("updates joint offset B and clears mode", function()
            local wx1, wy1 = s2w(SX1, SY1)
            local wx2, wy2 = s2w(SX2, SY2)
            local t1 = addBody('rectangle', wx1, wy1)
            local t2 = addBody('rectangle', wx2, wy2)
            local joint = joints.createJoint({
                body1 = t1.body, body2 = t2.body,
                jointType = 'revolute',
            })
            state.selection.selectedJoint = joint
            state.currentMode = 'setOffsetB'

            press(SX2, SY2)

            assert.is_nil(state.currentMode)
            assert.is_not_nil(state.selection.selectedJoint)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- positioningSFixture
    -- ═══════════════════════════════════════════════════════

    describe("positioningSFixture", function()
        it("repositions sfixture and clears mode", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            state.selection.selectedSFixture = sf
            state.currentMode = 'positioningSFixture'

            press(SX1 + 10, SY1 + 5)

            assert.is_nil(state.currentMode)
            assert.is_not_nil(state.selection.selectedSFixture)
        end)

        it("copies vertices to tempVerts if sfixture has vertices", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 0, 0, 'texfixture', {
                width = 40, height = 40,
            })
            -- texfixture already gets extra.vertices from createSFixture
            state.selection.selectedSFixture = sf
            state.currentMode = 'positioningSFixture'

            press(SX1 + 10, SY1 + 5)

            assert.is_nil(state.currentMode)
            assert.is_not_nil(state.texFixtureEdit.tempVerts)
            assert.is_true(#state.texFixtureEdit.tempVerts > 0)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- addNodeToConnectedTexture / addNodeToMeshUsert
    -- ═══════════════════════════════════════════════════════

    describe("addNode modes", function()
        it("adds anchor node when pressing near an anchor sfixture", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            local anchor = fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            local anchorId = anchor:getUserData().id

            local texfix = fixtures.createSFixture(thing.body, 20, 20, 'texfixture', {
                width = 40, height = 40,
            })

            state.selection.selectedSFixture = texfix
            state.currentMode = 'addNodeToConnectedTexture'

            -- Press at body center where anchor is
            press(SX1, SY1)

            local ud = state.selection.selectedSFixture:getUserData()
            assert.is_not_nil(ud.extra.nodes)
            assert.are.equal(1, #ud.extra.nodes)
            assert.are.equal('anchor', ud.extra.nodes[1].type)
            assert.are.equal(anchorId, ud.extra.nodes[1].id)
        end)

        it("clears mode when pressing far from any anchor/joint", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            local texfix = fixtures.createSFixture(thing.body, 0, 0, 'texfixture', {
                width = 40, height = 40,
            })

            state.selection.selectedSFixture = texfix
            state.currentMode = 'addNodeToMeshUsert'

            -- Press far away from everything
            press(EMPTY_SX, EMPTY_SY)

            assert.is_nil(state.currentMode)
        end)

        it("does not add duplicate consecutive nodes", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            local anchor = fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            local anchorId = anchor:getUserData().id

            local texfix = fixtures.createSFixture(thing.body, 20, 20, 'texfixture', {
                width = 40, height = 40,
            })
            local tud = texfix:getUserData()
            tud.extra.nodes = { { type = 'anchor', id = anchorId } }
            texfix:setUserData(tud)

            state.selection.selectedSFixture = texfix
            state.currentMode = 'addNodeToConnectedTexture'

            -- Press at anchor again — same ID as last added
            press(SX1, SY1)

            local ud = state.selection.selectedSFixture:getUserData()
            assert.are.equal(1, #ud.extra.nodes)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- pickAutoRopifyMode
    -- ═══════════════════════════════════════════════════════

    describe("pickAutoRopifyMode", function()
        it("sets pickAutoRopifyModeHitted when pressing on a body", function()
            addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.currentMode = 'pickAutoRopifyMode'

            press(SX1, SY1)

            assert.is_not_nil(state.pickAutoRopifyModeHitted)
            assert.are.equal('pickAutoRopifyMode', state.currentMode)
        end)

        it("clears mode when pressing empty space", function()
            addBodyAtScreen('rectangle', SX1, SY1, { width = 40, height = 40 })
            state.currentMode = 'pickAutoRopifyMode'

            press(EMPTY_SX, EMPTY_SY)

            assert.is_nil(state.currentMode)
            assert.is_nil(state.pickAutoRopifyModeHitted)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- jointCreationMode
    -- ═══════════════════════════════════════════════════════

    describe("jointCreationMode", function()
        it("sets body1 on first press", function()
            local t1 = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.currentMode = 'jointCreationMode'
            state.jointParams = {}

            press(SX1, SY1)

            assert.are.equal(t1.body, state.jointParams.body1)
            assert.is_not_nil(state.jointParams.p1)
            assert.is_nil(state.jointParams.body2)
        end)

        it("sets body2 on second press on different body", function()
            addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            addBodyAtScreen('rectangle', SX2, SY2, { width = 80, height = 80 })
            state.currentMode = 'jointCreationMode'
            state.jointParams = {}

            press(SX1, SY1)
            release(SX1, SY1)

            press(SX2, SY2)

            assert.is_not_nil(state.jointParams.body1)
            assert.is_not_nil(state.jointParams.body2)
            assert.are_not.equal(state.jointParams.body1, state.jointParams.body2)
        end)

        it("does not set body2 when pressing on same body as body1", function()
            addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.currentMode = 'jointCreationMode'
            state.jointParams = {}

            press(SX1, SY1)
            release(SX1, SY1)

            press(SX1, SY1)

            assert.is_not_nil(state.jointParams.body1)
            assert.is_nil(state.jointParams.body2)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- DEFAULT SELECTION (no special mode)
    -- ═══════════════════════════════════════════════════════

    describe("default selection", function()
        it("selects a body when pressing on it (paused)", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.world.paused = true

            press(SX1, SY1)

            assert.is_not_nil(state.selection.selectedObj)
            assert.are.equal(thing.id, state.selection.selectedObj.id)
        end)

        it("starts dragging when pressing on selected body (paused, lockedVerts)", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.world.paused = true
            state.polyEdit.lockedVerts = true

            press(SX1, SY1)

            assert.is_not_nil(state.interaction.draggingObj)
            assert.are.equal(thing.id, state.interaction.draggingObj.id)

            release(SX1, SY1)

            assert.is_nil(state.interaction.draggingObj)
            assert.is_not_nil(state.selection.selectedObj)
            assert.are.equal(thing.id, state.selection.selectedObj.id)
        end)

        it("sets pressMissedEverything when pressing empty space", function()
            press(EMPTY_SX, EMPTY_SY)
            assert.is_true(state.interaction.pressMissedEverything)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- DESELECTION (release after missing everything)
    -- ═══════════════════════════════════════════════════════

    describe("deselection on miss", function()
        it("clears selectedObj when pressing and releasing on empty space", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            -- First select the body
            press(SX1, SY1)
            release(SX1, SY1)
            assert.is_not_nil(state.selection.selectedObj)

            -- Now press and release on empty space
            press(EMPTY_SX, EMPTY_SY)
            release(EMPTY_SX, EMPTY_SY)

            assert.is_nil(state.selection.selectedObj)
        end)

        it("deselects sfixture back to body on miss", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 0, 0, 'anchor', { radius = 10 })
            state.selection.selectedSFixture = sf
            state.selection.selectedObj = nil

            press(EMPTY_SX, EMPTY_SY)
            release(EMPTY_SX, EMPTY_SY)

            assert.is_nil(state.selection.selectedSFixture)
            assert.is_not_nil(state.selection.selectedObj)
            assert.are.equal(thing.id, state.selection.selectedObj.id)
        end)

        it("clears panel visibility on miss", function()
            state.panelVisibility.addShapeOpened = true
            state.panelVisibility.addJointOpened = true
            state.panelVisibility.worldSettingsOpened = true

            press(EMPTY_SX, EMPTY_SY)
            release(EMPTY_SX, EMPTY_SY)

            assert.is_false(state.panelVisibility.addShapeOpened)
            assert.is_false(state.panelVisibility.addJointOpened)
            assert.is_false(state.panelVisibility.worldSettingsOpened)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- RELEASE HANDLERS
    -- ═══════════════════════════════════════════════════════

    describe("released handlers", function()
        it("clears pressMissedEverything on release", function()
            state.interaction.pressMissedEverything = true
            release(EMPTY_SX, EMPTY_SY)
            assert.is_false(state.interaction.pressMissedEverything)
        end)

        it("finalizes drag on release", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.interaction.draggingObj = thing
            state.selection.selectedObj = nil

            release(SX1, SY1)

            assert.is_nil(state.interaction.draggingObj)
            assert.is_not_nil(state.selection.selectedObj)
            assert.are.equal(thing.id, state.selection.selectedObj.id)
        end)
    end)

    -- ═══════════════════════════════════════════════════════
    -- VERTEX DRAG FINALIZATION
    -- ═══════════════════════════════════════════════════════

    describe("vertex drag finalization", function()
        it("resets polyEdit dragIdx on release", function()
            -- Need a selectedObj for maybeUpdateCustomPolygonVertices
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            state.selection.selectedObj = thing
            state.polyEdit.dragIdx = 3
            state.polyEdit.tempVerts = { 0, 0, 10, 0, 10, 10, 0, 10 }

            release(SX1, SY1)

            assert.are.equal(0, state.polyEdit.dragIdx)
        end)

        it("resets texFixtureEdit dragIdx on release", function()
            local thing = addBodyAtScreen('rectangle', SX1, SY1, { width = 80, height = 80 })
            local sf = fixtures.createSFixture(thing.body, 0, 0, 'texfixture', {
                width = 40, height = 40,
            })
            state.selection.selectedSFixture = sf
            state.texFixtureEdit.dragIdx = 1
            -- Provide valid vertex data that maybeUpdateTexFixtureVertices expects
            state.texFixtureEdit.tempVerts = { -20, -20, 20, -20, 20, 20, -20, 20 }

            release(SX1, SY1)

            assert.are.equal(0, state.texFixtureEdit.dragIdx)
        end)
    end)
end)
