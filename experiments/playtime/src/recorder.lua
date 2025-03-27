local box2dPointerJoints = require 'src.box2d-pointerjoints'
local registry = require 'src.registry'

local recorder = {
    isRecording = false,
    isReplaying = false,
    isPaused = false,
    currentTime = 0,
    recordings = {},           -- Will hold multiple recording layers
    activeLayer = 1,
    events = {},               -- Current layer's events
    --objectStates = {},         -- Store initial states of objects
    recordingMouseJoints = {}, -- here we save the mousejoints (or data to recreate them) whilst recording them
    replayingMouseJoints = {}  -- here we keep the actual mousejoints that have been createdwhile replaying a recording.

}

-- -- Event structure example:
-- local eventExample = {
--     timestamp = 0.5,    -- Time since recording started
--     type = "mouse",     -- "mouse", "touch", "keyboard", "ui"
--     action = "pressed", -- "pressed", "released", "moved", etc.
--     data = {
--         x = 100,
--         y = 200,
--         button = 1,
--         -- Additional event-specific data
--     },
--     uiState = {},   -- Snapshot of relevant UI state
--     worldState = {} -- Snapshot of relevant world state
-- }

function recorder:startRecording(layerIndex)
    self.isRecording = true
    self.currentTime = 0
    self.startTime = love.timer.getTime()
    self.activeLayer = layerIndex or #self.recordings + 1
    self.events = {}
end

