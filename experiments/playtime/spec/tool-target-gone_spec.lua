-- spec/tool-target-gone_spec.lua
-- An editor tool whose thing went while it was on (claudetools/tool-modes_spec.lua found these):
-- adding nodes to a ribbon or placing an sfixture, the ribbon / sfixture destroyed from its panel
-- or the room loaded again, and the next click in the world died (input-manager.lua:141, :95). A
-- Steiner point grabbed and the tool switched off before letting go left the drag behind: the
-- next time the tool was on, moving the mouse died (:748). Picking bodies for a joint kept a body
-- destroyed or rebuilt in between. A tool now ends when its thing is gone, a room load ends it,
-- and a joint is only made between bodies that are there.
-- Run with: love . --specs spec/tool-target-gone_spec.lua

if not love then return end

local state = require('src.state')
local registry = require('src.registry')
local objectManager = require('src.object-manager')
local fixtures = require('src.fixtures')
local joints = require('src.joints')
local subtypes = require('src.subtypes')
local modes = require('src.modes')
local input = require('src.input-manager')
local camera = require('src.camera')
local sceneLoader = require('src.scene-loader')
local sceneIO = require('src.io')
local sfixtureParams = require('src.sfixture-params')
local bodyParams = require('src.body-params')
local cam = camera.getInstance()

local function reset()
    local sel = state.selection
    sel.selectedObj, sel.selectedJoint, sel.selectedSFixture, sel.selectedBodies = nil, nil, nil, nil
    state.currentMode = nil
    state.jointParams = nil
    state.polyEdit.tempVerts, state.polyEdit.centroid, state.polyEdit.lockedVerts = nil, nil, true
    state.polyEdit.dragIdx = 0
    state.texFixtureEdit.tempVerts, state.texFixtureEdit.lockedVerts, state.texFixtureEdit.dragIdx = nil, true, 0
    state.interaction.draggingObj = nil
    state.interaction.pressMissedEverything = false
    state.interaction.polyVerts = {}
    state.world.paused = true
end

-- world point -> screen, then the editor's own press and release
local function click(wx, wy, button)
    local x, y = cam:getScreenCoordinates(wx, wy)
    input.handleMouseMoved(x, y, 0, 0)
    input.handleMousePressed(x, y, button or 1, false)
    input.handleMouseReleased(x, y, button or 1, false)
end

local function body(x, y)
    return objectManager.addThing('rectangle', { x = x, y = y, width = 60, height = 60 })
end

local function destroyRow(rows)
    for _, row in ipairs(rows) do if row.label == 'destroy' then return row end end
end

describe('a tool whose thing is gone', function()
    local a, b, joint

    before_each(function()
        registry.reset()
        state.physicsWorld = love.physics.newWorld(0, 0, true)
        cam:setTranslation(0, 0)
        cam:setScale(1)
        reset()
        a, b = body(0, 0), body(150, 0)
        joint = joints.createJoint({ body1 = a.body, body2 = b.body, jointType = 'revolute' })
    end)

    after_each(function()
        reset()
        state.physicsWorld:destroy()
        state.physicsWorld = nil
        registry.reset()
    end)

    it('adding ribbon nodes: the ribbon destroyed, the next click is fine and the tool ends', function()
        local ribbon = fixtures.createSFixture(a.body, 0, 0, subtypes.CONNECTED_TEXTURE, { radius = 30 })
        state.selection.selectedSFixture = ribbon
        modes.set(modes.ADD_NODE_CONNECTED_TEX)
        sfixtureParams.footer[1].run(nil, ribbon) -- its panel's destroy
        local x, y = joint:getAnchors()
        assert.has_no.errors(function() click(x, y) end)
        assert.is_nil(state.currentMode)
    end)

    it('placing an sfixture: the sfixture destroyed, the next click is fine and the tool ends', function()
        local snap = fixtures.createSFixture(a.body, 0, 0, subtypes.ANCHOR, { radius = 10 })
        state.selection.selectedSFixture = snap
        modes.set(modes.POSITIONING_SFIXTURE)
        sfixtureParams.footer[1].run(nil, snap)
        assert.has_no.errors(function() click(5, 5) end)
        assert.is_nil(state.currentMode)
    end)

    it('a room loaded while a tool is on ends the tool', function()
        local ribbon = fixtures.createSFixture(a.body, 0, 0, subtypes.CONNECTED_TEXTURE, { radius = 30 })
        state.selection.selectedSFixture = ribbon
        modes.set(modes.ADD_NODE_CONNECTED_TEX)
        state.polyEdit.tempVerts = { 0, 0, 10, 0, 10, 10 }
        state.jointParams = { jointType = 'revolute', body1 = a.body }
        local saved = require('vendor.dkjson').encode(sceneIO.gatherSaveData(state.physicsWorld, cam))
        sceneLoader.loadSceneData(saved, 'the room again')
        assert.is_nil(state.currentMode)
        assert.is_nil(state.jointParams)
        assert.is_nil(state.polyEdit.tempVerts)
        assert.has_no.errors(function() click(0, 0) end)
    end)

    it('a Steiner point let go of after the tool went off: the next Steiner tool moves fine', function()
        state.selection.selectedObj = a
        modes.set(modes.PLACE_STEINER)
        click(5, 5)                                   -- a point
        local x, y = cam:getScreenCoordinates(5, 5)
        input.handleMousePressed(x, y, 1, false)       -- grab it
        modes.clear()                                 -- the tool off before letting go
        input.handleMouseReleased(x, y, 1, false)
        state.selection.selectedObj = b               -- another body, no Steiner points
        modes.set(modes.PLACE_STEINER)
        assert.has_no.errors(function() input.handleMouseMoved(x + 10, y, 10, 0) end)
    end)

    it('the Steiner tool: its body destroyed, the next click is fine and the tool ends', function()
        state.selection.selectedObj = a
        modes.set(modes.PLACE_STEINER)
        destroyRow(bodyParams.rows).run(a.body, a)
        state.selection.selectedObj = a -- what a panel still showing it would hold
        assert.has_no.errors(function() click(5, 5) end)
        assert.is_nil(state.currentMode)
    end)

    it('making a joint: the first body destroyed after picking it, no joint to a destroyed body', function()
        state.jointParams = { jointType = 'revolute' }
        modes.set(modes.JOINT_CREATION)
        click(0, 0)
        assert.are.equal(a.body, state.jointParams.body1)
        destroyRow(bodyParams.rows).run(a.body, a)
        click(150, 0)
        local jp = state.jointParams
        for _, picked in ipairs({ jp and jp.body1, jp and jp.body2 }) do
            assert.is_false(picked:isDestroyed())
        end
    end)
end)
