-- dirty: Mipos getting dirty in a mud bath and clean again in a tub or with a sponge, each part its own dirt, by shader (docs/DIRT.md)
-- The look is scripts/spikes/dirt-look.lua: every part keeps a dirt mask in its own picture space, painted
-- where the part is below the mud's surface (so a dipped leg keeps its mud line, tilted with the leg),
-- washed where it's under clean water or the sponge rubs. Wet mud is dark and glints, it dries lighter and
-- cracks. The head hair has its own mask around the head. Keys: x (hold) sponge at the mouse, m all muddy, c all clean, space the original, n a new Mipo, h panel.
local s = {}

-- (a change to dirt-look.lua alone doesn't reload this scene: save this file too, or the bridge's /reload)
local dirtLook = love.filesystem.load('scripts/spikes/dirt-look.lua')()

local GROUND_Y = 600
local BATH_SCALE = 1.6
-- what gets dirty: every part and the face on it but the eyes. Left clean: the eyes and pupils, the inside of the
-- mouth (its backdrop sets a shader of its own, which would smear the paint; teeth, tongue) and the face patches
-- (eye hollows, cheeks, a snout: their own shader too)
local DIRTY = { texfixture = true, ['foot-back'] = true, ['foot-front'] = true, ['connected-texture'] = true,
    decal = true, brow = true, ['mouth-upper'] = true, ['mouth-lower'] = true, ['trace-vertices'] = true }
local function getsDirty(d)
    if not DIRTY[d.type] then return false end
    local extra = d.extra
    if d.type == 'decal' and extra and (extra.isEye or extra.facePatches or d.firstEye) then return false end
    return true
end

local function st()
    if not state.dirtySpike then
        state.dirtySpike = { showPanel = true, on = true, sponge = false, mipos = {}, fillFrames = 0 }
    end
    return state.dirtySpike
end

-- this frame's liquids, sponge and dt (s.update), used by the wrap
local frame = { liquids = {}, dt = 1 / 60 }
local lastMouse

local function wrap(d, draw)
    local c = st()
    if not c.on or love.keyboard.isDown('space') or (state.scene and state.scene.id ~= 'dirty')
        or not getsDirty(d) or not d.mipoThing or not dirtLook.bodyOf(d) or dirtLook.bodyOf(d):isDestroyed() then
        return draw(d)
    end
    if c.fillFrames > 0 and c.fill then
        local m = dirtLook.ensureMask(d)
        love.graphics.push('all')
        love.graphics.setCanvas(m.canvas)
        love.graphics.clear(c.fill[1], c.fill[2], 0, 0)
        love.graphics.pop()
        m.wetT = c.fill[2] > 0 and dirtLook.tuning.dry or 0
    end
    dirtLook.drawPart(d, draw)
end

-- the head hair: its own mask around the head (dirt-look.lua), through src/hair-locks.lua's state.hairWrap
local function hairWrap(instance, wantFront, draw)
    local c = st()
    if not c.on or love.keyboard.isDown('space') or (state.scene and state.scene.id ~= 'dirty') then
        return draw(instance, wantFront)
    end
    if c.fillFrames > 0 and c.fill then
        local m = dirtLook.ensureHairMask(instance)
        if m then
            love.graphics.push('all')
            love.graphics.setCanvas(m.canvas)
            love.graphics.clear(c.fill[1], c.fill[2], 0, 0)
            love.graphics.pop()
            m.wetT = c.fill[2] > 0 and dirtLook.tuning.dry or 0
        end
    end
    dirtLook.drawHair(instance, wantFront, draw)
end

local function liquidExtra(body)
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if type(ud) == 'table' and ud.extra and ud.subtype == 'liquid' then return ud.extra end
    end
end

