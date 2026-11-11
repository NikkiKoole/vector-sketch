-- shadow-silhouettes.lua — the textured world drawn once more into a canvas, as it is, for the shadows to
-- use: the soft wall shadows (src/backdrop-shadows.lua, shifting it as they lay it down) and the 3D ones
-- (src/projected-shadows.lua). Drawn once a frame however many use it (LS12: each shadow drawing the world
-- again cost ~4-5 ms on the phone). main.lua calls newFrame() before the shadows; within a frame the
-- canvas is drawn again only if the world, the transform or the target's size changed.
-- With a margin round the screen (lib.pad, screen points): a thing partly off the edge throws its whole
-- shadow, not one cut straight where the screen ended (Nikki 2026-11-11). As wide as the longest wall
-- shadow needs this frame, at most PAD_MAX; the cull (src/render/view.lua) reads the canvas, so it widens too.
-- Who draws it shifts it back by the pad (src/backdrop-shadows.lua, src/projected-shadows.lua).
local lib = {}

local PAD_MIN, PAD_MAX, PAD_STEP = 64, 384, 64
local pad = PAD_MIN

-- world units to screen points under the current transform
local function pointsPerUnit()
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 0)
    return math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
end

-- the margin this frame's shadows need: the wall shadows' shift and blur, a bit for the 3D ones
local function padNeeded()
    local state = require('src.state')
    local scale = pointsPerUnit()
    local need = PAD_MIN
    local walls = state.backdropShadows
    if walls then
        for _, one in ipairs(walls.layers or { walls }) do
            if one.offset then
                local reach = math.max(math.abs(one.offset[1]), math.abs(one.offset[2])) + 2 * (one.blur or 8)
                need = math.max(need, reach * scale)
            end
        end
    end
    if state.projectedShadows then need = math.max(need, 192) end
    return math.min(PAD_MAX, math.ceil(need / PAD_STEP) * PAD_STEP)
end

-- the margin the canvases have now (screen points on each side)
function lib.pad() return pad end

local canvas
local key = {}
local frameToken = {} -- a new one each frame (newFrame): what was drawn in an older frame is redrawn
-- What doesn't show in a shadow is left out of the outlines (LS25): a face's decals, brows and mouth sit
-- inside the head's outline, grass and water are too thin or see-through to cast one. Any filter also makes
-- the textured drawing leave out the scene's splits (a ground drawn in one, which may itself draw shadows
-- from these silhouettes).
local NO_SHADOW = { decal = true, brow = true, grass = true, liquid = true, ['mouth-backdrop'] = true,
    ['mouth-lower'] = true, ['mouth-upper'] = true, ['mouth-teeth'] = true, ['mouth-tongue'] = true }
-- (state.shadowAllParts puts everything back: to compare)
local function castsShadow(drawable)
    if require('src.state').shadowAllParts then return true end
    return not (drawable and NO_SHADOW[drawable.type])
end
local function everything() return true end

-- the textured world as plain outlines: no light or clay shaders (state.drawingOutlines, read by
-- src/render/shaders.lua), only the pictures' alpha matters here
local function drawOutlines(world, only)
    local textured = require('src.physics.box2d-draw-textured')
    local state = require('src.state')
    state.drawingOutlines = true
    local function shows(body, drawable) return castsShadow(drawable) and only(body, drawable) end
    local ok, err = pcall(textured.drawTexturedWorld, world, shows)
    -- hair locks are drawn by scene scripts, not the textured world: added here (when they're loaded)
    local hairLocks = package.loaded['src.hair-locks']
    if ok and hairLocks and hairLocks.drawShadow then
        ok, err = pcall(hairLocks.drawShadow, only ~= everything and only or nil)
    end
    state.drawingOutlines = false
    if not ok then error(err, 0) end
end

local function canvasFor(w, h)
    w, h = w + 2 * pad, h + 2 * pad
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        if canvas then canvas:release() end
        canvas = love.graphics.newCanvas(w, h)
        key = {}
    end
    return canvas
end

-- state.shadowEveryOther: the silhouettes drawn every other frame, kept in between (half their cost,
-- ~3 ms with 20 lit Mipos on an iPhone SE 2, LIGHT-AND-SHADOW LS23); a thing moving fast trails its
-- shadow by a frame. A moved or zoomed camera redraws them anyway (the transform is part of the key).
local frames = 0
function lib.newFrame()
    frames = frames + 1
    local state = require('src.state')
    if state.shadowEveryOther and frames % 2 == 0 then return end
    key, frameToken = {}, {}
end

-- into a canvas with the margin: the current transform moved by the pad
local function drawPadded(c, world, only)
    love.graphics.setCanvas({ c, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    -- the same transform one pad further right and down (a camera: a move, a turn, an even scale)
    local tx, ty = love.graphics.transformPoint(0, 0)
    local ux, uy = love.graphics.transformPoint(1, 0)
    local sx = pointsPerUnit()
    love.graphics.origin()
    love.graphics.translate(tx + pad, ty + pad)
    love.graphics.rotate(math.atan2(uy - ty, ux - tx))
    love.graphics.scale(sx, sx)
    drawOutlines(world, only)
    love.graphics.pop()
end

-- the silhouettes canvas (the current target plus lib.pad() on each side, drawn under the current
-- transform shifted by the pad: draw it at -pad, -pad) and its size
function lib.get(world)
    local target = love.graphics.getCanvas()
    local w, h
    if target then w, h = target:getDimensions() else w, h = love.graphics.getDimensions() end
    local x0, y0 = love.graphics.transformPoint(0, 0)
    local x1, y1 = love.graphics.transformPoint(1, 1)
    if key.frame == frameToken and key.world == world and key.x0 == x0 and key.y0 == y0 and key.x1 == x1
        and key.y1 == y1 and canvas then
        return canvas, canvas:getWidth(), canvas:getHeight()
    end
    pad = padNeeded()
    local silhouettes = canvasFor(w, h)
    key = { frame = frameToken, world = world, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    drawPadded(silhouettes, world, everything)
    if target then love.graphics.setCanvas({ target, stencil = true }) else love.graphics.setCanvas() end
    return silhouettes, silhouettes:getWidth(), silhouettes:getHeight()
end

-- one depth's silhouettes (src/projected-shadows.lua layers): only the bodies `only` says yes to, in a
-- canvas of their own (`name` tells them apart), once a frame like the rest
local layerCanvases, layerKeys = {}, {}
function lib.getLayer(world, name, only)
    local target = love.graphics.getCanvas()
    local w, h
    if target then w, h = target:getDimensions() else w, h = love.graphics.getDimensions() end
    w, h = w + 2 * pad, h + 2 * pad -- the same margin as the shared one (lib.get ran first this frame)
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
    drawPadded(c, world, only)
    if target then love.graphics.setCanvas({ target, stencil = true }) else love.graphics.setCanvas() end
    return c, w, h
end

return lib
