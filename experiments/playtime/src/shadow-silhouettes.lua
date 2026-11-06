-- shadow-silhouettes.lua — the textured world drawn once more into a canvas, as it is, for the shadows to
-- use: the soft wall shadows (src/backdrop-shadows.lua, shifting it as they lay it down) and the 3D ones
-- (src/projected-shadows.lua). Drawn once a frame however many use it (LS12: each shadow drawing the world
-- again cost ~4-5 ms on the phone). main.lua calls newFrame() before the shadows; within a frame the
-- canvas is drawn again only if the world, the transform or the target's size changed.
local lib = {}

local canvas
local key = {}
local frameToken = {} -- a new one each frame (newFrame): what was drawn in an older frame is redrawn
-- every body: a filter makes the textured drawing leave out the scene's splits (a ground drawn in one,
-- which may itself draw shadows from these silhouettes)
local function everything() return true end

-- the textured world as plain outlines: no light or clay shaders (state.drawingOutlines, read by
-- src/render/shaders.lua), only the pictures' alpha matters here
local function drawOutlines(world, only)
    local textured = require('src.physics.box2d-draw-textured')
    local state = require('src.state')
    state.drawingOutlines = true
    local ok, err = pcall(textured.drawTexturedWorld, world, only)
    state.drawingOutlines = false
    if not ok then error(err, 0) end
end

local function canvasFor(w, h)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        if canvas then canvas:release() end
        canvas = love.graphics.newCanvas(w, h)
        key = {}
    end
    return canvas
end

function lib.newFrame()
    key, frameToken = {}, {}
end

-- the silhouettes canvas (the size of the current target, drawn under the current transform) and its size
function lib.get(world)
    local target = love.graphics.getCanvas()
    local w, h
    if target then w, h = target:getDimensions() else w, h = love.graphics.getDimensions() end
    local silhouettes = canvasFor(w, h)
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 1)
    if key.frame == frameToken and key.world == world and key.x0 == x0 and key.y0 == y0 and key.x1 == x1
        and key.y1 == y1 then
        return silhouettes, w, h
    end
    key = { frame = frameToken, world = world, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    love.graphics.setCanvas({ silhouettes, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    drawOutlines(world, everything)
    if target then love.graphics.setCanvas({ target, stencil = true }) else love.graphics.setCanvas() end
    return silhouettes, w, h
end

-- one depth's silhouettes (src/projected-shadows.lua layers): only the bodies `only` says yes to, in a
-- canvas of their own (`name` tells them apart), once a frame like the rest
local layerCanvases, layerKeys = {}, {}
function lib.getLayer(world, name, only)
    local target = love.graphics.getCanvas()
    local w, h
    if target then w, h = target:getDimensions() else w, h = love.graphics.getDimensions() end
    local c = layerCanvases[name]
    if not c or c:getWidth() ~= w or c:getHeight() ~= h then
        if c then c:release() end
        c = love.graphics.newCanvas(w, h)
        layerCanvases[name], layerKeys[name] = c, nil
    end
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 1)
    local k = layerKeys[name]
    if k and k.frame == frameToken and k.world == world and k.x0 == x0 and k.y0 == y0 and k.x1 == x1 and k.y1 == y1 then
        return c, w, h
    end
    layerKeys[name] = { frame = frameToken, world = world, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    love.graphics.setCanvas({ c, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    drawOutlines(world, only)
    if target then love.graphics.setCanvas({ target, stencil = true }) else love.graphics.setCanvas() end
    return c, w, h
end

return lib