local function makeTub(x, kind)
    local h = 380 * BATH_SCALE
    local thing = props.makeBath(x, GROUND_Y - h / 2, BATH_SCALE)
    local extra = thing and liquidExtra(thing.body)
    if not extra then return end
    extra.dirtKind = kind
    if kind == 'mud' then
        extra.color, extra.surfaceColor = '4a3221f0', '6e4c2eff'
        extra.buoyancy, extra.drag, extra.fill = 1.15, 3, 0.6
    else
        extra.fill = 0.6
    end
end

local function ensureScene()
    local c = st()
    if not getObjectsByLabel('ground')[1] then
        local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 300, width = 7000, height = 600,
            bodyType = 'static', label = 'ground' })
        if thing then
            local extra = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
            extra.main = extra.main or {}
            extra.main.bgURL, extra.opacity, extra.tileWidthM, extra.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
        end
    end
    if #dirtLook.liquids() == 0 then
        makeTub(-1250, 'mud')
        makeTub(1250, 'clean')
    end
    c.mipos = mipoKit.alive(c.mipos)
    for i = #c.mipos + 1, 3 do
        mipoKit.spawn(c.mipos, -280 + (i - 1) * 280, GROUND_Y - 500)
    end
end

function s.onStart()
    worldState.paused = false
    st()
    ensureScene()
    state.drawableWrap = wrap
    state.hairWrap = hairWrap
    cam:setScale(0.24)
    cam:setTranslation(0, 150)
end

function s.onUnload()
    if state.drawableWrap == wrap then state.drawableWrap = nil end
    if state.hairWrap == hairWrap then state.hairWrap = nil end
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel
    elseif key == 'm' then c.fill, c.fillFrames = { 1, 1 }, 2; dirtLook.fillAll(1, 1) -- (and those off screen)
    elseif key == 'c' then c.fill, c.fillFrames = { 0, 0 }, 2; dirtLook.fillAll(0, 0)
    elseif key == 'n' then
        local mx = mouseWorldPos()
        mipoKit.spawn(c.mipos, mx, GROUND_Y - 900)
    end
end

function s.update(dt)
    local c = st()
    state.drawableWrap = wrap -- (again: a reload of this script makes a new function)
    state.hairWrap = hairWrap
    if c.fillFrames > 0 then c.fillFrames = c.fillFrames - 1 end
    frame.dt = dt or 1 / 60
    frame.liquids = dirtLook.liquids()
    local mx, my = love.mouse.getPosition()
    local moved = lastMouse and math.sqrt((mx - lastMouse[1]) ^ 2 + (my - lastMouse[2]) ^ 2) or 0
    lastMouse = { mx, my }
    if c.sponge or love.keyboard.isDown('x') then
        local wx, wy = mouseWorldPos()
        frame.brush = { x = wx, y = wy, moved = moved }
    else
        frame.brush = nil
    end
    dirtLook.paint(frame) -- (what was drawn last frame, into its masks)
    dirtLook.paintHair(frame)
    dirtLook.update(frame.dt)
end

function s.drawBelow()
    state.drawableWrap = wrap
    state.hairWrap = hairWrap
end

-- the mud: the engine draws every bath as see-through water (src/water-look.lua), so the mud bath is
-- taken out of its list and drawn here, thick and opaque in the mud's colour
local function drawMud(w)
    local mud = (dirtLook.MUDS[dirtLook.data().mud] or dirtLook.MUDS[1]).color
    local line = w.line
    love.graphics.stencil(function() love.graphics.polygon('fill', w.hull) end, 'replace', 1)
    love.graphics.stencil(function()
        for _, hole in ipairs(w.holes) do
            if #hole >= 6 then love.graphics.polygon('fill', hole) end
        end
    end, 'replace', 0, true)
    love.graphics.setStencilTest('equal', 1)
    local r, g, b = mud[1], mud[2], mud[3]
    for i = 1, #line / 2 - 1 do
        local ax, ay, bx, by = line[i * 2 - 1], line[i * 2], line[i * 2 + 1], line[i * 2 + 2]
        love.graphics.setColor(r * 0.8, g * 0.8, b * 0.8, 1)
        love.graphics.polygon('fill', ax, ay, bx, by, bx, w.bottom, ax, w.bottom)
        love.graphics.setColor(r * 1.1, g * 1.1, b * 1.1, 1) -- the wet top, a little lighter
        love.graphics.polygon('fill', ax, ay, bx, by, bx, by + 40, ax, ay + 40)
    end
    love.graphics.setColor(math.min(1, r * 1.6), math.min(1, g * 1.6), math.min(1, b * 1.6), 1)
    love.graphics.setLineWidth(10)
    love.graphics.line(line)
    love.graphics.setLineWidth(1)
    love.graphics.setStencilTest()
    love.graphics.setColor(1, 1, 1, 1)
