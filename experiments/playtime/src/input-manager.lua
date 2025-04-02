local lib = {}
local camera = require 'src.camera'
local cam = camera.getInstance()
local box2dPointerJoints = require 'src.box2d-pointerjoints'
local mathutils = require 'src.math-utils'
local recorder = require 'src.recorder'
local utils = require 'src.utils'
local script = require 'src.script'
local selectrect = require 'src.selection-rect'
local objectManager = require 'src.object-manager'
local state = require 'src.state'
local blob = require 'vendor.loveblobs'

local function handlePointer(x, y, id, action)
    if action == "pressed" then
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
        if state.selection.selectedJoint or state.selection.selectedObj or state.selection.selectedSFixture or state.selection.selectedBodies
            or state.currentMode == 'drawFreePoly' or state.currentMode == 'drawClickPoly' then
            local w, h = love.graphics.getDimensions()
            if x > w - 300 then
                return
            end
        end

        local startSelection = love.keyboard.isDown('lshift')
        if (startSelection) then
            state.interaction.startSelection = { x = x, y = y }
        end

        local cx, cy = cam:getWorldCoordinates(x, y)

        if state.polyEdit.tempVerts and state.selection.selectedObj and state.selection.selectedObj.shapeType == 'custom' and state.polyEdit.lockedVerts == false then
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

        if state.texFixtureEdit.tempVerts and state.selection.selectedSFixture and state.texFixtureEdit.lockedVerts == false then
            --local verts = mathutils.getLocalVerticesForCustomSelected(state.polyEdit.tempVerts,
            --    state.selection.selectedObj, state.polyEdit.centroid.x, state.polyEdit.centroid.y)
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



        if (state.currentMode == 'drawClickMode') then
            table.insert(state.interaction.polyVerts, cx)
            table.insert(state.interaction.polyVerts, cy)
        end
        if (state.interaction.setOffsetAFunc) then
            state.selection.selectedJoint = state.interaction.setOffsetAFunc(cx, cy)
            state.interaction.setOffsetAFunc = nil
        end
        if (state.interaction.setOffsetBFunc) then
            state.selection.selectedJoint = state.interaction.setOffsetBFunc(cx, cy)
            state.interaction.setOffsetBFunc = nil
        end
        if (state.interaction.setUpdateSFixturePosFunc) then
            state.selection.selectedSFixture = state.interaction.setUpdateSFixturePosFunc(cx, cy)
            state.interaction.setUpdateSFixturePosFunc = nil
        end

        local onPressedParams = {
            pointerForceFunc = function(fixture)
                return state.world.mouseForce
            end,
            damp = state.world.mouseDamping
        }

        local _, hitted, madedata = box2dPointerJoints.handlePointerPressed(cx, cy, id, onPressedParams,
            not state.world.paused)

        if (state.selection.selectedBodies and #hitted == 0) then
            state.selection.selectedBodies = nil
        end

        if #hitted > 0 then
            local ud = hitted[1]:getBody():getUserData()
            if ud and ud.thing then
                state.selection.selectedObj = ud.thing
            end
            if sceneScript and not state.world.paused and state.selection.selectedObj then
                state.selection.selectedObj = nil
            end
            if (state.currentMode == 'jointCreationMode') and state.selection.selectedObj then
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

            if (state.world.paused) then
                state.interaction.draggingObj = state.selection.selectedObj
                if state.selection.selectedObj then
                    local offx, offy = state.selection.selectedObj.body:getLocalPoint(cx, cy)
                    state.interaction.offsetDragging = { -offx, -offy }
                end
            else
                local newHitted = utils.map(hitted, function(h)
                    local ud = (h:getBody() and h:getBody():getUserData())
                    local thing = ud and ud.thing
                    return thing
                end)
                script.call('onPressed', newHitted)
            end
        else
            state.interaction.maybeHideSelectedPanel = true
        end
        if recorder.isRecording and #hitted > 0 and not state.world.paused and madedata.bodyID then
            --madedata.activeLayer = recorder.activeLayer
            recorder:recordMouseJointStart(madedata)
            -- print('should record a moujoint creation...', inspect(madedata))
        end
        -- if recorder.isRecording and #hitted > 0 then
        --     local wx, wy = cam:getWorldCoordinates(x, y)
        --     local hitObject = hitted[1]:getBody():getUserData().thing
        --     local localPointX, localPointY = hitObject.body:getLocalPoint(wx, wy)
        --     recorder:recordObjectGrab(hitObject, localPointX, localPointY, state.world.mouseForce, state.world
        --         .mouseDamping)
        -- end
    elseif action == "released" then
        -- Handle release logic
        local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
        if (#releasedObjs > 0) then
            local newReleased = utils.map(releasedObjs, function(h) return h:getUserData() and h:getUserData().thing end)

            script.call('onReleased', newReleased)
            if recorder.isRecording and not state.world.paused then
                for _, obj in ipairs(releasedObjs) do
                    recorder:recordMouseJointFinish(id, obj:getUserData().thing.id)
                    --  print('should record a moujoint deletion...', inspect(obj:getUserData().thing.id))
                end
            end

            -- if recorder.isRecording then
            --     --local releasedObjs = box2dPointerJoints.handlePointerReleased(x, y, id)
            --     for _, obj in ipairs(releasedObjs) do
            --         recorder:recordObjectRelease(obj:getUserData().thing)
            --     end
            -- end
        end
        if state.interaction.draggingObj then
            state.interaction.draggingObj.body:setAwake(true)
            state.selection.selectedObj = state.interaction.draggingObj
            state.interaction.draggingObj = nil
        end

        if state.currentMode == 'drawFreePoly' then
            objectManager.finalizePolygon()
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
    local mx, my = love.mouse.getPosition()
    local wx, wy = cam:getWorldCoordinates(mx, my)
    local offx = state.interaction.offsetDragging[1]
    local offy = state.interaction.offsetDragging[2]
    local rx, ry = mathutils.rotatePoint(offx, offy, 0, 0, state.interaction.draggingObj.body:getAngle())
    local oldPosX, oldPosY = state.interaction.draggingObj.body:getPosition()
    state.interaction.draggingObj.body:setPosition(wx + rx, wy + ry)
    if recorder.isRecording then
        local ud = state.interaction.draggingObj.body:getUserData()
        -- print(inspect(state.interaction.draggingObj))
        -- print(inspect(ud))
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
                        local oldPosX, oldPosY = state.selection.selectedBodies[j].body:getPosition()
                        state.selection.selectedBodies[j].body:setPosition(oldPosX + dx, oldPosY + dy)
                    end
                end
            end
        end
    end
end

function lib.handleMousePressed(x, y, button, istouch)
    if not istouch and button == 1 then
        if state.currentMode == 'drawFreePoly' then
            -- Start capturing mouse movement
            --state.interaction.capturingPoly = true
            state.interaction.polyVerts = {}
            state.interaction.lastPolyPt = nil
        else
            handlePointer(x, y, 'mouse', 'pressed')
        end
    end

    if state.world.playWithSoftbodies and button == 2 then
        local cx, cy = cam:getWorldCoordinates(x, y)


        local b = blob.softbody(state.physicsWorld, cx, cy, 102, 1, 1)
        b:setFrequency(3)
        b:setDamping(0.1)

        table.insert(state.world.softbodies, b)
    end
end

function lib.handleTouchPressed(id, x, y, dx, dy, pressure)
    --handlePointer(x, y, id, 'pressed')
    if state.currentMode == 'drawFreePoly' then
        -- Start capturing mouse movement
        --state.interaction.capturingPoly = true
        state.interaction.polyVerts = {}
        state.interaction.lastPolyPt = nil
    else
        handlePointer(x, y, id, 'pressed')
    end
end

function lib.handleMouseReleased(x, y, button, istouch)
    if not istouch then
        handlePointer(x, y, 'mouse', 'released')
    end
end

function lib.handleTouchReleased(id, x, y, dx, dy, pressure)
    handlePointer(x, y, id, 'released')
end

return lib
