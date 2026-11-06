-- shadow-silhouettes.lua — the textured world drawn once more into a canvas, as it is, for the shadows to
-- use: the soft wall shadows (src/backdrop-shadows.lua, shifting it as they lay it down) and the 3D ones
-- (src/projected-shadows.lua). Drawn once a frame however many use it (LS12: each shadow drawing the world
-- again cost ~4-5 ms on the phone). main.lua calls newFrame() before the shadows; within a frame the
-- canvas is drawn again only if the world, the transform or the target's size changed.
local lib = {}

local canvas
local key = {}

local function canvasFor(w, h)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        if canvas then canvas:release() end
        canvas = love.graphics.newCanvas(w, h)
        key = {}
    end
    return canvas
end

function lib.newFrame()
    key = {}
end

-- the silhouettes canvas (the size of the current target, drawn under the current transform) and its size
function lib.get(world)
    local target = love.graphics.getCanvas()
    local w, h
    if target then w, h = target:getDimensions() else w, h = love.graphics.getDimensions() end
    local silhouettes = canvasFor(w, h)
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 1)
    if key.world == world and key.x0 == x0 and key.y0 == y0 and key.x1 == x1 and key.y1 == y1 then
        return silhouettes, w, h
    end
    key = { world = world, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    local textured = require('src.physics.box2d-draw-textured')
    love.graphics.setCanvas({ silhouettes, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    textured.drawTexturedWorld(world)
    if target then love.graphics.setCanvas({ target, stencil = true }) else love.graphics.setCanvas() end
    return silhouettes, w, h
end

return lib
