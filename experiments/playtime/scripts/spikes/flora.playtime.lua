-- flora: flowers and plants grown from L-systems, made organic the way the trees are
-- docs/FLORA.md (2026-11-10). Four rows, each kind twice (two seeds): margriet, klaproos, paardenbloem, tulp,
-- watermunt, gras; zonnebloem, vingerhoedskruid, salomonszegel, mannetjesvaren, fluitenkruid; brandnetel,
-- witte en rode klaver, huislook, echeveria, aloë, hemelsleutel; riet, vossenstaart, struisgras. Each grows by
-- its kind (plant-kinds.lua) through plant-grow.lua: the L-system for the structure, then stems that wander,
-- reach for the light and bend under what they carry (heads nod, pedicels hang, fronds arch), widths that
-- add up, leaves round the stem in 3D (spiral, alternate, crossing pairs), older lower leaves bigger and
-- droopier. plant-look.lua draws them in Nikki's crayon strokes and drawn leaves, swaying.
-- The panel: organic (0 the bare L-system, 1 as tuned, 2 wild), age (0 seed, 1 flowering, 2 gone over:
-- clocks, capsules, yellow leaves), wind (it grew up in, and sways in), sun (where its light came from),
-- sway; grow (age 0 -> 1 in a few seconds), new seeds.
-- keys: g grow, n new seeds, o outlines, l labels
local s = {}

local KINDS = love.filesystem.load('scripts/spikes/plant-kinds.lua')()
local plantGrow = love.filesystem.load('scripts/spikes/plant-grow.lua')()
local plantLook = love.filesystem.load('scripts/spikes/plant-look.lua')()

local ROWS = {
    { ground = 0, step = 520, kinds = { 'daisy', 'poppy', 'dandelion', 'tulip', 'mint', 'grass' } },
    { ground = 2200, step = 780, kinds = { 'sunflower', 'foxglove', 'solomon', 'fern', 'cowparsley' } },
    { ground = 4000, step = 560, kinds = { 'nettle', 'whiteclover', 'redclover', 'houseleek', 'echeveria', 'aloe',
        'sedum' } },
    { ground = 6400, step = 800, kinds = { 'reed', 'foxtail', 'bentgrass' } },
}
local LABEL_SCALE = 3
local GROW_TIME = 6

local function lab()
    state.floraSpike = state.floraSpike or { organic = 1, age = 1, wind = 0, sun = 0, sway = 1, seed = 1,
        outlines = true, labels = true }
    return state.floraSpike
end

---------------------------------------------------------------- the plants

local built
local function envKey(c, age) return table.concat({ c.organic, age, c.wind, c.sun, c.seed }, '|') end

