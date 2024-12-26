--camera.lua
local Camera = require 'vendor.brady'


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
            x = offset,
            y = offset,
            resizable = true,
            maintainAspectRatio = true,
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

local _camera = createCamera()
local lib = {}
-- i've gotten rid of a lot of older functionality i was using i the vector sketch experiments, no longer usefull.'
lib.getInstance = function()
    return _camera
end
lib.centerCameraOnPosition = function(x, y, vw, vh)
    local cw, ch = _camera:getContainerDimensions()
    local targetScale = math.min(cw / vw, ch / vh)
    _camera:setScale(targetScale)
    _camera:setTranslation(x, y)
end
lib.setCameraViewport = function(c2, w, h)
    local cx, cy = c2:getTranslation()
    local cw, ch = c2:getContainerDimensions()
    local targetScale = math.min(cw / w, ch / h)
    c2:setScale(targetScale)
    c2:setTranslation(cx, -1 * h / 2)
end

return lib
