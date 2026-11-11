-- campfire: a campfire at night, its flames, sparks and warm flickering light on the Mipos round it
-- (src/fire.lua; Nikki 2026-11-11 "a fire, like campfire, but with good light and flame"). The scene's sky
-- sets the hour (22:00 to start; settings -> sky), the fire's own light (a point LIGHT on a body that
-- touches nothing, label 'campfire') flickers with its flames and lights the walls in a warm pool
-- (src/walls.lua). The ground, the wall and the Mipos are made when the scene has none.
-- play mode (tab): drag the Mipos about the fire. f: the flames' style (drawn licks / tongues).
local s = {}

local GROUND_Y = 900
local FIRE_X = 0
local FIRE_SIZE = 320
local LIGHT_STRENGTH = 2.4
local LIGHT_RANGE = 1900

local function c()
    state.campfire = state.campfire or {}
    return state.campfire
end

local function found(label)
    local thing = getObjectsByLabel(label)[1]
    return thing and thing.body and not thing.body:isDestroyed() and thing or nil
end

-- soil under rows of grass (as the facing scene's, Nikki's grass)
local function ensureGround()
    if found('ground') then return end
    local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y + 350, width = 7000, height = 700,
        bodyType = 'static', label = 'ground' })
    if not thing then return end
    for _, f in ipairs(thing.body:getFixtures()) do f:setFriction(0.9) end
    local tile = fixtures.createSFixture(thing.body, 0, 0, 'tile-repeat', { radius = 20 }):getUserData().extra
    tile.main = tile.main or {}
    tile.main.bgURL, tile.opacity, tile.tileWidthM, tile.tileHeightM = 'world/ground/soil-01.jpg', 1, 0.6, 0.6
    local grass = fixtures.createSFixture(thing.body, 0, 0, 'grass', { radius = 20 }):getUserData().extra
    grass.bands, grass.bandSpread, grass.bumps, grass.bumpSize = 16, 120, 25, 250
    grass.density, grass.height, grass.width = 3, 172, 0.93
end

-- a plaster wall behind the fire (src/walls.lua): the fire's light makes a warm pool on it
local function ensureWall()
    if found('wall') then return end
    local w, h = 5200, 1700
    local thing = objectManager.addThing('rectangle', { x = 0, y = GROUND_Y - h / 2, width = w, height = h,
        bodyType = 'static', label = 'wall' })
    if not thing then return end
    local wall = fixtures.createSFixture(thing.body, 0, 0, 'wall', { radius = 20 }):getUserData().extra
    wall.main.bgURL, wall.behind = 'world/walls/plaster-02.jpg', 160
end

