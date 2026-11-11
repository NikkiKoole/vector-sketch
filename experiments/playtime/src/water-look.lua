-- See-through water in any scene (ENGINE-MERGE EM3, the first slice): the cups and baths (LIQUID sfixtures,
-- src/liquid.lua) drawn with the water shader (src/render/water-shader.lua) instead of flat colour, at the
-- thin water settings seaside gave its cups (SEASIDE SS1b: little tint and bending, no mirror, shafts or specks).
-- The shader bends what's behind the water, so while a scene has any LIQUID the frame is drawn into a canvas:
--   drawStart  before anything is drawn (the sky, backdrops, walls, bodies all land in the canvas);
--              liquid.draw hands each water over (state.liquidDrawHook) instead of drawing it
--   drawEnd    after the scene script's draw: the canvas onto the real target, then the waters over it
-- A scene without water costs nothing. A scene that draws its own water (seaside sets its own hook) is left
-- alone. Known (as in seaside): the water is drawn over everything, so a Mipo in front of a bath is seen
-- through its water.
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

local canvas
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
    f.hook = f.hook or function(water) table.insert(state.waterLook.waters, water) end
    local hook = state.liquidDrawHook
    if hook and hook ~= f.hook then return end -- a scene draws its own water
    if #registry.sfixturesOf(subtypes.LIQUID) == 0 then
        if hook then state.liquidDrawHook = nil end
        return
    end
    state.liquidDrawHook = f.hook
    f.waters = {}
    f.previous = love.graphics.getCanvas()
    love.graphics.setCanvas({ canvasFor(love.graphics.getDimensions()), stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    f.on = true
end

function lib.drawEnd()
    local f = frame()
    if not f.on then return end
    f.on = false
    if f.previous then love.graphics.setCanvas({ f.previous, stencil = true }) else love.graphics.setCanvas() end
    f.previous = nil
    -- the frame as drawn, then the waters over it, bending it
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setBlendMode('alpha')
    love.graphics.pop()
    if #f.waters == 0 then return end
    local shader = waterShader.shader()
    local thin = lib.THIN
    love.graphics.setShader(shader)
    shader:send('scene', canvas)
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
    waterShader.drawThin(f.waters)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    f.waters = {}
end

return lib
