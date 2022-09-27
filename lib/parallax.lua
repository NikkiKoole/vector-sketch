local parallax = {}

parallax.sortOnDepth = function(list)
   table.sort(list, function(a, b) return a.depth < b.depth end)
end

local _dynamic = nil
local _p = nil
parallax.setDynamicThing = function(p)
   _dynamic = generateCameraLayer('dynamic', 1)
   _p = p
end
parallax.getDynamicThing = function()
   return _p
end
parallax.getDynamicCam = function()
   return _dynamic
end

return parallax