function recorder:stopRecording()
    self.isRecording = false
    self.recordings[self.activeLayer] = self.events
    -- print(#self.recordings, #self.events)
end

function recorder:startReplay()
    self.isReplaying = true
    self.currentTime = 0
    -- Save initial world state
end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function recorder:update(dt)
    if not (self.isRecording or self.isReplaying) or self.isPaused then return end

    self.currentTime = self.currentTime + dt

    if self.isReplaying then
        -- Process all recordings
        for layerIdx, events in ipairs(self.recordings) do
            for i = 1, #events do
                local evt = events[i]
                -- print(evt.timestamp, self.currentTime)
                if evt.timestamp == self.currentTime then
                    print('event at index ', i, #events)
                    recorder:processEvent(evt)
                end
            end
            -- self:processEventsAtCurrentTime(events)
        end
    end
end

local function getPointerPosition(id)
    if id == 'mouse' then
        return love.mouse.getPosition()
    else
        return love.touch.getPosition(id)
    end
end
function recorder:recordMouseJointUpdates(cam)
    for k, v in pairs(self.recordingMouseJoints) do
        --count = count + 1

        if v.data.pointerId then
            local x, y = getPointerPosition(v.data.pointerId)


            -- local mx = data.x
            -- local my = data.y
            --local cam = data.cam
            -- local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            local wx, wy = cam:getWorldCoordinates(x, y)

            local event = {
                type = "object_interaction",
                timestamp = self.currentTime,
                action = "mousejoint-update",
                data = {
                    --cam = cam,
                    pointerId = v.data.pointerId,
                    objectId = v.data.objectId,
                    x = wx,
                    y = wy
                }
            }
            -- print(inspect(event))
            table.insert(self.events, event)
        end
    end
end

function recorder:recordMouseJointStart(data)
    -- local created = box2dPointerJoints.makePointerJoint(data.id, registry.getBodyByID(data.udID), data.wx, data.wy,
    --     data.force, data
    --     .damp)
    -- print(created)

    local event = {
        type = "object_interaction",
        timestamp = self.currentTime,
        action = "mousejoint-start",
        data = {
            pointerId = data.pointerID,
            objectId = data.bodyID,
            wx = data.wx,
            wy = data.wy,
            force = data.force,
            damp = data.damp
        }
    }
    --    print(inspect(event))
    self.recordingMouseJoints[data.pointerID .. data.bodyID .. self.activeLayer] = event
    table.insert(self.events, event)
end

function recorder:recordMouseJointFinish(pointerid, bodyid)
    -- print(inspect(id))
    local event = {
        type = "object_interaction",
        timestamp = self.currentTime,
        action = "mousejoint-end",
        data = {
            pointerId = pointerid,
            objectId = bodyid,

        }
    }
    --   print(inspect(event))
    self.recordingMouseJoints[pointerid .. bodyid .. self.activeLayer] = nil
    table.insert(self.events, event)
end

function recorder:recordPause(pause)
    local event = {
        timestamp = self.currentTime,
        type = "world_interaction",
        action = "pause",
        data = {
            state = pause
        }
    }
    table.insert(self.events, event)
end

function recorder:recordObjectSetPosition(bodyId, x, y)
    local event = {
        timestamp = self.currentTime,
        type = "object_interaction",
        action = "position",
        data = {
            objectId = bodyId,
            x = x,
            y = y
        }
    }
    print(inspect(event))
    table.insert(self.events, event)
end

-- function recorder:recordObjectGrab(object, grabPointX, grabPointY, force, damping)
--     if not self.isRecording then return end

--     local event = {
--         timestamp = self.currentTime,
--         type = "object_interaction",
--         action = "grab",
--         data = {
--             objectId = object.id,
--             relativeGrabPoint = {
--                 x = grabPointX,
--                 y = grabPointY
--             },
--             force = force,
--             damping = damping
--         }
--     }
--     --print(inspect(event))
--     table.insert(self.events, event)
-- end

-- function recorder:recordObjectRelease(object)
--     if not self.isRecording then return end

--     local vx, vy = object.body:getLinearVelocity()
--     local event = {
--         timestamp = self.currentTime,
--         type = "object_interaction",
--         action = "release",
--         data = {
--             objectId = object.id,
--             finalVelocity = { x = vx, y = vy },
--             finalAngularVelocity = object.body:getAngularVelocity()
--         }
--     }
--     --print(inspect(event))
--     table.insert(self.events, event)
-- end

-- During replay, we'll need to map recorded object IDs to current objects
function recorder:mapRecordedIdToCurrentObject(recordedId)
    -- This needs to be implemented based on your object tracking system
    -- Could use position matching, object properties, or maintain an ID mapping
    --return self.objectMapping[recordedId]
    -- print(recordedId, inspect(registry.bodies))
    return registry.getBodyByID(recordedId)
end

function recorder:processEvent(event)
    --    print(inspect(event))
    --print(event.data.objectId)
    --print(registry.getBodyByID(event.data.objectId))
    if event.type == "object_interaction" then
        local currentObject = self:mapRecordedIdToCurrentObject(event.data.objectId)
        --      print(currentObject)
        if not currentObject then return end

        -- if event.action == "grab" then
        --     local grabPoint = {
        --         x = event.data.relativeGrabPoint.x * currentObject.width,
        --         y = event.data.relativeGrabPoint.y * currentObject.height
        --     }
        --     -- Apply the grab using your existing pointer joint system
        --     box2dPointerJoints.handlePointerPressed(
        --         grabPoint.x,
        --         grabPoint.y,
        --         'replay',
        --         {
        --             pointerForceFunc = function() return event.data.force end,
        --             damp = event.data.damping
        --         }
        --     )
        -- elseif event.action == "release" then
        --     box2dPointerJoints.handlePointerReleased(0, 0, 'replay')
        --     -- Optionally apply recorded velocity
        --     if event.data.finalVelocity then
        --         currentObject.body:setLinearVelocity(
        --             event.data.finalVelocity.x,
        --             event.data.finalVelocity.y
        --         )
        --     end
        -- else
        if event.action == "position" then
            --print(inspect(currentObject))
            currentObject:setPosition(event.data.x, event.data.y)
        elseif event.action == 'mousejoint-start' then
            local data = event.data
            local created = box2dPointerJoints.makePointerJoint(
                data.pointerId, registry.getBodyByID(data.objectId), data.wx, data.wy,
                data.force, data.damp)
            print(created)
            self.replayingMouseJoints[data.pointerId .. data.objectId .. self.activeLayer] =
            {
                joint = created.joint,
                body = created.jointBody,
                objectId = data.objectId
            }
        elseif event.action == 'mousejoint-update' then
            local data = event.data
            -- local mx = data.x
            -- local my = data.y
            -- local cam = data.cam
            -- -- local mx, my = getPointerPosition(mj.id) --love.mouse.getPosition()
            -- local wx, wy = cam:getWorldCoordinates(mx, my)
            self.replayingMouseJoints[data.pointerId .. data.objectId .. self.activeLayer].joint:setTarget(data.x, data
            .y)
            -- mj.joint:setTarget(wx, wy)
        elseif event.action == 'mousejoint-end' then
            print('jo got smethign', inspect(event))
            local data = event.data

            local is = self.replayingMouseJoints[data.pointerId .. data.objectId .. self.activeLayer]

            if is and is.joint then
                is.joint:destroy()
            end

            self.replayingMouseJoints[data.pointerId .. data.objectId .. self.activeLayer] = nil
            print(inspect(self.replayingMouseJoints))
            print(tablelength(self.replayingMouseJoints))
        else
            print(inspect(event))
        end
    end
    if event.type == 'world_interaction' then
        if event.action == 'pause' then
            worldState.paused = event.data.state
        end
    end
end

return recorder
