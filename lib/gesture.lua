local gestureState = {
    list = {},
    updateResolutionCounter = 0,
    updateResolution = 0.0167
}

local translateScheduler = {
    x = 0,
    y = 0,
    justItem = { x = 0, y = 0 },
    happenedByPressedItems = false,
    cache = { value = 0, cacheValue = 0, stopped = true, stoppedAt = 0, tweenValue = 0 }
}

local lib = {}

local _c = gestureState
lib.getState = function()
    return _c
end

return lib
