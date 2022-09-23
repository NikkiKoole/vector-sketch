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

-- todo @ global singleton gestureState
local _gs = gestureState
lib.getState = function()
    return _gs
end

function addGesturePoint(gest, time, x, y)
    assert(gest)
    print('adding gesture')
    table.insert(gest.positions, { time = time, x = x, y = y })
 end

 function removeGestureFromList(gesture)
    
    for i = #gestureState.list, 1, -1 do
       if gestureState.list[i] == gesture then
        print('removing gesture')
          table.remove(gestureState.list, i)
       end
    end
 end 


return lib
