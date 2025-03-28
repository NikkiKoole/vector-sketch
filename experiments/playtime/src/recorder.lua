local box2dPointerJoints = require 'src.box2d-pointerjoints'
local registry = require 'src.registry'
local utils = require 'src.utils'
function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

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
    replayingMouseJoints = {}, -- here we keep the actual mousejoints that have been createdwhile replaying a recording.
    replayIndices = {}
}

function recorder:startRecording(layerIndex)
    self.isRecording = true
    self.currentTime = 0
    self.startTime = love.timer.getTime()
    self.activeLayer = layerIndex or #self.recordings + 1
    --self.events = {}
    --self.recordings = {}

    self.replayIndices = {}
    self.recordingMouseJoints = {} -- here we save the mousejoints (or data to recreate them) whilst recording them
    self.replayingMouseJoints = {} --

    print('started recording on layer', self.activeLayer, layerIndex)
end

function recorder:stopRecording()
    self.isRecording = false
    self.recordings[self.activeLayer] = utils.deepCopy(self.events)
    self.events = {}
    -- self.recordings.layerindex = self.activeLayer
    -- print(#self.recordings, #self.events)
end

function recorder:startReplay()
    self.isReplaying = true
    self.currentTime = 0

    for i = 1, #self.recordings do
        self.replayIndices[i] = 1
    end
    -- Save initial world state
end

function recorder:update(dt)
    if not (self.isRecording or self.isReplaying) or self.isPaused then return end

    self.currentTime = self.currentTime + dt

    if self.isReplaying then
        -- Process all recordings
        for layerIdx = 1, #self.recordings do
            local events = self.recordings[layerIdx]
            --for layerIdx, events in ipairs(self.recordings) do
            --  local startIdx = self.replayIndices[layerIdx]
            --  local batchSize = 3
            -- local endIdx = math.min(startIdx + batchSize, #events)
            for i = 1, #events do
                local evt = events[i]
                -- print(evt.timestamp, self.currentTime)
                if evt.timestamp == self.currentTime then
                    --print('event at index ', i, #events)
                    recorder:processEvent(evt, layerIdx)
                    self.replayIndices[layerIdx] = i
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
        if v.data.pointerId then
            local x, y = getPointerPosition(v.data.pointerId)
            local wx, wy = cam:getWorldCoordinates(x, y)

            local event = {
                type = "object_interaction",
                timestamp = self.currentTime,
                action = "mousejoint-update",
                data = {
                    pointerId = v.data.pointerId,
                    objectId = v.data.objectId,
                    x = wx,
                    y = wy
                }
            }

            table.insert(self.events, event)
        end
    end
end

function recorder:recordMouseJointStart(data)
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
    --print(inspect(data))
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
    --print(inspect(event))
    table.insert(self.events, event)
end

-- During replay, we'll need to map recorded object IDs to current objects
function recorder:mapRecordedIdToCurrentObject(recordedId)
    return registry.getBodyByID(recordedId)
end

function recorder:processEvent(event, layerIdx)
    if event.type == "object_interaction" then
        local currentObject = self:mapRecordedIdToCurrentObject(event.data.objectId)

        if not currentObject then return end

        if event.action == "position" then
            currentObject:setPosition(event.data.x, event.data.y)
        elseif event.action == 'mousejoint-start' then
            local data = event.data
            local created = box2dPointerJoints.makePointerJoint(
                data.pointerId, registry.getBodyByID(data.objectId), data.wx, data.wy,
                data.force, data.damp)
            --print(created)
            self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx] =
            {
                joint = created.joint,
                body = created.jointBody,
                objectId = data.objectId
            }
        elseif event.action == 'mousejoint-update' then
            local data = event.data

            self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx].joint:setTarget(data.x, data
                .y)
        elseif event.action == 'mousejoint-end' then
            local data = event.data
            local is = self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx]

            if is and is.joint then
                is.joint:destroy()
            end

            self.replayingMouseJoints[data.pointerId .. data.objectId .. layerIdx] = nil
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
