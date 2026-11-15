-- See-through water in any scene (ENGINE-MERGE EM3, the first slice): the cups and baths (LIQUID sfixtures,
-- src/liquid.lua) drawn with the water shader (src/render/water-shader.lua) instead of flat colour, at the
-- thin water settings seaside gave its cups (SEASIDE SS1b: little tint and bending, no mirror, shafts or specks).
-- The shader bends what's behind the water, so while a scene has any LIQUID the frame is drawn into a canvas:
--   drawStart  before anything is drawn (the sky, backdrops, walls, bodies all land in the canvas);
--              liquid.draw hands each water over (state.liquidDrawHook) at its own place in the draw order,
--              and it's drawn there: what's drawn so far is copied (a copy per water: one a frame showed a
--              bath in front of the Mipos a copy from before them, taken at a back-layer bath, and painted
--              over the feet of a Mipo sitting in it), and the water bends that copy; what's drawn after
--              it (a Mipo in front of the bath) comes over the water (Nikki 2026-11-15, EM3: it was drawn
--              over everything at the end, so a
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
-- what's behind a water: the canvas so far, copied (the shader reads it while the water is drawn into the canvas)
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
    f.previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvasFor(love.graphics.getDimensions()), stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    f.on = true
end

-- Mud and paint (a container whose dirt kind is 'mud' or 'paint', src/dirt-look.lua): not see-through water but
-- thick and opaque in its colour, a wetter top and a line along the surface (glossy for paint). From the dirty spike.
local function drawThick(w, color, glossy)
    local line = w.line
    love.graphics.stencil(function() love.graphics.polygon('fill', w.hull) end, 'replace', 1)
    love.graphics.stencil(function()
        for _, hole in ipairs(w.holes) do
            if #hole >= 6 then love.graphics.polygon('fill', hole) end
        end
    end, 'replace', 0, true)
    love.graphics.setStencilTest('equal', 1)
    local r, g, b = color[1], color[2], color[3]
    for i = 1, #line / 2 - 1 do
        local ax, ay, bx, by = line[i * 2 - 1], line[i * 2], line[i * 2 + 1], line[i * 2 + 2]
        love.graphics.setColor(r * 0.8, g * 0.8, b * 0.8, 1)
        love.graphics.polygon('fill', ax, ay, bx, by, bx, w.bottom, ax, w.bottom)
        love.graphics.setColor(math.min(1, r * 1.1), math.min(1, g * 1.1), math.min(1, b * 1.1), 1) -- the wet top
        love.graphics.polygon('fill', ax, ay, bx, by, bx, by + 40, ax, ay + 40)
    end
    if glossy then
        love.graphics.setColor(1, 1, 1, 0.55)
    else
        love.graphics.setColor(math.min(1, r * 1.6), math.min(1, g * 1.6), math.min(1, b * 1.6), 1)
    end
    love.graphics.setLineWidth(glossy and 6 or 10)
    love.graphics.line(line)
    love.graphics.setLineWidth(1)
    love.graphics.setStencilTest()
    love.graphics.setColor(1, 1, 1, 1)
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
    local kind = water.extra.dirtKind
    if kind == 'mud' or kind == 'paint' then
        local dirt = require('src.dirt-look')
        local color = kind == 'paint' and (dirt.PAINTS[water.extra.paintColor] or dirt.PAINTS.red) or dirt.mudColor()
        local compare, value = love.graphics.getStencilTest()
        drawThick(water, color, kind == 'paint')
        if compare then love.graphics.setStencilTest(compare, value) else love.graphics.setStencilTest() end
        return
    end
    do
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
    -- its own colour and murk (the cup's or bath's 'water tint' and 'murky'; none: clear)
    local extra = water.extra
    local r, g, b = 1, 1, 1
    if extra.tint then r, g, b = require('src.color').hexToColor(extra.tint) end
    shader:send('tint', { r, g, b })
    shader:send('tintAmount', extra.tint and 1 or 0)
    shader:send('murk', extra.tint and (extra.murk or 0) or 0)
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
    require('src.pouring').draw(canvas) -- water poured out of cups, over the frame (src/pouring.lua)
end

return lib
