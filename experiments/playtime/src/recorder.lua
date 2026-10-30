local logger = require('src.logger')
local inspect = require('vendor.inspect')
local box2dPointerJoints = require('src.physics.box2d-pointerjoints')
local registry = require('src.registry')
local utils = require('src.utils')
local state = require('src.state')

local recorder = {
    isRecording = false,
    isReplaying = false,
    isPaused = false,
    currentTime = 0,
    recordings = {},           -- Will hold multiple recording layers
    activeLayer = 1,
    events = {},               -- Current layer's events
    recordingMouseJoints = {}, -- here we save the mousejoints (or data to recreate them) whilst recording them
    replayingMouseJoints = {}, -- here we keep the actual mousejoints that have been createdwhile replaying a recording.
    replayIndices = {}
}

-- One pointer on one body in one layer: the key for its mouse joint while recording and replaying.
local function jointKey(pointerId, objectId, layer)
    return pointerId .. objectId .. layer
end

function recorder:startRecording(layerIndex)
    self.isRecording = true
    self.currentTime = 0
    self.startTime = love.timer.getTime()
    self.activeLayer = layerIndex or #self.recordings + 1

    self.replayIndices = {}
    self.recordingMouseJoints = {} -- here we save the mousejoints (or data to recreate them) whilst recording them
    self.replayingMouseJoints = {} --

    logger:info('started recording on layer', self.activeLayer, layerIndex)
end

function recorder:stopRecording()
    self.isRecording = false
    self.recordings[self.activeLayer] = utils.deepCopy(self.events)
    self.events = {}
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
        -- Process all recordings. Cursor per layer, fire everything due up
        -- to currentTime: exact float-equality dispatch silently skipped
        -- events whenever replay's dt accumulation diverged from recording
        -- (panic cap, speed multiplier), orphaning mouse joints.
        for layerIdx = 1, #self.recordings do
            local events = self.recordings[layerIdx]
            local i = self.replayIndices[layerIdx] or 1
            while i <= #events and events[i].timestamp <= self.currentTime do
                recorder:processEvent(events[i], layerIdx)
                i = i + 1
            end
            self.replayIndices[layerIdx] = i
        end
    end
end

-- Record an event at the current time.
function recorder:addEvent(type, action, data)
    local event = { type = type, timestamp = self.currentTime, action = action, data = data }
    table.insert(self.events, event)
    return event
end

function recorder:recordMouseJointUpdates(cam)
    for _, v in pairs(self.recordingMouseJoints) do
        if v.data.pointerId then
            local x, y = box2dPointerJoints.getPointerPosition(v.data.pointerId)
            local wx, wy = cam:getWorldCoordinates(x, y)
            self:addEvent('object_interaction', 'mousejoint-update',
                { pointerId = v.data.pointerId, objectId = v.data.objectId, x = wx, y = wy })
        end
    end
end

function recorder:recordMouseJointStart(data)
    local event = self:addEvent('object_interaction', 'mousejoint-start', {
        pointerId = data.pointerID,
        objectId = data.bodyID,
        wx = data.wx,
        wy = data.wy,
        force = data.force,
        damp = data.damp
    })
    self.recordingMouseJoints[jointKey(data.pointerID, data.bodyID, self.activeLayer)] = event
end

function recorder:recordMouseJointFinish(pointerid, bodyid)
    self.recordingMouseJoints[jointKey(pointerid, bodyid, self.activeLayer)] = nil
    self:addEvent('object_interaction', 'mousejoint-end', { pointerId = pointerid, objectId = bodyid })
end

function recorder:recordPause(pause)
    self:addEvent('world_interaction', 'pause', { state = pause })
end

function recorder:recordObjectSetPosition(bodyId, x, y)
    self:addEvent('object_interaction', 'position', { objectId = bodyId, x = x, y = y })
end

-- During replay, we'll need to map recorded object IDs to current objects
function recorder.mapRecordedIdToCurrentObject(_self, recordedId)
    return registry.getBodyByID(recordedId)
end

function recorder:processEvent(event, layerIdx)
    if event.type == "object_interaction" then
        local currentObject = self:mapRecordedIdToCurrentObject(event.data.objectId)

        if not currentObject then return end

        local data = event.data
        local key = data.pointerId and jointKey(data.pointerId, data.objectId, layerIdx) -- not on 'position'
        if event.action == "position" then
            currentObject:setPosition(data.x, data.y)
        elseif event.action == 'mousejoint-start' then
            local created = box2dPointerJoints.makePointerJoint(
                data.pointerId, registry.getBodyByID(data.objectId), data.wx, data.wy,
                data.force, data.damp)

            if created and created.joint then
                self.replayingMouseJoints[key] = {
                    joint = created.joint,
                    body = created.jointBody,
                    objectId = data.objectId
                }
            end
        elseif event.action == 'mousejoint-update' then
            local mj = self.replayingMouseJoints[key]
            if mj and mj.joint and not mj.joint:isDestroyed() then
                mj.joint:setTarget(data.x, data.y)
            end
        elseif event.action == 'mousejoint-end' then
            local mj = self.replayingMouseJoints[key]
            if mj and mj.joint then
                mj.joint:destroy()
            end
            self.replayingMouseJoints[key] = nil
        else
            logger:info(inspect(event))
        end
    end
    if event.type == 'world_interaction' then
        if event.action == 'pause' then
            state.world.paused = event.data.state
        end
    end
end

return recorder
