local lib = {}
local logger = require 'src.logger'
local registry = require 'src.registry'
local camera = require 'src.camera'
local cam = camera.getInstance()
local box2dPointerJoints = require 'src.physics.box2d-pointerjoints'
local mathutils = require 'src.math-utils'
local recorder = require 'src.recorder'
local utils = require 'src.utils'
local script = require 'src.script'
local selectrect = require 'src.selection-rect'
local objectManager = require 'src.object-manager'
local state = require 'src.state'
local modes = require 'src.modes'
local blob = require 'vendor.loveblobs'
local ui = require('src.ui.all')
local fixtures = require 'src.fixtures'
local cdt = require 'src.cdt'
local subtypes = require 'src.subtypes'

-- In-flight Steiner drag state. Non-zero = we're dragging thing.extraSteiner
-- at this array index on state.selection.selectedObj. Cleared on release.
local steinerDragIdx = 0

-- Shared post-mutation refresh: re-triangulate any RESOURCE on the body,
-- and drop bind data on label-matched MESHUSERTs since triangle indices
-- moved. Called from both discrete (add/remove) and continuous (drag
-- release) Steiner edits.
local function refreshResourceAfterSteinerChange(body, thing)
    for _, f in ipairs(body:getFixtures()) do
        local fud = f:getUserData()
        if type(fud) == 'table' and subtypes.is(fud, subtypes.RESOURCE) and fud.extra then
            local idx = fud.extra.selectedBGIndex
            local bd = idx and state.backdrops and state.backdrops[idx]
            if bd then
                cdt.computeResourceMesh(fud, body, bd, mathutils)
            end
        end
    end
    local lbl = thing.label
    if lbl and #lbl > 0 then
        for _, v in pairs(registry.sfixtures) do
            if not v:isDestroyed() then
                local vud = v:getUserData()
                if vud and vud.label == lbl and subtypes.is(vud, subtypes.MESHUSERT) then
                    vud.extra.triangleBones = nil
                    vud.extra.influences = nil
                    vud.extra.bindVerts = nil
                    vud.extra.rigidLookup = nil
                    vud.extra.rigidBindCoords = nil
                end
            end
        end
    end
end
local subtypes = require 'src.subtypes'
local ST = require 'src.shape-types'
local joints = require 'src.joints'
local NT = require('src.node-types')

