local gestureState = {
    list = {},
    updateResolutionCounter = 0,
    updateResolution = 0.0167
}


local lib = {}

-- todo @ global singleton gestureState

lib.getState = function()
    return gestureState
end

function addGesturePoint(gest, time, x, y)
    assert(gest)
    print('adding gesture', #gest.positions)
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
