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
    if key == 'f' and fc.fire then
        local styles = fire.STYLES
        for i, name in ipairs(styles) do
            if name == (fc.fire.style or 'drawn') then fc.fire.style = styles[i % #styles + 1] break end
        end
    end
end

function s.update(dt)
    local fc = c()
    if not fc.fire then return end
    fire.update(fc.fire, dt)
    local body, light = fireLight()
    if body then
        local x, y, flicker = fire.light(fc.fire)
        body:setPosition(x, y)
        light.intensity = LIGHT_STRENGTH * flicker
    end
end

-- how dark the hour is: 0 by day .. 1 at night (the sky's hour light, src/scene-light.lua)
local function darkness()
    local h = state.hourLight
    if not h then return 0.6 end
    return math.max(0, math.min(1, 1.15 - (h[1] + h[2] + h[3]) / 3 * 1.3))
end

function s.draw()
    local fc = c()
    if not fc.fire then return end
    fire.drawGlow(fc.fire, darkness())
    fire.draw(fc.fire)
end

return s
