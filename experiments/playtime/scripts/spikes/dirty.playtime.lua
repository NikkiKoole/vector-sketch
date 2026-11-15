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

-- The dirt itself is the engine's since 2026-11-16 (src/dirt-look.lua, DIRT D9): painting, the mud drawn over the
-- parts, drying, the hair, mud and paint baths drawn thick. This scene keeps its baths, panel, sponge, keys, and the
-- drips and prints (paint-marks.lua, through state.dirtOnPart). (A change to paint-marks.lua alone doesn't reload
-- this scene: save this file too, or the bridge's /reload.)
local dirtLook = dirtLook -- (the script environment's: src/dirt-look.lua)
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
local function st()
    if not state.dirtySpike then
        state.dirtySpike = { showPanel = true, on = true, sponge = false, mipos = {}, fillFrames = 0 }
    end
    return state.dirtySpike
end

-- this frame's liquids, sponge and dt (s.update), for the drips and prints (paint-marks.lua, called by the engine's
-- painting through state.dirtOnPart)
local frame = { liquids = {}, dt = 1 / 60, n = 0 }
local lastMouse

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
    state.dirtOnPart = function(d, draw, body, m) marks.onPart(d, draw, body, m, frame) end
    cam:setScale(0.2)
    cam:setTranslation(0, 250)
end

function s.onUnload()
    state.dirtOnPart, state.dirtBrush, state.dirtOff = nil, nil, nil
end

function s.onKeyPress(key)
    local c = st()
    if key == 'h' then c.showPanel = not c.showPanel
    elseif key == 'm' then dirtLook.fillDrawn(1, 1) -- (and those off screen)
    elseif key == 'c' then dirtLook.fillDrawn(0, 0)
    elseif key == 'g' then marks.clearFloor()
    elseif key == 'n' then
        local mx = mouseWorldPos()
        mipoKit.spawn(c.mipos, mx, GROUND_Y - 900)
    end
end

function s.update(dt)
    local c = st()
    -- (again: a reload of this script makes a new function)
    state.dirtOnPart = function(d, draw, body, m) marks.onPart(d, draw, body, m, frame) end
    state.dirtOff = not c.on or love.keyboard.isDown('space') or nil
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
    state.dirtBrush = frame.brush -- the sponge, for the engine's painting
    marks.update(frame.dt, frame.liquids)
end

-- the floor's marks and the drops, then the sponge at the mouse
function s.draw()
    marks.draw()
    local b = frame.brush
    if not b then return end
    local r = dirtLook.look.sponge
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
            local t = sl[1].look or sl[1].tuning
            ui.label(x, y + 5, sl[3])
            local value = ui.sliderWithInput('dirt-' .. sl[2], x + 140, y - 4, inner - 230, sl[4], sl[5], t[sl[2]], nil, sl[6])
            if value then t[sl[2]] = value + 0 end
            y = y + P.row
        end
        ui.label(x, y + 5, 'x sponge  m muddy  c clean  g floor  n Mipo  h panel')
    end)
end

return s
