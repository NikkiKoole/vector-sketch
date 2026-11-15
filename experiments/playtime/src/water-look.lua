-- See-through water in any scene (ENGINE-MERGE EM3, the first slice): the cups and baths (LIQUID sfixtures,
-- src/liquid.lua) drawn with the water shader (src/render/water-shader.lua) instead of flat colour, at the
-- thin water settings seaside gave its cups (SEASIDE SS1b: little tint and bending, no mirror, shafts or specks).
-- The shader bends what's behind the water, so while a scene has any LIQUID the frame is drawn into a canvas:
--   drawStart  before anything is drawn (the sky, backdrops, walls, bodies all land in the canvas);
--              liquid.draw hands each water over (state.liquidDrawHook) at its own place in the draw order,
--              and it's drawn there: at the frame's first water what's drawn so far is copied (one copy a
--              frame), and the water bends that copy; what's drawn after it (a Mipo in front of the bath)
--              comes over the water (Nikki 2026-11-15, EM3: it was drawn over everything at the end, so a
--              Mipo in front of a bath was seen through its water)
--   drawEnd    after the scene script's draw: the canvas onto the real target
-- A scene without water costs nothing. A scene that draws its own water (seaside sets its own hook) is left
-- alone.
local lib = {}

local state = require('src.state')
local registry = require('src.registry')
local subtypes = require('src.subtypes')
local waterShader = require('src.render.water-shader')
local cam = require('src.camera').getInstance()

-- seaside's cup values (its caustics 1, halved for cups; cupCaustics, cupView, cupBend)
lib.THIN = { clarity = 1, refraction = 1, caustics = 0.5, blur = 1, causticSize = 0.3, viewDepth = 60,
    bend = 0.3 }

local function frame()
    state.waterLook = state.waterLook or { waters = {} }
    return state.waterLook
end

local canvas, behind
-- what's behind the first water this frame: the canvas so far, copied (the shader reads it while the water
-- is drawn into the canvas)
local function behindFor(w, h)
    if not behind or behind:getWidth() ~= w or behind:getHeight() ~= h then
        if behind then behind:release() end
        behind = love.graphics.newCanvas(w, h)
    end
    return behind
end
local function canvasFor(w, h)
    if not canvas or canvas:getWidth() ~= w or canvas:getHeight() ~= h then
        if canvas then canvas:release() end
        local _, _, flags = love.window.getMode()
        canvas = love.graphics.newCanvas(w, h, { msaa = flags.msaa or 0 })
    end
    return canvas
end

function lib.drawStart()
    local f = frame()
    f.on = false
    -- the hook as it is on state: a hot swap of this file makes a new function, so it's kept there too
    f.hook = f.hook or function(water) require('src.water-look').drawWater(water) end
    local hook = state.liquidDrawHook
    if hook and hook ~= f.hook then return end -- a scene draws its own water
    if #registry.sfixturesOf(subtypes.LIQUID) == 0 then
        if hook then state.liquidDrawHook = nil end
        return
    end
    state.liquidDrawHook = f.hook
    f.snapped = false
    f.previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvasFor(love.graphics.getDimensions()), stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    f.on = true
end

-- one water, now, at its place in the draw order (liquid.draw, through the hook)
local function sendThin(shader, scene)
    local thin = lib.THIN
    shader:send('scene', scene)
    shader:send('time', love.timer.getTime() % 1000)
    shader:send('pxPerWorld', cam:getScale() * love.graphics.getDPIScale())
    shader:send('clarity', thin.clarity)
    shader:send('refraction', thin.refraction)
    shader:send('caustics', thin.caustics)
    shader:send('blur', thin.blur)
    shader:send('causticSize', thin.causticSize)
    shader:send('viewDepth', thin.viewDepth)
    shader:send('bend', thin.bend)
    shader:send('mirror', 0)
    shader:send('rays', 0)
    shader:send('specks', 0)
end
function lib.drawWater(water)
    local f = frame()
    if not f.on then return end
    local target = love.graphics.getCanvas()
    if target ~= canvas then return end -- another pass (the shadows' outlines): no water there
    if not f.snapped then
        f.snapped = true
        local copy = behindFor(canvas:getDimensions())
        love.graphics.push('all')
        love.graphics.origin()
        love.graphics.setCanvas(copy)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader()
        love.graphics.setStencilTest()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode('replace', 'premultiplied')
        love.graphics.draw(canvas, 0, 0)
        love.graphics.pop()
    end
    local compare, value = love.graphics.getStencilTest()
    local shader = waterShader.shader()
    love.graphics.setShader(shader)
    sendThin(shader, behind)
    waterShader.drawThin({ water })
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
end

function lib.drawEnd()
    local f = frame()
    if not f.on then return end
    f.on = false
    if f.previous then love.graphics.setCanvas({ f.previous, stencil = true }) else love.graphics.setCanvas() end
    f.previous = nil
    -- the frame as drawn, the waters in it
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.pop()
end

return lib
