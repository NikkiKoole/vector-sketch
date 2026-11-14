-- dirty: Mipos getting dirty in mud and paint baths and clean again in a tub or with a sponge, each part its own dirt, by shader; drips and prints on the floor (docs/DIRT.md)
-- The look is scripts/spikes/dirt-look.lua: every part keeps a dirt mask in its own picture space, painted
-- where the part is below a bath's surface (so a dipped leg keeps its line, tilted with the leg), washed
-- where it's under clean water or the sponge rubs. Wet mud is dark and glints, it dries lighter and cracks;
-- paint is smooth and glossy, and paints mix (yellow then blue: green). The head hair has its own mask
-- around the head. scripts/spikes/paint-marks.lua: drops falling off a part fresh out of a bath, prints and
-- smears where a wet part touches the floor (step, or drag a Mipo along it: a brush).
-- Keys: x (hold) sponge at the mouse, m all muddy, c all clean, g wipe the floor, space the original,
-- n a new Mipo, h panel.
local s = {}

-- (a change to dirt-look.lua or paint-marks.lua alone doesn't reload this scene: save this file too, or
-- the bridge's /reload)
local dirtLook = love.filesystem.load('scripts/spikes/dirt-look.lua')()
local marks = love.filesystem.load('scripts/spikes/paint-marks.lua')()
marks.init(dirtLook)

local GROUND_Y = 600
-- the baths: mud on the left, clean water on the right, three paint pots between
local BATHS = {
    { x = -2200, scale = 1.1, kind = 'mud' },
    { x = -750, scale = 0.5, kind = 'paint', color = 'red' },
    { x = 0, scale = 0.5, kind = 'paint', color = 'yellow' },
    { x = 750, scale = 0.5, kind = 'paint', color = 'blue' },
    { x = 2200, scale = 1.1, kind = 'clean' },
}
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

-- this frame's liquids, sponge and dt (s.update), used by the wrap; onPart: the drips and prints
local frame = { liquids = {}, dt = 1 / 60, n = 0 }
frame.onPart = function(d, draw, body, m) marks.onPart(d, draw, body, m, frame) end
local lastMouse

local function wrap(d, draw)
    local c = st()
    if not c.on or love.keyboard.isDown('space') or (state.scene and state.scene.id ~= 'dirty')
        or not getsDirty(d) or not d.mipoThing or not dirtLook.bodyOf(d) or dirtLook.bodyOf(d):isDestroyed() then
        return draw(d)
    end
    if c.fillFrames > 0 and c.fill then dirtLook.fillMask(dirtLook.ensureMask(d), c.fill[1], c.fill[2]) end
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
        if m then dirtLook.fillMask(m, c.fill[1], c.fill[2]) end
    end
    dirtLook.drawHair(instance, wantFront, draw)
end

local function liquidExtra(body)
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if type(ud) == 'table' and ud.extra and ud.subtype == 'liquid' then return ud.extra end
    end
end

local function makeTub(b)
    local h = 380 * b.scale
    local thing = props.makeBath(b.x, GROUND_Y - h / 2, b.scale)
    local extra = thing and liquidExtra(thing.body)
    if not extra then return end
    extra.dirtKind, extra.paintColor = b.kind, b.color
    if b.kind == 'mud' then
        extra.buoyancy, extra.drag, extra.fill = 1.15, 3, 0.6
    elseif b.kind == 'paint' then
        extra.buoyancy, extra.drag, extra.fill = 1.1, 2.5, 0.65
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
        for _, b in ipairs(BATHS) do makeTub(b) end
    end
    marks.setFloor(-3400, 3400, GROUND_Y, 70, 2)
    c.mipos = mipoKit.alive(c.mipos)
    local spots = { -1350, 1250, 1500 }
    for i = #c.mipos + 1, 3 do
        mipoKit.spawn(c.mipos, spots[i], GROUND_Y - 500)
    end
end

function s.onStart()
    worldState.paused = false
    st()
    ensureScene()
    state.drawableWrap = wrap
    state.hairWrap = hairWrap
    cam:setScale(0.2)
    cam:setTranslation(0, 250)
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
    elseif key == 'g' then marks.clearFloor()
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
    frame.n = frame.n + 1
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
    dirtLook.paint(frame) -- (what was drawn last frame, into its masks; drips and prints through frame.onPart)
    dirtLook.paintHair(frame)
    dirtLook.update(frame.dt)
    marks.update(frame.dt, frame.liquids)
end

function s.drawBelow()
    state.drawableWrap = wrap
    state.hairWrap = hairWrap
end

-- a bath's colour: the mud picked in the panel, or the pot's paint
local function bathColor(extra)
    if extra.dirtKind == 'paint' then return dirtLook.PAINTS[extra.paintColor] or dirtLook.PAINTS.red end
    return dirtLook.mudColor()
end

-- mud and paint: the engine draws every bath as see-through water (src/water-look.lua), so these are
-- taken out of its list and drawn here, thick and opaque in their colour
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

-- the mud and paint baths, the floor's marks and the drops, then the sponge at the mouse
function s.draw()
    local looks = state.waterLook and state.waterLook.waters
    if looks then
        for i = #looks, 1, -1 do
            local extra = looks[i].extra
            if extra and (extra.dirtKind == 'mud' or extra.dirtKind == 'paint') then
                drawThick(looks[i], bathColor(extra), extra.dirtKind == 'paint')
                table.remove(looks, i)
            end
        end
    end
    marks.draw()
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
    { dirtLook, 'soak', 'soak (bath)', 0, 5, 0.1 }, { dirtLook, 'rinse', 'rinse (water)', 0, 5, 0.1 },
    { dirtLook, 'scrub', 'scrub (sponge)', 0, 10, 0.1 }, { dirtLook, 'sponge', 'sponge size', 20, 200, 5 },
    { dirtLook, 'dry', 'dry in (s)', 2, 120, 1 }, { dirtLook, 'wobble', 'bath line wobble', 0, 60, 1 },
    { dirtLook, 'strength', 'mud cover', 0, 1, 0.05 }, { dirtLook, 'splotch', 'splotchy', 0, 1, 0.05 },
    { dirtLook, 'grain', 'grain', 0, 1.5, 0.05 }, { dirtLook, 'grainSize', 'grain size', 5, 80, 1 },
    { dirtLook, 'tide', 'tide mark', 0, 1.5, 0.05 }, { dirtLook, 'shine', 'wet shine', 0, 1.5, 0.05 },
    { dirtLook, 'cracks', 'dry cracks', 0, 1, 0.05 }, { dirtLook, 'lines', 'drawn lines', 0, 1, 0.05 },
    { marks, 'print', 'prints', 0, 1, 0.05 }, { marks, 'wipe', 'print uses up', 0, 0.6, 0.02 },
    { marks, 'every', 'smear step', 4, 60, 1 }, { marks, 'dripRate', 'drips', 0, 40, 1 },
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
        local n = #dirtLook.MUDS + 1
        local bw = (inner - (n - 1) * 6) / n
        for i, mud in ipairs(dirtLook.MUDS) do
            if ui.button(x + (i - 1) * (bw + 6), y, bw, mud.name, nil, data.mud == i and { 0.5, 0.4, 0.3 } or nil) then
                data.mud = i
            end
        end
        if ui.button(x + (n - 1) * (bw + 6), y, bw, 'wipe floor') then marks.clearFloor() end
        y = y + P.row + 6
        for _, sl in ipairs(SLIDERS) do
            local t = sl[1].tuning
            ui.label(x, y + 5, sl[3])
            local value = ui.sliderWithInput('dirt-' .. sl[2], x + 140, y - 4, inner - 230, sl[4], sl[5], t[sl[2]], nil, sl[6])
            if value then t[sl[2]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'x sponge  m muddy  c clean  g floor  n Mipo  h panel')
    end)
end

return s
