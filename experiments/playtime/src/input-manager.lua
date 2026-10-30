local lib = {}
local registry = require('src.registry')
local camera = require('src.camera')
local cam = camera.getInstance()
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local mathutils = require('src.math-utils')
local recorder = require('src.recorder')
local mipoVoice = require('src.mipo-voice')
local mipoRegistry = require('src.mipo-registry')
local blobs = require('src.blob')
local signals = require('src.signals')
local doors = require('src.doors')
local utils = require('src.utils')
local script = require('src.script')
local selectrect = require('src.selection-rect')
local polyEdit = require('src.poly-edit')
local meshusertBind = require('src.meshusert-bind')
local state = require('src.state')
local modes = require('src.modes')
local ui = require('src.ui.all')
local fixtures = require('src.fixtures')
local cdt = require('src.cdt')
local subtypes = require('src.subtypes')
local resourceLink = require('src.resource-link')
local ST = require('src.shape-types')
local joints = require('src.joints')
local NT = require('src.node-types')
local playMode = require('src.play-mode')
local units = require('src.physics-units')
local cameraFollow = require('src.camera-follow')

local PANEL_WIDTH = 300        -- presses this close to the right edge belong to the open panel
local PALETTE_HEIGHT = 400     -- the colour palette along the bottom
local CORNER_GRAB_RADIUS = 10  -- world units: a polygon or texfixture corner being edited
local STEINER_GRAB_RADIUS = 20 -- body-local units: an extra Steiner point
local NODE_GRAB_RADIUS = 30    -- world units: an anchor or joint, for connected-texture/meshusert nodes

-- In-flight Steiner drag state. Non-zero = we're dragging thing.extraSteiner
-- at this array index on state.selection.selectedObj. Cleared on release.
local steinerDragIdx = 0

-- Shared post-mutation refresh: re-triangulate any RESOURCE on the body,
-- and drop bind data on the MESHUSERTs linked to it since triangle indices
-- moved. Called from both discrete (add/remove) and continuous (drag
-- release) Steiner edits.
local function refreshResourceAfterSteinerChange(body)
    for _, ud in ipairs(fixtures.sfixtureData(body, subtypes.RESOURCE)) do
        local bd = resourceLink.backdrop(ud)
        if bd then
            cdt.computeResourceMesh(ud, body, bd)
        end
    end
    for _, v in pairs(registry.sfixtures) do
        if not v:isDestroyed() then
            local vud = v:getUserData()
            local resource = vud and subtypes.is(vud, subtypes.MESHUSERT) and resourceLink.find(vud)
            if resource and resource:getBody() == body then
                meshusertBind.clearInfluences(vud.extra, true)
            end
        end
    end
end
local distanceSquared = function(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

-- Pre-physics pressed handlers (run before physics hit detection)
local function pressedDrawClickMode(cx, cy, x)
    local w = love.graphics.getDimensions()
    if x < w - PANEL_WIDTH then
        table.insert(state.interaction.polyVerts, cx)
        table.insert(state.interaction.polyVerts, cy)
    end
end

-- SET_OFFSET_A / SET_OFFSET_B: the press becomes the selected joint's anchor on body A / B.
local function pressedSetOffset(side)
    return function(cx, cy)
        local joint = state.selection.selectedJoint
        if joint and not joint:isDestroyed() then
            local bodyA, bodyB = joint:getBodies()
            local body = side == 'A' and bodyA or bodyB
            local fx, fy = mathutils.rotatePoint(cx - body:getX(), cy - body:getY(), 0, 0, -body:getAngle())
            local update = side == 'A' and joints.updateJointOffsetA or joints.updateJointOffsetB
            state.selection.selectedJoint = update(joint, fx, fy)
        end
        modes.clear()
    end
end

local function pressedPositioningSFixture(cx, cy)
    state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture, cx, cy)
    local oldTexFixUD = state.selection.selectedSFixture:getUserData()
    if (oldTexFixUD.extra.vertices) then
        state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
    end
    modes.clear()
end

