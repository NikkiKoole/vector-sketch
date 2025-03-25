local recorder = {
    isRecording = false,
    isReplaying = false,
    isPaused = false,
    currentTime = 0,
    recordings = {}, -- Will hold multiple recording layers
    activeLayer = 1,
    events = {} -- Current layer's events
}

-- Event structure example:
local eventExample = {
    timestamp = 0.5, -- Time since recording started
    type = "mouse", -- "mouse", "touch", "keyboard", "ui"
    action = "pressed", -- "pressed", "released", "moved", etc.
    data = {
        x = 100,
        y = 200,
        button = 1,
        -- Additional event-specific data
    },
    uiState = {}, -- Snapshot of relevant UI state
    worldState = {} -- Snapshot of relevant world state
}

function recorder:startRecording(layerIndex)
    self.isRecording = true
    self.currentTime = 0
    self.activeLayer = layerIndex or #self.recordings + 1
    self.events = {}
end

function recorder:stopRecording()
    self.isRecording = false
    self.recordings[self.activeLayer] = self.events
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
            self:processEventsAtCurrentTime(events)
        end
    end
end

return recorder