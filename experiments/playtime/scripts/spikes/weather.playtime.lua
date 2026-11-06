-- weather: rain, storm, fog, snow, wind and heat over one hillside, blended by amount (docs/WEATHER.md)
-- Every weather is a set of amounts (clouds, rain, snow, fog, wind, heat, storm) that the scene eases
-- toward, so two weathers blend and a change is never a cut. What falls and blows is drawn; heat is
-- the one shader: the scene goes into a canvas and the air above the ground bends it (as the sea does).
-- Effects come out of state: rain wets the ground and fills puddles, heat dries them and melts the
-- snow, snow settles round the feet, wind pushes light bodies more than heavy ones.
--
-- play mode (tab): 1 clear  2 windy  3 rain  4 storm  5 fog  6 snow  7 heat;  a the weather machine
-- (picks the next weather now and then);  m a Mipo, b a crate at the mouse;  r dry and clear;  h the panel

local s = {}

local GROUND_TOP = 0
local X1, X2 = -5000, 5000
local OUTLINE = { 0.16, 0.14, 0.2 }
local GROUND = { 0.55, 0.66, 0.42 }
local GROUND_WET = { 0.32, 0.42, 0.28 }
local GROUND_HOT = { 0.72, 0.68, 0.42 }
local EARTH = { 0.46, 0.36, 0.27 }
local WOOD = { 0.8, 0.6, 0.38 }

local KEYS = { 'clouds', 'rain', 'snow', 'fog', 'wind', 'heat', 'storm' }

-- the weathers: targets for the amounts (wind is signed: + blows to the right)
local WEATHERS = {
    { name = 'clear', clouds = 0.2, rain = 0, snow = 0, fog = 0, wind = 0.12, heat = 0, storm = 0 },
    { name = 'windy', clouds = 0.45, rain = 0, snow = 0, fog = 0, wind = 0.9, heat = 0, storm = 0 },
    { name = 'rain', clouds = 0.85, rain = 0.65, snow = 0, fog = 0.1, wind = 0.25, heat = 0, storm = 0 },
    { name = 'storm', clouds = 1, rain = 1, snow = 0, fog = 0.05, wind = 0.85, heat = 0, storm = 1 },
    { name = 'fog', clouds = 0.3, rain = 0, snow = 0, fog = 1, wind = 0.05, heat = 0, storm = 0 },
    { name = 'snow', clouds = 0.75, rain = 0, snow = 0.8, fog = 0.15, wind = 0.2, heat = 0, storm = 0 },
    { name = 'heat', clouds = 0, rain = 0, snow = 0, fog = 0, wind = 0.04, heat = 1, storm = 0 },
}
local BY_NAME = {}
for i, w in ipairs(WEATHERS) do BY_NAME[w.name] = i end