-- the fire's light: a point light on a small body that touches nothing
local function fireLight()
    local thing = found('campfire')
    if not thing then
        thing = objectManager.addThing('circle', { x = FIRE_X, y = GROUND_Y - FIRE_SIZE * 0.45, radius = 12,
            bodyType = 'kinematic', label = 'campfire' })
        if not thing then return nil end
        for _, f in ipairs(thing.body:getFixtures()) do f:setSensor(true) end
        fixtures.createSFixture(thing.body, 0, 0, 'light', { radius = 8 })
    end
    for _, f in ipairs(thing.body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.subtype == 'light' then
            local e = ud.extra
            e.lightType, e.colorHex, e.range = 'point', 'ffa04cff', LIGHT_RANGE
            return thing.body, e
        end
    end
end

-- three Mipos round the fire, the two nearest turned towards it
local function ensureMipos()
    local any = false
    for _ in pairs(mipoRegistry.getAll()) do any = true end
    if any then return end
    local list = {}
    for _, spot in ipairs({ { -850, 'right' }, { 850, 'left' }, { -1700, 'front' } }) do
        local inst = mipoKit.spawn(list, FIRE_X + spot[1], GROUND_Y - 500)
        if inst and spot[2] ~= 'front' then characterManager.switchFacing(inst, spot[2]) end
    end
end

function s.onStart()
    worldState.paused = false
    ensureGround()
    ensureWall()
    local fc = c()
    fc.fire = fc.fire or fire.new(FIRE_X, GROUND_Y, FIRE_SIZE)
    fc.fire.style = fc.fire.style or 'drawn'
    fc.fire.licks, fc.fire.lickClock = fc.fire.licks or {}, fc.fire.lickClock or 0
    fireLight()
    ensureMipos()
end

function s.onKeyPress(key)
    local fc = c()
    if key == 'h' then fc.showPanel = not fc.showPanel end
    if key == 'f' and fc.fire then
        local styles = fire.STYLES
        for i, name in ipairs(styles) do
            if name == (fc.fire.style or 'drawn') then fc.fire.style = styles[i % #styles + 1] break end
        end
    end
end

-- how dark the hour is for the fire: 0 by day .. 1 at night, following the sun, the change spread over the
-- panel's hours (fire.nightness: from the sky's hour, whatever the light level)
local function darkness()
    local st = state.campfire and state.campfire.settings
    return fire.nightness((st and st.duskHours) or 4)
end

-- The fire throws shadows (CF3): the 3D shadows (src/projected-shadows.lua) from a lamp where the flames
-- are. The wall stands WALL_BEHIND behind the Mipos (its foot hidden by the grass), the fire a little in
-- front of them: close to the light, their shadows come out big on the wall and wobble with the flames.
local WALL_BEHIND = 160      -- the wall sfixture's own `behind`
local FIRE_IN_FRONT = 120    -- the fire this far in front of the Mipos: less, bigger shadows
local SHADOW_SOFTNESS = 30   -- the flames' size as a lamp (world units): the shadows' soft edge

-- Day and night: the fire's light, shadows and glow each go from a day value to a night value with
-- how dark the hour is (darkness(), smooth over dusk and dawn: no switch). The panel's sliders (h hides).
local DAY_NIGHT = {
    { key = 'light', text = 'light', lo = 0, hi = 4, day = 0.5, night = LIGHT_STRENGTH },
    { key = 'shadow', text = 'shadows', lo = 0, hi = 1, day = 0.08, night = 0.6 },
    { key = 'glow', text = 'glow', lo = 0, hi = 2, day = 0.4, night = 1 },
}
local function settings()
    local fc = c()
    fc.settings = fc.settings or {}
    local st = fc.settings
    for _, row in ipairs(DAY_NIGHT) do -- each filled at use: a hot swap keeps older settings
        if st[row.key .. 'Day'] == nil then st[row.key .. 'Day'] = row.day end
        if st[row.key .. 'Night'] == nil then st[row.key .. 'Night'] = row.night end
    end
    if st.duskHours == nil then st.duskHours = 4 end
    if fc.showPanel == nil then fc.showPanel = true end
    return st
end
-- a setting at this hour: day .. night by darkness
local function atHour(key)
    local st, n = settings(), darkness()
    return st[key .. 'Day'] + (st[key .. 'Night'] - st[key .. 'Day']) * n
end
local shadowLight = { kind = 'point', x = 0, h = 0, z = 0 }
local shadowOne = { light = shadowLight, strength = 0, softness = SHADOW_SOFTNESS }
local function wallArea()
    love.graphics.rectangle('fill', -2600, GROUND_Y - 1700, 5200, 1700)
end
local shadowSettings = { area = wallArea, floorY = GROUND_Y - WALL_BEHIND, depth = WALL_BEHIND,
    lights = { shadowOne } }

local function fireShadows(x, y, flicker)
    local z = WALL_BEHIND + FIRE_IN_FRONT
    shadowLight.x, shadowLight.z = x, z
    shadowLight.h = shadowSettings.floorY + z - y -- on screen a lamp sits at y = floorY + z - h
    shadowOne.strength = atHour('shadow') * math.min(1, flicker)
    shadowOne.softness = SHADOW_SOFTNESS * (0.8 + 0.4 * flicker)
    state.projectedShadows = shadowSettings
end

function s.update(dt)
    local fc = c()
    if not fc.fire then return end
    fire.update(fc.fire, dt)
    local body, light = fireLight()
    local x, y, flicker = fire.light(fc.fire)
    if body then
        body:setPosition(x, y)
        light.intensity = atHour('light') * flicker
    end
    if x then fireShadows(x, y, flicker) end
end

function s.onUnload()
    if state.projectedShadows == shadowSettings then state.projectedShadows = nil end
end

function s.draw()
    local fc = c()
    if not fc.fire then return end
    fire.drawGlow(fc.fire, darkness(), atHour('glow'))
    fire.draw(fc.fire)
end

-- the day / night panel, bottom right: per row a day slider and a night slider, then dusk
local PANEL = { w = 470, row = 34, pad = 6 }
function s.drawUI()
    local fc = c()
    local st = settings()
    if not fc.showPanel then return end
    ui.startFrame()
    local sw, sh = love.graphics.getDimensions()
    local w, h = PANEL.w, PANEL.row * (#DAY_NIGHT + 3) + 34
    local x0, y0 = sw - w - 12, math.max(12, sh - h - 12)
    ui.panel(x0, y0, w, h, '•• fire: day / night ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = 0, startX = x0 + PANEL.pad, startY = y0 + 28 })
        local function row() return ui.nextLayoutPosition(layout, w - PANEL.pad * 2, PANEL.row) end
        local x, y = row()
        ui.label(x + 80, y + 4, 'day')
        ui.label(x + 270, y + 4, 'night')
        for _, r in ipairs(DAY_NIGHT) do
            x, y = row()
            ui.label(x, y + 4, r.text)
            local step = (r.hi - r.lo) / 100
            local d = ui.sliderWithInput('fire-' .. r.key .. 'Day', x + 75, y - 2, 90, r.lo, r.hi,
                st[r.key .. 'Day'], nil, step)
            if d then st[r.key .. 'Day'] = d + 0 end
            local n = ui.sliderWithInput('fire-' .. r.key .. 'Night', x + 265, y - 2, 90, r.lo, r.hi,
                st[r.key .. 'Night'], nil, step)
            if n then st[r.key .. 'Night'] = n + 0 end
        end
        x, y = row()
        ui.label(x, y + 4, 'dusk')
        local k = ui.sliderWithInput('fire-duskHours', x + 75, y - 2, 90, 0.5, 10, st.duskHours, nil, 0.1)
        if k then st.duskHours = k + 0 end
        ui.label(x + 265, y + 4, 'hours round sunset')
        x, y = row()
        ui.label(x, y + 4, string.format('now %d%% night   h hides', math.floor(darkness() * 100 + 0.5)))
    end)
end

return s
