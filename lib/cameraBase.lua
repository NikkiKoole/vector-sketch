local Camera = require 'vendor.brady'

local function createCamera()
    offset = 0
    local W, H = love.graphics.getDimensions()
 
    return Camera(
       W - 2 * offset,
       H - 2 * offset,
       {
          x = offset, y = offset, resizable = true, maintainAspectRatio = true,
          resizingFunction = function(self, w, h)
             resizeCamera(self, w, h)
             local W, H = love.graphics.getDimensions()
             self.x = offset
             self.y = offset
          end,
          getContainerDimensions = function()
             local W, H = love.graphics.getDimensions()
             return W - 2 * offset, H - 2 * offset
          end
       }
    )
 end
 
local _c = createCamera()
local lib = {} 
lib.getInstance = function()
   return _c
end
return lib