local function build(c, age)
    if built then for _, plant in ipairs(built.plants) do plantLook.release(plant) end end
    built = { key = envKey(c, age), plants = {} }
    c.built = built -- (for a look from the bridge)
    local i = 0
    for _, row in ipairs(ROWS) do
        local n = #row.kinds * 2
        local x0 = -(n - 1) * row.step / 2
        for col = 1, n do
            i = i + 1
            local kindName = row.kinds[math.floor((col - 1) / 2) + 1]
            local kind = KINDS[kindName]
            local rng = love.math.newRandomGenerator(i * 7919 + c.seed * 104729)
            local x = x0 + (col - 1) * row.step + (rng:random() - 0.5) * row.step * 0.2
            local plant = plantGrow.grow(kind, rng, x, row.ground,
                { organic = c.organic, age = age, wind = c.wind, sun = c.sun })
            plant.name = kind.name
            plant.stroke = 1 + (i % plantLook.strokeCount)
            plant.labelX = x0 + (col - 1) * row.step
            plant.ground = row.ground
            plant.first = col % 2 == 1
            built.plants[#built.plants + 1] = plant
        end
    end
end

local function currentAge(c)
    if c.growing then
        local t = (love.timer.getTime() - c.growing) / GROW_TIME
        if t >= 1 then c.growing = nil; return c.age end
        return t * c.age
    end
    return c.age
end

---------------------------------------------------------------- the scene

-- a floor under each row and a ruler Mipo at its end, made once (kept over a scene reload while alive; a row
-- added later gets its own)
local function makeFloorsAndRulers(c)
    c.floors = c.floors or {}
    for r, row in ipairs(ROWS) do
        local f = c.floors[r]
        if not f or f:isDestroyed() then
            local floor = objectManager.addThing('rectangle', { x = 0, y = row.ground + 60, width = 16000,
                height = 120, bodyType = 'static', label = 'flora-floor' })
            c.floors[r] = floor and floor.body
        end
    end
    c.rulersByRow = c.rulersByRow or {}
    for r, row in ipairs(ROWS) do
        local inst = c.rulersByRow[r]
        local torso = inst and inst.parts and inst.parts.torso1
        if not (torso and torso.body and not torso.body:isDestroyed()) then
            local x = (#row.kinds + 0.6) * row.step
            inst = characterManager.createCharacter('humanoid', x, row.ground - 900, 0.3)
            if inst then characterManager.randomizeMipoConstrained(inst) end
            c.rulersByRow[r] = inst
        end
    end
end

function s.onStart()
    worldState.paused = false
    cam:setScale(0.16)
    cam:setTranslation(0, 900)
    local c = lab()
    makeFloorsAndRulers(c)
    build(c, c.age)
end

function s.onUnload()
    built = nil
end

function s.onKeyPress(key)
    local c = lab()
    if key == 'g' then c.growing = love.timer.getTime()
    elseif key == 'n' then c.seed = c.seed + 1
    elseif key == 'o' then c.outlines = not c.outlines
    elseif key == 'l' then c.labels = not c.labels
    end
end

function s.drawBelow()
    local c = lab()
    local age = currentAge(c)
    local key = envKey(c, age)
    -- while a slider moves, wait until it rests a moment (growing: every frame)
    local now = love.timer.getTime()
    if key ~= c.growSeen then c.growSeen, c.growAt = key, now end
    if not built or (built.key ~= key and (c.growing or now - (c.growAt or 0) > 0.12)) then build(c, age) end
    local x0, y0 = cam:getWorldCoordinates(0, 0)
    local x1, y1 = cam:getWorldCoordinates(love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(0.9, 0.88, 0.8, 1)
    love.graphics.rectangle('fill', x0, y0, x1 - x0, y1 - y0)
    for _, row in ipairs(ROWS) do
        love.graphics.setColor(0.55, 0.47, 0.34, 1)
        love.graphics.rectangle('fill', x0, row.ground - 6, x1 - x0, 300)
    end
    local opts = { time = now, sway = c.sway, wind = c.wind, outlines = c.outlines }
    local t0 = love.timer.getTime()
    local margin = 200 -- (the sway)
    for _, plant in ipairs(built.plants) do
        local b = plant.box
        if b[3] + margin >= x0 and b[1] - margin <= x1 and b[4] + margin >= y0 and b[2] - margin <= y1 then
            opts.stroke = plant.stroke
            plantLook.draw(plant, opts)
        end
    end
    -- what drawing them costs (ms a frame, smoothed; read from the bridge: state.floraSpike.drawMs)
    c.drawMs = (c.drawMs or 0) * 0.95 + (love.timer.getTime() - t0) * 1000 * 0.05
    love.graphics.setColor(1, 1, 1, 1)
end

local function label(text, x, y)
    local font = love.graphics.getFont()
    local sc = LABEL_SCALE
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.print(text, x - font:getWidth(text) * sc / 2 + 4, y + 4, 0, sc, sc)
    love.graphics.setColor(1, 0.97, 0.9, 1)
    love.graphics.print(text, x - font:getWidth(text) * sc / 2, y, 0, sc, sc)
end

function s.draw()
    local c = lab()
    if not built then return end
    local x0 = cam:getWorldCoordinates(0, 0)
    local x1 = cam:getWorldCoordinates(love.graphics.getWidth(), 0)
    love.graphics.setColor(0.55, 0.47, 0.34, 1)
    for _, row in ipairs(ROWS) do love.graphics.rectangle('fill', x0, row.ground, x1 - x0, 290) end
    if c.labels then
        for i, plant in ipairs(built.plants) do
            if plant.first then
                local nxt = built.plants[i + 1]
                local x = nxt and (plant.labelX + nxt.labelX) / 2 or plant.labelX
                label(plant.name, x, plant.ground + 50)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local PANEL = { w = 300, row = 34, pad = 6 }
function s.drawUI()
    local c = lab()
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local w, h = PANEL.w, PANEL.row * 8 + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    local half = (w - PANEL.pad * 3) / 2
    ui.panel(x0, y0, w, h, '•• flora ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local function slider(key, text, lo, hi)
            local x, y = row()
            ui.label(x, y + 4, text)
            local v = ui.sliderWithInput('flora-' .. key, x + 100, y - 2, 120, lo, hi, c[key], nil, 0.05)
            if v then c[key] = v + 0 end
        end
        local x, y = row()
        if ui.button(x, y, half, c.growing and 'growing…' or 'grow', PANEL.row - 6) then
            c.growing = love.timer.getTime()
        end
        if ui.button(x + half + PANEL.pad, y, half, 'new seeds', PANEL.row - 6) then c.seed = c.seed + 1 end
        x, y = row()
        local oc, ov = ui.checkbox(x, y, c.outlines, 'outlines')
        if oc then c.outlines = ov end
        local lc, lv = ui.checkbox(x + half + PANEL.pad, y, c.labels, 'names')
        if lc then c.labels = lv end
        slider('organic', 'organic', 0, 2)
        slider('age', 'age', 0, 2)
        slider('wind', 'wind', -1, 1)
        slider('sun', 'sun', -1, 1)
        slider('sway', 'sway', 0, 3)
    end)
end

return s