-- Nearest anchor-sfixture or joint anchor to (cx, cy), or nil when nothing
-- is within maxDist. Shared by node-adding (pressedAddNode) and the hover
-- indicator (showCloseNode).
local function findClosestNode(cx, cy, maxDist)
    local closest = nil
    local closestDistanceSquared = math.huge
    for _, f in pairs(registry.sfixtures) do
        local body = f:getBody()
        local ud = f:getUserData()
        if subtypes.is(ud, subtypes.ANCHOR) then
            local centerX, centerY = mathutils.getCenterOfPoints(
                { body:getWorldPoints(f:getShape():getPoints()) })

            local d = distanceSquared(centerX, centerY, cx, cy)
            if d < closestDistanceSquared then
                closestDistanceSquared = d
                closest = { type = NT.ANCHOR, id = ud.id, x = centerX, y = centerY }
            end
        end
    end

    for _, joint in pairs(registry.joints) do
        local x1, y1 = joint:getAnchors()
        local d = distanceSquared(x1, y1, cx, cy)
        if d < closestDistanceSquared then
            closestDistanceSquared = d
            closest = { type = NT.JOINT, id = joint:getUserData().id, x = x1, y = y1 }
        end
    end

    if closest and math.sqrt(closestDistanceSquared) < maxDist then
        return closest
    end
    return nil
end