local distanceSquared = function(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    --local distance = math.sqrt(dx * dx + dy * dy)
    return dx * dx + dy * dy
end

-- Pre-physics pressed handlers (run before physics hit detection)
local function pressedDrawClickMode(cx, cy, x)
    local w = love.graphics.getDimensions()
    if x < w - 300 then
        table.insert(state.interaction.polyVerts, cx)
        table.insert(state.interaction.polyVerts, cy)
    end
end

local function pressedSetOffsetA(cx, cy)
    local bodyA = state.selection.selectedJoint:getBodies()
    local fx, fy = mathutils.rotatePoint(cx - bodyA:getX(), cy - bodyA:getY(), 0, 0, -bodyA:getAngle())
    state.selection.selectedJoint =
        joints.updateJointOffsetA(state.selection.selectedJoint, fx, fy)
    print('got here!')
    modes.clear()
end

local function pressedSetOffsetB(cx, cy)
    local _, bodyB = state.selection.selectedJoint:getBodies()
    local fx, fy = mathutils.rotatePoint(cx - bodyB:getX(), cy - bodyB:getY(), 0, 0, -bodyB:getAngle())
    state.selection.selectedJoint =
        joints.updateJointOffsetB(state.selection.selectedJoint, fx, fy)
    modes.clear()
end

local function pressedPositioningSFixture(cx, cy)
    state.selection.selectedSFixture = fixtures.updateSFixturePosition(state.selection.selectedSFixture, cx, cy)
    local oldTexFixUD = state.selection.selectedSFixture:getUserData()
    if (oldTexFixUD.extra.vertices) then
        state.texFixtureEdit.tempVerts = utils.shallowCopy(oldTexFixUD.extra.vertices)
    end
    modes.clear()
end

local function pressedAddNode(cx, cy)
    -- we need to walk trough all anchor fitures and all joints to see if im very close to one?
    local closest = nil
    local closestDistanceSquared = math.huge
    for _, f in pairs(registry.sfixtures) do
        local body = f:getBody()
        local ud = f:getUserData()
        if subtypes.is(ud, subtypes.ANCHOR) then
            -- todo this will find ALL sfitures bot just anchors
            local centerX, centerY = mathutils.getCenterOfPoints(
                { body:getWorldPoints(f:getShape():getPoints()) })

            local d = distanceSquared(centerX, centerY, cx, cy)
            if d < closestDistanceSquared then
                closestDistanceSquared = d
                closest = { type = NT.ANCHOR, id = f:getUserData().id }
            end
        end
    end

    for _, j in pairs(registry.joints) do
        local x1, y1 = j:getAnchors()
        local d = distanceSquared(x1, y1, cx, cy)
        if d < closestDistanceSquared then
            closestDistanceSquared = d
            closest = { type = NT.JOINT, id = j:getUserData().id }
        end
    end

    if math.sqrt(closestDistanceSquared) < 30 then
        local ud = state.selection.selectedSFixture:getUserData()
        ud.extra.nodes = ud.extra.nodes or {}

        local lastAdded = ud.extra.nodes[#ud.extra.nodes]
        if (closest and lastAdded and lastAdded.id ~= closest.id) or not lastAdded then
            table.insert(ud.extra.nodes, closest)
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
    [modes.SET_OFFSET_A]           = pressedSetOffsetA,
    [modes.SET_OFFSET_B]           = pressedSetOffsetB,
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
    if x < w - 300 and #hitted == 0 then
        modes.clear()
        state.pickAutoRopifyModeHitted = nil
    end
end

local function pressedJointCreation(cx, cy, hitted)
    local hitted2Bodies = #hitted == 2 and hitted[1]:getUserData() == nil and hitted[2]:getUserData() == nil
    if hitted2Bodies and (state.jointParams.body1 == nil) and (state.jointParams.body2 == nil) then
        -- if you click exactly where two bodies overlap,
        -- picking the one whose center is closest to your click as body1.
        local b1 = hitted[1]:getBody():getUserData().thing.body
        local b2 = hitted[2]:getBody():getUserData().thing.body

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
    objectManager.finalizePolygon()
end

local function releasedDrawFreePath()
    print('todo')
    objectManager.finalizePath()
end

local releasedHandlers = {
    [modes.DRAW_FREE_POLY] = releasedDrawFreePoly,
    [modes.DRAW_FREE_PATH] = releasedDrawFreePath,
}

local function handlePointer(x, y, id, action, _button)
    if action == "pressed" then
        -- Track whether press originated over a UI element
        state.interaction.pressedOverUI = ui.activeElementID or ui.overPanel or false
        -- this is a nice pattern, early return!
        if modes.is(modes.EDIT_MESH_TRIS) then return end

        -- POC Steiner-placement on the selected body's polygon.
        --   Left-click on existing point  → start drag (commits on release)
        --   Left-click away               → add a new point
        --   Right-click near existing     → remove nearest within radius
        if modes.is(modes.PLACE_STEINER) then
            if not state.interaction.pressedOverUI
                and state.selection.selectedObj
                and state.selection.selectedObj.body then
                local thing = state.selection.selectedObj
                local body = thing.body
                local wx, wy = cam:getWorldCoordinates(x, y)
                local lx, ly = body:getLocalPoint(wx, wy)
                thing.extraSteiner = thing.extraSteiner or {}

                -- Nearest existing Steiner within grab radius.
                local grabIdx, grabD = nil, 20 * 20
                for i = 1, #thing.extraSteiner, 2 do
                    local dx = thing.extraSteiner[i] - lx
                    local dy = thing.extraSteiner[i + 1] - ly
                    local d = dx * dx + dy * dy
                    if d < grabD then grabD = d; grabIdx = i end
                end

                local changed = false
                if _button == 1 and grabIdx then
                    -- Start drag — position updates in handleMouseMoved;
                    -- RESOURCE refresh deferred until release.
                    steinerDragIdx = grabIdx
                elseif _button == 1 then
                    -- Place a new point at click.
                    thing.extraSteiner[#thing.extraSteiner + 1] = lx
                    thing.extraSteiner[#thing.extraSteiner + 1] = ly
                    changed = true
                elseif _button == 2 and grabIdx then
                    -- Remove nearest.
                    table.remove(thing.extraSteiner, grabIdx)
                    table.remove(thing.extraSteiner, grabIdx)
                    changed = true
                end
                if changed then
                    refreshResourceAfterSteinerChange(body, thing)
                end
            end
            return
        end
        -- Handle press logig
        --   -- this will block interacting on bodies when 'roughly' over the opened panel
        if state.panelVisibility.saveDialogOpened then return end
        if state.panelVisibility.showPalette then
            local w, h = love.graphics.getDimensions()
            if y < h - 400 or x > w - 300 then
                state.panelVisibility.showPalette = nil
                return
            else
                return
            end
        end
        if state.selection.selectedJoint or state.selection.selectedObj
            or state.selection.selectedSFixture or state.selection.selectedBodies
            or modes.is(modes.DRAW_FREE_POLY)
            or modes.is(modes.DRAW_FREE_PATH) then
            local w = love.graphics.getDimensions()
            if x > w - 300 then
                return
            end
        end

        local startSelection = love.keyboard.isDown('lshift')
        if (startSelection) then
            state.interaction.startSelection = { x = x, y = y }
        end

        local cx, cy = cam:getWorldCoordinates(x, y)
        local rightShape = state.selection.selectedObj and (state.selection.selectedObj.shapeType == ST.CUSTOM or
            state.selection.selectedObj.shapeType == ST.RIBBON)
        -- print('hello??')
        if state.polyEdit.tempVerts and state.selection.selectedObj
            and rightShape and state.polyEdit.lockedVerts == false then
            local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
                state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.polyEdit.dragIdx = i

                    return
                else
                    state.polyEdit.dragIdx = 0
                end
            end
        end

        if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture
            and state.texFixtureEdit.lockedVerts == false then
            local thing = state.selection.selectedSFixture:getBody():getUserData().thing
            local verts = mathutils.getLocalVerticesForCustomSelected(state.texFixtureEdit.tempVerts,
                thing, 0, 0)

            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.texFixtureEdit.dragIdx = i
                    return
                else
                    state.texFixtureEdit.dragIdx = 0
                end
            end
        end

        -- Pre-physics mode dispatch
        local preHandler = prePhysicsHandlers[state.currentMode]
        if preHandler then
            local earlyReturn = preHandler(cx, cy, x)
            if earlyReturn then return end
        end

        -- Physics hit detection (shared infrastructure)
        local onPressedParams = {
            pointerForceFunc = function(_fixture)
                return state.world.mouseForce
            end,
            damp = state.world.mouseDamping
        }

        local _, hitted, madedata = box2dPointerJoints.handlePointerPressed(cx, cy, id, onPressedParams,
            not state.world.paused)

        if (state.selection.selectedBodies and #hitted == 0) then
            state.selection.selectedBodies = nil
        end

        -- Post-physics mode dispatch
        if modes.is(modes.PICK_AUTO_ROPIFY) then
            pressedPickAutoRopifyMode(hitted, x)
        end

        -- Default selection + jointCreationMode handling
        if #hitted > 0 and (not modes.is(modes.PICK_AUTO_ROPIFY)) then
            local ud = hitted[1]:getBody():getUserData()
            if ud and ud.thing then
                state.selection.selectedObj = ud.thing
            end
            if state.scene.sceneScript and not state.world.paused and state.selection.selectedObj then
                state.selection.selectedObj = nil
            end
            if modes.is(modes.JOINT_CREATION) and state.selection.selectedObj then
                pressedJointCreation(cx, cy, hitted)
            end

            if (state.world.paused) then
                if state.polyEdit.lockedVerts then
                    state.interaction.draggingObj = state.selection.selectedObj

                    if state.selection.selectedObj then
                        local offx, offy = state.selection.selectedObj.body:getLocalPoint(cx, cy)
                        state.interaction.offsetDragging = { -offx, -offy }
                    end
                end
            else
                local newHitted = utils.map(hitted, function(h)
                    local hud = (h:getBody() and h:getBody():getUserData())
                    local hthing = hud and hud.thing
                    return hthing
                end)
                script.call('onPressed', newHitted)
            end
        else
            state.interaction.pressMissedEverything = true
        end
        if recorder.isRecording and #hitted > 0 and not state.world.paused and madedata.bodyID then
            recorder:recordMouseJointStart(madedata)
        end
    elseif action == "released" then
        if modes.is(modes.EDIT_MESH_TRIS) then return end
        if modes.is(modes.PLACE_STEINER) then
            -- Commit any in-flight Steiner drag: refresh RESOURCE now that
            -- the point has landed, and drop bindings since topology moved.
            if steinerDragIdx > 0 then
                local thing = state.selection.selectedObj
                if thing and thing.body then
                    refreshResourceAfterSteinerChange(thing.body, thing)
                end
                steinerDragIdx = 0
            end
            return
        end

        -- Handle release logic
        local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
        if (#releasedObjs > 0) then
            local newReleased = utils.map(releasedObjs,
                function(h) return h:getUserData() and h:getUserData().thing end)

            script.call('onReleased', newReleased)
            if recorder.isRecording and not state.world.paused then
                for _, obj in ipairs(releasedObjs) do
                    recorder:recordMouseJointFinish(id, obj:getUserData().thing.id)
                end
            end
        end

        if state.interaction.pressMissedEverything then
            local wasOverUI = ui.activeElementID or ui.focusedTextInputID or ui.overPanel or state.interaction.pressedOverUI
            local wasSpawning = state.interaction.draggingObj ~= nil
            if not wasOverUI and not wasSpawning then
                if (state.selection.selectedSFixture and not state.selection.selectedSFixture:isDestroyed()) then
                    local body = state.selection.selectedSFixture:getBody()
                    local rthing = body:getUserData().thing

                    state.selection.selectedObj = rthing
                    state.selection.selectedSFixture = nil
                    state.texFixtureEdit.tempVerts = nil
                    state.texFixtureEdit.centroid = nil
                    state.texFixtureEdit.lockedVerts = true
                    state.interaction.maybeHideSelectedPanel = false
                elseif (state.selection.selectedJoint) then
                    state.selection.selectedJoint = nil
                    state.interaction.maybeHideSelectedPanel = false
                else
                    if not (ui.activeElementID or ui.focusedTextInputID) then
                        state.selection.selectedObj = nil
                        state.selection.selectedSFixture = nil
                        state.selection.selectedJoint = nil
                    end
                    state.interaction.maybeHideSelectedPanel = false
                    state.polyEdit.tempVerts = nil
                    state.polyEdit.lockedVerts = true
                end
                -- todo this is dumb..
                state.panelVisibility.addBehavior = false
                state.panelVisibility.customBehavior = false
                state.panelVisibility.addJointOpened = false
                state.panelVisibility.addShapeOpened = false
                state.panelVisibility.bgSettingsOpened = false
                state.panelVisibility.worldSettingsOpened = false
                state.panelVisibility.recordingPanelOpened = false
                state.panelVisibility.showPalette = false
            end
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
            objectManager.maybeUpdateCustomPolygonVertices()
        end

        if state.texFixtureEdit.dragIdx > 0 then
            state.texFixtureEdit.dragIdx = 0
            objectManager.maybeUpdateTexFixtureVertices()
        end

        if (state.interaction.startSelection) then
            local tlx = math.min(state.interaction.startSelection.x, x)
            local tly = math.min(state.interaction.startSelection.y, y)
            local brx = math.max(state.interaction.startSelection.x, x)
            local bry = math.max(state.interaction.startSelection.y, y)
            local tlxw, tlyw = cam:getWorldCoordinates(tlx, tly)
            local brxw, bryw = cam:getWorldCoordinates(brx, bry)
            local selected = selectrect.selectWithin(state.physicsWorld,
                { x = tlxw, y = tlyw, width = brxw - tlxw, height = bryw - tlyw })

            state.selection.selectedBodies = selected
            state.interaction.startSelection = nil
        end
    end
end

function lib.handleDraggingObj()
    --print('getshere')
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

    if state.world.playWithSoftbodies and button == 2 then
        local cx, cy = cam:getWorldCoordinates(x, y)


        local b = blob.softbody(state.physicsWorld, cx, cy, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)

        table.insert(state.world.softbodies, b)
    end
end

function lib.handleTouchPressed(id, x, y, _dx, _dy, _pressure)
    --handlePointer(x, y, id, 'pressed')
    if modes.is(modes.DRAW_FREE_POLY) or modes.is(modes.DRAW_FREE_PATH) then
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
    local closest = nil
    local closestDistanceSquared = math.huge
    for _, f in pairs(registry.sfixtures) do
        local body = f:getBody()
        local ud = f:getUserData()
        if subtypes.is(ud, subtypes.ANCHOR) then
            -- todo this will find ALL sfitures bot just anchors
            local centerX, centerY = mathutils.getCenterOfPoints({ body:getWorldPoints(f:getShape():getPoints()) })

            local d = distanceSquared(centerX, centerY, cx, cy)
            if d < closestDistanceSquared then
                closestDistanceSquared = d
                closest = { centerX, centerY }
            end
        end
    end
    for _, j in pairs(registry.joints) do
        local x1, y1 = j:getAnchors()
        local d = distanceSquared(x1, y1, cx, cy)
        if d < closestDistanceSquared then
            closestDistanceSquared = d
            closest = { x1, y1 }
        end
    end
    if math.sqrt(closestDistanceSquared) < 30 then
        return closest
    end
    return nil
end

function lib.handleMouseMoved(x, y, dx, dy)
    --print('moved')
    --
    --

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

    -- TRIANGLE SELECTION FOR MESH EDITING
    if modes.is(modes.EDIT_MESH_TRIS) and state.selection.selectedSFixture then
        local cx, cy = cam:getWorldCoordinates(x, y)
        local ud = state.selection.selectedSFixture:getUserData()
        if ud and subtypes.is(ud, subtypes.MESHUSERT) and ud.label then
            -- Find the RESOURCE fixture with matching label — it owns the
            -- triangle index array (ud.extra.triangles).
            local mappert = nil
            for _, v in pairs(registry.sfixtures) do
                if not v:isDestroyed() then
                    local vud = v:getUserData()
                    if #vud.label > 0 and vud.label == ud.label and subtypes.is(vud, subtypes.RESOURCE) then
                        mappert = v
                        break
                    end
                end
            end
            local button = nil
            if love.mouse.isDown(1) then button = 1 end
            if love.mouse.isDown(2) then button = 2 end
            local isCtrl = love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
            if mappert and button ~= nil then
                local mb = mappert:getBody()
                local mud = mb:getUserData()
                local mextra = mappert:getUserData().extra
                local triIdx = mextra and mextra.triangles
                if not triIdx or #triIdx < 3 then return end
                -- Match the draw path's vertex source: CDT mode uses
                -- meshVertices (includes Steiner points), basic mode falls
                -- back to the polygon.
                local baseVerts = (mextra and mextra.meshVertices) or mud.thing.vertices

                local body = state.selection.selectedSFixture:getBody()
                local polyCx, polyCy = mathutils.computeCentroid(baseVerts)
                local centeredVerts = mathutils.makePolygonRelativeToCenter(baseVerts, polyCx, polyCy)

                local brushRadius = tonumber(state.triangleEditor.brushSize) or 20
                local isRightClick = (button == 2)

                local function removeSelectedIndex(sel, idx)
                    for n = #sel, 1, -1 do
                        if sel[n] == idx then
                            table.remove(sel, n)
                            return true
                        end
                    end
                    return false
                end

                local mx = ud.extra.meshX or 0
                local my = ud.extra.meshY or 0
                local sx = ud.extra.scaleX or 1
                local sy = ud.extra.scaleY or 1
                local mr = ud.extra.meshRot or 0
                local cosR, sinR = math.cos(mr), math.sin(mr)

                local function worldAt(vertIndex)
                    local lx = centeredVerts[(vertIndex - 1) * 2 + 1]
                    local ly = centeredVerts[(vertIndex - 1) * 2 + 2]
                    lx = (lx + mx) * sx
                    ly = (ly + my) * sy
                    if mr ~= 0 then
                        lx, ly = lx * cosR - ly * sinR, lx * sinR + ly * cosR
                    end
                    return body:getWorldPoint(lx, ly)
                end

                local numTris = math.floor(#triIdx / 3)
                for t = 1, numTris do
                    local i1 = triIdx[(t - 1) * 3 + 1]
                    local i2 = triIdx[(t - 1) * 3 + 2]
                    local i3 = triIdx[(t - 1) * 3 + 3]
                    if i1 and i2 and i3 then
                        local x1, y1 = worldAt(i1)
                        local x2, y2 = worldAt(i2)
                        local x3, y3 = worldAt(i3)
                        local ccx = (x1 + x2 + x3) / 3
                        local ccy = (y1 + y2 + y3) / 3
                        local dist = math.sqrt((cx - ccx) ^ 2 + (cy - ccy) ^ 2)
                        if dist < brushRadius then
                            if isCtrl and button == 1 then
                                local tb = ud.extra.triangleBones
                                if tb and tb[t] then
                                    state.triangleEditor.selectedBone = tb[t]
                                    return
                                end
                            elseif isRightClick then
                                removeSelectedIndex(state.triangleEditor.selectedTriangles, t)
                                local tb = ud.extra.triangleBones
                                if tb and tb[t] == state.triangleEditor.selectedBone then
                                    tb[t] = nil
                                end
                            else
                                local already = false
                                for _, idx in ipairs(state.triangleEditor.selectedTriangles) do
                                    if idx == t then already = true; break end
                                end
                                if not already then
                                    table.insert(state.triangleEditor.selectedTriangles, t)
                                end
                            end
                        end
                    end
                end
                return
            end
        end
    end


    if state.polyEdit.dragIdx and state.polyEdit.dragIdx > 0 then
        local index = state.polyEdit.dragIdx
        local obj = state.selection.selectedObj
        local angle = obj.body:getAngle()
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        state.polyEdit.tempVerts[index] = state.polyEdit.tempVerts[index] + dx2
        state.polyEdit.tempVerts[index + 1] = state.polyEdit.tempVerts[index + 1] + dy2
    elseif state.texFixtureEdit.dragIdx and state.texFixtureEdit.dragIdx > 0 then
        local index = state.texFixtureEdit.dragIdx
        local obj = state.selection.selectedSFixture:getBody():getUserData().thing


        local angle = obj.body:getAngle()
        local dx2, dy2 = mathutils.rotatePoint(dx, dy, 0, 0, -angle)
        dx2 = dx2 / cam.scale
        dy2 = dy2 / cam.scale
        state.texFixtureEdit.tempVerts[index] = state.texFixtureEdit.tempVerts[index] + dx2
        state.texFixtureEdit.tempVerts[index + 1] = state.texFixtureEdit.tempVerts[index + 1] + dy2

        local ud = state.selection.selectedSFixture:getUserData()
        --logger:info(inspect(ud))
        ud.extra.vertices[index] = state.texFixtureEdit.tempVerts[index]
        ud.extra.vertices[index + 1] = state.texFixtureEdit.tempVerts[index + 1]
        state.selection.selectedSFixture:setUserData(ud)
        -- print(index)
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
        local tx, ty = cam:getTranslation()
        cam:setTranslation(tx - dx / cam.scale, ty - dy / cam.scale)
    end
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
    if key == 'i' and state.polyEdit.tempVerts then
        -- figure out where my mousecursor is, between what nodes?

        if state.selection.selectedObj and state.selection.selectedObj.shapeType == ST.RIBBON then
            -- logger:inspect(state.selection.selectedObj)
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            objectManager.insertRibbonPair(wx, wy)
            objectManager.maybeUpdateCustomPolygonVertices()
        else
            -- print(inspect(state.polyEdit))
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            objectManager.insertCustomPolygonVertex(wx, wy)
            objectManager.maybeUpdateCustomPolygonVertices()
        end
    end
    if key == 'd' and state.polyEdit.tempVerts then
        -- Remove a vertex
        if state.selection.selectedObj and state.selection.selectedObj.shapeType == ST.RIBBON then
            --logger:inspect(state.selection.selectedObj)
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            objectManager.removeRibbonPair(wx, wy)
            objectManager.maybeUpdateCustomPolygonVertices()
        else
            local mx, my = love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(mx, my)
            objectManager.removeCustomPolygonVertex(wx, wy)
        end
    end
end

return lib
