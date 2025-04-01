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
        if state.ui.saveDialogOpened then return end
        if state.ui.showPalette then
            local w, h = love.graphics.getDimensions()
            if y < h - 400 or x > w - 300 then
                state.ui.showPalette = nil
                return
            else
                return
            end
        end
        if state.ui.selectedJoint or state.ui.selectedObj or state.ui.selectedSFixture or state.ui.selectedBodies or state.ui.drawClickPoly then
            local w, h = love.graphics.getDimensions()
            if x > w - 300 then
                return
            end
        end

        local startSelection = love.keyboard.isDown('lshift')
        if (startSelection) then
            state.ui.startSelection = { x = x, y = y }
        end

        local cx, cy = cam:getWorldCoordinates(x, y)

        if state.ui.polyTempVerts and state.ui.selectedObj and state.ui.selectedObj.shapeType == 'custom' and state.ui.polyLockedVerts == false then
            local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.polyTempVerts,
                state.ui.selectedObj, state.ui.polyCentroid.x, state.ui.polyCentroid.y)
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.ui.polyDragIdx = i

                    return
                else
                    state.ui.polyDragIdx = 0
                end
            end
        end

        if state.ui.texFixtureTempVerts and state.ui.selectedSFixture and state.ui.texFixtureLockedVerts == false then
            --local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.polyTempVerts,
            --    state.ui.selectedObj, state.ui.polyCentroid.x, state.ui.polyCentroid.y)
            local thing = state.ui.selectedSFixture:getBody():getUserData().thing
            local verts = mathutils.getLocalVerticesForCustomSelected(state.ui.texFixtureTempVerts,
                thing, 0, 0)
            --local verts = state.ui.texFixtureTempVerts
            for i = 1, #verts, 2 do
                local vx = verts[i]
                local vy = verts[i + 1]
                local dist = math.sqrt((cx - vx) ^ 2 + (cy - vy) ^ 2)
                if dist < 10 then
                    state.ui.texFixtureDragIdx = i
                    return
                else
                    state.ui.texFixtureDragIdx = 0
                end
            end
        end



        if (state.ui.drawClickPoly) then
            table.insert(state.ui.polyVerts, cx)
            table.insert(state.ui.polyVerts, cy)
        end
        if (state.ui.setOffsetAFunc) then
            state.ui.selectedJoint = state.ui.setOffsetAFunc(cx, cy)
            state.ui.setOffsetAFunc = nil
        end
        if (state.ui.setOffsetBFunc) then
            state.ui.selectedJoint = state.ui.setOffsetBFunc(cx, cy)
            state.ui.setOffsetBFunc = nil
        end
        if (state.ui.setUpdateSFixturePosFunc) then
            state.ui.selectedSFixture = state.ui.setUpdateSFixturePosFunc(cx, cy)
            state.ui.setUpdateSFixturePosFunc = nil
        end

        local onPressedParams = {
            pointerForceFunc = function(fixture)
                return state.world.mouseForce
            end,
            damp = state.world.mouseDamping
        }

        local _, hitted, madedata = box2dPointerJoints.handlePointerPressed(cx, cy, id, onPressedParams,
            not state.world.paused)

        if (state.ui.selectedBodies and #hitted == 0) then
            state.ui.selectedBodies = nil
        end

        if #hitted > 0 then
            local ud = hitted[1]:getBody():getUserData()
            if ud and ud.thing then
                state.ui.selectedObj = ud.thing
            end
            if sceneScript and not state.world.paused and state.ui.selectedObj then
                state.ui.selectedObj = nil
            end
            if state.ui.jointCreationMode and state.ui.selectedObj then
                if state.ui.jointCreationMode.body1 == nil then
                    state.ui.jointCreationMode.body1 = state.ui.selectedObj.body
                    local px, py = state.ui.jointCreationMode.body1:getLocalPoint(cx, cy)
                    state.ui.jointCreationMode.p1 = { px, py }
                elseif state.ui.jointCreationMode.body2 == nil then
                    if (state.ui.selectedObj.body ~= state.ui.jointCreationMode.body1) then
                        state.ui.jointCreationMode.body2 = state.ui.selectedObj.body
                        local px, py = state.ui.jointCreationMode.body2:getLocalPoint(cx, cy)
                        state.ui.jointCreationMode.p2 = { px, py }
                        --print(state.ui.jointCreationMode.body2:getLocalPoint(cx, cy))
                    end
                end
            end

            if (state.world.paused) then
                -- local ud = state.ui.currentlySelectedObject:getBody():getUserData()
                state.ui.draggingObj = state.ui.selectedObj
                if state.ui.selectedObj then
                    local offx, offy = state.ui.selectedObj.body:getLocalPoint(cx, cy)
                    state.ui.offsetDragging = { -offx, -offy }
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
            state.ui.maybeHideSelectedPanel = true
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
        if state.ui.draggingObj then
            state.ui.draggingObj.body:setAwake(true)
            state.ui.selectedObj = state.ui.draggingObj
            state.ui.draggingObj = nil
        end

        if state.ui.drawFreePoly then
            objectManager.finalizePolygon()
        end

        if state.ui.polyDragIdx > 0 then
            state.ui.polyDragIdx = 0
            objectManager.maybeUpdateCustomPolygonVertices()
        end

        if state.ui.texFixtureDragIdx > 0 then
            state.ui.texFixtureDragIdx = 0
            objectManager.maybeUpdateTexFixtureVertices()
        end

        if (state.ui.startSelection) then
            local tlx = math.min(state.ui.startSelection.x, x)
            local tly = math.min(state.ui.startSelection.y, y)
            local brx = math.max(state.ui.startSelection.x, x)
            local bry = math.max(state.ui.startSelection.y, y)
            local tlxw, tlyw = cam:getWorldCoordinates(tlx, tly)
            local brxw, bryw = cam:getWorldCoordinates(brx, bry)
            local selected = selectrect.selectWithin(state.physicsWorld,
                { x = tlxw, y = tlyw, width = brxw - tlxw, height = bryw - tlyw })

            state.ui.selectedBodies = selected
            state.ui.startSelection = nil
        end
    end
end

function lib.handleDraggingObj()
    local mx, my = love.mouse.getPosition()
    local wx, wy = cam:getWorldCoordinates(mx, my)
    local offx = state.ui.offsetDragging[1]
    local offy = state.ui.offsetDragging[2]
    local rx, ry = mathutils.rotatePoint(offx, offy, 0, 0, state.ui.draggingObj.body:getAngle())
    local oldPosX, oldPosY = state.ui.draggingObj.body:getPosition()
    state.ui.draggingObj.body:setPosition(wx + rx, wy + ry)
    if recorder.isRecording then
        local ud = state.ui.draggingObj.body:getUserData()
        -- print(inspect(state.ui.draggingObj))
        -- print(inspect(ud))
        recorder:recordObjectSetPosition(state.ui.draggingObj.id, wx + rx, wy + ry)
    end
    -- figure out if we are dragging a group!
    if state.ui.selectedBodies then
        for i = 1, #state.ui.selectedBodies do
            if (state.ui.selectedBodies[i] == state.ui.draggingObj) then
                local newPosX, newPosY = state.ui.draggingObj.body:getPosition()
                local dx = newPosX - oldPosX
                local dy = newPosY - oldPosY
                for j = 1, #state.ui.selectedBodies do
                    if (state.ui.selectedBodies[j] ~= state.ui.draggingObj) then
                        local oldPosX, oldPosY = state.ui.selectedBodies[j].body:getPosition()
                        state.ui.selectedBodies[j].body:setPosition(oldPosX + dx, oldPosY + dy)
                    end
                end
            end
        end
    end
end

function lib.handleMousePressed(x, y, button, istouch)
    if not istouch and button == 1 then
        if state.ui.drawFreePoly then
            -- Start capturing mouse movement
            state.ui.capturingPoly = true
            state.ui.polyVerts = {}
            state.ui.lastPolyPt = nil
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
    if state.ui.drawFreePoly then
        -- Start capturing mouse movement
        state.ui.capturingPoly = true
        state.ui.polyVerts = {}
        state.ui.lastPolyPt = nil
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