local function pressedAddNode(cx, cy)
    local closest = findClosestNode(cx, cy, NODE_GRAB_RADIUS)
    if closest then
        local ud = state.selection.selectedSFixture:getUserData()
        ud.extra.nodes = ud.extra.nodes or {}

        local lastAdded = ud.extra.nodes[#ud.extra.nodes]
        if not lastAdded or lastAdded.id ~= closest.id then
            table.insert(ud.extra.nodes, { type = closest.type, id = closest.id })
        end

        state.selection.selectedSFixture:setUserData(ud)
        return true -- signal early return
    else
        modes.clear()
        return true -- signal early return
    end
end

local prePhysicsHandlers = {
    [modes.DRAW_CLICK]             = pressedDrawClickMode,
    [modes.SET_OFFSET_A]           = pressedSetOffset('A'),
    [modes.SET_OFFSET_B]           = pressedSetOffset('B'),
    [modes.POSITIONING_SFIXTURE]   = pressedPositioningSFixture,
    [modes.ADD_NODE_CONNECTED_TEX] = pressedAddNode,
    [modes.ADD_NODE_MESHUSERT]     = pressedAddNode,
}

-- Post-physics pressed handlers (run after physics hit detection, need hitted)
local function pressedPickAutoRopifyMode(hitted, x)
    if #hitted > 0 then
        state.pickAutoRopifyModeHitted = hitted[1]:getBody():getUserData()
    end
    local w = love.graphics.getDimensions()
    if x < w - PANEL_WIDTH and #hitted == 0 then
        modes.clear()
        state.pickAutoRopifyModeHitted = nil
    end
end

local function pressedJointCreation(cx, cy, hitted)
    local hitted2Bodies = #hitted == 2 and hitted[1]:getUserData() == nil and hitted[2]:getUserData() == nil
    if hitted2Bodies and (state.jointParams.body1 == nil) and (state.jointParams.body2 == nil) then
        -- if you click exactly where two bodies overlap,
        -- picking the one whose center is closest to your click as body1.
        local b1 = utils.thingOf(hitted[1]:getBody()).body
        local b2 = utils.thingOf(hitted[2]:getBody()).body

        local b1x, b1y = b1:getLocalPoint(cx, cy)
        local b2x, b2y = b2:getLocalPoint(cx, cy)
        -- todo i think a good compromise is to pick the body where
        -- the cx,cy is closst to its middel as the first,
        -- this will result in the most usefull cases i think.
        if (distanceSquared(b1x, b1y, 0, 0) < distanceSquared(b2x, b2y, 0, 0)) then
            state.jointParams.body1 = b1
            state.jointParams.body2 = b2
            state.jointParams.p1 = { b1x, b1y }
            state.jointParams.p2 = { b2x, b2y }
        else
            state.jointParams.body1 = b2
            state.jointParams.body2 = b1
            state.jointParams.p1 = { b2x, b2y }
            state.jointParams.p2 = { b1x, b1y }
        end
    else
        if state.jointParams.body1 == nil then
            state.jointParams.body1 = state.selection.selectedObj.body
            local px, py = state.jointParams.body1:getLocalPoint(cx, cy)
            state.jointParams.p1 = { px, py }
        elseif state.jointParams.body2 == nil then
            if (state.selection.selectedObj.body ~= state.jointParams.body1) then
                state.jointParams.body2 = state.selection.selectedObj.body
                local px, py = state.jointParams.body2:getLocalPoint(cx, cy)
                state.jointParams.p2 = { px, py }
            end
        end
    end
end

-- Released handlers
local function releasedDrawFreePoly()
    polyEdit.finalizePolygon()
end

local function releasedDrawFreePath()
    polyEdit.finalizePath()
end

local releasedHandlers = {
    [modes.DRAW_FREE_POLY] = releasedDrawFreePoly,
    [modes.DRAW_FREE_PATH] = releasedDrawFreePath,
}

local mipoMass = mipoRegistry.totalMass

-- Grabbing a Mipo by its torso makes it hop a little (puppet-maker2 outside.lua: torso impulse on tap).
-- The impulse scales with the Mipo's total mass so every Mipo hops about the same.
lib.mipoHopSpeed = 500 -- world units/s at 100 px per metre (src/physics-units.lua)
local function hopMipo(mipo)
    local torso = mipo.parts and mipo.parts.torso1
    if not torso or not torso.body or torso.body:isDestroyed() then return end
    torso.body:applyLinearImpulse(0, -mipoMass(mipo) * units.speed(lib.mipoHopSpeed))
end

-- What a drag pulls along: a whole Mipo (by any part), a whole blob, else the body.
local function grabbedMass(body)
    local mipo = mipoRegistry.getFromBody(body)
    if mipo then return mipoMass(mipo) end
    return blobs.massOf(body) or body:getMass()
end

-- What a press on bodies does while playing: the scene script, signals, doors, a Mipo's squeak.
-- cx, cy: the press in world space (a door's leaf and doorway are tapped by position).
local function playPressed(hitted, cx, cy)
    local newHitted = utils.map(hitted, function(h)
        local hthing = utils.thingOf(h:getBody())
        return hthing
    end)
    script.call('onPressed', newHitted)
    local pressedBodies = {}
    for _, fixture in ipairs(hitted) do pressedBodies[#pressedBodies + 1] = fixture:getBody() end
    signals.onPressed(pressedBodies)
    doors.onPressed(pressedBodies, cx, cy)
    for _, fixture in ipairs(hitted) do
        local mipo, partName = mipoRegistry.getFromBody(fixture:getBody())
        if mipo then
            mipoVoice.squeak(mipo, 'pickup')
            -- only grabbing the torso hops; a hand or foot is just picked up
            if partName == 'torso1' then hopMipo(mipo) end
            break
        end
    end
end

local function pointerParams()
    return {
        -- dragStrength is in weights (at 9.8 m/s^2) of what's grabbed: a fixed force threw
        -- the lightest Mipos (mass 1.6) at 80 weights and the heaviest (5.9) at 22.
        -- makePointerJoint takes forces as at 100 px per metre.
        pointerForceFunc = function(fixture)
            local weight = units.weight(grabbedMass(fixture:getBody()))
            return units.toReferenceForce(state.world.dragStrength * weight)
        end,
        damp = state.world.mouseDamping
    }
end

-- Letting go: the pointer joints, the scene script, the recorder.
local function releasePointer(x, y, id)
    local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
    if (#releasedObjs > 0) then
        local newReleased = utils.map(releasedObjs, utils.thingOf)
        if not state.world.paused then doors.onReleased(releasedObjs) end -- a Mipo dropped on a door

        script.call('onReleased', newReleased)
        if recorder.isRecording and not state.world.paused then
            for _, obj in ipairs(releasedObjs) do
                local thing = utils.thingOf(obj) -- nil for a blob's rim
                if thing then recorder:recordMouseJointFinish(id, thing.id) end
            end
        end
    end
end

-- Play mode (src/play-mode.lua): the pointer only plays. No selection, tool modes or panel gates.
local function handlePlayPointer(x, y, id, action)
    if action == "pressed" then
        local cx, cy = cam:getWorldCoordinates(x, y)
        local _, hitted, madedata = box2dPointerJoints.handlePointerPressed(cx, cy, id, pointerParams(), true)
        if #hitted > 0 then playPressed(hitted, cx, cy) else doors.onPressed({}, cx, cy) end
        if recorder.isRecording and #hitted > 0 and madedata.bodyID then
            recorder:recordMouseJointStart(madedata)
        end
    elseif action == "released" then
        releasePointer(x, y, id)
    end
end

-- PLACE_STEINER, a POC: extra Steiner points on the selected body's polygon.
--   Left-click on an existing point -> start a drag (commits on release)
--   Left-click away                 -> add a new point
--   Right-click near an existing one -> remove it
local function pressedPlaceSteiner(x, y, button)
    local thing = state.selection.selectedObj
    if state.interaction.pressedOverUI or not (thing and thing.body) then return end
    local body = thing.body
    local wx, wy = cam:getWorldCoordinates(x, y)
    local lx, ly = body:getLocalPoint(wx, wy)
    thing.extraSteiner = thing.extraSteiner or {}

    -- Nearest existing Steiner within grab radius.
    local grabIdx, grabD = nil, STEINER_GRAB_RADIUS * STEINER_GRAB_RADIUS
    for i = 1, #thing.extraSteiner, 2 do
        local d = distanceSquared(lx, ly, thing.extraSteiner[i], thing.extraSteiner[i + 1])
        if d < grabD then grabD = d; grabIdx = i end
    end

    if button == 1 and grabIdx then
        -- Start drag: position updates in handleMouseMoved, RESOURCE refresh on release.
        steinerDragIdx = grabIdx
    elseif button == 1 then
        thing.extraSteiner[#thing.extraSteiner + 1] = lx
        thing.extraSteiner[#thing.extraSteiner + 1] = ly
        refreshResourceAfterSteinerChange(body)
    elseif button == 2 and grabIdx then
        table.remove(thing.extraSteiner, grabIdx)
        table.remove(thing.extraSteiner, grabIdx)
        refreshResourceAfterSteinerChange(body)
    end
end

-- Commit an in-flight Steiner drag: refresh RESOURCE now that the point has landed, and drop
-- bindings since topology moved.
local function releasedPlaceSteiner()
    if steinerDragIdx > 0 then
        local thing = state.selection.selectedObj
        if thing and thing.body then
            refreshResourceAfterSteinerChange(thing.body)
        end
        steinerDragIdx = 0
    end
end

-- True when a press belongs to an open panel (the save dialog, the palette, the right column)
-- and not to the bodies under it. A press outside the palette closes it.
local function pressedOnPanel(x, y)
    if state.panelVisibility.saveDialogOpened then return true end
    local w, h = love.graphics.getDimensions()
    if state.panelVisibility.showPalette then
        if y < h - PALETTE_HEIGHT or x > w - PANEL_WIDTH then
            state.panelVisibility.showPalette = nil
        end
        return true
    end
    local panelOpen = state.selection.selectedJoint or state.selection.selectedObj
        or state.selection.selectedSFixture or state.selection.selectedBodies
        or modes.is(modes.DRAW_FREE_POLY) or modes.is(modes.DRAW_FREE_PATH)
    return panelOpen and x > w - PANEL_WIDTH or false
end

-- The first corner of `verts` (flat x, y list) within `radius` of (cx, cy), or nil.
local function findVertexNear(verts, cx, cy, radius)
    for i = 1, #verts, 2 do
        if mathutils.dist(cx, cy, verts[i], verts[i + 1]) < radius then return i end
    end
    return nil
end

-- A press on a corner of the polygon or texfixture being edited (`edit` is state.polyEdit or
-- state.texFixtureEdit) grabs it for dragging. True when it did.
local function grabCorner(edit, verts, cx, cy)
    local i = findVertexNear(verts, cx, cy, CORNER_GRAB_RADIUS)
    if #verts > 0 then edit.dragIdx = i or 0 end
    return i ~= nil
end

local function pressedEditedCorner(cx, cy)
    local obj = state.selection.selectedObj
    local rightShape = obj and (obj.shapeType == ST.CUSTOM or obj.shapeType == ST.RIBBON)
    if state.polyEdit.tempVerts and rightShape and state.polyEdit.lockedVerts == false then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            obj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
        if grabCorner(state.polyEdit, verts, cx, cy) then return true end
    end
    local sfixture = state.selection.selectedSFixture
    if state.texFixtureEdit.tempVerts and sfixture and state.texFixtureEdit.lockedVerts == false then
        local verts = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
            utils.thingOf(sfixture:getBody()), 0, 0)
        if grabCorner(state.texFixtureEdit, verts, cx, cy) then return true end
    end
    return false
end

-- A press on bodies in the editor: select (a blob by its rim too), make joints, start dragging
-- while paused, play while running.
local function pressedSelect(hitted, cx, cy)
    -- a blob's rim bodies have no thing: clicking the rim selects the blob
    local hitBody = blobs.ownerOf(hitted[1]:getBody()) or hitted[1]:getBody()
    local thing = utils.thingOf(hitBody)
    if thing then
        state.selection.selectedObj = thing
        -- a blob shows its blob settings; clicking empty space goes to the body
        local blobFixture = blobs.sfixtureOf(hitBody)
        local sel = state.selection.selectedSFixture
        if blobFixture then
            state.selection.selectedSFixture = blobFixture
        elseif sel and (sel:isDestroyed() or subtypes.is(sel:getUserData(), subtypes.SOFTBODY)) then
            state.selection.selectedSFixture = nil
        end
    end
    if state.scene.sceneScript and not state.world.paused and state.selection.selectedObj then
        state.selection.selectedObj = nil
    end
    if modes.is(modes.JOINT_CREATION) and state.selection.selectedObj then
        pressedJointCreation(cx, cy, hitted)
    end

    if not state.world.paused then
        playPressed(hitted, cx, cy)
    elseif state.polyEdit.lockedVerts then
        state.interaction.draggingObj = state.selection.selectedObj
        if state.selection.selectedObj then
            local offx, offy = state.selection.selectedObj.body:getLocalPoint(cx, cy)
            state.interaction.offsetDragging = { -offx, -offy }
        end
    end
end

-- A click on nothing (not on a panel, not while placing a body) steps the selection back: from
-- an sfixture to its body, else drops the joint, else drops everything. The side panels close.
local function clearSelectionAndPanels()
    local sel = state.selection
    if sel.selectedSFixture and not sel.selectedSFixture:isDestroyed() then
        sel.selectedObj = utils.thingOf(sel.selectedSFixture:getBody())
        sel.selectedSFixture = nil
        state.texFixtureEdit.tempVerts = nil
        state.texFixtureEdit.centroid = nil
        state.texFixtureEdit.lockedVerts = true
    elseif sel.selectedJoint then
        sel.selectedJoint = nil
    else
        if not (ui.activeElementID or ui.focusedTextInputID) then
            sel.selectedObj = nil
            sel.selectedSFixture = nil
            sel.selectedJoint = nil
        end
        state.polyEdit.tempVerts = nil
        state.polyEdit.lockedVerts = true
    end
    state.interaction.maybeHideSelectedPanel = false
    for _, panel in ipairs({ 'addBehavior', 'customBehavior', 'bgSettingsOpened', 'worldSettingsOpened',
        'recordingPanelOpened', 'showPalette' }) do
        state.panelVisibility[panel] = false
    end
end

-- Shift-drag on the screen: select the bodies inside the box.
local function finishBoxSelection(x, y)
    local start = state.interaction.startSelection
    local tlxw, tlyw = cam:getWorldCoordinates(math.min(start.x, x), math.min(start.y, y))
    local brxw, bryw = cam:getWorldCoordinates(math.max(start.x, x), math.max(start.y, y))
    state.selection.selectedBodies = selectrect.selectWithin(state.physicsWorld,
        { x = tlxw, y = tlyw, width = brxw - tlxw, height = bryw - tlyw })
    state.interaction.startSelection = nil
end

local function handlePointer(x, y, id, action, button)
    if playMode.isOn() then return handlePlayPointer(x, y, id, action) end
    if action == "pressed" then
        -- Track whether press originated over a UI element
        state.interaction.pressedOverUI = ui.activeElementID or ui.overPanel or false
        -- this is a nice pattern, early return!
        if modes.is(modes.EDIT_MESH_TRIS) then return end

        if modes.is(modes.PLACE_STEINER) then return pressedPlaceSteiner(x, y, button) end
        if pressedOnPanel(x, y) then return end

        local startSelection = love.keyboard.isDown('lshift')
        if (startSelection) then
            state.interaction.startSelection = { x = x, y = y }
        end

        local cx, cy = cam:getWorldCoordinates(x, y)
        if pressedEditedCorner(cx, cy) then return end

        -- Pre-physics mode dispatch
        local preHandler = prePhysicsHandlers[state.currentMode]
        if preHandler then
            local earlyReturn = preHandler(cx, cy, x)
            if earlyReturn then return end
        end

        -- Physics hit detection (shared infrastructure)
        local _, hitted, madedata = box2dPointerJoints.handlePointerPressed(cx, cy, id, pointerParams(),
            not state.world.paused)

        if (state.selection.selectedBodies and #hitted == 0) then
            state.selection.selectedBodies = nil
        end

        -- Post-physics mode dispatch
        if modes.is(modes.PICK_AUTO_ROPIFY) then
            pressedPickAutoRopifyMode(hitted, x)
        end

        if #hitted > 0 and (not modes.is(modes.PICK_AUTO_ROPIFY)) then
            pressedSelect(hitted, cx, cy)
        else
            state.interaction.pressMissedEverything = true
        end
        if recorder.isRecording and #hitted > 0 and not state.world.paused and madedata.bodyID then
            recorder:recordMouseJointStart(madedata)
        end
    elseif action == "released" then
        if modes.is(modes.EDIT_MESH_TRIS) then return end
        if modes.is(modes.PLACE_STEINER) then return releasedPlaceSteiner() end

        -- Handle release logic
        releasePointer(x, y, id)

        if state.interaction.pressMissedEverything then
            local wasOverUI = ui.activeElementID or ui.focusedTextInputID or ui.overPanel
                or state.interaction.pressedOverUI
            local wasSpawning = state.interaction.draggingObj ~= nil
            if not wasOverUI and not wasSpawning then clearSelectionAndPanels() end
        end
        state.interaction.pressMissedEverything = false
        state.interaction.pressedOverUI = false

        if state.interaction.draggingObj then
            state.interaction.draggingObj.body:setAwake(true)
            state.selection.selectedObj = state.interaction.draggingObj
            state.interaction.draggingObj = nil
        end

        -- if we have released a mousebutton but it isnt nr1, then we keep on drawing free polygon
        if (modes.is(modes.DRAW_FREE_POLY) or modes.is(modes.DRAW_FREE_PATH))
            and not love.mouse.isDown(1) then
            state.interaction.capturingPoly = false

            local releaseHandler = releasedHandlers[state.currentMode]
            if releaseHandler then
                releaseHandler()
            end
        end

        if state.polyEdit.dragIdx > 0 then
            state.polyEdit.dragIdx = 0
            polyEdit.maybeUpdateCustomPolygonVertices()
        end

        if state.texFixtureEdit.dragIdx > 0 then
            state.texFixtureEdit.dragIdx = 0
            polyEdit.maybeUpdateTexFixtureVertices()
        end

        if state.interaction.startSelection then finishBoxSelection(x, y) end
    end
end

function lib.handleDraggingObj()
    if state.interaction.draggingObj.body:isDestroyed() then
        state.interaction.draggingObj = nil
        return
    end
    local mx, my = love.mouse.getPosition()
    local wx, wy = cam:getWorldCoordinates(mx, my)
    local offx = state.interaction.offsetDragging[1]
    local offy = state.interaction.offsetDragging[2]
    local rx, ry = mathutils.rotatePoint(offx, offy, 0, 0, state.interaction.draggingObj.body:getAngle())
    local oldPosX, oldPosY = state.interaction.draggingObj.body:getPosition()
    state.interaction.draggingObj.body:setPosition(wx + rx, wy + ry)
    if recorder.isRecording then
        recorder:recordObjectSetPosition(state.interaction.draggingObj.id, wx + rx, wy + ry)
    end
    -- figure out if we are dragging a group!
    if state.selection.selectedBodies then
        for i = 1, #state.selection.selectedBodies do
            if (state.selection.selectedBodies[i] == state.interaction.draggingObj) then
                local newPosX, newPosY = state.interaction.draggingObj.body:getPosition()
                local dx = newPosX - oldPosX
                local dy = newPosY - oldPosY
                for j = 1, #state.selection.selectedBodies do
                    if (state.selection.selectedBodies[j] ~= state.interaction.draggingObj) then
                        local otherPosX, otherPosY = state.selection.selectedBodies[j].body:getPosition()
                        state.selection.selectedBodies[j].body:setPosition(otherPosX + dx, otherPosY + dy)
                    end
                end
            end
        end
    end
end

function lib.handleMousePressed(x, y, button, istouch)
    if playMode.isOn() then -- left grabs; right/middle pan (handleMouseMoved)
        if not istouch and button == 1 then handlePointer(x, y, 'mouse', 'pressed', button) end
        return
    end
    if not istouch and button == 1 then
        if modes.is(modes.DRAW_FREE_POLY) or modes.is(modes.DRAW_FREE_PATH) then
            -- Start capturing mouse movement
            state.interaction.capturingPoly = true
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        else
            handlePointer(x, y, 'mouse', 'pressed', button)
        end
    end
    if not istouch and button == 2 then
        handlePointer(x, y, 'mouse', 'pressed', button)
    end
end

function lib.handleTouchPressed(id, x, y, _dx, _dy, _pressure)
    if not playMode.isOn() and (modes.is(modes.DRAW_FREE_POLY) or modes.is(modes.DRAW_FREE_PATH)) then
        -- Start capturing mouse movement
        state.interaction.capturingPoly = true
        state.interaction.polyVerts = {}
        state.interaction.lastPolyPt = nil
    else
        handlePointer(x, y, id, 'pressed')
    end
end

function lib.handleMouseReleased(x, y, _button, istouch)
    if not istouch then
        handlePointer(x, y, 'mouse', 'released')
    end
end

function lib.handleTouchReleased(id, x, y, _dx, _dy, _pressure)
    handlePointer(x, y, id, 'released')
end

function lib.showCloseNode()
    local mx, my = love.mouse.getPosition()
    local cx, cy = cam:getWorldCoordinates(mx, my)
    local node = findClosestNode(cx, cy, NODE_GRAB_RADIUS)
    if node then
        return { node.x, node.y }
    end
    return nil
end

local function panCamera(dx, dy)
    local tx, ty = cam:getTranslation()
    cam:setTranslation(tx - dx / cam.scale, ty - dy / cam.scale)
    cameraFollow.notePan() -- you steer now, until the next touch
end

-- The last place `value` is in `list`, or nil.
local function lastIndexOf(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then return i end
    end
    return nil
end

-- EDIT_MESH_TRIS: brushing over the selected MESHUSERT's triangles with a button down. Left adds
-- them to the selection, right takes them out (and off the selected bone), ctrl+left picks the
-- bone of the triangle under it. True when the move was a brush stroke.
local function brushTriangles(x, y)
    local ud = state.selection.selectedSFixture:getUserData()
    if not (ud and subtypes.is(ud, subtypes.MESHUSERT) and ud.label) then return false end
    -- The linked RESOURCE fixture owns the triangle index array (ud.extra.triangles).
    local mappert = resourceLink.find(ud)
    local button = (love.mouse.isDown(2) and 2) or (love.mouse.isDown(1) and 1) or nil
    if not (mappert and button) then return false end
    local mextra = mappert:getUserData().extra
    local triIdx = mextra and mextra.triangles
    if not triIdx or #triIdx < 3 then return true end

    -- Match the draw path's vertex source: CDT mode uses meshVertices (includes Steiner
    -- points), basic mode falls back to the polygon.
    local baseVerts = mextra.meshVertices or utils.thingOf(mappert:getBody()).vertices
    local centeredVerts = mathutils.makePolygonRelativeToCenter(baseVerts, mathutils.computeCentroid(baseVerts))
    local worldAt = fixtures.makeMeshVertexMapper(ud.extra, centeredVerts, state.selection.selectedSFixture:getBody())
    local cx, cy = cam:getWorldCoordinates(x, y)
    local brushRadius = tonumber(state.triangleEditor.brushSize) or 20
    local isCtrl = love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
    local selected = state.triangleEditor.selectedTriangles
    local bones = ud.extra.triangleBones

    for t = 1, math.floor(#triIdx / 3) do
        local i1, i2, i3 = triIdx[t * 3 - 2], triIdx[t * 3 - 1], triIdx[t * 3]
        if i1 and i2 and i3 then
            local x1, y1 = worldAt(i1)
            local x2, y2 = worldAt(i2)
            local x3, y3 = worldAt(i3)
            if mathutils.dist(cx, cy, (x1 + x2 + x3) / 3, (y1 + y2 + y3) / 3) < brushRadius then
                if isCtrl and button == 1 then
                    if bones and bones[t] then
                        state.triangleEditor.selectedBone = bones[t]
                        return true
                    end
                elseif button == 2 then
                    local i = lastIndexOf(selected, t)
                    if i then table.remove(selected, i) end
                    if bones and bones[t] == state.triangleEditor.selectedBone then bones[t] = nil end
                elseif not lastIndexOf(selected, t) then
                    table.insert(selected, t)
                end
            end
        end
    end
    return true
end

-- A screen drag (dx, dy) in the body's own frame, in world units.
local function localDelta(body, dx, dy)
    local lx, ly = mathutils.rotatePoint(dx, dy, 0, 0, -body:getAngle())
    return lx / cam.scale, ly / cam.scale
end

function lib.handleMouseMoved(x, y, dx, dy)
    if playMode.isOn() then -- play mode: moving only pans (right/middle drag)
        if love.mouse.isDown(3) or love.mouse.isDown(2) then panCamera(dx, dy) end
        return
    end

    -- Steiner drag: live-update the grabbed point's body-local position.
    -- RESOURCE refresh runs on release so we don't thrash bind data per
    -- frame; the body fill + POC overlay recompute from thing.extraSteiner
    -- each frame anyway, so the preview tracks the mouse.
    if modes.is(modes.PLACE_STEINER) and steinerDragIdx > 0
        and state.selection.selectedObj
        and state.selection.selectedObj.body then
        local thing = state.selection.selectedObj
        local wx, wy = cam:getWorldCoordinates(x, y)
        local lx, ly = thing.body:getLocalPoint(wx, wy)
        thing.extraSteiner[steinerDragIdx] = lx
        thing.extraSteiner[steinerDragIdx + 1] = ly
        return
    end

    if modes.is(modes.EDIT_MESH_TRIS) and state.selection.selectedSFixture and brushTriangles(x, y) then
        return
    end

    if state.polyEdit.dragIdx and state.polyEdit.dragIdx > 0 then
        local index = state.polyEdit.dragIdx
        local dx2, dy2 = localDelta(state.selection.selectedObj.body, dx, dy)
        state.polyEdit.tempVerts[index] = state.polyEdit.tempVerts[index] + dx2
        state.polyEdit.tempVerts[index + 1] = state.polyEdit.tempVerts[index + 1] + dy2
    elseif state.texFixtureEdit.dragIdx and state.texFixtureEdit.dragIdx > 0 then
        local index = state.texFixtureEdit.dragIdx
        local dx2, dy2 = localDelta(state.selection.selectedSFixture:getBody(), dx, dy)
        state.texFixtureEdit.tempVerts[index] = state.texFixtureEdit.tempVerts[index] + dx2
        state.texFixtureEdit.tempVerts[index + 1] = state.texFixtureEdit.tempVerts[index + 1] + dy2

        local ud = state.selection.selectedSFixture:getUserData()
        ud.extra.vertices[index] = state.texFixtureEdit.tempVerts[index]
        ud.extra.vertices[index + 1] = state.texFixtureEdit.tempVerts[index + 1]
        state.selection.selectedSFixture:setUserData(ud)
    elseif state.interaction.capturingPoly
        and (modes.is(modes.DRAW_FREE_POLY)
            or modes.is(modes.DRAW_FREE_PATH))
        and (not (love.mouse.isDown(3) or love.mouse.isDown(2))) then
        local wx, wy = cam:getWorldCoordinates(x, y)
        -- Check if the distance from the last point is greater than minPointDistance
        local addPoint = false
        if not state.interaction.lastPolyPt then
            addPoint = true
        else
            local lastX, lastY = state.interaction.lastPolyPt.x, state.interaction.lastPolyPt.y
            local distSq = (wx - lastX) ^ 2 + (wy - lastY) ^ 2
            if distSq >= (state.editorPreferences.minPointDistance / cam.scale) ^ 2 then
                addPoint = true
            end
        end
        if addPoint then
            table.insert(state.interaction.polyVerts, wx)
            table.insert(state.interaction.polyVerts, wy)
            state.interaction.lastPolyPt = { x = wx, y = wy }
        end
    elseif love.mouse.isDown(3) or love.mouse.isDown(2) then
        panCamera(dx, dy)
    end
end

-- A key in the editor. While a text field has focus the key is typed and
-- nothing else hears it (a space in a label used to pause the world).
function lib.keyPressed(key)
    local typing = ui.focusedTextInputID -- before: enter/escape can end the typing
    ui.handleKeyPress(key)
    if typing then return end
    lib.handleKeyPressed(key)
    script.call('onKeyPress', key)
end

function lib.handleKeyPressed(key)
    if key == 'escape' then
        if state.panelVisibility.quitDialogOpened == true then
            love.event.quit()
        end
        if state.panelVisibility.quitDialogOpened == false then
            state.panelVisibility.quitDialogOpened = true
        end
    end
    if key == 'space' then
        if state.panelVisibility.quitDialogOpened == true then
            state.panelVisibility.quitDialogOpened = false
        else
            state.world.paused = not state.world.paused
            if recorder.isRecording then recorder:recordPause(state.world.paused) end
        end
    end
    if key == "c" then
        love.graphics.captureScreenshot(os.time() .. ".png")
    end
    if key == 'f5' then
        state.world.paused = true
        state.panelVisibility.saveDialogOpened = true
    end
    -- i / d: insert or delete a corner (a ribbon: a pair) at the mouse in the edited polygon
    if (key == 'i' or key == 'd') and state.polyEdit.tempVerts then
        local wx, wy = cam:getWorldCoordinates(love.mouse.getPosition())
        local ribbon = state.selection.selectedObj and state.selection.selectedObj.shapeType == ST.RIBBON
        if key == 'i' and ribbon then
            polyEdit.insertRibbonPair(wx, wy)
        elseif key == 'i' then
            polyEdit.insertCustomPolygonVertex(wx, wy)
        elseif ribbon then
            polyEdit.removeRibbonPair(wx, wy)
        else
            polyEdit.removeCustomPolygonVertex(wx, wy)
        end
        if key == 'i' or ribbon then polyEdit.maybeUpdateCustomPolygonVertices() end
    end
end

return lib
