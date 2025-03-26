local box2dPointerJoints = require 'src.box2d-pointerjoints'
local registry = require 'src.registry'

local recorder = {
    isRecording = false,
    isReplaying = false,
    isPaused = false,
    currentTime = 0,
    recordings = {},  -- Will hold multiple recording layers
    activeLayer = 1,
    events = {},      -- Current layer's events
    objectStates = {} -- Store initial states of objects
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
    print(#self.recordings, #self.events)
end

function recorder:startReplay()
    self.isReplaying = true
    self.currentTime = 0
    -- Save initial world state
end

function recorder:update(dt)
    if not (self.isRecording or self.isReplaying) or self.isPaused then return end

    self.currentTime = self.currentTime + dt

    if self.isReplaying then
        -- Process all recordings
        for layerIdx, events in ipairs(self.recordings) do
            for i = 1, #events do
                local evt = events[i]

                if evt.timestamp == self.currentTime then
                    -- print('event at index ', i)
                    recorder:processEvent(evt)
                end
            end
            -- self:processEventsAtCurrentTime(events)
        end
    end
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

function recorder:recordObjectGrab(object, grabPointX, grabPointY, force, damping)
    if not self.isRecording then return end

    local event = {
        timestamp = self.currentTime,
        type = "object_interaction",
        action = "grab",
        data = {
            objectId = object.id,
            relativeGrabPoint = {
                x = grabPointX,
                y = grabPointY
            },
            force = force,
            damping = damping
        }
    }
    --print(inspect(event))
    table.insert(self.events, event)
end

function recorder:recordObjectRelease(object)
    if not self.isRecording then return end

    local vx, vy = object.body:getLinearVelocity()
    local event = {
        timestamp = self.currentTime,
        type = "object_interaction",
        action = "release",
        data = {
            objectId = object.id,
            finalVelocity = { x = vx, y = vy },
            finalAngularVelocity = object.body:getAngularVelocity()
        }
    }
    --print(inspect(event))
    table.insert(self.events, event)
end

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

        if event.action == "grab" then
            local grabPoint = {
                x = event.data.relativeGrabPoint.x * currentObject.width,
                y = event.data.relativeGrabPoint.y * currentObject.height
            }
            -- Apply the grab using your existing pointer joint system
            box2dPointerJoints.handlePointerPressed(
                grabPoint.x,
                grabPoint.y,
                'replay',
                {
                    pointerForceFunc = function() return event.data.force end,
                    damp = event.data.damping
                }
            )
        elseif event.action == "release" then
            box2dPointerJoints.handlePointerReleased(0, 0, 'replay')
            -- Optionally apply recorded velocity
            if event.data.finalVelocity then
                currentObject.body:setLinearVelocity(
                    event.data.finalVelocity.x,
                    event.data.finalVelocity.y
                )
            end
        elseif event.action == "position" then
            --print(inspect(currentObject))
            currentObject:setPosition(event.data.x, event.data.y)
        else
            -- print('jo got smethign', inspect(event))
        end
    end
end

return recorder