-- the weather machine (after dreamengine's weather.c): where each weather tends to go next
local NEXT = {
    clear = { windy = 3, rain = 2, heat = 2, fog = 1.5, snow = 1 },
    windy = { clear = 4, rain = 4, storm = 2 },
    rain = { storm = 3, clear = 3, windy = 2, fog = 2 },
    storm = { rain = 6, windy = 4 },
    fog = { clear = 5, rain = 3, snow = 2 },
    snow = { clear = 4, fog = 3, windy = 3 },
    heat = { clear = 5, storm = 3, windy = 2 },
}

local function clamp(x, a, b) return math.max(a, math.min(b, x)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function mix(c1, c2, t)
    return { lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t) }
end
-- a fixed pseudo-random 0..1 for a number (blade heights, lumps)
local function hash(n)
    local x = math.sin(n * 127.1 + 311.7) * 43758.5453
    return x - math.floor(x)
end

local function scene()
    state.weatherScene = state.weatherScene or {
        target = {}, now = {}, settings = { blend = 4, push = 1 },
        weather = 'clear', auto = false, autoTimer = 25, time = 0,
        drops = {}, flakes = {}, splashes = {}, leaves = {}, swirls = {}, clouds = {},
        wet = 0, puddle = 0, snowDepth = 0, flash = 0, boltTimer = 4, bolt = nil,
        mipos = {}, crates = {}, showPanel = true,
    }
    local sc = state.weatherScene
    for _, k in ipairs(KEYS) do
        sc.target[k] = sc.target[k] or WEATHERS[1][k]
        sc.now[k] = sc.now[k] or WEATHERS[1][k]
    end
    return sc
end

local function setWeather(sc, name)
    local w = WEATHERS[BY_NAME[name]]
    if not w then return end
    sc.weather = name
    for _, k in ipairs(KEYS) do sc.target[k] = w[k] end
end

local function pickNext(name)
    local options = NEXT[name] or NEXT.clear
    local sum = 0
    for _, wgt in pairs(options) do sum = sum + wgt end
    local r = love.math.random() * sum
    for n, wgt in pairs(options) do
        r = r - wgt
        if r <= 0 then return n end
    end
    return 'clear'
end

local function viewRect()
    local w, h = love.graphics.getDimensions()
    local x1, y1 = cam:getWorldCoordinates(0, 0)
    local x2, y2 = cam:getWorldCoordinates(w, h)
    return math.min(x1, x2), math.min(y1, y2), math.max(x1, x2), math.max(y1, y2)
end

---------------------------------------------------------------- the world

local function build(sc)
    for _, b in ipairs(sc.bodies or {}) do
        if not b:isDestroyed() then b:destroy() end
    end
    local ground = love.physics.newBody(world, 0, 0, 'static')
    love.physics.newFixture(ground, love.physics.newPolygonShape(X1, GROUND_TOP, X2, GROUND_TOP, X2,
        GROUND_TOP + 600, X1, GROUND_TOP + 600))
    -- walls at the world's ends, so the wind can't carry anything off it
    love.physics.newFixture(ground, love.physics.newRectangleShape(X1 - 50, -2000, 100, 4400))
    love.physics.newFixture(ground, love.physics.newRectangleShape(X2 + 50, -2000, 100, 4400))
    sc.bodies = { ground }
    sc.ground = ground
end

local function spawnMipo(sc, x, y)
    local inst = characterManager.createCharacter('humanoid', x, y, 0.3)
    if inst then characterManager.randomizeMipoConstrained(inst) end
    if inst then sc.mipos[#sc.mipos + 1] = inst end
end

local function spawnCrate(sc, x, y)
    local body = love.physics.newBody(world, x, y, 'dynamic')
    local size = 110 + love.math.random() * 90
    love.physics.newFixture(body, love.physics.newRectangleShape(size, size * 0.8), 1.5)
    sc.crates[#sc.crates + 1] = { body = body }
end

-- hills as height fields, drawn as strip meshes (concave is fine that way)
local function hillMesh(seed, top, amp, step)
    local verts, line = {}, {}
    for x = X1 - 2000, X2 + 2000, step do
        local y = top - amp * (0.55 + 0.25 * math.sin(x * 0.0007 + seed) + 0.15 * math.sin(x * 0.0019 + seed * 3)
            + 0.05 * math.sin(x * 0.006 + seed * 7))
        verts[#verts + 1] = { x, y }
        verts[#verts + 1] = { x, GROUND_TOP + 10 }
        line[#line + 1] = x
        line[#line + 1] = y
    end
    return love.graphics.newMesh(verts, 'strip', 'static'), line
end

local skyMesh
local hills = {}
local function ensureMeshes()
    if skyMesh then return end
    skyMesh = love.graphics.newMesh({
        { X1 * 6, -40000, 0, 0 }, { X2 * 6, -40000, 0, 0 },
        { X1 * 6, -3500, 0, 0 }, { X2 * 6, -3500, 0, 0 },
        { X1 * 6, GROUND_TOP, 0, 0 }, { X2 * 6, GROUND_TOP, 0, 0 },
    }, 'strip', 'stream')
    hills.far, hills.farLine = hillMesh(1.3, GROUND_TOP - 250, 900, 120)
    hills.mid, hills.midLine = hillMesh(4.1, GROUND_TOP - 60, 420, 90)
end

-- a soft round blob for fog banks
local blob
local function ensureBlob()
    if blob then return end
    local size = 128
    local data = love.image.newImageData(size, size)
    data:mapPixel(function(px, py)
        local dx, dy = (px + 0.5) / size * 2 - 1, (py + 0.5) / size * 2 - 1
        local d = math.sqrt(dx * dx + dy * dy)
        local a = clamp(1 - d, 0, 1)
        return 1, 1, 1, a * a * (3 - 2 * a)
    end)
    blob = love.graphics.newImage(data)
end

---------------------------------------------------------------- the air's colours

local SKY = {
    day = { { 0.38, 0.74, 0.80 }, { 0.94, 0.93, 0.74 } }, -- Puppetmaker's turquoise -> cream
    grey = { { 0.55, 0.58, 0.62 }, { 0.80, 0.81, 0.80 } },
    storm = { { 0.20, 0.22, 0.28 }, { 0.44, 0.45, 0.47 } },
    snow = { { 0.78, 0.81, 0.86 }, { 0.94, 0.94, 0.95 } },
    fog = { { 0.80, 0.82, 0.82 }, { 0.86, 0.87, 0.86 } },
    heat = { { 0.62, 0.78, 0.86 }, { 1.0, 0.91, 0.72 } },
}

-- the sky (top, bottom), the air (what far things fade to) and the light on everything, from the amounts
local function airColours(now)
    local top, bottom = SKY.day[1], SKY.day[2]
    local function toward(pair, t)
        t = clamp(t, 0, 1)
        top, bottom = mix(top, pair[1], t), mix(bottom, pair[2], t)
    end
    toward(SKY.grey, now.rain * 1.1 + math.max(0, now.clouds - 0.5) * 0.8)
    toward(SKY.snow, now.snow * 1.1)
    toward(SKY.fog, now.fog * 0.9)
    toward(SKY.storm, now.storm)
    toward(SKY.heat, now.heat)
    local light = 1 - 0.15 * now.rain - 0.2 * now.storm - 0.08 * math.max(0, now.clouds - 0.5)
    local warm = { 1, 1 - 0.03 * now.heat, 1 - 0.1 * now.heat }
    return top, bottom, bottom, light, warm
end

---------------------------------------------------------------- updating

local function updateAmounts(sc, dt)
    local k = 1 - math.exp(-dt / math.max(0.1, sc.settings.blend))
    for _, key in ipairs(KEYS) do
        sc.now[key] = sc.now[key] + (sc.target[key] - sc.now[key]) * k
    end
    if sc.auto then
        sc.autoTimer = sc.autoTimer - dt
        if sc.autoTimer <= 0 then
            setWeather(sc, pickNext(sc.weather))
            sc.autoTimer = 18 + love.math.random() * 17
        end
    end
end

-- the wind's speed now in world units a second (signed): the steady part and the gusts
local WIND_SPEED = 12 -- metres a second at wind 1
local function windNow(sc)
    local w, t = sc.now.wind, sc.time
    local gust = 0.55 + 0.45 * math.sin(t * 1.3) * math.sin(t * 0.37 + 1) + 0.25 * math.max(0, math.sin(t * 0.21 + 2)) ^ 4
    return w * gust * WIND_SPEED * love.physics.getMeter(), gust
end

-- wind on bodies: a drag on each fixture's size against the body's own speed, so a light Mipo
-- (little mass for its size) goes further than a crate
local DRAG = 0.12
local function blow(sc, wind)
    if math.abs(wind) < 1 then return end
    local meter2 = love.physics.getMeter() ^ 2
    for _, body in ipairs(world:getBodies()) do
        if body:getType() == 'dynamic' and body:isAwake() or (body:getType() == 'dynamic' and math.abs(wind) > 200) then
            local area = 0
            for _, f in ipairs(body:getFixtures()) do
                if not f:isSensor() then
                    local ax, ay, bx, by = f:getBoundingBox()
                    area = area + (bx - ax) * (by - ay)
                end
            end
            if area > 0 then
                local vx = body:getLinearVelocity()
                local _, y = body:getPosition()
                local shelter = y > GROUND_TOP - 30 and 0.3 or 1
                body:applyForce(DRAG * sc.settings.push * shelter * area / meter2 * (wind - vx), 0)
            end
        end
    end
end

local function updateRain(sc, dt, wind, x1, y1, x2)
    local want = sc.now.rain
    local n = math.floor(want * 900 * dt * (x2 - x1) / 3000 + love.math.random())
    for _ = 1, n do
        if #sc.drops > 1600 then break end
        local depth = love.math.random()
        sc.drops[#sc.drops + 1] = {
            x = lerp(x1, x2, love.math.random()) - wind * 0.6, y = y1 - 200 - love.math.random() * 300,
            vy = 2200 + 600 * depth, depth = depth, land = GROUND_TOP - 20 + depth * 90,
        }
    end
    local keep = {}
    for _, d in ipairs(sc.drops) do
        d.x = d.x + wind * 0.9 * dt
        d.y = d.y + d.vy * dt
        if d.y >= d.land then
            if #sc.splashes < 300 then sc.splashes[#sc.splashes + 1] = { x = d.x, y = d.land, t = 0, depth = d.depth } end
        else
            keep[#keep + 1] = d
        end
    end
    sc.drops = keep
    local sp = {}
    for _, p in ipairs(sc.splashes) do
        p.t = p.t + dt
        if p.t < 0.3 then sp[#sp + 1] = p end
    end
    sc.splashes = sp
end

local function updateSnow(sc, dt, wind, x1, y1, x2)
    local n = math.floor(sc.now.snow * 260 * dt * (x2 - x1) / 3000 + love.math.random())
    for _ = 1, n do
        if #sc.flakes > 1400 then break end
        local depth = love.math.random()
        sc.flakes[#sc.flakes + 1] = {
            x = lerp(x1, x2, love.math.random()) - wind * 2, y = y1 - 100 - love.math.random() * 200,
            r = 4 + 7 * depth, vy = 110 + 140 * depth, phase = love.math.random() * 6.28, depth = depth,
            land = GROUND_TOP - 20 + depth * 90 - sc.snowDepth,
        }
    end
    local keep = {}
    for _, f in ipairs(sc.flakes) do
        f.x = f.x + (wind * 0.5 + 50 * math.sin(sc.time * 1.7 + f.phase)) * dt
        f.y = f.y + f.vy * dt
        if f.y < f.land then keep[#keep + 1] = f end
    end
    sc.flakes = keep
end

local LEAF_COLOURS = { { 0.85, 0.55, 0.2 }, { 0.75, 0.32, 0.18 }, { 0.9, 0.72, 0.25 }, { 0.55, 0.6, 0.25 } }
local function updateLeaves(sc, dt, wind, x1, y1, x2, y2)
    local strength = math.abs(sc.now.wind)
    if strength > 0.3 and #sc.leaves < 140 then
        local n = math.floor((strength - 0.3) * 30 * dt + love.math.random())
        for _ = 1, n do
            local fromLeft = wind > 0
            sc.leaves[#sc.leaves + 1] = {
                x = fromLeft and x1 - 100 or x2 + 100, y = lerp(y1, GROUND_TOP, 0.3 + 0.7 * love.math.random()),
                vx = wind * 0.5, vy = 0, rot = love.math.random() * 6.28, spin = (love.math.random() - 0.5) * 8,
                colour = LEAF_COLOURS[love.math.random(#LEAF_COLOURS)], phase = love.math.random() * 6.28,
                size = 14 + love.math.random() * 10,
            }
        end
    end
    local keep = {}
    for _, l in ipairs(sc.leaves) do
        local onGround = l.y >= GROUND_TOP - 4
        if onGround and math.abs(wind) < 400 then
            l.vx, l.vy = l.vx * 0.9, 0
        else
            l.vx = l.vx + (wind - l.vx) * math.min(1, dt * 1.5)
            l.vy = l.vy + (300 - l.vy) * math.min(1, dt * 1.2) + math.sin(sc.time * 3 + l.phase) * 600 * dt
            if onGround and math.abs(wind) >= 400 then l.vy = -200 - love.math.random() * 300 end
            l.rot = l.rot + l.spin * dt
        end
        l.x = l.x + l.vx * dt
        l.y = math.min(GROUND_TOP - 3, l.y + l.vy * dt)
        if l.x > x1 - 600 and l.x < x2 + 600 and l.y > y1 - 600 and l.y < y2 + 600 then keep[#keep + 1] = l end
    end
    sc.leaves = keep
    -- swirl lines in a gust
    local _, gust = windNow(sc)
    if strength > 0.35 and gust > 0.75 and #sc.swirls < 8 and love.math.random() < dt * 2 then
        sc.swirls[#sc.swirls + 1] = { x = lerp(x1, x2, love.math.random()), y = lerp(y1, GROUND_TOP - 100, love.math.random()),
            t = 0, life = 1.4, len = 260 + love.math.random() * 220 }
    end
    local sw = {}
    for _, w in ipairs(sc.swirls) do
        w.t = w.t + dt
        w.x = w.x + wind * 0.8 * dt
        if w.t < w.life then sw[#sw + 1] = w end
    end
    sc.swirls = sw
end

local function updateClouds(sc, dt, wind)
    if #sc.clouds == 0 then
        for i = 1, 26 do
            local puffs = {}
            for p = 1, 5 + love.math.random(4) do
                puffs[p] = { (p - 3) * 120 + love.math.random() * 60, -love.math.random() * 90 + math.abs(p - 3) * 25,
                    90 + love.math.random() * 80 }
            end
            sc.clouds[i] = { x = lerp(X1, X2, love.math.random()), y = -1500 - love.math.random() * 1600,
                order = love.math.random(), puffs = puffs }
        end
    end
    for _, c in ipairs(sc.clouds) do
        c.x = c.x + (wind * 0.25 + 15) * dt * (0.5 + 0.5 * (c.y / -3100))
        if c.x > X2 + 800 then c.x = X1 - 800 elseif c.x < X1 - 800 then c.x = X2 + 800 end
    end
end

local function updateLightning(sc, dt, x1, x2)
    sc.flash = math.max(0, sc.flash - dt * 2.5)
    if sc.bolt then
        sc.bolt.t = sc.bolt.t + dt
        if sc.bolt.t > 0.35 then sc.bolt = nil end
    end
    if sc.now.storm < 0.3 then return end
    sc.boltTimer = sc.boltTimer - dt * sc.now.storm
    if sc.boltTimer > 0 then return end
    sc.boltTimer = 3 + love.math.random() * 7
    sc.flash = 1
    local x = lerp(x1, x2, 0.15 + 0.7 * love.math.random())
    local pts, y = { x, -1700 }, -1700
    while y < GROUND_TOP - 10 do
        y = math.min(GROUND_TOP - 10, y + 120 + love.math.random() * 120)
        x = x + (love.math.random() - 0.5) * 220
        pts[#pts + 1] = x
        pts[#pts + 1] = y
    end
    sc.bolt = { pts = pts, t = 0 }
end

-- the ground's state: wet, puddles, snow
local function updateGround(sc, dt)
    local n = sc.now
    sc.wet = clamp(sc.wet + (n.rain * 0.25 - (0.015 + n.heat * 0.2 + math.abs(n.wind) * 0.03) * (1 - n.rain)) * dt, 0, 1)
    sc.puddle = clamp(sc.puddle + (n.rain * 0.06 - (0.006 + n.heat * 0.08) * (1 - n.rain)) * dt, 0, 1)
    local melt = (n.heat * 25 + n.rain * 4 + 0.6) * (1 - n.snow)
    sc.snowDepth = clamp(sc.snowDepth + (n.snow * 5 - melt) * dt, 0, 70)
end

-- rain on the Mipos: now and then a wet spot on a body under the open sky (src/wet.lua)
local function wetBodies(sc, dt)
    if sc.now.rain < 0.05 then return end
    sc.wetTimer = (sc.wetTimer or 0) - dt * sc.now.rain
    if sc.wetTimer > 0 then return end
    sc.wetTimer = 0.25
    local bodies = {}
    for _, body in ipairs(world:getBodies()) do
        if body:getType() == 'dynamic' then bodies[#bodies + 1] = body end
    end
    if #bodies == 0 then return end
    local body = bodies[love.math.random(#bodies)]
    local x, y = body:getPosition()
    wet.splash(x + (love.math.random() - 0.5) * 30, y - 10, 28, 0.6)
end

---------------------------------------------------------------- hooks

function s.onStart()
    worldState.paused = false
    local sc = scene()
    if not (sc.ground and not sc.ground:isDestroyed()) then
        sc.mipos, sc.crates = {}, {}
        build(sc)
        spawnMipo(sc, -500, GROUND_TOP - 300)
        spawnMipo(sc, 100, GROUND_TOP - 300)
        spawnMipo(sc, 650, GROUND_TOP - 300)
        spawnCrate(sc, 1200, GROUND_TOP - 200)
    end
    camera.setBounds(X1, -4500, X2, GROUND_TOP + 700)
end

function s.onUnload()
    local sc = state.weatherScene
    if sc and sc.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = sc.savedDrawBodies
        sc.savedDrawBodies = nil
    end
    wet.clear()
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local sc = scene()
    local mx, my = mouseWorldPos()
    local n = tonumber(key)
    if n and WEATHERS[n] then
        sc.auto = false
        setWeather(sc, WEATHERS[n].name)
    elseif key == 'a' then
        sc.auto = not sc.auto
        sc.autoTimer = 0
    elseif key == 'm' then spawnMipo(sc, mx, my)
    elseif key == 'b' then spawnCrate(sc, mx, my)
    elseif key == 'h' then sc.showPanel = not sc.showPanel
    elseif key == 'r' then
        sc.wet, sc.puddle, sc.snowDepth = 0, 0, 0
        sc.drops, sc.flakes, sc.leaves, sc.splashes = {}, {}, {}, {}
        wet.clear()
    end
end

function s.update(dt)
    local sc = state.weatherScene
    if not sc or not sc.ground or sc.ground:isDestroyed() then return end
    sc.time = sc.time + dt
    updateAmounts(sc, dt)
    local x1, y1, x2, y2 = viewRect()
    local wind = windNow(sc)
    blow(sc, wind)
    updateClouds(sc, dt, wind)
    updateRain(sc, dt, wind, x1, y1, x2)
    updateSnow(sc, dt, wind, x1, y1, x2)
    updateLeaves(sc, dt, wind, x1, y1, x2, y2)
    updateLightning(sc, dt, x1, x2)
    updateGround(sc, dt)
    wetBodies(sc, dt)
    wet.update(dt)
end

---------------------------------------------------------------- drawing

-- heat: the scene drawn into a canvas, then bent through this
local shimmerShader = love.graphics.newShader([[
extern number time;
extern number heat;
extern number groundV;   // the ground line's place on the screen, 0 top .. 1 bottom
extern vec4 view;        // the world rect on screen: x1, y1, x2, y2
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 wp = vec2(mix(view.x, view.z, uv.x), mix(view.y, view.w, uv.y));
    float above = -wp.y;                         // world units above the ground (ground at 0)
    float near = exp(-max(above, 0.0) / 420.0);  // strongest just above the ground
    float strength = heat * (0.12 + 0.88 * near) * step(-30.0, above);
    // the air rises: the pattern moves up over time, stretched tall
    vec2 q = vec2(wp.x * 0.010, wp.y * 0.022 + time * 2.4);
    float n1 = noise(q) + 0.5 * noise(q * 2.3 + 7.0);
    float n2 = noise(q * 1.7 + 3.0);
    vec2 offsetWorld = vec2((n1 - 0.75) * 16.0, (n2 - 0.5) * 7.0) * strength;
    vec2 offset = offsetWorld / vec2(view.z - view.x, view.w - view.y);
    vec4 c = Texel(tex, uv + offset);
    // the mirage: just below the ground line the sky and hills show mirrored, wavering
    float below = uv.y - groundV;
    float band = 0.035;
    if (below > 0.0 && below < band) {
        float fade = (1.0 - below / band) * heat * 0.55;
        vec4 m = Texel(tex, vec2(uv.x + offset.x * 2.0, groundV - below * 1.6 + offset.y));
        c = mix(c, m, fade);
    }
    return c * color;
}
]])

local sceneCanvas, prevCanvas
local function ensureCanvas()
    local w, h = love.graphics.getDimensions()
    if not sceneCanvas or sceneCanvas:getWidth() ~= w or sceneCanvas:getHeight() ~= h then
        local _, _, flags = love.window.getMode()
        sceneCanvas = love.graphics.newCanvas(w, h, { msaa = flags.msaa or 0 })
    end
end

local function veil(colour, alpha, x1, y1, x2, y2)
    if alpha <= 0.002 then return end
    love.graphics.setColor(colour[1], colour[2], colour[3], alpha)
    love.graphics.rectangle('fill', x1 - 50, y1 - 50, x2 - x1 + 100, y2 - y1 + 100)
end

local function drawSun(sc, x1, x2)
    local n = sc.now
    local alpha = clamp(1 - n.clouds * 0.9 - n.fog * 0.6 - n.storm, 0, 1)
    if alpha <= 0 then return end
    local x, y = lerp(x1, x2, 0.78), -1500 + (x2 - x1) * 0.0
    local r = 150 + 70 * n.heat
    love.graphics.setColor(1, 0.95, 0.7, alpha * (0.15 + 0.2 * n.heat))
    love.graphics.circle('fill', x, y, r * 2.2)
    love.graphics.setColor(1, 0.93 - 0.08 * n.heat, 0.6 - 0.15 * n.heat, alpha)
    love.graphics.circle('fill', x, y, r)
end

local function drawClouds(sc, top, light)
    local n = sc.now
    local count = n.clouds * #sc.clouds
    local white = mix({ 1, 1, 1 }, { 0.62, 0.64, 0.68 }, clamp(n.rain * 0.8 + n.storm * 0.5, 0, 1))
    white = mix(white, top, 0.15 + 0.3 * n.fog)
    local belly = mix(white, { 0.35, 0.37, 0.44 }, 0.25 + 0.45 * n.storm)
    for i, c in ipairs(sc.clouds) do
        local a = clamp(count - (i - 1), 0, 1)
        if a > 0 then
            local depthFade = 0.45 + 0.55 * (c.y / -3100)
            love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a * (1 - depthFade * 0.6))
            for _, p in ipairs(c.puffs) do love.graphics.circle('fill', c.x + p[1], c.y + p[2], p[3] + 6) end
            love.graphics.setColor(belly[1] * light, belly[2] * light, belly[3] * light, a)
            for _, p in ipairs(c.puffs) do love.graphics.circle('fill', c.x + p[1], c.y + p[2], p[3]) end
            love.graphics.setColor(white[1] * light, white[2] * light, white[3] * light, a)
            for _, p in ipairs(c.puffs) do love.graphics.circle('fill', c.x + p[1] - 8, c.y + p[2] - 16, p[3] * 0.86) end
        end
    end
end

local function drawHill(mesh, line, colour, light)
    love.graphics.setColor(colour[1] * light, colour[2] * light, colour[3] * light)
    love.graphics.draw(mesh)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(4)
    love.graphics.line(line)
end

local function drawRain(sc, front, light)
    love.graphics.setLineWidth(3)
    local wind = windNow(sc)
    for _, d in ipairs(sc.drops) do
        if (d.depth >= 0.5) == front then
            local a = (0.25 + 0.4 * d.depth)
            love.graphics.setColor(0.78 * light, 0.84 * light, 0.92 * light, a)
            local k = 0.035
            love.graphics.line(d.x, d.y, d.x - wind * 0.9 * k, d.y - d.vy * k)
        end
    end
    for _, p in ipairs(sc.splashes) do
        if (p.depth >= 0.5) == front then
            local t = p.t / 0.3
            love.graphics.setColor(0.85, 0.9, 0.96, 0.6 * (1 - t))
            love.graphics.arc('line', 'open', p.x, p.y, 6 + 22 * t, math.pi * 1.1, math.pi * 1.9)
        end
    end
end

local function drawSnow(sc, front)
    for _, f in ipairs(sc.flakes) do
        if (f.depth >= 0.5) == front then
            love.graphics.setColor(1, 1, 1, 0.55 + 0.45 * f.depth)
            love.graphics.circle('fill', f.x, f.y, f.r)
        end
    end
end

local function drawGrass(sc, x1, x2, light)
    local n = sc.now
    local wind = windNow(sc)
    local lean = clamp(wind / (WIND_SPEED * love.physics.getMeter()), -1.2, 1.2)
    local colour = mix(mix({ 0.42, 0.6, 0.3 }, { 0.3, 0.45, 0.25 }, sc.wet), { 0.78, 0.72, 0.4 }, n.heat * 0.7)
    love.graphics.setLineWidth(5)
    love.graphics.setColor(colour[1] * light, colour[2] * light, colour[3] * light)
    local step = 26
    for x = math.floor(x1 / step) * step, x2, step do
        local h = 40 + 55 * hash(x) - sc.snowDepth * 0.6
        if h > 6 then
            local sway = lean * (0.7 + 0.3 * math.sin(sc.time * 4 + x * 0.013)) + 0.08 * math.sin(sc.time * 1.5 + x * 0.05)
            local bend = clamp(sway, -1.2, 1.2)
            local mx, my = x + math.sin(bend * 0.5) * h * 0.5, GROUND_TOP - math.cos(bend * 0.5) * h * 0.5
            local tx, ty = x + math.sin(bend) * h, GROUND_TOP - math.cos(bend) * h
            love.graphics.line(x, GROUND_TOP + 4, mx, my, tx, ty)
        end
    end
end

local function drawGround(sc, x1, x2, light)
    local n = sc.now
    local colour = mix(mix(GROUND, GROUND_WET, sc.wet * 0.8), GROUND_HOT, n.heat * 0.5)
    love.graphics.setColor(colour[1] * light, colour[2] * light, colour[3] * light)
    love.graphics.rectangle('fill', x1 - 50, GROUND_TOP, x2 - x1 + 100, 90)
    local earth = mix(EARTH, { 0.3, 0.24, 0.2 }, sc.wet * 0.6)
    love.graphics.setColor(earth[1] * light, earth[2] * light, earth[3] * light)
    love.graphics.rectangle('fill', x1 - 50, GROUND_TOP + 90, x2 - x1 + 100, 2000)
    love.graphics.setColor(OUTLINE)
    love.graphics.setLineWidth(4)
    love.graphics.line(x1 - 50, GROUND_TOP, x2 + 50, GROUND_TOP)
    -- puddles in the dips: flat ovals that fill and ripple
    if sc.puddle > 0.01 then
        for i = -12, 12 do
            local px = i * 420 + 130 * math.sin(i * 2.1)
            if px > x1 - 400 and px < x2 + 400 then
                local w = (90 + 120 * hash(i + 0.5)) * math.sqrt(sc.puddle)
                local py = GROUND_TOP + 30 + 40 * hash(i + 0.25)
                local sky = { 0.66, 0.76, 0.82 }
                love.graphics.setColor(sky[1] * light, sky[2] * light, sky[3] * light, 0.85)
                love.graphics.ellipse('fill', px, py, w, w * 0.12)
                love.graphics.setColor(1, 1, 1, 0.35)
                love.graphics.setLineWidth(2)
                love.graphics.ellipse('line', px, py, w, w * 0.12)
                if n.rain > 0.05 then
                    for r = 0, 1 do
                        local t = (sc.time * 1.3 + hash(i + r) + r * 0.5) % 1
                        local rx = px + (hash(i * 3 + r + math.floor(sc.time * 1.3 + hash(i + r) + r * 0.5)) - 0.5) * w
                        love.graphics.setColor(1, 1, 1, 0.5 * (1 - t) * n.rain)
                        love.graphics.ellipse('line', rx, py, 6 + 30 * t, (6 + 30 * t) * 0.15)
                    end
                end
            end
        end
    end
end

local function drawSnowLayer(sc, x1, x2)
    if sc.snowDepth < 1 then return end
    local pts = {}
    local step = 60
    local x0 = math.floor((x1 - 100) / step) * step
    for x = x0, x2 + 100, step do
        local lump = 0.75 + 0.5 * hash(x * 0.37)
        pts[#pts + 1] = { x, GROUND_TOP - sc.snowDepth * lump }
        pts[#pts + 1] = { x, GROUND_TOP + sc.snowDepth * 0.6 }
    end
    local mesh = love.graphics.newMesh(pts, 'strip', 'stream')
    love.graphics.setColor(0.97, 0.98, 1)
    love.graphics.draw(mesh)
    mesh:release()
    local line = {}
    for i = 1, #pts, 2 do
        line[#line + 1] = pts[i][1]
        line[#line + 1] = pts[i][2]
    end
    love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 0.6)
    love.graphics.setLineWidth(3)
    love.graphics.line(line)
end

local function drawLeaves(sc)
    for _, l in ipairs(sc.leaves) do
        love.graphics.push()
        love.graphics.translate(l.x, l.y)
        love.graphics.rotate(l.rot)
        love.graphics.setColor(l.colour)
        love.graphics.ellipse('fill', 0, 0, l.size, l.size * 0.45)
        love.graphics.setColor(OUTLINE)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse('line', 0, 0, l.size, l.size * 0.45)
        love.graphics.line(-l.size, 0, l.size, 0)
        love.graphics.pop()
    end
end

local function drawSwirls(sc)
    love.graphics.setLineWidth(4)
    local dir = sc.now.wind >= 0 and 1 or -1
    for _, w in ipairs(sc.swirls) do
        local t = w.t / w.life
        local a = math.sin(t * math.pi) * 0.7
        local pts = {}
        local head = t * 1.3
        for i = 0, 24 do
            local u = i / 24
            if u <= head then
                local x = w.x + dir * u * w.len
                local y = w.y + math.sin(u * 7) * 18
                if u > 0.75 then -- the curl at the end
                    local c = (u - 0.75) / 0.25 * math.pi * 1.6
                    x = w.x + dir * (0.75 * w.len + math.sin(c) * 40)
                    y = w.y + math.sin(0.75 * 7) * 18 - (1 - math.cos(c)) * 40
                end
                pts[#pts + 1] = x
                pts[#pts + 1] = y
            end
        end
        if #pts >= 4 then
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.line(pts)
        end
    end
end

local function drawFogBanks(sc, air, x1, x2)
    local fog = sc.now.fog
    if fog < 0.02 then return end
    ensureBlob()
    local wind = windNow(sc)
    local span = 5200
    for i = 0, 13 do
        local x = (i * 420 + sc.time * (40 + wind * 0.15) * (0.6 + 0.4 * hash(i))) % span
        x = math.floor(x1 / span) * span + x
        for k = 0, 1 do
            local bx = x + k * span
            if bx > x1 - 1200 and bx < x2 + 1200 then
                local y = GROUND_TOP - 80 - 220 * hash(i + 0.7)
                local w, h = 900 + 600 * hash(i + 0.3), 220 + 160 * hash(i + 0.9)
                love.graphics.setColor(air[1], air[2], air[3], fog * 0.5)
                love.graphics.draw(blob, bx, y, 0, w / 128, h / 128, 64, 64)
            end
        end
    end
end

function s.drawBelow()
    local sc = state.weatherScene
    if not sc or not sc.ground or sc.ground:isDestroyed() then return end
    ensureMeshes()
    local n = sc.now
    local x1, y1, x2, y2 = viewRect()
    local top, bottom, air, light = airColours(n)
    sc.air, sc.light = air, light

    -- with heat, everything from the sky on goes into a canvas, so the air can bend it
    sc.shimmer = n.heat > 0.02
    if sc.shimmer then
        ensureCanvas()
        prevCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas({ sceneCanvas, stencil = true })
        love.graphics.clear(0, 0, 0, 1)
    end

    for i = 1, 6 do
        local c = i <= 4 and top or bottom
        if i <= 2 then c = mix(top, { 0.1, 0.12, 0.2 }, 0.2) end
        local v = { skyMesh:getVertex(i) }
        skyMesh:setVertex(i, v[1], v[2], 0, 0, c[1], c[2], c[3], 1)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(skyMesh)
    drawSun(sc, x1, x2)
    drawClouds(sc, top, light)

    -- the far hills, the air between, the near hills, the air again: haze by depth, thicker in fog
    local haze = 0.25 + 0.55 * n.fog + 0.3 * n.heat + 0.2 * n.rain + 0.1 * n.snow
    drawHill(hills.far, hills.farLine, mix({ 0.5, 0.62, 0.55 }, { 0.75, 0.7, 0.5 }, n.heat * 0.5), light)
    veil(air, clamp(haze, 0, 0.92), x1, y1, x2, GROUND_TOP)
    drawHill(hills.mid, hills.midLine, mix({ 0.48, 0.62, 0.38 }, { 0.72, 0.68, 0.42 }, n.heat * 0.5), light)
    veil(air, clamp(haze * 0.5, 0, 0.8), x1, y1, x2, GROUND_TOP)

    drawRain(sc, false, light)
    drawSnow(sc, false)
    drawGround(sc, x1, x2, light)
    drawGrass(sc, x1, x2, light)

    -- the crates (the ground and crates as plain bodies would be lime green)
    sc.savedDrawBodies = state.world.debugDrawBodies
    state.world.debugDrawBodies = false
    for _, c in ipairs(sc.crates) do
        if not c.body:isDestroyed() then
            local fx = c.body:getFixtures()[1]
            love.graphics.setColor(WOOD[1] * light, WOOD[2] * light, WOOD[3] * light)
            love.graphics.polygon('fill', c.body:getWorldPoints(fx:getShape():getPoints()))
            love.graphics.setColor(OUTLINE)
            love.graphics.setLineWidth(4)
            love.graphics.polygon('line', c.body:getWorldPoints(fx:getShape():getPoints()))
        end
    end
    sc.drawing = true
end

function s.draw()
    local sc = state.weatherScene
    if not (sc and sc.drawing) then return end
    sc.drawing = nil
    if sc.savedDrawBodies ~= nil then
        state.world.debugDrawBodies = sc.savedDrawBodies
        sc.savedDrawBodies = nil
    end
    local n = sc.now
    local x1, y1, x2, y2 = viewRect()
    local light = sc.light

    drawSnowLayer(sc, x1, x2) -- over the feet
    drawLeaves(sc)
    drawFogBanks(sc, sc.air, x1, x2)

    if sc.shimmer then
        local w, h = love.graphics.getDimensions()
        local _, gy = cam:getScreenCoordinates(0, GROUND_TOP)
        love.graphics.setCanvas(prevCanvas)
        love.graphics.push()
        love.graphics.origin()
        love.graphics.setShader(shimmerShader)
        shimmerShader:send('time', sc.time)
        shimmerShader:send('heat', n.heat)
        shimmerShader:send('groundV', gy / h)
        shimmerShader:send('view', { x1, y1, x2, y2 })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode('alpha', 'premultiplied')
        love.graphics.draw(sceneCanvas, 0, 0, 0, w / sceneCanvas:getWidth(), h / sceneCanvas:getHeight())
        love.graphics.setBlendMode('alpha')
        love.graphics.setShader()
        love.graphics.pop()
    end

    -- the light on everything (Mipos too): darker under rain and storm, warmer in heat
    local _, _, _, lightNow, warm = airColours(n)
    if lightNow < 0.999 or n.heat > 0.01 then
        love.graphics.setBlendMode('multiply', 'premultiplied')
        love.graphics.setColor(lightNow * warm[1], lightNow * warm[2], lightNow * warm[3], 1)
        love.graphics.rectangle('fill', x1 - 50, y1 - 50, x2 - x1 + 100, y2 - y1 + 100)
        love.graphics.setBlendMode('alpha')
    end

    drawRain(sc, true, light)
    drawSnow(sc, true)
    drawSwirls(sc)

    -- lightning: the bolt, then the whole sky lit for a moment
    if sc.bolt then
        local a = 1 - sc.bolt.t / 0.35
        love.graphics.setLineWidth(14)
        love.graphics.setColor(0.7, 0.75, 1, a * 0.4)
        love.graphics.line(sc.bolt.pts)
        love.graphics.setLineWidth(5)
        love.graphics.setColor(1, 1, 0.9, a)
        love.graphics.line(sc.bolt.pts)
    end
    if sc.flash > 0 then
        local f = sc.flash * (0.6 + 0.4 * math.sin(sc.flash * 30))
        veil({ 1, 1, 1 }, f * 0.35, x1, y1, x2, y2)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local SLIDERS = {
    { key = 'clouds', min = 0, max = 1 },
    { key = 'rain', min = 0, max = 1 },
    { key = 'snow', min = 0, max = 1 },
    { key = 'fog', min = 0, max = 1 },
    { key = 'wind', min = -1, max = 1 },
    { key = 'heat', min = 0, max = 1 },
    { key = 'storm', min = 0, max = 1 },
    { key = 'blend', min = 0.2, max = 15, settings = true },
    { key = 'push', min = 0, max = 3, settings = true },
}

function s.drawUI()
    local sc = state.weatherScene
    if not (sc and state.playMode) then return end
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(string.format('%s%s   1 clear 2 windy 3 rain 4 storm 5 fog 6 snow 7 heat   a machine  m b r h',
        sc.weather, sc.auto and ' (machine)' or ''), 20, 20)
    if not sc.showPanel then return end
    ui.startFrame()
    local BH, pad, colW = 34, 8, 330
    local rows = math.ceil(#SLIDERS / 2)
    local w = colW * 2 + pad * 3
    local h = (BH + pad) * rows + pad + 20
    local _, sh = love.graphics.getDimensions()
    local x0, y0 = 20, sh - h - 20
    ui.panel(x0, y0, w, h, '•• weather ••', function()
        local top = y0 + pad + 20
        for k, sl in ipairs(SLIDERS) do
            local x = x0 + pad + ((k - 1) % 2) * (colW + pad)
            local y = top + math.floor((k - 1) / 2) * (BH + pad)
            local tbl = sl.settings and sc.settings or sc.target
            local v = ui.sliderWithInput('weather' .. sl.key, x, y, 150, sl.min, sl.max, tbl[sl.key])
            if v and v ~= tbl[sl.key] then
                tbl[sl.key] = v
                if not sl.settings then sc.auto = false end
            end
            ui.label(x + 250, y, sl.key)
        end
    end)
end

return s