end

-- the mud bath, then the sponge at the mouse
function s.draw()
    local looks = state.waterLook and state.waterLook.waters
    if looks then
        for i = #looks, 1, -1 do
            if looks[i].extra and looks[i].extra.dirtKind == 'mud' then
                drawMud(looks[i])
                table.remove(looks, i)
            end
        end
    end
    local b = frame.brush
    if not b then return end
    local r = dirtLook.tuning.sponge
    love.graphics.setColor(0.98, 0.86, 0.35, 0.35)
    love.graphics.circle('fill', b.x, b.y, r)
    love.graphics.setColor(0.75, 0.6, 0.2, 0.9)
    love.graphics.setLineWidth(4)
    love.graphics.circle('line', b.x, b.y, r)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── the panel ──
local P = { w = 420, row = 28, pad = 10 }
local SLIDERS = {
    { 'soak', 'soak (mud)', 0, 5, 0.1 }, { 'rinse', 'rinse (water)', 0, 5, 0.1 }, { 'scrub', 'scrub (sponge)', 0, 10, 0.1 },
    { 'sponge', 'sponge size', 20, 200, 5 }, { 'dry', 'dry in (s)', 2, 120, 1 }, { 'wobble', 'mud line wobble', 0, 60, 1 },
    { 'strength', 'mud cover', 0, 1, 0.05 }, { 'splotch', 'splotchy', 0, 1, 0.05 }, { 'grain', 'grain', 0, 1.5, 0.05 },
    { 'grainSize', 'grain size', 5, 80, 1 }, { 'tide', 'tide mark', 0, 1.5, 0.05 }, { 'shine', 'wet shine', 0, 1.5, 0.05 },
    { 'cracks', 'dry cracks', 0, 1, 0.05 }, { 'lines', 'drawn lines', 0, 1, 0.05 },
}
function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    ui.startFrame()
    local sw, sh = ui.getDimensions()
    local w, h = P.w, P.row * (#SLIDERS + 5) + 40
    local x0, y0 = sw - w - 16, math.max(12, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• dirty ••', function()
        local x, y = x0 + P.pad, y0 + 32
        local inner = w - P.pad * 2
        local oc, ov = ui.checkbox(x, y + 2, c.on, 'dirt (space: the original)')
        if oc then c.on = ov end
        y = y + P.row
        local sc, sv = ui.checkbox(x, y + 2, c.sponge, 'sponge on the mouse (or hold x)')
        if sc then c.sponge = sv end
        y = y + P.row
        local data = dirtLook.data()
        local bw = (inner - 3 * 6) / #dirtLook.MUDS
        for i, mud in ipairs(dirtLook.MUDS) do
            if ui.button(x + (i - 1) * (bw + 6), y, bw, mud.name, nil, data.mud == i and { 0.5, 0.4, 0.3 } or nil) then
                data.mud = i
            end
        end
        y = y + P.row + 6
        local t = dirtLook.tuning
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 5, sl[2])
            local value = ui.sliderWithInput('dirt-' .. sl[1], x + 140, y - 4, inner - 230, sl[3], sl[4], t[sl[1]], nil, sl[5])
            if value then t[sl[1]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'x sponge  m muddy  c clean  n Mipo  h panel')
    end)
end

return s
