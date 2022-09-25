local Camera = require 'vendor.brady'

-- todo this function gets called continuosly
-- from brady
local function resizeCamera(self, w, h)
   local scaleW, scaleH = w / self.w, h / self.h
   local scale = math.min(scaleW, scaleH)
   -- the line below keeps aspect
   --self.w, self.h = scale * self.w, scale * self.h
   -- the line below deosnt keep aspect
   self.w, self.h = scaleW * self.w, scaleH * self.h
   self.aspectRatio = self.w / w
   self.offsetX, self.offsetY = self.w / 2, self.h / 2
   offset = offset * scale

end

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
