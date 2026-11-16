-- floats: floats or sinks? The encyclopedia experiment: throw things from the table into a glass tub of water.
-- A duck, a beach ball, a cork, a wooden block, an apple, an ice cube, an egg, a sponge, a stone, a key and a
-- coin on a table beside a tub (props.makeBath, the engine's level water, src/liquid.lua), and a Mipo.
--
-- Floating here is honest: the engine's water (W4, liquid.floatIn) lifts by the body's own mass, so
-- everything floats alike. Here its lift is off (extra.buoyancy = 0; its drag and the surface's splash
-- stay) and this script lifts each fixture by the water it displaces: the part of its polygon under the
-- surface (clipped like floatIn does) x the water's density x g, at the middle of that part. So a thing
-- lighter than water floats, as deep as its density says (ice ~9/10 under), and a heavier one sinks: an egg
-- slowly, a stone or a key fast. The sponge soaks up water and sinks after a few seconds; out of the water it
-- dries and floats again. Going in fast throws a crown of drops and goes bloop; sinking things trail bubbles.
--
-- play mode (tab): pick a thing up and throw it in. keys: r everything back on the table, m a Mipo at the
-- mouse. The panel: the water's density and each thing's density and what it's doing.

local s = {}

local FLOOR_Y = 0
local TUB_X, TUB_SCALE = 700, 1.6          -- makeBath: 1000 x 380 at scale 1
local TUB_W, TUB_H = 1000 * TUB_SCALE, 380 * TUB_SCALE
local TABLE_X1, TABLE_X2, TABLE_TOP = -2300, -350, -520

-- The things, in kitchen-encyclopedia densities (water = 1). Shapes in local units around their middle.
local function ellipse(rx, ry, n)
    local out = {}
    for k = 0, (n or 14) - 1 do
        local a = k / (n or 14) * math.pi * 2
        out[#out + 1] = math.cos(a) * rx
        out[#out + 1] = math.sin(a) * ry
    end
    return out
end
local function rect(w, h)
    return { -w / 2, -h / 2, w / 2, -h / 2, w / 2, h / 2, -w / 2, h / 2 }
end
local DUCK = { -85, -10, -60, 30, 40, 40, 90, 10, 95, -25, 70, -20, 60, -55, 40, -85, 10, -90, -10, -65, 0, -30,
    -40, -20, -75, -40 }
local STONE = { -70, -20, -40, -50, 20, -55, 65, -25, 70, 20, 30, 50, -30, 48, -68, 25 }

local THINGS = {
    { name = 'duck', density = 0.3, outline = DUCK, color = { 1, 0.85, 0.2 } },
    { name = 'ball', density = 0.08, radius = 95, color = { 0.95, 0.35, 0.35 } },
    { name = 'cork', density = 0.24, outline = rect(55, 80), color = { 0.8, 0.62, 0.42 } },
    { name = 'block', density = 0.6, outline = rect(180, 110), color = { 0.85, 0.65, 0.4 } },
    { name = 'apple', density = 0.85, radius = 70, color = { 0.55, 0.8, 0.25 } },
    { name = 'ice', density = 0.92, outline = rect(110, 110), color = { 0.85, 0.95, 1 }, alpha = 0.75 },
    { name = 'egg', density = 1.08, outline = ellipse(55, 72), color = { 0.98, 0.95, 0.88 } },
    { name = 'sponge', density = 0.3, wet = 1.35, outline = rect(160, 90), color = { 1, 0.9, 0.3 } },
    { name = 'stone', density = 2.6, outline = STONE, color = { 0.55, 0.55, 0.58 } },
    { name = 'key', density = 7.8, outline = rect(160, 34), color = { 0.85, 0.75, 0.3 } },
    { name = 'coin', density = 8.9, outline = rect(80, 16), color = { 0.9, 0.8, 0.35 } },
}

-- thick: water's own drag, by the water a thing pushes aside (not by its mass, as the engine's drag is), so a
-- light thing that leaps up out of a dive settles instead of bouncing out of the tub
local tune = { water = 1, thick = 4, soak = 0.25, dry = 0.08 }

local function fl()
    state.floats = state.floats or { things = {}, mipos = {}, drops = {}, bubbles = {} }
    return state.floats
end

local function alive(body) return body and not body:isDestroyed() end

local function liquidExtra(body)
    for _, f in ipairs(body:getFixtures()) do
        local ud = f:getUserData()
        if ud and ud.extra and ud.subtype == 'liquid' then return ud.extra end
    end
end

local function setDensity(body, d)
    for _, f in ipairs(body:getFixtures()) do
        if not f:isSensor() and f:getUserData() == nil then f:setDensity(d) end
    end
    body:resetMassData()
end

local function spawnThing(sd, def, x, y)
    local thing
    if def.radius then
        thing = objectManager.addThing('circle', { x = x, y = y, radius = def.radius, label = 'floats-' .. def.name })
    else
        local verts = {}
        for i = 1, #def.outline, 2 do
            verts[i], verts[i + 1] = def.outline[i] + x, def.outline[i + 1] + y
        end
        thing = objectManager.addThing('custom', { x = x, y = y, vertices = verts, label = 'floats-' .. def.name })
    end
    if not thing then return end
    local body = thing.body
    setDensity(body, def.density)
    for _, f in ipairs(body:getFixtures()) do
        if not f:isSensor() then
            f:setFriction(0.6)
            f:setRestitution(def.name == 'ball' and 0.5 or 0.1)
        end
    end
    local entry = { def = def, body = body, density = def.density, home = { x, y } }
    -- drawn by this script (drawThing), not as a grey body (src/physics/box2d-draw.lua showsBody); a plain
    -- table, the env has no setmetatable: stockThings takes the old ones out
    state.hiddenBodies = state.hiddenBodies or {}
    state.hiddenBodies[body] = true
    if def.outline then -- the outline in the body's own frame, to draw it whole (the fixtures are its pieces)
        entry.outline = {}
        for i = 1, #def.outline, 2 do
            local lx, ly = body:getLocalPoint(def.outline[i] + x, def.outline[i + 1] + y)
            entry.outline[i], entry.outline[i + 1] = lx, ly
        end
        local ok, tris = pcall(love.math.triangulate, entry.outline)
        entry.tris = ok and tris or nil
    end
    sd.things[#sd.things + 1] = entry
end

local function spawnTable(sd)
    local w = TABLE_X2 - TABLE_X1
    local top = objectManager.addThing('rectangle', { x = (TABLE_X1 + TABLE_X2) / 2, y = TABLE_TOP + 30,
        width = w, height = 60, bodyType = 'static', label = 'floats-table' })
    sd.fixed[#sd.fixed + 1] = top and top.body
    for _, x in ipairs({ TABLE_X1 + 60, TABLE_X2 - 60 }) do
        local leg = objectManager.addThing('rectangle', { x = x, y = (TABLE_TOP + 60 + FLOOR_Y) / 2, width = 60,
            height = FLOOR_Y - TABLE_TOP - 60, bodyType = 'static', label = 'floats-table' })
        sd.fixed[#sd.fixed + 1] = leg and leg.body
    end
end

local function stockThings(sd)
    for _, t in ipairs(sd.things) do
        if state.hiddenBodies then state.hiddenBodies[t.body] = nil end
        if alive(t.body) then objectManager.destroyBody(t.body) end
    end
    sd.things = {}
    local n = #THINGS
    for k, def in ipairs(THINGS) do
        local x = TABLE_X1 + 130 + (k - 1) * (TABLE_X2 - TABLE_X1 - 260) / (n - 1)
        spawnThing(sd, def, x, TABLE_TOP - 120)
    end
end

local function build(sd)
    sd.fixed = {}
    local floor = objectManager.addThing('rectangle', { x = 0, y = FLOOR_Y + 100, width = 7000, height = 200,
        bodyType = 'static', label = 'floats-floor' })
    sd.fixed[#sd.fixed + 1] = floor and floor.body
    local tub = props.makeBath(TUB_X, FLOOR_Y - TUB_H / 2, TUB_SCALE)
    if tub then
        sd.tub = tub.body
        local extra = liquidExtra(tub.body)
        extra.fill = 0.72
        extra.buoyancy = 0 -- this script lifts by density (see the top)
        sd.fixed[#sd.fixed + 1] = tub.body
    end
    spawnTable(sd)
end

-- a short bloop, lower for bigger things (made once per size)
local bloops = {}
local function bloop(size)
    local k = math.max(1, math.min(4, math.floor(size / 60) + 1))
    if not bloops[k] then
        local rate, len = 44100, 0.16
        local data = love.sound.newSoundData(math.floor(rate * len), rate, 16, 1)
        local f0 = ({ 700, 520, 380, 260 })[k]
        local phase = 0
        for i = 0, data:getSampleCount() - 1 do
            local t = i / rate
            local f = f0 * (1 + 2.2 * t / len)        -- a bloop rises
            phase = phase + f / rate
            local env = math.min(1, t / 0.005) * math.exp(-t * 22)
            data:setSample(i, math.sin(phase * math.pi * 2) * env * 0.5)
        end
        bloops[k] = love.audio.newSource(data, 'static')
    end
    local src = bloops[k]:clone()
    src:setVolume(0.6)
    src:play()
end

local function areaCentroid(poly)
    local a, cx, cy = 0, 0, 0
    local n = #poly
    for i = 1, n, 2 do
        local x1, y1 = poly[i], poly[i + 1]
        local x2, y2 = poly[(i + 1) % n + 1], poly[(i + 2) % n + 1]
        local c = x1 * y2 - x2 * y1
        a = a + c
        cx, cy = cx + (x1 + x2) * c, cy + (y1 + y2) * c
    end
    if math.abs(a) < 1e-6 then return 0, 0, 0 end
    return math.abs(a) / 2, cx / (3 * a), cy / (3 * a)
end

local function fixturePolygon(body, shape)
    local kind = shape:getType()
    if kind == 'polygon' then return { body:getWorldPoints(shape:getPoints()) } end
    if kind == 'circle' then
        local cx, cy = body:getWorldPoint(shape:getPoint())
        local r, out = shape:getRadius(), {}
        for k = 0, 15 do
            local a = k / 16 * math.pi * 2
            out[k * 2 + 1], out[k * 2 + 2] = cx + math.cos(a) * r, cy + math.sin(a) * r
        end
        return out
    end
end

local function splash(sd, x, level, speed, size)
    local n = math.min(40, math.floor(speed / 60 * size / 60))
    for _ = 1, n do
        local a = -math.pi / 2 + (love.math.random() - 0.5) * 1.6
        local v = speed * (0.3 + love.math.random() * 0.5)
        sd.drops[#sd.drops + 1] = { x = x + (love.math.random() - 0.5) * size, y = level, vx = math.cos(a) * v,
            vy = math.sin(a) * v, r = 6 + love.math.random() * 10, life = 1 }
    end
    if n > 0 then bloop(size) end
end

-- Each fixture lifted by the water it displaces; what's in the water and how deep (for the panel, soaking
-- and splashes).
local function floatAll(sd)
    local extra = alive(sd.tub) and liquidExtra(sd.tub)
    if not extra then return end
    local level, water = liquid.water(extra, sd.tub)
    if not level or #water < 6 then return end
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #water, 2 do
        x1, x2 = math.min(x1, water[i]), math.max(x2, water[i])
        y1, y2 = math.min(y1, water[i + 1]), math.max(y2, water[i + 1])
    end
    sd.level, sd.waterX1, sd.waterX2 = level, x1, x2
    local seen = {}
    world:queryBoundingBox(x1, y1, x2, y2, function(fixture)
        local body = fixture:getBody()
        if body:getType() == 'dynamic' then seen[body] = true end
        return true
    end)
    local meter = love.physics.getMeter()
    local _, gy = world:getGravity()
    local rho = tune.water / (meter * meter) -- Box2D's mass is density x area / meter^2
    sd.share = sd.share or {} -- by body; pruned below when a body leaves the water
    for body in pairs(seen) do
        local wetArea, totalArea = 0, 0
        for _, fixture in ipairs(body:getFixtures()) do
            local poly = not fixture:isSensor() and fixture:getUserData() == nil and fixture:getDensity() > 0
                and fixturePolygon(body, fixture:getShape())
            if poly and #poly >= 6 then
                totalArea = totalArea + areaCentroid(poly)
                local inside = liquid._clipConvex(poly, water)
                if #inside >= 6 then
                    local area, cx, cy = areaCentroid(inside)
                    if area > 0 then
                        wetArea = wetArea + area
                        local vx, vy = body:getLinearVelocityFromWorldPoint(cx, cy)
                        local k = rho * area * tune.thick
                        body:applyForce(-vx * k, -rho * area * gy - vy * k, cx, cy)
                    end
                end
            end
        end
        local share = totalArea > 0 and wetArea / totalArea or 0
        local was = sd.share[body] or 0
        if share > 0 and was == 0 then
            local _, vy = body:getLinearVelocity()
            local bx = body:getPosition()
            if vy > 250 then splash(sd, bx, level, vy, math.sqrt(totalArea)) end
        end
        sd.share[body] = share
    end
    for body in pairs(sd.share) do
        if not seen[body] then sd.share[body] = nil end
    end
end

-- the sponge soaks up water while it's in it, and dries out of it
local function soak(sd, dt)
    for _, t in ipairs(sd.things) do
        if t.def.wet and alive(t.body) then
            local share = sd.share and sd.share[t.body] or 0
            t.soaked = t.soaked or 0
            if share > 0.3 then
                t.soaked = math.min(1, t.soaked + tune.soak * dt * share)
            else
                t.soaked = math.max(0, t.soaked - tune.dry * dt)
            end
            local d = t.def.density + (t.def.wet - t.def.density) * t.soaked
            if math.abs(d - t.density) > 0.01 then
                t.density = d
                setDensity(t.body, d)
            end
        end
    end
end

local function stepParticles(sd, dt)
    local _, gy = world:getGravity()
    local keep = {}
    for _, d in ipairs(sd.drops) do
        d.vy = d.vy + gy * dt
        d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
        d.life = d.life - dt * 0.8
        local fell = sd.level and d.vy > 0 and d.y > sd.level and d.x > sd.waterX1 and d.x < sd.waterX2
        if d.life > 0 and not fell and d.y < FLOOR_Y then keep[#keep + 1] = d end
    end
    sd.drops = keep
    -- bubbles from things sinking under the surface
    for _, t in ipairs(sd.things) do
        local share = alive(t.body) and sd.share and sd.share[t.body] or 0
        if share > 0.95 then
            local _, vy = t.body:getLinearVelocity()
            if vy > 40 and love.math.random() < math.min(0.5, vy / 1500) then
                local x, y = t.body:getPosition()
                sd.bubbles[#sd.bubbles + 1] = { x = x + (love.math.random() - 0.5) * 60, y = y - 30,
                    r = 5 + love.math.random() * 9, wob = love.math.random() * 6 }
            end
        end
    end
    keep = {}
    for _, b in ipairs(sd.bubbles) do
        b.y = b.y - (120 + b.r * 12) * dt
        b.wob = b.wob + dt * 7
        if sd.level and b.y > sd.level then keep[#keep + 1] = b end
    end
    sd.bubbles = keep
end

function s.onStart()
    worldState.paused = false
    local sd = fl()
    if not alive(sd.tub) then build(sd) end
    local things = {}
    for _, t in ipairs(sd.things) do
        if alive(t.body) then things[#things + 1] = t end
    end
    sd.things = things
    if #sd.things == 0 then stockThings(sd) end
    sd.mipos = mipoKit.alive(sd.mipos)
    if #sd.mipos == 0 then mipoKit.spawn(sd.mipos, 2100, FLOOR_Y - 500) end
    camera.setBounds(-2700, -2200, 2700, 300)
    camera.zoomTo(0.27, 0.5)
end

function s.onKeyPress(key)
    if not state.playMode then return end
    local sd = fl()
    if key == 'r' then
        stockThings(sd)
    elseif key == 'm' then
        local mx, my = mouseWorldPos()
        mipoKit.spawn(sd.mipos, mx, my)
    end
end

function s.update(dt)
    local sd = fl()
    floatAll(sd)
    soak(sd, dt)
    stepParticles(sd, dt)
end

-- what a thing is doing, for the panel
local function doing(sd, t)
    if not alive(t.body) then return '-' end
    local share = sd.share and sd.share[t.body] or 0
    if share == 0 then return '' end
    local _, vy = t.body:getLinearVelocity()
    if share < 0.98 then return math.abs(vy) < 30 and 'floats' or 'bobbing' end
    if vy > 15 then return 'sinking' end
    if vy < -15 then return 'rising' end
    return 'on the bottom'
end

local function drawThing(t)
    local body = t.body
    if not alive(body) then return end
    local def = t.def
    local c = def.color
    -- a soaked sponge goes darker
    local dark = 1 - 0.35 * (t.soaked or 0)
    love.graphics.push()
    love.graphics.translate(body:getPosition())
    love.graphics.rotate(body:getAngle())
    love.graphics.setColor(c[1] * dark, c[2] * dark, c[3] * dark, def.alpha or 1)
    if def.radius then
        love.graphics.circle('fill', 0, 0, def.radius)
        love.graphics.setColor(0.2, 0.15, 0.1, 1)
        love.graphics.circle('line', 0, 0, def.radius)
        if def.name == 'ball' then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.arc('fill', 0, 0, def.radius, -0.6, 0.6)
            love.graphics.arc('fill', 0, 0, def.radius, math.pi - 0.6, math.pi + 0.6)
            love.graphics.setColor(0.2, 0.15, 0.1, 1)
            love.graphics.circle('line', 0, 0, def.radius)
        elseif def.name == 'apple' then
            love.graphics.setColor(0.4, 0.25, 0.1, 1)
            love.graphics.setLineWidth(8)
            love.graphics.line(0, -def.radius + 10, 8, -def.radius - 25)
            love.graphics.setLineWidth(1)
        end
    elseif t.outline then
        for _, tri in ipairs(t.tris or {}) do love.graphics.polygon('fill', tri) end
        love.graphics.setColor(0.2, 0.15, 0.1, 1)
        love.graphics.setLineWidth(4)
        love.graphics.polygon('line', t.outline)
        love.graphics.setLineWidth(1)
        if def.name == 'duck' then
            love.graphics.circle('fill', 55, -60, 7)
            love.graphics.setColor(1, 0.55, 0.1, 1)
            love.graphics.polygon('fill', 88, -45, 120, -35, 90, -22)
        elseif def.name == 'sponge' then
            love.graphics.setColor(0.6, 0.5, 0.1, 0.6)
            for k = 1, 9 do love.graphics.circle('fill', ((k * 37) % 130) - 65, ((k * 23) % 60) - 30, 6) end
        elseif def.name == 'key' then
            love.graphics.setColor(0.2, 0.15, 0.1, 1)
            love.graphics.circle('line', -60, 0, 10)
        end
    end
    love.graphics.pop()
end

-- the things go under the tub's water (drawn in front of everything by the engine)
function s.drawBelow()
    local sd = state.floats
    if not sd then return end
    -- the tub's glass: a pale back pane
    love.graphics.setColor(0.85, 0.93, 0.97, 0.5)
    love.graphics.rectangle('fill', TUB_X - TUB_W / 2, FLOOR_Y - TUB_H, TUB_W, TUB_H)
    for _, t in ipairs(sd.things) do drawThing(t) end
    love.graphics.setColor(1, 1, 1, 1)
end

function s.draw()
    local sd = state.floats
    if not sd then return end
    love.graphics.setColor(1, 1, 1, 0.75)
    for _, b in ipairs(sd.bubbles) do
        love.graphics.circle('line', b.x + math.sin(b.wob) * 6, b.y, b.r)
    end
    love.graphics.setColor(0.45, 0.72, 0.92, 0.9)
    for _, d in ipairs(sd.drops) do love.graphics.circle('fill', d.x, d.y, d.r * math.max(0.3, d.life)) end
    -- the glass's front: its rim and a shine
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.setLineWidth(18)
    love.graphics.line(TUB_X - TUB_W / 2 + 70, FLOOR_Y - TUB_H + 60, TUB_X - TUB_W / 2 + 70, FLOOR_Y - 80)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function s.drawUI()
    local sd = state.floats
    if not (sd and state.playMode) then return end
    ui.startFrame()
    local BH, pad, w = 26, 4, 300
    local rows = #sd.things + 3
    local h = BH * rows + pad * (rows + 1) + 20
    local x0, y0 = 20, 20
    ui.panel(x0, y0, w, h, '•• floats ••', function()
        local layout = ui.createLayout({ type = 'columns', spacing = pad, startX = x0 + pad, startY = y0 + pad + 20 })
        local x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        local v = ui.sliderWithInput('floatswater', x, y, 140, 0.5, 3, tune.water)
        if v then tune.water = v + 0 end
        ui.label(x + 240, y, 'water')
        for _, t in ipairs(sd.things) do
            x, y = ui.nextLayoutPosition(layout, w - 20, BH)
            ui.label(x, y, string.format('%-7s %.2f  %s', t.def.name, t.density, doing(sd, t)))
        end
        x, y = ui.nextLayoutPosition(layout, w - 20, BH)
        ui.label(x, y, 'r things back   m Mipo')
    end)
end

return s
