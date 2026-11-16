-- dragfeel: dragging a Mipo that feels handled: notices the finger, crouches before the lift, lags and leans, braces, feels for the floor, reaches for things to hold (docs/DRAG-FEEL.md)
-- Nikki 2026-11-16: "anticipation while dragging a mipo? so it sort of feels more natural dragging" and "the
-- mipo testing his surroundings a bit while dragging to try to avoid or connect with things".
-- The behaviour is scripts/spikes/drag-feel.lua (its switches lib.on, its numbers lib.tuning); this scene is a
-- room with things to meet: a wall to brace against, a low ceiling, a bar, a ladder, a ledge, a floor to feel
-- for, a few Mipos standing about.
-- play mode (tab): drag the Mipos about. keys: n a Mipo at the mouse, s the senses drawn, h the panel
local s = {}

-- (a change to drag-feel.lua alone doesn't reload this scene: save this file too)

local feel = love.filesystem.load('scripts/spikes/drag-feel.lua')()

local FLOOR = 0

local function st()
    state.dragFeelScene = state.dragFeelScene or { showPanel = true, mipos = {} }
    return state.dragFeelScene
end

local function box(x, y, w, h, label, sensor)
    local thing = objectManager.addThing('rectangle', { x = x, y = y, width = w, height = h,
        bodyType = 'static', label = label })
    if thing then
        for _, f in ipairs(thing.body:getFixtures()) do
            if sensor then f:setSensor(true) else f:setFriction(0.9) end
        end
    end
    return thing
end

local LABELS = { 'df-floor', 'df-wall', 'df-ceiling', 'df-bar', 'df-post', 'df-ladder', 'df-rung', 'df-ledge' }

local function build()
    for _, label in ipairs(LABELS) do
        for _, thing in ipairs(getObjectsByLabel(label)) do
            if thing.body and not thing.body:isDestroyed() then objectManager.destroyBody(thing.body) end
        end
    end
    feel.clearHolds()
    box(0, FLOOR + 150, 9000, 300, 'df-floor')
    box(-4400, FLOOR - 1500, 200, 3000, 'df-wall')                  -- the wall on the left, to brace against
    box(4400, FLOOR - 1500, 200, 3000, 'df-wall')
    box(-2300, FLOOR - 1050, 1400, 120, 'df-ceiling')               -- a low ceiling to duck under
    -- a bar on two posts (Mipos pass the posts; the bar is a hold)
    box(-200, FLOOR - 700, 36, 1400, 'df-post', true)
    box(700, FLOOR - 700, 36, 1400, 'df-post', true)
    local bar = box(250, FLOOR - 1400, 900, 24, 'df-bar', true)
    if bar then feel.addHold(bar.body, -180, FLOOR - 1400, 680, FLOOR - 1400) end
    -- a ladder: every rung a hold
    local rail = box(1700, FLOOR - 1100, 24, 2200, 'df-ladder', true)
    box(1960, FLOOR - 1100, 24, 2200, 'df-ladder', true)
    for y = FLOOR - 200, FLOOR - 2100, -160 do
        box(1830, y, 260, 16, 'df-rung', true)
        if rail then feel.addHold(rail.body, 1720, y, 1940, y) end
    end
    -- a ledge high on the right wall: stand on it, or hang from its edge
    local ledge = box(3700, FLOOR - 1600, 1200, 100, 'df-ledge')
    if ledge then feel.addHold(ledge.body, 3110, FLOOR - 1650) end -- its corner
end

function s.onStart()
    worldState.paused = false
    local c = st()
    build()
    c.mipos = mipoKit.alive(c.mipos)
    local spots = { -3600, -900, 1100, 2700 } -- (not under the low ceiling: one spawned on top of it)
    for i = #c.mipos + 1, #spots do mipoKit.spawn(c.mipos, spots[i], FLOOR - 600) end
    cam:setScale(0.1)
    cam:setTranslation(0, -1100)
end

function s.onUnload()
    feel.unload()
end

function s.onKeyPress(key)
    local c = st()
    if key == 'n' then
        local mx, my = mouseWorldPos()
        mipoKit.spawn(c.mipos, mx, my)
    elseif key == 's' then feel.on.senses = not feel.on.senses
    elseif key == 'h' then c.showPanel = not c.showPanel
    end
end

function s.update(dt)
    local c = st()
    c.mipos = mipoKit.alive(c.mipos)
    feel.update(dt, c.mipos)
end

function s.draw()
    feel.drawSenses()
end

-- ── the panel: a switch per stage, its numbers ──
local SLIDERS = {
    { 'notice', 'notice: how near', 200, 2000, 10 },
    { 'pickupTime', 'pickup: crouch s', 0, 0.5, 0.01 }, { 'crouch', 'pickup: knees', 0, 80, 1 },
    { 'strength', 'drag: x weight', 2, 40, 0.5 },
    { 'follow', 'spring: Hz', 0.5, 6, 0.1 }, { 'damping', 'spring: damping', 0.05, 1.5, 0.01 },
    { 'upright', 'upright: muscle', 0, 40, 1 }, { 'lean', 'lean per px/s', 0, 0.08, 0.001 },
    { 'maxLean', 'lean: at most', 0, 60, 1 }, { 'dangle', 'dangle: muscle', 0, 40, 0.5 },
    { 'lookAhead', 'brace: look ahead s', 0.05, 1, 0.01 },
    { 'feel', 'feel: leg lengths', 0.2, 4, 0.1 }, { 'walk', 'air walk: steps/s', 0, 5, 0.1 },
    { 'reach', 'reach: how far', 50, 700, 5 }, { 'grabSpeed', 'reach: below px/s', 0, 2000, 10 },
    { 'gripBreak', 'grip: breaks at x weight', 0.5, 8, 0.1 }, { 'pullAway', 'grip: pull away px', 100, 1500, 10 },
    { 'hangFor', 'hang: seconds (0 ever)', 0, 30, 0.5 },
}

function s.drawUI()
    local c = st()
    if not c.showPanel then return end
    if state.playMode then ui.startFrame() end -- (in the editor its own UI started it: twice wipes the click)
    local sw, sh = ui.getDimensions()
    local row, pad, w = 26, 8, 430
    local switchRows = math.ceil(#feel.ORDER / 3)
    local h = row * (#SLIDERS + switchRows + 2) + 40
    local x0, y0 = sw - w - 12, math.max(8, (sh - h) / 2)
    ui.panel(x0, y0, w, h, '•• drag feel ••', function()
        local x, y = x0 + pad, y0 + 30
        local inner = w - pad * 2
        local third = inner / 3
        for i, name in ipairs(feel.ORDER) do
            local col, r = (i - 1) % 3, math.floor((i - 1) / 3)
            local clicked, v = ui.checkbox(x + col * third, y + r * row, feel.on[name], name)
            if clicked then feel.on[name] = v end
        end
        y = y + switchRows * row + 6
        local t = feel.tuning
        for _, sl in ipairs(SLIDERS) do
            ui.label(x, y + 3, sl[2])
            local v = ui.sliderWithInput('df-' .. sl[1], x + 190, y - 3, inner - 280, sl[3], sl[4], t[sl[1]], nil, sl[5])
            if v then t[sl[1]] = v + 0 end
            y = y + row
        end
        y = y + 4
        if ui.button(x, y, inner / 2 - 4, 'print values') then
            local parts = {}
            for _, sl in ipairs(SLIDERS) do parts[#parts + 1] = sl[1] .. ' = ' .. tostring(t[sl[1]]) end
            print('drag feel: ' .. table.concat(parts, ', '))
        end
        ui.label(x + inner / 2 + 4, y + 3, 'n Mipo  s senses  h')
    end)
end

return s
