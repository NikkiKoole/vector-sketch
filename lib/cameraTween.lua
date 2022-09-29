local _cameraTween = nil
local _tweenCameraDelta = nil

local lib = {}
lib.setCameraTween = function(data)
   --print(inspect(data))
   _cameraTween = data
end

lib.resetCameraTween = function()
   if _cameraTween then
      _cameraTween = nil
      _tweenCameraDelta = 0
   end
end

lib.getTween = function()
    return _cameraTween
end    
lib.setDelta = function(d)
    _tweenCameraDelta = d
end
return lib